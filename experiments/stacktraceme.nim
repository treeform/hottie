import winim, os, osproc, strformat, tables, algorithm, strutils, times, print, flatty/hexprint, flatty/binny




proc main() =
  print "main"

  var context = cast[ptr[CONTEXT]](alloc(sizeof(CONTEXT)))
  context.ContextFlags = CONTEXT_ALL
  RtlCaptureContext(context)

  print context.Rsp.toHex, context.Rbp.toHex


  #echo hexPrint(cast[ptr[uint8]](context.Rsp), 1024)

  var stackSize = 1024
  var stack = newString(stackSize)
  for i in 0 ..< stackSize:
    let at = cast[ptr[char]](context.Rsp + i - 16)
    stack[i] = at[]

  echo hexPrint(stack)
  var i = 8
  while true:
    print stack.readUInt64(i).toHex()

    i += 8




  # var stack = cast[ptr[STACKFRAME64]](alloc(sizeof(STACKFRAME64)))
  # # stack.AddrPC.Offset    = context.Rip
  # # stack.AddrPC.Mode      = addrModeFlat

  # # stack.AddrFrame.Offset = context.Rbp  # This value is not always used.
  # # stack.AddrFrame.Mode   = addrModeFlat

  # # stack.AddrStack.Offset = context.Rsp
  # # stack.AddrStack.Mode   = addrModeFlat

  # #stack.Virtual          = false

  # echo "---"
  # #print stack
  # #print stack.AddrPC.Offset.toHex, stack.AddrStack.Offset.toHex, stack.AddrReturn.Offset.toHex

  # while true:
  #   let stackRes = StackWalk64(
  #     IMAGE_FILE_MACHINE_AMD64,
  #     GetCurrentProcess(),
  #     GetCurrentThread(),
  #     stack,
  #     context,
  #     nil,
  #     SymFunctionTableAccess64,
  #     SymGetModuleBase64,
  #     nil
  #   )

  #   #print stack
  #   print stack.AddrPC.Offset.toHex, stack.AddrStack.Offset.toHex, stack.AddrReturn.Offset.toHex

  #   # print "getting sym"
  #   # var pSymbol: PSYMBOL_INFO
  #   # pSymbol.MaxNameLen = MAX_SYM_NAME
  #   # pSymbol.SizeOfStruct = sizeof(SYMBOL_INFO).ULONG
  #   # SymFromAddr(GetCurrentProcess(), stack.AddrPC.Offset, nil, pSymbol)
  #   # print pSymbol

  #   if stackRes == 0 or stack.AddrReturn.Offset == 0:
  #     break

proc main1() =
  print "main1"
  main()
  print "exit main"

proc main2() =
  print "main2"
  main1()
  print "exit mmain2"

main2()
