function Class(base, _ctor)
    local c = {}    -- a new class instance
    if not _ctor and type(base) == 'function' then
        _ctor = base
        base = nil
    elseif type(base) == 'table' then
        -- our new class is a shallow copy of the base class!
        for i,v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end

    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    c.__index = c

    -- expose a constructor which can be called by <classname>(<args>)
    local mt = {}

    mt.__call = function(class_tbl, ...)
        local obj = {}
        setmetatable(obj,c)
        if c._ctor then
            c._ctor(obj,...)
        end
        return obj
    end
    c._ctor = _ctor
    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do
            if m == klass then return true end
            m = m._base
        end
        return false
    end

    setmetatable(c, mt)
    return c
end

function defineProperty(class_tbl, name, func)
    local index = rawget(class_tbl, "__index")
    if type(index) == "table" then
        class_tbl.__index = function(obj, name)
            local retval = rawget(obj, name)
            if retval then
                return retval
            end

            local prop = rawget(rawget(class_tbl, "__prop") or {}, name)
            if type(prop) == "function" then
                return prop(obj, name)
            end

            return nil
        end
    end

    class_tbl.__prop = class_tbl.__prop or {}
    class_tbl.__prop[name] = func
end

Person = Class()
function Person:_ctor(name, age)
    self.name = name
    self.age = age
end

function Person:__tostring()
    return string.format("Person<%s,%d>", self.name, self.age)
end

p = Person("张三", 32)
print(Person, p)
print(p)
defineProperty(Person, "propName", function(self) return string.format("<%s>", self.name) end)
print(p.propName)
