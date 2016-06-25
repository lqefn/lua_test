local Thread = require("llthreads2.ex")
local ev = require("ev")

local loop = ev.Loop.default
print(loop)

local thread = Thread.new(function()
    local ev = require("ev")
    local socket = require("socket")
    local ok= print
    
    local loop = ev.Loop.new()
    print(loop)
    
     local timer1 = ev.Timer.new(
        function(loop, timer, revents)
           print(true, 'one second timer1')
           print(ev.TIMEOUT == revents, 'ev.TIMEOUT(' .. ev.TIMEOUT .. ') == revents (' .. revents .. ')')
           --loop:unloop()
        end,
        1)
     timer1:start(loop)
     
local function newtry()
   local try = {}
   setmetatable(try, try)
   function try:__call(body)
      local is_err, err = pcall(body)
      for _, finalizer in ipairs(self) do
         -- ignore errors in finalizers:
         pcall(finalizer)
      end
      assert(is_err, err)
   end
   function try:finally(finalizer)
      self[#self + 1] = finalizer
   end
   return try
end

local function test_echo()
   local got_response
   local try = newtry()
   try(function()
          local server = assert(socket.bind("*", 0))
          try:finally(function() server:close() end)
          server:settimeout(0)
          ev.IO.new(
             function(loop, watcher)
                watcher:stop(loop)
                local client = assert(server:accept())
                client:settimeout(0)
                ev.IO.new(
                   function(loop, watcher)
                      watcher:stop(loop)
                      local buff = assert(client:receive('*a'))
                      ev.IO.new(
                         function(loop, watcher)
                            watcher:stop(loop)
                            assert(client:send(buff))
                            assert(client:shutdown("send"))
                         end,
                         client:getfd(),
                         ev.WRITE):start(loop)
                   end,
                   client:getfd(),
                   ev.READ):start(loop)
             end,
             server:getfd(),
             ev.READ):start(loop)
          local port   = select(2, server:getsockname())
          local client = assert(socket.connect("127.0.0.1", port))
          try:finally(function() client:close() end)
          client:settimeout(0)
          ev.IO.new(
             function(loop, watcher)
                watcher:stop(loop)
                local str = "Hello World"
                assert(client:send(str))
                assert(client:shutdown("send"))
                ev.IO.new(
                   function(loop, watcher)
                      watcher:stop(loop)
                      local response = assert(client:receive("*a"))
                      ok(response == str,
                         tostring(response) .. " == " .. tostring(str))
                      got_response = true
                   end,
                   client:getfd(),
                   ev.READ):start(loop)
             end,
             client:getfd(),
             ev.WRITE):start(loop)
          loop:loop()
       end)
   ok(got_response, "echo")
end
     test_echo()
     loop:loop()
end)

print("BEGIN")
thread:start()
thread:join()
print("END")