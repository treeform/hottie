import os

var i = 0
while true:
  echo "here ", i, " ", os.getCurrentProcessId()
  inc i
  sleep(1000)
