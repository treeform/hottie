<img src="docs/banner.png">

# Sampling profiler that finds hot paths in your code.

Currently only works on Windows with GCC (mingw).

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
samples        time  path
    1198     627.ms  C:\nim-1.4.6\lib\system.nim:2200
     526     275.ms  C:\p\pixie\src\pixie\paths.nim:1145
     501     262.ms
     449     235.ms  C:\p\pixie\src\pixie\paths.nim:1147
     350     183.ms  C:\nim-1.4.6\lib\system\iterators_1.nim:107
     258     135.ms  C:\nim-1.4.6\lib\system.nim:1844
     246     129.ms  C:\nim-1.4.6\lib\system\iterators_1.nim:109
     243     127.ms  C:\p\vmath\src\vmath.nim:516
     219     115.ms  C:\p\pixie\src\pixie\paths.nim:1143
     174     91.1ms  C:\mingw64\include\emmintrin.h:698
     167     87.4ms  C:\p\pixie\src\pixie\paths.nim:1265
     160     83.7ms  C:\mingw64\include\emmintrin.h:1392
     144     75.4ms  C:\p\bumpy\src\bumpy.nim:488
     138     72.2ms  C:\p\pixie\src\pixie\paths.nim:1301
     111     58.1ms  C:\nim-1.4.6\lib\system\iterators_1.nim:57
     110     57.6ms  C:\mingw64\include\emmintrin.h:1270
     110     57.6ms  C:\nim-1.4.6\lib\system\iterators_1.nim:97
     106     55.5ms  C:\p\pixie\src\pixie\paths.nim:1101
     101     52.9ms  C:\p\pixie\src\pixie\paths.nim:1181
      96     50.2ms  C:\p\bumpy\src\bumpy.nim:485
      87     45.5ms  C:\p\pixie\src\pixie\paths.nim:1186
      83     43.4ms  C:\p\pixie\src\pixie\paths.nim:1146
      83     43.4ms  C:\p\pixie\src\pixie\paths.nim:1165
      82     42.9ms  C:\p\pixie\src\pixie\paths.nim:1303
      78     40.8ms  C:\p\pixie\src\pixie\paths.nim:1229
      71     37.2ms  C:\nim-1.4.6\lib\system\iterators.nim:212
      70     36.6ms  C:\mingw64\include\emmintrin.h:1300
      70     36.6ms  C:\p\bumpy\src\bumpy.nim:486
      70     36.6ms  C:\mingw64\include\emmintrin.h:1204
      67     35.1ms  C:\p\pixie\src\pixie\paths.nim:1267
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
  -a, --addresses     bool    false  profile by assembly instruction addresses
  -l, --lines         bool    false  profile by source lines (default)
  -p, --procedures    bool    false  profile by inlined and regular procedure definitions
  -r, --regions       bool    false  profile by regular procedure definitions only
```
