import os, strutils

{.passC: "-sectcreate __TEXT __info_plist ./Info.plist".}
{.passL: "-framework Security -framework CoreFoundation".}

{.emit: """
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/ptrace.h>
#include <mach/mach.h>
#include <errno.h>
#include <stdlib.h>
#include <Security/Authorization.h>
""".}

# proc acquireTaskportRight(): int =
#   {.emit: """
#   OSStatus stat;
#   AuthorizationItem taskport_item[] = {{"system.privilege.taskport:"}};
#   AuthorizationRights rights = {1, taskport_item}, *out_rights = NULL;
#   AuthorizationRef author;
#   int retval = 0;

#   AuthorizationFlags auth_flags = kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | ( 1 << 5);

#   stat = AuthorizationCreate (NULL, kAuthorizationEmptyEnvironment,auth_flags,&author);
#   if (stat != errAuthorizationSuccess)
#     {
#       return 0;
#     }

#   stat = AuthorizationCopyRights ( author, &rights, kAuthorizationEmptyEnvironment, auth_flags,&out_rights);
#   if (stat != errAuthorizationSuccess)
#     {
#       printf("fail");
#       return 1;
#     }
#   return 0;
#   """.}

type
  mach_port_t {.importc: "mach_port_t".} = object
  thread_act_port_array_t {.importc: "thread_act_port_array_t".} = object
  arm_thread_state64_t = object
    x: array[29, uint64]
    fp: uint64
    lr: uint64
    sp: uint64
    pc: uint64
    cpsr: uint32
    pad: uint32

proc mach_task_self(): mach_port_t =
  {.emit: "return mach_task_self();".}

proc task_for_pid(port: mach_port_t, pid: cint, task: ptr mach_port_t): cint {.importc: "task_for_pid".}
proc mach_error_string(code: cint): cstring {.importc: "mach_error_string".}

proc task_threads(task: mach_port_t, list: ptr thread_act_port_array_t, count: ptr cint): cint =
  {.emit: "return task_threads(task, list, count);".}

proc armThreadState64Count(): cint =
  {.emit: "return ARM_THREAD_STATE64_COUNT;".}

proc thread_get_state(threads: thread_act_port_array_t, state: ptr arm_thread_state64_t, count: ptr cint): cint =
  {.emit: "return thread_get_state(threads[0], ARM_THREAD_STATE64, state, count);".}

proc main() =
  let pid = parseInt(paramStr(1))
  echo pid

  var
    infoPid: cint = pid.cint
    err: cint
    task: mach_port_t
    threadList: thread_act_port_array_t
    threadCount: cint
    state: arm_thread_state64_t

  # if acquireTaskportRight() != 0:
  #   echo "acquireTaskportRight() failed!"

  let machPort = mach_task_self()

  err = task_for_pid(machPort, infoPid, task.addr)
  if err != 0:
    echo "task_for_pid() failed with message: ", mach_error_string(err)
    quit(-1)

  err = task_threads(task, addr threadList, addr threadCount)
  if err != 0:
    echo "task_threads() failed with message: ", mach_error_string(err)
    quit(-1)

  for i in 0 ..< 100:
    var stateCount: cint = armThreadState64Count()
    err = thread_get_state(threadList, addr state, addr stateCount);
    if err != 0:
      echo "thread_get_state() failed with message: ", mach_error_string(err)
      quit(-1)

    echo "pc: ", state.pc.toHex()

  quit(0)

main()
