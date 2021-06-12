import std/tables

export tables

type
  RollUpKind* = enum
    Addresses
    Lines
    Procs
    Frames

  DumpLine* = object
    address*: uint64
    addressEnd*: uint64
    text*: string

  CallGraph* = Table[string, TableRef[string, int]]

  DumpFile* = ref object
    exeName*: string
    exeFormat*: string
    asmLines*: seq[DumpLine]
    nimLines*: seq[DumpLine]
    procs*: seq[DumpLine]
    frames*: seq[DumpLine]
    callGraph*: CallGraph

proc addressToDumpLine*(dumpLines: seq[DumpLine], address: uint64): DumpLine =
  for line in dumpLines:
    if line.address <= address and address <= line.addressEnd:
      return line
