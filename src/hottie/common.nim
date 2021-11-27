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

var
  # Used on mac for PIE (Position Independent Executables) to offset addresses.
  startOffset*: uint64

proc addressToDumpLine*(dumpLines: seq[DumpLine], address: uint64): DumpLine =
  ## Convert a memory address to a DumpLine.

  # # linear search
  # for line in dumpLines:
  #   if line.address <= address and address <= line.addressEnd:
  #     return line

  # soft-of binary search:
  var
    a = 0
    b = len(dumpLines) - 1
    c = 0
  while a <= b:
    c = (b + a) div 2
    if dumpLines[c].addressEnd < address:
      a = c + 1
    elif dumpLines[c].address > address:
      b = c - 1
    else:
      return dumpLines[c]
  return
