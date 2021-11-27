var k: int

proc junk(i: int) =
  if i == 0: return
  junk(i - 1)

proc functionA1() {.extern: "functionA1".} =
  for i in 0 .. 1_000_000:
    inc k

proc functionA2() {.extern: "functionA2".} =
  for i in 0 .. 1_000_000:
    inc k

proc functionB() {.extern: "functionB".} =
  for i in 0 .. 1000:
    junk(10)
    functionA1()
    functionA2()

proc functionC() {.extern: "functionC".} =
  junk(10)
  functionB()

junk(10)
functionC()
echo k
