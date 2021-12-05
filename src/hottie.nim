import algorithm, cligen, hottie/common, hottie/parser, os, osproc, strformat,
    strutils, tables, times, re

when defined(windows):
  import hottie/windows
elif defined(linux):
  import hottie/linux
else:
  import hottie/mac

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
  cpuHotAddresses: CountTable[uint64],
  samplesPerSecond: float64,
  cpuSamples: int,
  numLines: int
) =
  var cpuHotPaths: CountTable[string]
  for address, count in cpuHotAddresses:
    let dumpLine = dumpLines.addressToDumpLine(address.uint64)
    cpuHotPaths.inc(dumpLine.text, count)
  var cpuHotPathsArr = newSeq[(string, int)]()
  for k, v in cpuHotPaths:
    cpuHotPathsArr.add((k, v))
  dumpTable(cpuHotPathsArr, samplesPerSecond, cpuSamples, numLines)

proc dumpStacks(
  cpuHotStacks: CountTable[string],
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
  frames = false,
  paths: seq[string]
) =
  if workingDir != "":
    setCurrentDir(workingDir)

  if paths.len == 0:
    echo "hottie [your.exe]"
    echo "See hottie --help for more details"

  for exePath in paths:

    var dumpFile = getDumpFile(exePath)

    var
      p = startProcess(exePath, options = {poParentStreams})
      pid = p.processID()
      threadIds = getThreadIds(pid)
      startTime = epochTime()
      cpuSamples: int
      cpuHotAddresses = CountTable[uint64]()
      cpuHotStacks = CountTable[string]()

    when defined(macosx):
      let (output, ret) = execCmdEx("vmmap --wide " & $pid)
      for line in output.split("\n"):
        if line =~ re"__TEXT\s*([{0-9}{a-f}]*)-.*":
          startOffset = parseHexInt(matches[0]).uint64
          break
      threadIds.add(pid)

    while true:
      try:
        if not p.running:
          break
      except:
        break
      let startSample = epochTime()
      if sample(
        cpuHotAddresses,
        cpuHotStacks,
        pid,
        threadIds,
        dumpFile,
        stacks
      ):
        break
      inc cpuSamples
      # Wait to approach the user supplied sampling rate.
      while startSample + 1/rate.float64 * 0.8 > epochTime():
        spinVar += 1

    let
      exitTime = epochTime()
      totalTime = exitTime - startTime
    p.close()

    echo "Program ended"

    let samplesPerSecond = cpuSamples.float64 / (totalTime)

    if stacks:
      dumpStacks(cpuHotStacks, samplesPerSecond, cpuSamples, numLines)
    elif addresses:
      dumpScan(dumpFile.asmLines, cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    elif procedures:
      dumpScan(dumpFile.procs, cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    elif frames:
      dumpScan(dumpFile.frames, cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)
    else: #lines:
      dumpScan(dumpFile.nimLines, cpuHotAddresses, samplesPerSecond, cpuSamples, numLines)

    echo strformat.`&`"Samples per second: {samplesPerSecond:.1f} totalTime: {totalTime:.3f}ms"

    when defined(macosx):
      # Need for some reason on mac?
      quit(0)

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
      "frames": "profile by 'C' stack framed procedure definitions only"
    }
  )
