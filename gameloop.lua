local Thread = require("llthreads2.ex")
local chan = require("chan")
local cmsgpack = require("cmsgpack")

local BATTLE_START_EVENT = "start battle"
local TICK_TIME = 1.0 / 60
local battleID = string.format("battle_%d", math.random(1, 10000000))
local sender = chan.new(battleID .. "sender")
local receiver = chan.new(battleID .. "receiver")
local tickServer = Thread.new(function(tickTime, battleID) 
    local ev = require("ev")    
    local chan = require("chan")
    local cmsgpack = require("cmsgpack")
    local loop = ev.Loop.new()
    local BATTLE_START_EVENT = "start battle"
    
    local sender = chan.get(battleID .. "receiver")
    local receiver = chan.get(battleID .. "sender")

    local maxTickCount = 1 * 1.5 / tickTime
    local startEvent = receiver:recv(3 * 1000)
    print("startEvent", startEvent)
    if startEvent ~= BATTLE_START_EVENT then
        print("need start battle event, but receive:", startEvent)
        return
    end
    
    local tickIndex = 0    
    local loopTimer = ev.Timer.new(
        function(loop, timer, revents)           
           local inputEvent = receiver:recv(1)
           if inputEvent then
              print("input:", inputEvent)
           end
           
           sender:send(string.format("{tick = %d, event = %s}", tickIndex, inputEvent or ""))           
           
           tickIndex = tickIndex + 1
           if (tickIndex > maxTickCount) then
              sender:send("quit")
              loop:unloop()
           end
           --print("tick:", tickIndex)
        end, tickTime, tickTime)
     loopTimer:start(loop)
     loop:loop()    
end, TICK_TIME, battleID) 
tickServer:start()

sender:send(BATTLE_START_EVENT)
sender:send("input 1")

while 1 do
    local tickAndInput = receiver:recv()
    if tickAndInput == "quit" then
        break
    else
        print(tickAndInput)
    end
end

tickServer:join()
print("END")