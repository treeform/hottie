var k: int

proc functionA() {.extern: "functionA".} =
  for i in 0 .. 1_000_000_000:
    inc k

proc functionB() {.extern: "functionB".} =
  functionA()

proc functionC() {.extern: "functionC".} =
  functionB()

functionC()
echo k
