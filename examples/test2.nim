import os

var
  i = 0
  x = 0
while true:
  echo "here ", i, " ", os.getCurrentProcessId(), " //", x
  inc i
  for j in 0 .. 100_000_000:
    inc x
