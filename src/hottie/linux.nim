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

  detach(threadId)
  let rip = regs.rip.int - startOffsets[threadId].int

  if cpuHotAddresses.hasKeyOrPut(rip, 1):
    inc cpuHotAddresses[rip] 
  inc cpuSamples