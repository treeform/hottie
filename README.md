<img src="docs/banner.png">

# A Sampling profiler for Nim that finds 🌶️ code.

nimble update dep: winim 3.6.0 -> 3.8.0

`nimble install hottie`

![Github Actions](https://github.com/treeform/hottie/workflows/Github%20Actions/badge.svg)

[API reference](https://nimdocs.com/treeform/hottie)

Currently only works on Windows with GCC (mingw).

Supports Linux using GCC(`--passL:"-no-pie"` is required) and Clang.

# How to use:

First compile your exe with `--debugger:native` to get the line numbers, and probably `-d:release` or `-d:danger` because you are profiling:

`nim c --debugger:native -d:release your.nim`

Then run your executable with hottie:

`hottie your.exe`

# Example:

`hottie .\tests\benchmark_svg.exe`

First output from the program itself:

```
name ............................... min time      avg time    std dv   runs
svg decode ........................ 28.371 ms     29.925 ms    ±0.259   x167
```

Then output from `hottie`:

```
 samples           time   percent what
     581      582.441ms   11.532% C:\mingw64\include\config\i386\cygwin.S:158
     349      349.866ms    6.927% C:\p\pixie\src\pixie\paths.nim:1143
     290      290.719ms    5.756%
     250      250.620ms    4.962% C:\p\bumpy\src\bumpy.nim:489
     185      185.459ms    3.672% C:\nim-1.4.6\lib\system\iterators_1.nim:109
     110      110.273ms    2.183% C:\nim-1.4.6\lib\system\comparisons.nim:267
     109      109.270ms    2.164% C:\p\pixie\src\pixie\paths.nim:1265
     106      106.263ms    2.104% C:\p\bumpy\src\bumpy.nim:488
      97       97.241ms    1.925% C:\p\pixie\src\pixie\paths.nim:1301
      94       94.233ms    1.866% C:\mingw64\include\emmintrin.h:698
      91       91.226ms    1.806% C:\nim-1.4.6\lib\system\iterators_1.nim:107
      87       87.216ms    1.727% C:\p\pixie\src\pixie\paths.nim:1146
      81       81.201ms    1.608% C:\p\pixie\src\pixie\paths.nim:1145
      75       75.186ms    1.489% C:\p\vmath\src\vmath.nim:516
      68       68.169ms    1.350% C:\mingw64\include\emmintrin.h:1270
      62       62.154ms    1.231% C:\mingw64\include\emmintrin.h:1300
      58       58.144ms    1.151% C:\p\pixie\src\pixie\paths.nim:1100
      53       53.131ms    1.052% C:\p\pixie\src\pixie\paths.nim:1063
      52       52.129ms    1.032% C:\p\pixie\src\pixie\paths.nim:991
      45       45.112ms    0.893% C:\p\bumpy\src\bumpy.nim:485
      45       45.112ms    0.893% C:\nim-1.4.6\lib\system\iterators_1.nim:57
      44       44.109ms    0.873% C:\p\pixie\src\pixie\paths.nim:1303
      44       44.109ms    0.873% C:\p\pixie\src\pixie\paths.nim:1101
      42       42.104ms    0.834% C:\mingw64\include\emmintrin.h:1392
      40       40.099ms    0.794% C:\p\pixie\src\pixie\paths.nim:1183
      36       36.089ms    0.715% C:\p\pixie\src\pixie\paths.nim:1267
      35       35.087ms    0.695% C:\nim-1.4.6\lib\system.nim:1527
      35       35.087ms    0.695% C:\nim-1.4.6\lib\system\memory.nim:24
      35       35.087ms    0.695% C:\p\pixie\src\pixie\paths.nim:1083
      32       32.079ms    0.635% C:\p\pixie\src\pixie\paths.nim:1181
```

File links should be clickable in your VSCode or other terminals.

# Usage:

```
Usage:
  hottie [optional-params] [paths: string...]
Options:
  -h, --help                         print this cligen-erated help
  --help-syntax                      advanced: prepend,plurals,..
  -w=, --workingDir=  string  ""     set workingDir
  -r=, --rate=        int     1000   target rate per second (faster not always possible)
  -n=, --numLines=    int     30     number of lines to display
  -s, --stacks        bool    false  profile by stack traces
  -a, --addresses     bool    false  profile by assembly instruction addresses
  -l, --lines         bool    false  profile by source lines (default)
  -p, --procedures    bool    false  profile by inlined and regular procedure definitions
  --regions           bool    false  profile by 'C' stack framed procedure definitions only
```
