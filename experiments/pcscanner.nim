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

proc acquireTaskportRight(): int =
  {.emit: """
  OSStatus stat;
  AuthorizationItem taskport_item[] = {{"system.privilege.taskport:"}};
  AuthorizationRights rights = {1, taskport_item}, *out_rights = NULL;
  AuthorizationRef author;
  int retval = 0;

  AuthorizationFlags auth_flags = kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | ( 1 << 5);

  stat = AuthorizationCreate (NULL, kAuthorizationEmptyEnvironment,auth_flags,&author);
  if (stat != errAuthorizationSuccess)
    {
      return 0;
    }

  stat = AuthorizationCopyRights ( author, &rights, kAuthorizationEmptyEnvironment, auth_flags,&out_rights);
  if (stat != errAuthorizationSuccess)
    {
      printf("fail");
      return 1;
    }
  return 0;
  """.}

let pid = parseInt(paramStr(1))
echo pid

if acquireTaskportRight() != 0:
  echo "acquireTaskportRight() failed!"


proc main() =
  {.emit: """
    int infoPid;
    kern_return_t kret;
    mach_port_t task;
    thread_act_port_array_t threadList;
    mach_msg_type_number_t threadCount;
    arm_thread_state64_t state;

    infoPid = 97825;

    kret = task_for_pid(mach_task_self(), infoPid, &task);
    if (kret!=KERN_SUCCESS)
      {
        printf("task_for_pid() failed with message %s!\n",mach_error_string(kret));
        exit(0);
      }

    kret = task_threads(task, &threadList, &threadCount);
    if (kret!=KERN_SUCCESS)
      {
        printf("task_threads() failed with message %s!\n", mach_error_string(kret));
        exit(0);
      }

    for (int i = 0; i < 1000; i ++) {
      mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
      kret = thread_get_state( threadList[0], ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount);
      if (kret!=KERN_SUCCESS)
          {
          printf("thread_get_state() failed with message %s!\n", mach_error_string(kret));
          exit(0);
          }

      //printf("Thread %d has %d threads. Thread 0 state: \n", infoPid, threadCount);
      //printf("EIP: %lx\nEAX: %lx\nEBX: %lx\nECX: %lx\nEDX: %lx\nSS: %lx\n", state.__eip, state.__eax, state.__ebx, state.__ecx, state.__edx, state.__ss);

      printf("pc: %llx\n", state.__pc);
    }
  """.}


main()
