import winim, os, osproc, strformat, tables, algorithm, strutils, times, cligen, flatty/hexPrint, flatty/binny, print

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

proc parseCallGraph(): Table[string, TableRef[string, int]] =
  let output = readFile("dump.txt")
  var lines = output.split("\n")
  var regionName = ""
  for num, line in lines:
    if '<' in line and ">:" in line:
      let
        arr = line.split(" ", 1)
      var
        name = arr[1]
      if name != "":
        name = name.strip()[1..^3]
        # let firstPart = name.split("__")[0]
        # if firstPart != "":
        #   name = firstPart
      #print name
      regionName = name
      result[regionName] = newTable[string, int]()
    if line.endsWith(">") and ("#" in line or "callq" in line):
      let name = line.split("<",1)[1][0..^2]
      if not name.startsWith(".rdata"):
        #print ">>>", name
        result[regionName][name] = 1



proc parseDumpLines(exePath: string, rollUp: RollUpKind): seq[DumpLine] =
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
        name = name.strip()[1..^3]#.split("__")[0]
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
import print

proc addressToDumpLine(dumpLines: seq[DumpLine], address: uint64): DumpLine =
  for line in dumpLines:
    if line.address <= address and address <= line.addressEnd:
      #print line.address, "<=", address, "<=", line.addressEnd
      return line

