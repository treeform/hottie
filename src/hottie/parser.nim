## Parses objdump files.

import common, os, osproc, strutils, tables, times

proc parseCallGraph*(lines: seq[string]): CallGraph =
  ## Parses the call graph for stack parsing.
  var frameName = ""
  for num, line in lines:
    if '<' in line and ">:" in line:
      let
        arr = line.split(" ", 1)
      var
        name = arr[1]
      if name != "":
        name = name.strip()[1..^3]
      frameName = name
      result[frameName] = newTable[string, int]()
    if line.endsWith(">") and ("#" in line or "callq" in line):
      let name = line.split("<", 1)[1][0..^2]
      if not name.startsWith(".rdata"):
        result[frameName][name] = 1

proc getDumpFile*(exePath: string): DumpFile =
  ## Runs objdump or uses cache.
  ## Parses objdump output file.
  result = DumpFile()
  var output: string

  if not fileExists("dump.txt") or
    getLastModificationTime("dump.txt") < getLastModificationTime(exePath) or
    readFile("dump.txt").split(":", 1)[0].strip() != exePath:
    echo "Running objdump..."


    var exePath = exePath

    when defined(macosx):
      exePath = exePath & ".dSYM/Contents/Resources/DWARF/" & exePath.lastPathPart()

    let (data, code) = execCmdEx("objdump -dl " & exePath)
    output = data
    if code != 0:
      echo output
      quit("Failed to run objdump.")
    writeFile("dump.txt", output)
  else:
    output = readFile("dump.txt")

  var lines = output.split("\n")

  result.callGraph = parseCallGraph(lines)

  for num, line in lines:
    proc dumpLink(): string =
      "dump.txt".absolutePath & ":" & $(num + 1)

    if '<' in line and ">:" in line:
      # Frames (big not-inline functions)
      let
        arr = line.split(" ", 1)
      var
        name = arr[1]
      if name != "":
        name = name.strip()[1..^3] #.split("__")[0]

      result.frames.add DumpLine(
        address: 0,
        text: name & " @ " & dumpLink()
      )
    elif line.len == 0:
      continue
    elif "():" in line:
      # Inline function
      let name = line.split("():")[0].split("__")[0]
      result.procs.add DumpLine(
        address: 0,
        text: name,
      )
    elif "/" in line:
      # Source code lines
      var line = line
      if line.startsWith("; "):
        line = line[2..^1]
      if "failed to parse" in line:
        line = ""
      result.nimLines.add DumpLine(
        address: 0,
        text: line.normalizedPath,
      )
    elif (line.startsWith("  ") or line[0].isDigit) and ":" in line:
      # Assembly instructions.
      let
        arr = line.split(":", 1)
      let
        address = fromHex[uint64](arr[0].strip())
      result.asmLines.add DumpLine(
        address: address,
        text: dumpLink()
      )
      proc capAddress(s: var seq[DumpLine], address: uint64) =
        if s.len > 0:
          if s[^1].address == 0:
            s[^1].address = address
          s[^1].addressEnd = address
      capAddress(result.asmLines, address)
      capAddress(result.nimLines, address)
      capAddress(result.procs, address)
      capAddress(result.frames, address)

    elif "Dwarf Error" in line:
      continue
    elif "Disassembly of section" in line:
      continue
    elif "section" in line:
      continue
    elif "file format" in line:
      continue
    elif line.strip() == "":
      continue
    elif "..." in line:
      continue
    else:
      quit("Failed to parse objdump line:" & line)
