import common, strutils, winim

proc getThreadIds*(pid: int): seq[int] =
  var h = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, DWORD(pid))
  if h != INVALID_HANDLE_VALUE:
    var te: THREADENTRY32
    te.dwSize = DWORD(sizeof(te))
    var valid = Thread32First(h, te.addr)
    while valid == 1:
      if te.th32OwnerProcessID == DWORD(pid):
        result.add te.th32ThreadID
      valid = Thread32Next(h, te.addr)
    CloseHandle(h)

proc sample*(
  cpuHotAddresses: var CountTable[uint64],
  cpuHotStacks: var CountTable[string],
  pid: int,
  threadIds: seq[int],
  dumpFile: DumpFile,
  stacks: bool
): bool =
  #for threadId in threadIds:
  block:
    let threadId = threadIds[0]
    var processHandle = OpenProcess(PROCESS_ALL_ACCESS, false, pid.DWORD)
    var threadHandle = OpenThread(
      THREAD_ALL_ACCESS,
      false,
      threadId.DWORD
    )

    var context: CONTEXT
    context.ContextFlags = CONTEXT_ALL

    SuspendThread(threadHandle)
    GetThreadContext(
      threadHandle,
      context.addr
    )
    var stackTrace: string
    if stacks:
      var prevFun = ""
      block:
        var bytesRead: SIZE_T
        let startAddress = context.Rsp
        var i = 0
        let dl = dumpFile.frames.addressToDumpLine(context.Rip.uint64)
        prevFun = dl.text.split(" @ ")[0]
        stackTrace.add prevFun.split("__", 1)[0]
        stackTrace.add "<"
        while i < 10_000:
          var value: uint64
          ReadProcessMemory(
            hProcess = processHandle,
            lpBaseAddress = cast[LPCVOID](startAddress + i),
            lpBuffer = cast[LPCVOID](value.addr),
            nSize = 8,
            lpNumberOfBytesRead = bytesRead.addr)
          if bytesRead != 8:
            break
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

    ResumeThread(threadHandle)

    cpuHotAddresses.inc(context.Rip.uint64)

    if stacks:
      cpuHotStacks.inc(stackTrace)

    CloseHandle(threadHandle)
    CloseHandle(processHandle)

  return false
