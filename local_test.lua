local chan = require("chan")
local Thread = require("llthreads2.ex")

local ch = chan.new("chan", 1000)

local thread = Thread.new(function()
  local chan = require("chan")
  local socket = require("socket")

  local ch = chan.get("chan")
  while true do
    ch:send(os.date())
    socket.sleep(5)
  end
end)

thread:start()
for i = 1, 30 do
  print(ch:recv(1000))
end