proc sample(
  cpuSamples: var int,
  cpuHotAddresses: var Table[DWORD64, int],
  cpuHotStacks: var Table[seq[uint64], int],
  pid: int,
  threadIds: seq[int],
  dumpLine: seq[DumpLine],
  callGraph: Table[string, TableRef[string, int]]
) =
  #for threadId in threadIds:
  block:
    let threadId = threadIds[0]
    var processHandle = OpenProcess(PROCESS_ALL_ACCESS, false, pid.DWORD)
    var threadHandle = OpenThread(
      THREAD_ALL_ACCESS,
      false,
      threadId.DWORD
    )

    var context: CONTEXT
    context.ContextFlags = CONTEXT_ALL

    SuspendThread(threadHandle)
    GetThreadContext(
      threadHandle,
      context.addr
    )

    var prevFun = ""

    # # ---------------------------------------
    block:
      var stackSize = 512 * 10
      var stack = newString(stackSize)
      var bytesRead: SIZE_T
      let startAddress = context.Rsp
      ReadProcessMemory(
        hProcess = processHandle,
        lpBaseAddress = cast[LPCVOID](startAddress),
        lpBuffer = cast[LPCVOID](stack[0].addr),
        nSize = stackSize,
        lpNumberOfBytesRead = bytesRead.addr)
      doAssert bytesRead == stackSize

      # for i in 0 ..< stackSize:
      #   #let at = cast[ptr[char]](context.Rsp + i - 16)
      #   let at = cast[ptr[char]](context.Rsp + i)
      #   stack[i] = at[]
      #echo hexPrint(stack, context.Rsp.int + 8 - stackSize)
      var i = 0
      print "---"
      let dl = dumpLine.addressToDumpLine(context.Rip.uint64)
      prevFun = dl.text.split(" @ ")[0]
      print prevFun
      while i + 8 < stack.len:
        let value = stack.readUInt64(i)
        let address = startAddress + i
        #print address.toHex(), value.toHex()
        let dl = dumpLine.addressToDumpLine(value)
        if dl.text != "":
          let thisFun = dl.text.split(" @ ")[0]
          let canCall = prevFun in callGraph[thisFun]
          #print thisFun, callGraph[thisFun]
          #print "can", thisFun, "call", prevFun, "?", canCall
          #print dl
          if canCall:
            prevFun = thisFun
            print thisFun
          else:
            discard
            #print "skip"

        if "stdlib_ioInit000" in dl.text:
          break
        # if startAddress.uint64 <= value and value <= (startAddress + stackSize).uint64:
        #   print "^ points to stack"
          #i = value.int - startAddress.int
        # if address == context.Rsp:
        #   print "^ RSP ^^^^^^^^^"
        i += 8

    # ---------------------------------------
    # block:
    #   # proc StackWalk64*(MachineType: DWORD, hProcess: HANDLE, hThread: HANDLE, StackFrame: LPSTACKFRAME64, ContextRecord: PVOID, ReadMemoryRoutine: PREAD_PROCESS_MEMORY_ROUTINE64, FunctionTableAccessRoutine: PFUNCTION_TABLE_ACCESS_ROUTINE64, GetModuleBaseRoutine: PGET_MODULE_BASE_ROUTINE64, TranslateAddress: PTRANSLATE_ADDRESS_ROUTINE64): WINBOOL {.winapi, stdcall, dynlib: "dbghelp", importc.}
    #   var stack: STACKFRAME64
    #   #var stack = cast[ptr[STACKFRAME64]](alloc(sizeof(STACKFRAME64)))

    #   stack.AddrPC.Offset    = context.Rip
    #   stack.AddrPC.Mode      = addrModeFlat
    #   stack.AddrStack.Offset = context.Rsp
    #   stack.AddrStack.Mode   = addrModeFlat
    #   stack.AddrFrame.Offset = context.Rbp  # This value is not always used.
    #   stack.AddrFrame.Mode   = addrModeFlat
    #   stack.Virtual          = true

    #   echo "---"
    #   print stack.AddrPC.Offset.toHex, stack.AddrStack.Offset.toHex, stack.AddrFrame.Offset.toHex

    #   while true:
    #     SetLastError(0)
    #     let stackRes = StackWalk64(
    #       IMAGE_FILE_MACHINE_AMD64,
    #       processHandle,
    #       threadHandle,
    #       stack,
    #       context.addr,
    #       nil,
    #       SymFunctionTableAccess64,
    #       SymGetModuleBase64,
    #       nil
    #     )

    #     print stackRes, stack.AddrPC.Offset.toHex, stack.AddrStack.Offset.toHex, stack.AddrFrame.Offset.toHex

    #     if stackRes == 0:
    #       break

    ResumeThread(threadHandle)
    if context.Rip notin cpuHotAddresses:
      cpuHotAddresses[context.Rip] = 1
    else:
      cpuHotAddresses[context.Rip] += 1
    inc cpuSamples

    # if stackPCs notin cpuHotStacks:
    #   cpuHotStacks[stackPCs] = 1
    # else:
    #   cpuHotStacks[stackPCs] += 1

    CloseHandle(threadHandle)
    CloseHandle(processHandle)



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
    let dumpLine = parseDumpLines(exePath, Regions)
    let callGraph = parseCallGraph()

    var
      p = startProcess(exePath, options={poParentStreams})
      pid = p.processID()
      threadIds = getThreadIds(pid)
      startTime = epochTime()
      cpuSamples: int
      cpuHotAddresses = Table[DWORD64, int]()
      cpuHotStacks = Table[seq[uint64], int]()

    while p.running:
      sample(cpuSamples, cpuHotAddresses, cpuHotStacks, pid, threadIds, dumpLine, callGraph)
      for j in 0 .. 1_000_000:
        g += j
      sleep(10)
    var
      exitTime = epochTime()
    p.close()

    # for stack, count in cpuHotStacks:
    #   print "--"
    #   for address in stack:
    #     #print address
    #     let dl = dumpLineArr.addressToDumpLine(address)
    #     #print dl
    #     #if dl.text != "":
    #     print address, dl.text

    quit()

    let samplesPerSecond = (exitTime - startTime) / cpuSamples.float64

    if addresses:
      dumpScan(parseDumpLines(exePath, Addresses), cpuHotAddresses, samplesPerSecond)
    if procedures:
      dumpScan(parseDumpLines(exePath, Procs), cpuHotAddresses, samplesPerSecond)
    if regions:
      dumpScan(parseDumpLines(exePath, Regions), cpuHotAddresses, samplesPerSecond)
    if lines or not(addresses or procedures or regions):
      dumpScan(parseDumpLines(exePath, Lines), cpuHotAddresses, samplesPerSecond)

when isMainModule:
  dispatch(
    hottie,
    help = {
      "addresses": "profile by assembly instruction addresses",
      "lines": "profile by source lines (default)",
      "procedures": "profile by inlined and regular procedure definitions",
      "regions": "profile by regular procedure definitions only"
    }
  )
