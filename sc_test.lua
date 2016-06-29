local sc = require("schema")
local inspect = require("inspect")

local function check(typ, value)
    typ = sc.checkType(typ)
    local name, expected, actual = typ("value", value)

    if actual then
        return false, table.concat({inspect(value),  "\n", name, " 应该为: ", expected , " 实为: ", actual})
    else
        return true
    end
end

local Person = sc.Array(sc.Record({name = sc.String, age = sc.Int, id = sc.Int}))

print(check(Person, {{name = "张三", age = 1, id = 12}}))

local Person = sc.Array(sc.NamedTuple({{"name", sc.String}, {"age",sc.Int}, {"id", sc.Int}}))

print(check(Person, {{"张三", 1, 12}}))

