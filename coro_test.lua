local Thread = require("llthreads2.ex")
local socket = require("socket")
local http = require("socket.http")

taskList = {}

function startHttpRequestTask(url, callback)
    print("startHttpRequest", url)
    local task = Thread.new(function(url)
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        print("request", url)
        local t = {}
        local respt = http.request{
            url = url,
            sink = ltn12.sink.table(t)
        }
        return table.concat(t)
    end, url)
    task:start()
    taskList[#taskList + 1] = {task = task, callback = callback}
end

function AsyncHttpRequest(url)
    local coro = coroutine.running()
    print("load :", url)
    startHttpRequestTask(url, function(result) coroutine.resume(coro, result) end)
end

function update()
    if #taskList > 0 then
        for idx = #taskList, 1, -1 do
            local taskInfo = taskList[idx]

            local task = taskInfo.task
            if not task:alive() then
                local ok, ret = task:join()
                local callback = taskInfo.callback
                print("task done")
                callback(ret)
                table.remove(taskList, idx)
            end
        end
        return true
    else
        print("all task complete")
        return false
    end
end

function cofunction()
    print("start")
    local dataList = {"http://www.baidu.com", "http://www.python.com", "http://www.sina.cn"}
    for idx, data in ipairs(dataList) do
        local param = data
        print("loadAsync:", param)
        local res = coroutine.yield(AsyncHttpRequest(param))
        print("task result:", string.sub(res, 1, 100) .. "...")
    end
end

co = coroutine.create(cofunction)
print(coroutine.resume(co))

function loop()
    while update() do
        socket.sleep(1.0 / 60)
        --print("update")
    end
end

loop()
print("loop end")
