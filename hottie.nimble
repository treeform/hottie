version     = "0.0.1"
author      = "Andre von Houck"
description = "Sampling profiler that finds hot paths in your code."
license     = "MIT"
srcDir      = "src"

bin = @["hottie"]

requires "nim >= 1.4.6"
requires "cligen >= 1.3.2"
when defined(windows):
  requires "winim >= 3.8.0"
elif defined(linux):
  requires "ptrace >= 0.0.4"
