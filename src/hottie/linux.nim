import common, os, posix, ptrace, strformat, strutils, tables

proc getThreadIds*(pid: int): seq[int] =
  for x in walkdir(fmt"/proc/{pid}/task", true):
    try:
      let tid = parseInt(x.path)
      result.add tid
    except: discard

proc sample*(
  cpuHotAddresses: var CountTable[uint64],
  cpuHotStacks: var CountTable[string],
  pid: int,
  threadIds: seq[int],
  dumpFile: DumpFile,
  stacks: bool
): bool =
  let threadId = threadIds[0].Pid
  var regs: Registers
  attach(threadId)

  wait(nil)
  getRegs(threadId, addr regs)

  var stackTrace: string
  if stacks:
    var prevFun = ""
    block:
      let startAddress = regs.rsp
      var i = 0
      let dl = dumpFile.frames.addressToDumpLine(regs.rip)
      prevFun = dl.text.split(" @ ")[0]
      stackTrace.add prevFun.split("__", 1)[0]
      stackTrace.add "<"
      while i < 10_000:
        var value = threadId.getData((startAddress + i.culong).clong).uint64
        let dl = dumpFile.frames.addressToDumpLine(value)
        if "stdlib_ioInit000" in dl.text or "NimMainModule" in dl.text:
          break
        if dl.text != "":
          let thisFun = dl.text.split(" @ ")[0]
          let canCall = prevFun in dumpFile.callGraph[thisFun]
          if canCall:
            if prevFun == thisFun:
              if not stackTrace.endsWith("*"):
                stackTrace[^1] = '*'
            else:
              prevFun = thisFun
              stackTrace.add thisFun.split("__", 1)[0]
              stackTrace.add "<"
        i += 8

  detach(threadId)
  let rip = regs.rip.uint64

  cpuHotAddresses.inc(rip)
  if stacks:
   cpuHotStacks.inc(stackTrace)

  return true
