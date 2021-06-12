import std/[tables, strformat, os, strutils, posix, parseutils]
import ptrace, common
export common
var startOffsets: Table[int, uint64]

proc fetchStackAddrs(pid: int) =
  ## Gets offsets from start of program
  for line in lines(fmt"/proc/{pid}/maps"):
    try:
      var stack: uint64
      discard parseHex(line, stack)
      startOffsets[pid] = stack
    except: discard
    break

proc getThreadIds*(pid: int): seq[int] =
  for x in walkdir(fmt"/proc/{pid}/task", true):
    try:
      let tid = parseInt(x.path)
      result.add tid
      fetchStackAddrs(tid)
    except: discard

proc toRel(address: uint64, pid: int): uint64 = address - startOffsets[pid]

proc sample*(
  cpuSamples: var int,
  cpuHotAddresses: var Table[int64, int],
  cpuHotStacks: var Table[string, int],
  pid: int,
  threadIds: seq[int],
  dumpLine: seq[DumpLine],
  callGraph: CallGraph,
  stacks: bool
) =
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
      let dl = dumpLine.addressToDumpLine(regs.rip.toRel(threadId))
      prevFun = dl.text.split(" @ ")[0]
      stackTrace.add prevFun.split("__", 1)[0]
      stackTrace.add "<"
      while i < 10_000:
        var value = threadId.getData((startAddress + i.culong).clong).uint64
        let dl = dumpLine.addressToDumpLine(value.toRel(threadId))
        if "stdlib_ioInit000" in dl.text or "NimMainModule" in dl.text:
          break
        if dl.text != "":
          let thisFun = dl.text.split(" @ ")[0]
          let canCall = prevFun in callGraph[thisFun]
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
  let rip = regs.rip.toRel(threadId).int
  
  if cpuHotAddresses.hasKeyOrPut(rip, 1):
    inc cpuHotAddresses[rip] 
  inc cpuSamples
  if stacks:
    if stackTrace notin cpuHotStacks:
      cpuHotStacks[stackTrace] = 1
    else:
      cpuHotStacks[stackTrace] += 1