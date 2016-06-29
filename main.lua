local Thread = require("llthreads2.ex")
local socket = require("socket")
local inspect = require("inspect")
print(socket)

local function main()
    print("main start")

    local t = Thread.new(function()
        local struct = require("struct")
        local socket = require("socket")
        local cjson = require("cjson")
        print(socket)
        local sock = socket.connect("localhost", 8080)
        local dataList = {}

        while true do
            local sendData = "Hello, test"
            sock:send(struct.pack("<i", string.len(sendData)))
            sock:send(sendData)

            local lenData = sock:receive(4)
            local len, _ = struct.unpack("<i", lenData)
            print(len)
            local data = sock:receive(len)
            table.insert(dataList, data)
        end
        sock:close()

        return unpack(dataList)
    end)

    t:start()
    local ret = {t:join()}
    print(inspect(ret))
end

main()
print("end")
