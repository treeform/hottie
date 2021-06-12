var k: int

proc functionA1() {.extern: "functionA1".} =
  for i in 0 .. 1_000_000:
    inc k

proc functionA2() {.extern: "functionA2".} =
  for i in 0 .. 1_000_000:
    inc k

proc functionB() {.extern: "functionB".} =
  for i in 0 .. 1000:
    functionA1()
    functionA2()

proc functionC() {.extern: "functionC".} =
  functionB()

functionC()
echo k
