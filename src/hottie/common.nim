import std/tables
export tables

type
  RollUpKind* = enum
    Addresses
    Lines
    Procs
    Regions

  DumpLineKind* = enum
    dlAsm
    dlFunction
    dlPath

  DumpLine* = object
    kind*: DumpLineKind
    address*: uint64
    addressEnd*: uint64
    text*: string

  CallGraph* = Table[string, TableRef[string, int]]

proc addressToDumpLine*(dumpLines: seq[DumpLine], address: uint64): DumpLine =
  for line in dumpLines:
    if line.address <= address and address <= line.addressEnd:
      return line