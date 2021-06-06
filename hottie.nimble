version     = "0.0.1"
author      = "treeform"
description = "Sampling profiler that finds hot paths in your code."
license     = "MIT"
srcDir      = "src"

bin = @["hottie"]

requires "nim >= 1.4.6"
requires "winim >= 3.6.0"
requires "cligen >= 1.3.2"
