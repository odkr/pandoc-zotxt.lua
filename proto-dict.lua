Keys = {}
local mt = {}
setmetatable(Keys, mt)

-- if we had a pairs metamethod, that returns an iterator that
-- whenever it hits nil, it doesn't return, but simply grabs
-- the prototype, 

function mt.__pairs (obj)
    local h = {}
    local t = obj
    local k
    return function ()
        while true do
            local v
            repeat k, v = next(t, k) until k == nil or not h[k]
            if k ~= nil then
                h[k] = true
                return k, v
            end
            local mt = getmetatable(t)
            if not mt then return end
            if type(mt.__index) ~= 'table' then return end
            t = mt.__index 
            k = nil
        end
    end
end

objA = {a = 1, b = 1}
objB = setmetatable({b = 2}, {__index = objA, __pairs = mt.__pairs})

for k, v in pairs(objB) do print(k, v) end
