import posix, ptrace

var child: Pid;
var syscallNum: clong;

child = fork()
if child == 0:
  traceMe()
  discard execl("/Users/me/p/hottie/examples/test3", "test3")
else:
  var a: cint
  wait(nil)

  var regs: Registers
  getRegs(child, addr regs)
  echo "Syscall number: ", regs.orig_rax
  if errno != 0:
    echo errno, " ", strerror(errno)

  syscallNum = peekUser(child, SYSCALL_NUM)
  if errno != 0:
    echo errno, " ", strerror(errno)
  echo "The child made a system call: ", syscallNum
  cont(child)
