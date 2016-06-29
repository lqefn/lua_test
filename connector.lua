local ev = require("ev")
local socket = require("socket")
local inspect = require("inspect")
local struct = require("struct")
require("class")

SocketTCP = Class(function(self, loop, host, port, timeout)
    self.state = "none"
    self.loop = loop
    self.host = host
    self.port = port
    self.timeout = timeout or 5.0
    self.sendBuf = {}
    self.sock = nil

    self.io_connector = nil
    self.timer_connector = nil

    self.io_reader = nil
    self.io_writer = nil
end)

function SocketTCP:_startConnecting()
    local function isConnected(status, error)
        print(status, error)
        if status then
            return true
        end

        if error == "Operation already in progress" then
            return false
        end
        if error == "already connected" then
            return true
        end

        return false
    end

    self.io_connector = ev.IO.new(function(loop, watcher, event)
        print("onConnectIO event", event)
        local ok, err = self.sock:connect(self.host, self.port)

        if self.state == "connecting" then
            if isConnected(ok, err) then
                self:_connectionMade()
            else
                self:_connectionFailed()
                self.sock:close()
            end
        end

        self:_stopConnecting()
    end, self.sock:getfd(), ev.READ + ev.WRITE)

    self.timer_connector = ev.Timer.new(function(loop, watcher, event)
        local ok, err = self.sock:connect(self.host, self.port)

        if self.state == "connecting" then
            if isConnected(ok, err) then
                self:_connectionMade()
            else
                self:_connectionFailed()
                self.sock:close()
            end
        end

        self:_stopConnecting()
    end, self.timeout)

    self.io_connector:start(self.loop)
    self.timer_connector:start(self.loop)
end

function SocketTCP:_stopConnecting()
    if self.io_connector then
        self.io_connector:stop(self.loop)
        self.io_connector = nil
    end

    if self.timer_connector then
        self.timer_connector:stop(self.loop)
        self.timer_connector = nil
    end
end

function SocketTCP:_startReading()
    self.io_reader = ev.IO.new(function(loop, watcher, event)
        print("onReadIO event", event)
        local data, err, partial, time = self.sock:receive(8192)
        print("read", data, err, partial, time)
        data = data or partial

        if data and #data > 0 then
            self:dataReceived(data)
        end

        if err =="closed" or err == "Socket is not connected" then
            self.sock:close()

            self:_connectionLost()
        end
    end, self.sock:getfd(), ev.READ)

    self.io_reader:start(self.loop)
end

function SocketTCP:_stopReading()
    if self.io_reader then
        self.io_reader:stop(self.loop)
        self.io_reader = nil
    end
end

function SocketTCP:_startWriting()
    self.io_writer = ev.IO.new(function(loop, watcher, event)
        print("onWriteIO event", event)

        if #self.sendBuf > 0 then
            local sendData = self.sendBuf[1]
            local data, pos = sendData.data, sendData.pos

            local all, err, sendPos, time = self.sock:send(data, pos)
            print("write:", all, err, sendPos, time)

            if all then
                table.remove(self.sendBuf, 1)
                print("send one packet")

                if #self.sendBuf == 0 then
                    self:_stopWriting()
                end
            end
            if sendPos and err == "timeout" then
                sendData.pos = sendPos + 1
            end

            if err =="closed" or err == "Socket is not connected" then
                self.sock:close()

                self:_connectionLost()
            end
        else
            self:_stopWriting()
        end
    end, self.sock:getfd(), ev.WRITE)

    self.io_writer:start(self.loop)
end

function SocketTCP:_stopWriting()
    if self.io_writer then
        self.io_writer:stop(self.loop)
        self.io_writer = nil
    end
end

function SocketTCP:connect()
    self.state = "connecting"

    local sock = socket.tcp()
    self.sock = sock
    sock:settimeout(0)
    sock:setoption("tcp-nodelay", true)

    local ok, err = sock:connect(self.host, self.port)
    if ok then
        self:_connectionMade()
    else
        self:_startConnecting()
    end
end

function SocketTCP:disconnect()
    self:_stopConnecting()
    self:_stopReading()
    self:_stopWriting()

    self.sock:close()

    self:_connectionLost()
end

function SocketTCP:_connectionMade()
    self.state = "connected"
    self.sendBuf = {}

    self:_startReading()
    print("conneciton Made")

    self:connectionMade()
end

function SocketTCP:connectionMade()
end

function SocketTCP:_connectionFailed()
    self.state = "connectFailed"
    print("connection Failed")

    self:connectionFailed()
end

function SocketTCP:connectionFailed()

end

function SocketTCP:_connectionLost()
    local oldState = self.state

    self.state = "closed"
    print("connection Lost")

    if oldState == "connected" then
        self:connectionLost()
    end
end

function SocketTCP:connectionLost()
end

function SocketTCP:dataReceived(data)
    print("data recevied:", inspect(data))

    self:send(string.rep(data, 100000))
end

function SocketTCP:send(data)
    self.sendBuf[#self.sendBuf + 1] = {data = data, pos = 1}
    self:_startWriting()
end

local host = "localhost"
local port = 8080

local loop = ev.Loop.default

local sock = SocketTCP(loop, host, port)
sock:connect()

loop:loop()
print("END")
