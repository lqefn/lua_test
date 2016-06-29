local ev = require("ev")
local socket = require("socket")
local ok= print

local loop = ev.Loop.new()
print(loop)

local i = 1
local timer

timer = ev.Timer.new(
    function(loop, timer, revents)
        print(true, 'one second timer1')
        print(ev.TIMEOUT == revents, 'ev.TIMEOUT(' .. ev.TIMEOUT .. ') == revents (' .. revents .. ')')
        loop:unloop()

        i = i + 1
        print(i)
        if i < 100 then
            timer:again(loop, 0.0166)
            loop:loop()
        end
    end, 0.0166)
timer:start(loop)
loop:loop()
print(i)
