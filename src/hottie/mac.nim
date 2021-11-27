import common, os, posix, strformat, strutils, tables

# http://os-tres.net/blog/2010/02/17/mac-os-x-and-task-for-pid-mach-call/
# http://uninformed.org/index.cgi?v=4&a=3&p=14

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

type
  #mach_port_t {.importc: "mach_port_t".} = object
  thread_act_port_array_t {.importc: "thread_act_port_array_t".} = object
  arm_thread_state64_t = object
    x: array[29, uint64]
    fp: uint64
    lr: uint64
    sp: uint64
    pc: uint64
    cpsr: uint32
    pad: uint32

proc mach_task_self(): cint =
  {.emit: "return mach_task_self();".}

proc task_for_pid(port: cint, pid: cint, task: ptr cint): cint =
  {.emit: "return task_for_pid(port, pid, task);".}

proc mach_error_string(code: cint): cstring =
  {.emit: "return mach_error_string(code);".}

proc task_threads(task: cint, list: ptr thread_act_port_array_t, count: ptr cint): cint =
  {.emit: "return task_threads(task, list, count);".}

proc armThreadState64Count(): cint =
  {.emit: "return ARM_THREAD_STATE64_COUNT;".}

proc thread_get_state(threads: thread_act_port_array_t, state: ptr arm_thread_state64_t, count: ptr cint): cint =
  {.emit: "return thread_get_state(threads[0], ARM_THREAD_STATE64, state, count);".}


proc mach_vm_region(task: cint): cint =
  {.emit: """
    mach_vm_address_t address = 0;
    mach_vm_size_t size = 0;
    vm_region_flavor_t flavor;
    vm_region_info_t info = 0;
    mach_msg_type_number_t infoCnt = sizeof(vm_region_basic_info_data_64_t);
    mach_port_t object_name = 0;

    int err = mach_vm_region(
      task,
      &address,
      &size,
      VM_REGION_BASIC_INFO,
      info,
      &infoCnt,
      &object_name
    );

    printf("address: %lx\n", address);
    printf("size: %lx\n", size);
    printf("info: %lx\n", info);

    return err;
  """.}

proc getThreadIds*(pid: int): seq[int] =
  ## TODO add multi threaded support
  return

proc sample*(
  cpuHotAddresses: var CountTable[uint64],
  cpuHotStacks: var CountTable[string],
  pid: int,
  threadIds: seq[int],
  dumpFile: DumpFile,
  stacks: bool
): bool =

  if stacks:
    # TODO add support for stacks
    discard

  var
    infoPid: cint = pid.cint
    err: cint
    task: cint
    threadList: thread_act_port_array_t
    threadCount: cint
    state: arm_thread_state64_t

  let machPort = mach_task_self()

  err = task_for_pid(machPort, infoPid, task.addr)
  if err != 0:
    echo "task_for_pid() failed with message: ", mach_error_string(err)
    return true

  err = task_threads(task, addr threadList, addr threadCount)
  if err != 0:
    echo "task_threads() failed with message: ", mach_error_string(err)
    return true

  # TODO: Figure out how to use vm_region
  # err = mach_vm_region(machPort)
  # echo "done mach_vm_region"
  # if err != 0:
  #   echo "mach_vm_region() failed with message: ", mach_error_string(err)
  #   return

  var stateCount: cint = armThreadState64Count()
  err = thread_get_state(threadList, addr state, addr stateCount);
  if err != 0:
    echo "thread_get_state() failed with message: ", mach_error_string(err)
    return true

  let rip: uint64 = (state.pc - startOffset + 0x100000000.uint64)
  cpuHotAddresses.inc(rip)
  return false
