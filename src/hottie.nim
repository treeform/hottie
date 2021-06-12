import winim, os, osproc, strformat, tables, algorithm, strutils, times, cligen

when defined(windows):
  import hottie/windows
elif defined(linux):
  import hottie/linux
else:
  {.error: "Hottie does not support this OS consider porting it!".}


proc runObjDump(exePath: string) =
  # Run object dump if the dump file does not exist, is old or of different exe.
  if not fileExists("dump.txt") or
    getLastModificationTime("dump.txt") < getLastModificationTime(exePath) or
    readFile("dump.txt").split(":", 1)[0].strip() != exePath:
      echo "Running objdump..."
      let (output, code) = execCmdEx("objdump -dl " & exePath)
      writeFile("dump.txt", output)

proc parseCallGraph(): CallGraph =
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
      regionName = name
      result[regionName] = newTable[string, int]()
    if line.endsWith(">") and ("#" in line or "callq" in line):
      let name = line.split("<",1)[1][0..^2]
      if not name.startsWith(".rdata"):
        result[regionName][name] = 1

proc parseDumpLines(rollUp: RollUpKind): seq[DumpLine] =
  let output = readFile("dump.txt")
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

proc dumpTable(
  cpuHotPathsArr: var seq[(string, int)],
  samplesPerSecond: float64,
  cpuSamples: int,
  numLines: int
) =
  cpuHotPathsArr.sort proc(a, b: (string, int)): int = b[1] - a[1]
  echo " samples           time   percent what"
  for p in cpuHotPathsArr[0 ..< min(cpuHotPathsArr.len, numLines)]:
    let
      samples = p[1]
      time = (samples.float64 / samplesPerSecond) * 1000
      per = samples.float64 / cpuSamples.float64 * 100
      text = p[0]
    echo strformat.`&`("{p[1]:8} {time:12.3f}ms {per:8.3f}% {text}")

proc dumpScan(
  dumpLines: seq[DumpLine],
  cpuHotAddresses: Table[int64, int],
  samplesPerSecond: float64,
  cpuSamples: int,
  numLines: int
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
  dumpTable(cpuHotPathsArr, samplesPerSecond, cpuSamples, numLines)

proc dumpStacks(
  cpuHotStacks: Table[string, int],
  samplesPerSecond: float,
  cpuSamples: int,
  numLines: int
) =
  var cpuHotPathsArr = newSeq[(string, int)]()
  for k, v in cpuHotStacks:
    cpuHotPathsArr.add((k, v))
  dumpTable(cpuHotPathsArr, samplesPerSecond, cpuSamples, numLines)

var spinVar: uint64

proc hottie(
  workingDir: string = "",
  rate = 1000,
  numLines = 30,
  stacks = false,
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
    runObjDump(exePath)
    var dumpLine: seq[DumpLine]
    var callGraph: CallGraph
    if stacks:
      dumpLine = parseDumpLines(Regions)
      callGraph = parseCallGraph()
    var
      p = startProcess(exePath, options={poParentStreams})
      pid = p.processID()
      threadIds = getThreadIds(pid)
      startTime = epochTime()
      cpuSamples: int
      cpuHotAddresses = Table[DWORD64, int]()
      cpuHotStacks = Table[string, int]()

    while p.running:
      let startSample = epochTime()
      sample(cpuSamples, cpuHotAddresses, cpuHotStacks, pid, threadIds, dumpLine, callGraph, stacks)
      # Wait to approach the user supplied sampling rate.
      while startSample + 1/rate.float64 * 0.8 > epochTime():
        spinVar += 1

    let
      exitTime = epochTime()
      totalTime = exitTime - startTime
    p.close()

    let samplesPerSecond = cpuSamples.float64 / (totalTime)

    if stacks:
      dumpStacks(cpuHotStacks, samplesPerSecond, cpuSamples, numLines)
    elif addresses:
      dumpScan(parseDumpLines(Addresses), cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    elif procedures:
      dumpScan(parseDumpLines(Procs), cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    elif regions:
      dumpScan(parseDumpLines(Regions), cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    else: #lines:
      dumpScan(parseDumpLines(Lines), cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)

    echo strformat.`&`"Samples per second: {samplesPerSecond:.1f} totalTime: {totalTime:.3f}ms"

when isMainModule:
  dispatch(
    hottie,
    help = {
      "rate": "target rate per second (faster not always possible)",
      "numLines": "number of lines to display",
      "stacks": "profile by stack traces",
      "addresses": "profile by assembly instruction addresses",
      "lines": "profile by source lines (default)",
      "procedures": "profile by inlined and regular procedure definitions",
      "regions": "profile by 'C' stack framed procedure definitions only"
    }
  )
