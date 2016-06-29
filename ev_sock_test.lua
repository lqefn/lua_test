local ev = require("ev")
local socket = require("socket")
local inspect = require("inspect")
local struct = require("struct")

local loop = ev.Loop.default
local client = socket.tcp()
client:settimeout(0)
client:connect("www.baidu.com", 80)

function on_read(loop, watcher, event)
    print("onread event", event)

    print(inspect({client:receive("*a")}))
end

function on_write(loop, watcher, event)
    print("on_write event", event)

    local msg = "GET / HTTP/1.1\r\n\r\n"
    print(inspect({client:send(struct.pack(">I", #msg) .. msg)}))
    loop:unloop()
end

ev.IO.new(on_read, client:getfd(), ev.READ):start(loop)
ev.IO.new(on_write, client:getfd(), ev.WRITE):start(loop)

local loopTimer = ev.Timer.new(function(loop, watcher, event)
    loop:unloop()
end, 0.000001, 0.0000001)
loopTimer:start(loop)

for i = 1, 10 do
    socket.sleep(0.2)
    loop:loop()
end

require("class")

Transport = Class()
function Transport:write(data)
end

function Transport:loseConnection()
end

Connector = Class(function(self, factory)
    self.factory = factory

end)

function Connector:connect()
end

function Connector:startConnecting()
end

function Connector:stopConnecting()
end

function Connector:disconnect()
end

Factory = Class()
function Factory:buildProtocol(addr)
end

function Factory:doStart()
end

function Factory:doStop()
end

function Factory.forProtocol(protocol)
end

ClientFactory = Class(Factory)
function ClientFactory:startedConnecting(connector)
end

function ClientFactory:clientConnectionFailed(connector, reason)
end

function ClientFactory:clientConnectionLost(connector, reason)
end

ReconnectingClientFactory = Class(ClientFactory, function(self)
    self.maxDelay = 3600
    self.initialDelay = 1.0
    self.factor = 2.7182818284590451
    self.jitter = 0.11962656472

    self.delay = self.initialDelay
    self.retries = 0
    self.maxRetries = nil
    self._callID = nil
    self.connector = nil
    self.clock = nil

    self.continueTrying = 1
end)

function ReconnectingClientFactory:clientConnectionFailed(connector, reason)
    if self.continueTrying then
        self.connector = connector
        self:retry()
    end
end

function ReconnectingClientFactory:clientConnectionLost(connector, unused_reason)
    if self.continueTrying then
        self.connector = connector
        self:retry()
    end
end

function ReconnectingClientFactory:retry(connector)
    if not self.continueTrying then
        if self.noisy then
        --log.msg("Abandoning %s on explicit request", connector,))
        end
        return
    end

    if connector == nil then
        if self.connector == nil then
            error("no connector to retry")
        else
            connector = self.connector
        end
    end

    self.retries = self.retries + 1
    if self.maxRetries ~= nil and (self.retries > self.maxRetries) then
        if self.noisy then
        --log.msg("Abandoning %s after %d retries." % (connector, self.retries))
        end
        return
    end

    self.delay = math.min(self.delay * self.factor, self.maxDelay)
    if self.jitter then
        self.delay = math.random() * (self.delay + self.delay * self.jitter)
    end

    if self.noisy then
    --log.msg("%s will retry in %d seconds" % (connector, self.delay,))
    end

    local function reconnector()
        self._callID = nil
        connector:connect()
    end

    self._callID = self.clock:callLater(self.delay, reconnector)
end

function ReconnectingClientFactory:stopTrying()
    if self._callID then
        self._callID:cancel()
        self._callID = nil
    end

    self.continueTrying = 0
    if self.connector then
        pcall(function()
            self.connector:stopConnecting()
        end)
    end
end

function ReconnectingClientFactory:resetDelay(self)
    self.delay = self.initialDelay
    self.retries = 0
    self._callID = nil
    self.continueTrying = 1
end

Protocol = Class(function(self)
    self.connected = false
    self.transport = nil
end)

function Protocol:makeConnection(transport)
    self.connected = true
    self.transport = transport
    self:connectionMade()
end

function Protocol:connectionMade()
end

function Protocol:dataReceived(data)
end

function Protocol:connectionLost(reason)
end

local IntNStringReceiver = Class(Protocol, function(self)
    Protocol._ctor(self)

    self._unprocessed = ""
    self.MAX_LENGTH = 99999
end)

function IntNStringReceiver:stringReceived(string)
end

function IntNStringReceiver:lengthLimitExceeded(length)
    self.transport:loseConnection()
end

function IntNStringReceiver:dataReceived(data)
    local alldata = self._unprocessed .. data
    local currentOffset = 1
    local prefixLength = self.prefixLength
    local fmt = self.structFormat
    self._unprocessed = alldata

    while (#alldata > currentOffset + prefixLength) do
        local messageStart = currentOffset + prefixLength
        local length = struct.unpack(fmt, alldata, currentOffset)
        if length > self.MAX_LENGTH then
            self._unprocessed = alldata
            self:lengthLimitExceeded(length)
            return
        end

        local messageEnd = messageStart + length - 1
        if #alldata < messageEnd then
            print("#alldata", #alldata, "messageEnd:", messageEnd)
            break
        end

        local packet = string.sub(alldata, messageStart, messageEnd)
        currentOffset = messageEnd + 1
        self:stringReceived(packet)
        self._unprocessed = string.sub(alldata, currentOffset)
        print("unproc:", self._unprocessed)
    end
end

function IntNStringReceiver:sendString(string)
    if #string >= 2 ^ (8 * self.prefixLength) then
        error(string.format("Try to send %d bytes whereas maximum is %d", #string, 2 ^ (8 * self.prefixLength)))
    end
    self.transport:write(struct.pack(self.structFormat, #string) .. string)
end

Int32StringReceiver = Class(IntNStringReceiver, function(self)
    IntNStringReceiver._ctor(self)

    self.structFormat = ">I"
    self.prefixLength = struct.size(self.structFormat)
end)

Int16StringReceiver = Class(IntNStringReceiver, function(self)
    IntNStringReceiver._ctor(self)

    self.structFormat = ">H"
    self.prefixLength = struct.size(self.structFormat)
end)

Int8StringReceiver = Class(IntNStringReceiver, function(self)
    IntNStringReceiver._ctor(self)

    self.structFormat = ">B"
    self.prefixLength = struct.size(self.structFormat)
end)

function Int8StringReceiver:stringReceived(string)
    print("recv str:", inspect(string))
end
function Int8StringReceiver:dataReceived(data)
    print("recv data", inspect(data))
    self._base.dataReceived(self, data)
end
i8s = Int8StringReceiver()

local data = "Hello"
i8s:dataReceived(struct.pack(">B", #data) .. data)
local data = "dsdsdsdsdsdsds"
i8s:dataReceived(struct.pack(">B", #data) .. data)
local data = "Hello,中华人民共和国"
i8s:dataReceived(struct.pack(">B", #data))
i8s:dataReceived(string.sub(data, 1, -2))
i8s:dataReceived(string.sub(data, -1))
local data = "Hello，有机会"
i8s:dataReceived(struct.pack(">B", #data) .. data)
