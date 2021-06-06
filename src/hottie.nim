import winim, os, osproc, strformat, tables, algorithm, strutils, times, cligen

type
  RollUpKind = enum
    Addresses
    Lines
    Procs
    Regions

  DumpLineKind = enum
    dlAsm
    dlFunction
    dlPath

  DumpLine = object
    kind: DumpLineKind
    address: uint64
    addressEnd: uint64
    text: string

proc dumpLines(exePath: string, rollUp: RollUpKind): seq[DumpLine] =
  let (output, code) = execCmdEx("objdump -dl " & exePath)
  writeFile("dump.txt", output)

  var lines = output.split("\n")
  for num, line in lines:
    proc dumpLink(): string =
      "dump.txt".absolutePath & ":" & $(num + 1)

    if '<' in line and ">:" in line:
      # Regions (big not-inline functions)
      let
        arr = line.split(" ", 1)
      var
        name = arr[1]
      if name != "":
        name = name.strip()[1..^3].split("__")[0]
      if rollUp == Regions:
        result.add DumpLine(
          kind: dlFunction,
          address: 0,
          text: name & " @ " & dumpLink()
        )
    elif "():" in line:
      # Inline function
      let name = line.split("():")[0].split("__")[0]
      if rollUp == Procs:
        result.add DumpLine(
          kind: dlFunction,
          address: 0,
          text: name,
        )
    elif "/" in line:
      # Source code lines
      if rollUp == Lines:
        result.add DumpLine(
          kind: dlPath,
          address: 0,
          text: line.normalizedPath,
        )
    elif line.startsWith("  ") and ":" in line:
      # Assembly instructions.
      let
        arr = line.split(":", 1)
      let
        address = fromHex[uint64](arr[0].strip())
      if rollUp == Addresses:
        result.add DumpLine(
          kind: dlAsm,
          address: address,
          text: dumpLink()
        )
      if result.len > 0:
        if result[^1].address == 0:
          result[^1].address = address
        result[^1].addressEnd = address

    elif "Dwarf Error" in line:
      continue
    elif "Disassembly of section" in line:
      continue
    elif "file format" in line:
      continue
    elif line.strip() == "":
      continue
    elif "..." in line:
      continue
    else:
      quit("Failed to parse objdump line:" & line)

proc getThreadIds(pid: int): seq[int] =
  var h = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, DWORD(pid))
  if h != INVALID_HANDLE_VALUE:
    var te: THREADENTRY32
    te.dwSize = DWORD(sizeof(te))
    var valid = Thread32First(h, te.addr)
    while valid == 1:
      if te.th32OwnerProcessID == DWORD(pid):
        result.add te.th32ThreadID
      valid = Thread32Next(h, te.addr)
    CloseHandle(h)

proc sample(
  cpuSamples: var int,
  cpuHotAddresses: var Table[DWORD64, int],
  pid: int,
  threadIds: seq[int]
) =
  #for threadId in threadIds:
  block:
    let threadId = threadIds[0]
    var threadHandle = OpenThread(
      THREAD_ALL_ACCESS,
      false,
      threadId.DWORD
    )

    var context: CONTEXT
    context.ContextFlags = CONTEXT_CONTROL

    SuspendThread(threadHandle)
    GetThreadContext(
      threadHandle,
      context.addr
    )
    ResumeThread(threadHandle)
    if context.Rip notin cpuHotAddresses:
      cpuHotAddresses[context.Rip] = 1
    else:
      cpuHotAddresses[context.Rip] += 1
    inc cpuSamples

proc addressToDumpLine(dumpLines: seq[DumpLine], address: uint64): DumpLine =
  for line in dumpLines:
    if line.address >= address and address <= line.addressEnd:
      return line

proc dumpScan(
  dumpLines: seq[DumpLine],
  cpuHotAddresses: Table[DWORD64, int],
  samplesPerSecond: float64
) =
  var cpuHotPaths: Table[string, int]
  for address, count in cpuHotAddresses:
    let dumpLine = dumpLines.addressToDumpLine(address.uint64)
    if dumpLine.text notin cpuHotPaths:
      cpuHotPaths[dumpLine.text] = count
    else:
      cpuHotPaths[dumpLine.text] += count

  var cpuHotPathsArr = newSeq[(string, int)]()
  for k, v in cpuHotPaths:
    cpuHotPathsArr.add((k, v))
  cpuHotPathsArr.sort proc(a, b: (string, int)): int = b[1] - a[1]

  echo " samples       time  path"
  for p in cpuHotPathsArr[0 ..< min(cpuHotPathsArr.len, 30)]:
    let
      time = (p[1].float64 * samplesPerSecond) * 1000
      text = p[0]
    echo strformat.`&`("{p[1]:8} {time:8.3}ms  {text}")

var g: int

proc hottie(
  workingDir: string = "",
  addresses = false,
  lines = false,
  procedures = false,
  regions = false,
  paths: seq[string]
) =
  if workingDir != "":
    setCurrentDir(workingDir)

  if paths.len == 0:
    echo "hottie [your.exe]"
    echo "See hottie --help for more details"

  for exePath in paths:
    var
      p = startProcess(exePath, options={poParentStreams})
      pid = p.processID()
      threadIds = getThreadIds(pid)
      startTime = epochTime()
      cpuSamples: int
      cpuHotAddresses = Table[DWORD64, int]()

    while p.running:
      sample(cpuSamples, cpuHotAddresses, pid, threadIds)
      for j in 0 .. 1_000_000:
        g += j
      sleep(0)
    var
      exitTime = epochTime()
    p.close()

    let samplesPerSecond = (exitTime - startTime) / cpuSamples.float64

    if addresses:
      dumpScan(dumpLines(exePath, Addresses), cpuHotAddresses, samplesPerSecond)
    if procedures:
      dumpScan(dumpLines(exePath, Procs), cpuHotAddresses, samplesPerSecond)
    if regions:
      dumpScan(dumpLines(exePath, Regions), cpuHotAddresses, samplesPerSecond)
    if lines or not(addresses or procedures or regions):
      dumpScan(dumpLines(exePath, Lines), cpuHotAddresses, samplesPerSecond)

when isMainModule:
  dispatch(
    hottie,
    help = {
      "addresses": "profile by assembly instruction addresses",
      "lines": "profile by source line (default)",
      "procedures": "profile by inlined and regular procedure definitions",
      "regions": "profile by regular procedure definitions only"
    }
  )
