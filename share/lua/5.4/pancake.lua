---
-- Toolkit for writing [Lua filters](https://pandoc.org/lua-filters.html)
-- for [Pandoc](https://pandoc.org).
--
-- @author Odin Kroeger
-- @copyright 2022 Odin Kroeger
-- @license MIT
-- @release v0.0.0

-- Initialisation
-- --------------

-- luacheck: module, allow defined top
-- luacheck: globals PANDOC_VERSION PANDOC_SCRIPT_FILE PANDOC_STATE pandoc

-- Load Pandoc modules in older versions of Pandoc.
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
if not pandoc.List then pandoc.List = require 'List' end
if pandoc.types then
    if PANDOC_VERSION >= {2, 8} and not pandoc.system then
        pandoc.system = require 'pandoc.system'
    end
    if PANDOC_VERSION >= {2, 12} and not pandoc.path then
        pandoc.path = require 'pandoc.path'
    end
end

-- Set up custom global environment.
local _G = _G

local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local pairs = pairs
local pcall = pcall
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type

local debug = debug
local io = io
local math = math
local os = os
local package = package
local string = string
local table = table

local PANDOC_STATE = PANDOC_STATE
local PANDOC_SCRIPT_FILE = PANDOC_SCRIPT_FILE
local PANDOC_VERSION = PANDOC_VERSION
local pandoc = pandoc

local M = {}
local _ENV = M

local format = string.format
local concat = table.concat
local pack = table.pack
local unpack = table.unpack
local sort = table.sort
local stringify = pandoc.utils.stringify
local includes = pandoc.List.includes


--- System
-- @section

--- The path segment separator used by the operating system.
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence typically used on the given operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


--- Type-checking
-- @section

do
    local abbrs = {
        ['%*'] = 'boolean|function|number|string|table|thread|userdata',
        ['%?(.*)'] = '%1|nil'
    }
    local msg = 'expected %s, got %s.'

    ---
    -- Check whether a value is of a type.
    --
    -- <h3>Type Declaration Grammar:</h3>
    --
    -- Give one or more Lua type names separated by a pipe ('|') to check
    -- that a value is of one of the given types (e.g., 'string|table'
    -- checks whether the value is a string or a table). '*' is short
    -- for the list of all types but `nil`. '?T' is short for 'T|nil'
    -- (e.g., '?table' is short for 'table|nil').
    --
    -- In [Extended Backus-Naur Form](https://en.wikipedia.org/wiki/EBNF):
    --
    -- > Type = 'boolean' | 'function' | 'nil'    | 'number'   |
    --          'string'  | 'table'    | 'thread' | 'userdata'
    -- >
    -- > Type list = [ '?' ], type, { '|', type }
    -- >
    -- > Wildcard = [ '?' ], '*'
    -- >
    -- > Type declaration = type list | wildcard
    --
    -- <h3>Complex Types:</h3>
    --
    -- You can check types of table or userdata fields by
    -- declarding a table that maps indices to declarations.
    --
    --      > type_check({1, '2'}, {'number', 'number'})
    --      nil    index 2: expected number, got string.
    --      > type_check({foo = 'bar'}, {foo = '?table'})
    --      nil    index foo: expected table or nil, got string.
    --      > type_check('foo', {foo = '?table'})
    --      nil    expected table or userdata, got string.
    --
    -- <h3>Caveats:</h3>
    --
    -- Wrong type names (e.g., 'int') do *not* throw an error,
    -- but will always return one.
    --
    -- @param val A value.
    -- @tparam string|table decl A type declaration.
    -- @treturn[1] bool `true` if the value matches the declaration.
    -- @treturn[2] nil `nil` otherwise.
    -- @treturn[2] string An error message.
    function type_match (val, decl, _seen)
        local t = type(decl)
        if t == 'string' then
            -- luacheck: ignore t
            local t = type(val)
            for pattern, repl in pairs(abbrs) do
                decl = decl:gsub(pattern, repl)
            end
            for exp in decl:gmatch '[^|]+' do
                if t == exp then return true end
            end
            return nil, msg:format(decl:gsub('|', ' or '), t)
        elseif t == 'table' then
            -- luacheck: ignore t
            local ok, err = type_match(val, 'table|userdata')
            if not ok then return nil, err end
            if not _seen then _seen = {} end
            assert(not _seen[val], 'cycle in data tree.')
            _seen[val] = true
            for k, t in pairs(decl) do
                ok, err = type_match(val[k], t, _seen)
                if not ok then return nil, format('index %s: %s', k, err) end
            end
            return true
        end
        error(msg:format('string or table', t))
    end
end

--- Decorator that adds type checks to a function.
--
-- Only adds type checks if the global variable `DEBUG` is truthy.
--
-- <h3>Type declaration grammar:</h3>
--
-- The type declaration syntax is that of @{type_match}, save for
-- that you can use '...' to declare that the remaining arguments
-- are of the same type as the previous one.
--
-- @tip Obscure Lua errors may indicate that
--  the quotes around '...' are missing.
--
-- @caveats
--
-- * Wrong type names (e.g., 'int') do *not* throw an error.
-- * Sometimes the strack trace is wrong.
--
-- @tparam string|table ... One type declaration per argument.
-- @treturn func A function that adds type checks to another function.
--
-- @usage
-- store = type_check('*', 'table', '?number', '...')(
--     function (val, tab, ...)
--          local indices = table.pack(...)
--          for i = 1, indices.n do tab[indices[i]] = val end
--     end
-- )
--
-- @function type_check
function type_check (...)
    local decls = pack(...)
    if not _G.DEBUG then
        return function (...) return ... end
    end
    return function (func)
        return function (...)
            local args = pack(...)
            local decl, prev
            local n = math.max(decls.n, args.n)
            for i = 1, n do
                if     decls[i] == '...' then prev = true
                elseif decls[i]          then prev = false
                                              decl = decls[i]
                elseif not prev          then break
                end
                if args[i] == nil and prev and i >= decls.n then break end
                local ok, err = type_match(args[i], decl)
                if not ok then error(format('argument %d: %s', i, err), 2) end
            end
            return func(...)
        end
    end
end


--- Errors
-- @section

--- Create a custom assertion function.
--
-- See <http://lua-users.org/wiki/FinalizedExceptions>.
--
-- @func[opt] fin Called before an error is thrown.
-- @func[opt] msgh Takes the error and the caller's variables,
--  and returns a new error.
-- @treturn func An assertion function.
--
-- @usage
-- > local assert = asserter(nil, vars_sub)
-- > function foo ()
-- >    bar = 'The bar'
-- >    assert(false, '${bar} is to blame!')
-- > end
-- > foo()
-- The bar is to blame!
-- stack traceback:
--         [C]: in function 'error'
--         stdin:3: in function 'foo'
--         (...tail calls...)
--         [C]: in ?
--
-- @function asserter
asserter = type_check('?function', '?function')(
    function (fin, msgh)
        return function (ok, ...)
            if ok then return ok, ... end
            if fin then fin() end
            local err = ...
            if msgh then err = msgh(err, vars_get(3)) end
            error(err, 0)
        end
    end
)

--- Decorator that runs a function in protected mode.
--
-- See <http://lua-users.org/wiki/FinalizedExceptions>.
--
-- @func func A function.
-- @treturn func A function running in protected mode.
--
-- @usage
-- > foo = protect(function () return 'foo' end)
-- > foo()
-- foo
-- > boo = protect(function () error 'bar!' end)
-- > boo()
-- nil    bar!
--
-- @function protect
-- @see unprotect
protect = type_check('function')(
    function (func)
        return function (...)
            local results = pack(pcall(func, ...))
            if not results[1] then return nil, unpack(results, 2) end
            return unpack(results, 2)
        end
    end
)

--- Decorator that raises an error if a function returns a falsy value.
--
-- @func func A function.
-- @treturn func A function that throws an error on failures.
--
-- @usage
-- > foo = unprotect(function () return 'foo' end)
-- > foo()
-- foo
-- > boo = unprotect(function () return nil, 'boo.' end)
-- > boo()
-- boo.
-- stack traceback:
--         [C]: in function 'error'
--         stdin:4: in function 'boo'
--         (...tail calls...)
--         [C]: in ?
--
-- @function unprotect
-- @see protect
unprotect = type_check('function')(
    function (func)
        return function (...)
            local results = pack(func(...))
            if not results[1] then error(results[2], 0) end
            return unpack(results)
        end
    end
)


--- Tables
-- @section

--- Make a *deep* copy of a value.
--
-- * Copies metatables.
-- * Handles cyclic data.
-- * Bypasses `__pairs` and `__newindex`.
--
-- @param val A value.
-- @return A deep copy.
--
-- @usage
-- > foo = {1, 2, 3}
-- > bar = {foo, 4}
-- > baz = copy(bar)
-- > foo[#foo + 1] = 4
-- > table.unpack(baz, 1)
-- 1    2    3
--
-- @function copy
copy = type_check('?*', '?table')(
    function (val, _seen)
        if type(val) ~= 'table' then return val end
        if     not _seen  then _seen = {}
        elseif _seen[val] then return _seen[val]
        end
        local cp = {}
        local mt = getmetatable(val)
        if type(mt) == 'table' then setmetatable(cp, mt) end
        _seen[val] = cp
        for k, v in next, val do
            rawset(cp, copy(k, _seen), copy(v, _seen))
        end
        return cp
    end
)

--- Get the indices and number of items in a table.
--
-- @tip
--
-- `select(2, keys(t)) == #t` checks whether a table is a list.
--
-- @tab tab A table.
-- @treturn tab The indices.
-- @treturn int The number of items.
--
-- @function keys
keys = type_check('table')(
    function (tab)
        local ks = {}
        local n = 0
        for k in pairs(tab) do
            n = n + 1
            ks[n] = k
        end
        return ks, n
    end
)

--- Derive a sorting function from a list of values.
--
-- Values that are not in the list are sorted lexically.
--
-- @tab values Values.
-- @treturn func A sorting function.
--
-- @usage
-- > tab = {a = 3, b = 4, c = 2, d = 1}
-- > for k, v in sorted(tab, order{'d', 'c'}) do
-- >     print(k, v)
-- > end
-- d    1
-- c    2
-- a    3
-- b    4
--
-- @function order
order = type_check('table')(
    function (vals)
        local order = {}
        for i = 1, #vals do order[vals[i]] = i end
        return function (a, b)
            local i, j = order[a], order[b]
            if i and j then return i < j end
            if i then return true end
            if j then return false end
            return a < b
        end
    end
)

--- Iterate over the key-value pairs of a table in a given order.
--
-- @tab tab A table.
-- @func[opt] func A sorting function.
--  Defaults to the `sort` metamethod or sorting lexically.
-- @bool[opt] raw Bypass `__pairs` metamethod?
--  Done by default if `__pairs` is set to `sorted`.
-- @treturn func A *stateful* iterator.
--
-- @usage
-- > -- Iterating over keys in lexical order.
-- > tab = {c = 3, b = 2, a = 1}
-- > for k, v in sorted(tab) do
-- >     print(k, v)
-- > end
-- a    1
-- b    2
-- c    3
-- -- Supplying a sorting function.
-- > for k, v in sorted(tab, order{'c', 'b', 'a'}) do
-- >     print(k, v)
-- > end
-- c    3
-- b    2
-- a    1
-- > -- Setting the `sort` metamethod.
-- > mt = {sort = order{'c', 'b', 'a'}}
-- > setmetatable(tab, mt)
-- > for k, v in sorted(tab) do
-- >     print(k, v)
-- > end
-- c    3
-- b    2
-- a    1
-- > -- Using `sorted` as `__pairs` metamethod.
-- > mt.__pairs = sorted
-- > for k, v in pairs(tab) do
-- >     print(k, v)
-- > end
-- c    3
-- b    2
-- a    1
--
-- @function sorted
sorted = type_check('table', '?function', '?boolean')(
    function (tab, func, raw)
        local mt = getmetatable(tab)
        if mt then
            if not func then func = mt.sort end
            if raw == nil then raw = mt.__pairs == sorted end
        end
        local ks
        if raw then ks = pack(tabulate(next, tab))
               else ks = keys(tab)
        end
        sort(ks, func)
        local i = 0
        return function ()
            i = i + 1
            local k = ks[i]
            if k == nil then return end
            return k, tab[k]
        end, tab
    end
)

--- Tabulate the values that an iterator returns.
--
-- @func iter An iterator. Must accept, but not honour,
--  the same arguments as @{next}.
-- @tab[opt] tab A table to iterate over.
-- @param[opt] idx An index to start at.
-- @return The values returned by the iterator.
--
-- @usage
-- > tab = {a = true, b = true, c = true}
-- > tabulate(next, tab)
-- a    b    c
--
-- @function tabulate
tabulate = type_check('function')(
    function (iter, tab, idx)
        local vals = {}
        local n = 0
        for v in iter, tab, idx do
            n = n + 1
            vals[n] = v
        end
        return unpack(vals)
    end
)

-- Merge tables.
--
-- @caveats The first table is updated *in-place*.
--
-- @tab tab A table.
-- @tparam tab|userdata ... Mappings to merge into that table.
-- @treturn tab The table.
--
-- @function update
update = type_check('table', '?table|userdata', '...')(
    function (tab, ...)
        local maps = pack(...)
        for i = 1, maps.n do
            if maps[i] then
                for k, v in pairs(maps[i]) do tab[k] = v end
            end
        end
        return tab
    end
)

--- Walk a tree and apply a function to every node.
--
-- * The tree is walked bottom-up.
-- * Nodes are only changed if the function returns a value other than `nil`.
-- * Handles cyclic data structures.
--
-- @param val A value.
-- @func func A function.
-- @return A changed value.
--
-- @function walk
walk = type_check('*', 'function', '?table')(
    function (val, func, _seen)
        if type(val) ~= 'table' then
            local ret = func(val)
            if ret == nil then return val end
            return ret
        end
        if     not _seen  then _seen = {}
        elseif _seen[val] then return _seen[val]
        end
        local ret = {}
        local mt = getmetatable(val)
        if type(mt) == 'table' then setmetatable(ret, mt) end
        _seen[val] = ret
        for k, v in pairs(val) do
            if type(v) == 'table' then v = walk(v, func, _seen) end
            local new = func(v)
            if new == nil then ret[k] = v
                          else ret[k] = new
            end
        end
        return ret
    end
)

---------
-- Strings
--
-- @section

--- Iterate over substrings of a string.
--
-- @caveats Neither supports multi-byte characters nor frontier patterns.
--
-- @string str A string.
-- @string pattern Where to split the string.
-- @int[opt] max Split the string into at most that many substrings.
-- @string[opt] incl Include separators in substrings?
--
--  * 'l' includes them on the left,
--  * 'r' on the right.
--
--  By default, separators are *not* included.
-- @treturn func A *stateful* iterator.
--
-- @usage
-- > for s in split('CamelCase', '%u', nil, 'l') do
-- >     print(string.format('"%s"', s))
-- > end
-- ""
-- "Camel"
-- "Case"
--
-- @function split
-- @todo Add a flag to disable pattern matching?
split = type_check('string', 'string', '?number', '?string')(
    function (str, pattern, max, incl)
        -- @fxime Why wouldn't it? Check this.
        assert(not pattern:match '%f[%%]%%f', 'split does not support %f.')
        assert(not incl or incl == 'l' or incl == 'r', 'expecting "l" or "r".')
        local pos = 1
        local lst = 1
        local n = 1
        return function ()
            if not pos then return end
            local ts, te, s, e
            if not max or n < max then s, e = str:find(pattern, pos) end
            if s then
                if not incl then
                    ts = pos
                    te = s - 1
                elseif incl == 'l' then
                    ts = lst
                    te = s - 1
                else
                    ts = pos
                    te = e
                end
                pos = e + 1
                lst = s
            else
                if incl == 'l' then
                    ts = lst
                else
                    ts = pos
                end
                pos = nil
            end
            n = n + 1
            return str:sub(ts, te)
        end
    end
)


--- Variables
-- @section

--- Get a copy of a function's variables.
--
-- @caveats
--
-- If a global variable is shadowed by a variable that is neither one of
-- the function's local variables nor one of its upvalues, then that variable
-- is looked up in `_ENV` and the shadowing variable is ignored.
--
-- @int[opt=2] level A stack level > 0, where
--  `vars_get` is at level 1,
--  its caller is at level 2,
--  etc.
-- @treturn table A mapping of variable names to values.
--
-- @usage
-- > function bar ()
-- >     print(vars_get(3).foo)
-- > end
-- > function foo ()
-- >     foo = 'foo'
-- >     bar()
-- > end
-- > foo()
-- foo
--
-- @function vars_get
vars_get = type_check('?number')(
    function (level)
        if not level then level = 2 end
        assert(level > 0, 'stack level is not a positive number.')
        local info = debug.getinfo(level, 'f')
        assert(info, 'the stack is not that high.')
        local vars = copy(_ENV)
        for i = 1, 2 do
            local j = 1
            while true do
                local k, v
                if i == 1 then k, v = debug.getupvalue(info.func, j)
                          else k, v = debug.getlocal(level, j)
                end
                if not k then break end
                vars[k] = copy(v)
                j = j + 1
            end
        end
        return vars
    end
)

do
    -- Lookup a path in a namespace.
    --
    -- @tab vars A mapping of variable names to values.
    -- @string path A dot-separated path.
    -- @return[1] A value.
    -- @treturn[2] nil `nil` if an error occurs.
    -- @treturn[2] string An error message.
    local function lookup (vars, path)
        if     path == ''       then return nil, 'name is the empty string.'
        elseif path:match '^%.' then return nil, 'name starts with a dot.'
        elseif path:match '%.$' then return nil, 'name ends with a dot.'
        end
        local function sub (d) return path:sub(1, d - 1) end
        local len = #path
        local v = vars
        for seg, d in path:gmatch '([^%.]*)()' do
            if seg == '' then
                return nil, sub(d) .. ': consecutive dots.'
            elseif not seg:match '^[_%a][_%w]*$' then
                return nil, sub(d) .. ': illegal name.'
            end
            v = v[seg]
            if d > len then break end
            local t = type(v)
            if t ~= 'table' then
                return nil, format('%s: expected table, got %s.', sub(d), t)
            end
        end
        if v == nil then return nil, path .. ': is undefined.' end
        return v
    end

    -- Expand a variable from a variable expression.
    --
    -- See @{vars_sub} for the expression syntax.
    --
    -- @tab seen Variables encounterd so far.
    -- @tab vars A mapping of variable names to values.
    -- @string exp A variable expression.
    -- @treturn string The value of the expression.
    -- @raise See @{vars_sub}.
    local function expand (seen, vars, exp)
        -- luacheck: ignore assert msgh
        local function msgh (err) return format('${%s}: %s', exp, err) end
        local assert = asserter(nil, msgh)
        local path, pipe = tabulate(split(exp, '|', 2))
        assert(not seen[path], 'cycle in lookup.')
        seen[path] = true
        local v = assert(lookup(vars, path))
        if type(v) == 'string' then v = assert(vars_sub(v, vars, seen)) end
        if pipe then
            for fn in split(pipe, '|') do
                local f = assert(lookup(vars, fn))
                assert(type(f) == 'function', fn .. ': not a function.')
                v = f(v)
            end
        end
        assert(type_match(v, 'number|string'))
        return tostring(v)
    end

    --- Substitute variables in strings.
    --
    -- If a string of characters is placed within braces ('{...}') and the
    -- opening brace ('{') immediately follows a single dollar ('$') sign,
    -- then that string is interpreted as a variable name and the whole
    -- expression is replaced with the value of that variable. Variable names
    -- must only consist of letters, numbers, and underscores ('_') and
    -- must start with a letter or an underscore.
    --
    --    > vars_sub(
    --    >     '${v1} is ${v2}.',
    --    >     {v1 = 'foo', v2 = 'bar'}
    --    > )
    --    foo is bar.
    --
    -- If a braced string is preceded by two or more dollar signs, it is *not*
    -- interpreted as a variable name and the expression is *not* replaced
    -- with the value of a variable. Moreover, any series of *n* dollar signs
    -- is replaced with *n* – 1 dollar signs.
    --
    --    > vars_sub(
    --    >     '$${var} costs $$1.',
    --    >     {var = 'foo'}
    --    > )
    --    ${var} costs $1.
    --
    -- You can lookup values in tables by joining table
    -- indices with dots ('.').
    --
    --    > vars_sub(
    --    >     '${foo.bar} is baz.', {
    --    >         foo = { bar = 'baz' }
    --    >     }
    --    > )
    --    baz is baz.
    --
    -- If a variable name is followed by a pipe symbol ('|'), then the string
    -- between that pipe symbol and the next pipe symbol/the closing brace is
    -- interpreted as a function name, this function is then given the value
    -- of that variable, and the whole expression is replaced with the
    -- first value the function returns.
    --
    --    > vars_sub(
    --    >     '${var|barify} is bar!', {
    --    >         var = 'foo',
    --    >         barify = function (s)
    --    >             return s:gsub('foo', 'bar')
    --    >         end
    --    >     }
    --    > )
    --    bar is bar!
    --
    -- Variables are substituted recursively.
    --
    --    > vars_sub(
    --    >     '${foo|barify} is bar.', {
    --    >         foo = '${bar}',
    --    >         bar = 'baz'
    --    >         barify = function (s) return s:gsub('baz', 'bar') end
    --    >     }
    --    > )
    --    bar is bar.
    --
    -- The expression as a whole must evaluate either to a string or a number.
    --
    -- Variables can be given as a table (e.g., `{foo = 'bar'}`) or a function
    -- (e.g., `function (k) if k == 'foo' then return bar end end`). If
    -- they are given as a function, multi-dimensional lookups ('${foo.bar}'),
    -- pipes ('${foo|bar'), and recursive substitution are *not* supported.
    -- The given function is run in protected mode.
    --
    -- @string str A string.
    -- @tparam func|tab map A mapping of variable names to values.
    -- @treturn[1] string A transformed string.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    --
    -- @function vars_sub
    vars_sub = type_check('string', 'function|table', '?table')(protect(
        function (str, mapping, _seen)
            if not _seen then _seen = {} end
            local repl
            local t = type(mapping)
            if t == 'table' then
                repl = function (...) return expand(_seen, mapping, ...) end
            elseif t == 'function' then
                repl = function (...) return assert(mapping(...)) end
            else
                error(format('expected function or table, got %s.', t), 2)
            end
            return str:gsub('%f[%$]%${(.-)}', repl):gsub('%$(%$*)', '%1'), nil
        end
    ))
end

do
    -- luacheck: ignore assert
    local assert = asserter(nil, vars_sub)

    -- Look up a variable in the environment.
    --
    -- @side Prints a warning to STDERR if the variable is empty.
    --
    -- @string var The variable name.
    -- @treturn string The value of that variable.
    -- @raise An error if the variable name is illegal or
    --  if the variable is unset.
    local function get_env (var)
        assert(var ~= '', '$${}: variable name is the empty string.')
        assert(var:match '^[%a_][%w_]+$', '$${${var}}: illegal variable name.')
        local val = assert(os.getenv(var), '$${${var}}: is undefined.')
        if val == '' then xwarn('$${${var}}: is empty.') end
        return val
    end

    --- Substitute environment variables in strings.
    --
    -- Uses the same syntax as @{vars_sub}, but without
    -- pipes or recursive substitution.
    --
    -- @side Prints a warning to STDERR if a variable is empty.
    --
    -- @string str A string.
    -- @treturn[1] string A transformed string.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    --
    -- @function env_sub
    env_sub = type_check('string')(
        function (str)
            return vars_sub(str, get_env)
        end
    )
end


--- Metatables
-- @section

--- Metatable that makes indices case-insensitive.
--
-- @usage
--
-- > tab = setmetatable({}, ignore_case)
-- > tab.FOO = 'bar'
-- > tab.foo
-- bar
--
-- @todo Rename to nocase.
ignore_case = {}

--- Look up an item.
--
-- @tab tab A table.
-- @param key A key.
-- @return The item.
function ignore_case.__index (tab, key)
    if type(key) == 'string' and key:match '%u' then
        return tab[key:lower()]
    end
end

--- Store a new item.
--
-- @tab tab A table.
-- @param key A key.
-- @param val A value.
function ignore_case.__newindex (tab, key, val)
    if type(key) == 'string' then key = key:lower() end
    rawset(tab, key, val)
end

--- Metatable that sorts key-value pairs.
--
-- @usage
-- > tab = setmetatable({c = 3, b = 2, a = 1}, sort_pairs)
-- > for k, v in pairs(tab) do
-- >     print(k, v)
-- > end
-- a    1
-- b    2
-- c    3
sort_pairs = {}

--- Iterate over the key-value pairs of a table in a given order.
--
-- What order pairs are iterated over is defined by the `sort` metamethod.
-- If no metamethod of that name is given, pairs are iterated over in
-- lexical order. See @{sorted} for details.
--
-- @tab tab A table.
-- @treturn func A *stateful* iterator.
--
-- @usage
-- > sort = order{'c', 'b', 'a'}
-- > mt = update({sort = sort}, sort_pairs)
-- > tab = setmetatable({a = 1, b = 2, c = 3}, mt)
-- > for k, v in pairs(tab) do
-- >     print(k, v)
-- > end
-- c    3
-- b    2
-- a    1
sort_pairs.__pairs = sorted


--- Prototypes
-- @section

--- Base prototype.
--
-- @tip `Object(...)` is equivalent to `Object:new(...)`.
--
-- @object Object
Object = setmetatable({}, {
    __call = type_check({new = 'function'})(
        function (self, ...)
            return self:new(...)
        end
    )
})

--- Delegate to an object.
--
-- Set a table's metatable to a copy of the objects's metatable, then set the
-- table's `__index` metavalue to the object. If no table is given, create
-- one. If a metatable is given, override the table's new metatable with
-- that table. In other words,
--
--     Object:clone(tab, mt)
--
-- is equivalent to
--
--     do
--         local mt = update({}, getmetatable(Object), {__index = Object}, mt)
--         setmetatable(tab or {}, mt)
--     end
--
-- @caveats The given table is changed *in-place*.
--
-- @tab[opt] tab A table.
-- @tab[opt] mt A metatable.
-- @treturn tab The table.
--
-- @usage
-- > Foo = Object:clone({}, {__tostring = function (t) return t.bar end})
-- > Foo.bar = 'baz'
-- > tostring(Foo)
-- baz
-- > bar = Foo()
-- > tostring(bar)
-- baz
-- > bar.bar = 'bar'
-- > tostring(bar)
-- bar
--
-- @function Object:clone
Object.clone = type_check('table', '?table', '?table')(
    function (self, tab, mt)
        mt = update({}, getmetatable(self), {__index = self}, mt)
        return setmetatable(tab or {}, mt)
    end
)

--- Create and initialise a table that delegates to an object.
--
-- `Object:new(...)` is equivalent to `update(Object:clone(), ...)`.
--
-- @tab ... Properties.
-- @treturn Object An object.
--
-- @usage
-- > foo = Object:new{foo = 'foo'}
-- > foo.foo
-- foo
-- > bar = foo:new{bar = 'bar'}
-- > bar.foo
-- foo
-- > bar.bar
-- bar
--
-- @function Object:new
Object.new = type_check({clone = 'function'}, '?table', '...')(
    function (proto, ...)
        local obj = proto:clone()
        if select('#', ...) > 0 then update(obj, ...) end
        return obj
    end
)

--- Add getters to a table.
--
-- <h3>Getter protocol:</h3>
--
-- If an index is not present in a the table, look for a function of the same
-- name in the table's `getters` metavalue, which must be a table that maps
-- indices to functions. If `getters` contains a function of the give name,
-- that function is called with the table as its only argument and whatever it
-- returns is returned as the value of the given index. If `getters` does
-- not contain a function of that name, the name is looked up using the
-- table's *old* `__index` metavalue.
--
-- @caveats
--
-- * Tables are modified *in-place*.
-- * Getters are *not* inherited.
--
-- @tab tab A table.
-- @treturn tab The table.
--
-- @usage
-- > -- Enable getters for an object:
-- > Foo = getterify(Object:clone())
-- > Foo.foo = 'bar'
-- > mt = getmetatable(Foo)
-- > mt.getters = {bar = function (obj) return obj.foo end}
-- > Foo.bar
-- bar
-- > -- Getters are *not* inherited.
-- > baz = Foo()
-- > baz.foo = 'bam!'
-- > -- The getter is reached via the prototype chain,
-- > -- so it sees Foo.foo, not bar.foo:
-- > baz.bar
-- bar
-- > -- But you can make getters quasi-inheritable:
-- > Foo.clone = function (...) return getterify(Object.clone(...)) end
-- > baz = Foo()
-- > baz.foo = 'bam!'
-- > baz.bar
-- bam!
-- > -- Now every object down the prototype chain is getterified.
-- > bam = baz()
-- > bam.foo = 'BAM!'
-- > bam.bar
-- BAM!
--
-- @function getterify
getterify = type_check('table')(
    function (tab)
        local mt = update({}, getmetatable(tab))
        local index = mt.__index
        mt.__index = type_check('table')(
            -- luacheck: ignore tab
            function (tab, key)
                local getters = getmetatable(tab).getters
                if getters then
                    local get = getters[key]
                    if get then return get(tab) end
                end
                if index then
                    local t = type(index)
                    if t == 'table'    then return index[key]      end
                    if t == 'function' then return index(tab, key) end
                    error(format('__index points to a %s value.', t), 2)
                end
            end
        )
        return setmetatable(tab, mt)
    end
)


--- File I/O
-- @section

--- Check whether a file exists.
--
-- @caveats
--
-- Another process may create a file of the given name between the time
-- `file_exists` tries to access that file and the time it returns.
--
-- @string fname A filename.
-- @treturn[1] boolean `true` if the file exists.
-- @treturn[2] nil `nil` if the file does not exist.
-- @treturn[2] string An error message.
-- @treturn[2] int The error number 2.
-- @raise An error if the file cannot be closed again.
--
-- @function file_exists
file_exists = type_check('string')(
    function (fname)
        assert(fname ~= '', 'filename is the empty string.')
        local file, err, errno = io.open(fname, 'r')
        if not file then return nil, err, errno end
        assert(file:close())
        return true
    end
)

do
    --- Locate a file in Pandoc's resource path.
    --
    -- @caveats Absolute filenames are returned as they are.
    --
    -- @string fname A filename.
    -- @treturn[1] string A filename in Pandoc's resource path.
    -- @treturn[2] nil `nil` if the file could not be found.
    -- @treturn[2] string An error message.
    --
    -- @function file_locate
    local resource_path = PANDOC_STATE.resource_path
    file_locate = type_check('string')(
        function (fname)
            assert(fname ~= '', 'filename is the empty string.')
            if not resource_path or path_is_abs(fname) then return fname end
            for i = 1, #resource_path do
                local dir = resource_path[i]
                if dir == '' then
                    local err = 'resource path %d is the empty string.'
                    return nil, format(err, i)
                end
                local path = path_join(dir, fname)
                if file_exists(path) then return path end
            end
            return nil, fname .. ': not found in resource path.'
        end
    )
end

--- Read a file at once.
--
-- @string fname A filename.
-- @treturn[1] string The contents of the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--
-- @function file_read
file_read = type_check('string')(
    function (fname)
        assert(fname ~= '', 'filename is the empty string.')
        local str, err, errno, file, ok
        file, err, errno = io.open(fname, 'r')
        if not file then return nil, err, errno end
        str, err, errno = file:read('a')
        if not str then return nil, err, errno end
        ok, err, errno = file:close()
        if not ok then return nil, err, errno end
        return str
    end
)

do
    local with_temporary_directory
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        with_temporary_directory = pandoc.system.with_temporary_directory
    end

    -- Write data to a file (worker).
    --
    -- @param file The name or handle of a file to write data to.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written out sucessfully.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    local function write (fname, ...)
        local file, ok, err, errno
        file, err, errno = io.open(fname, 'w')
        if not file then return nil, err, errno end
        ok, err, errno = file:write(...)
        if not ok then return nil, err, errno end
        ok, err, errno = file:flush()
        if not ok then return nil, err, errno end
        return file:close()
    end

    --- Write data to a file at once.
    --
    -- If a file of that name exists already, it is overwritten.
    --
    -- @caveats
    --
    -- Data is first written to a temporary file, that file is then renamed
    -- to the given filename. This is safe and secure starting with Pandoc
    -- v2.8. If you are using an older version of Pandoc, the caveats of
    -- @{with_tmp_file} apply.
    --
    -- Moreover, if Pandoc exits because it catches a signal (e.g., because
    -- the user presses `Ctrl`-`c`), this file will *not* be deleted. This
    -- is a [bug](https://github.com/jgm/pandoc/issues/7355) in Pandoc.
    --
    -- @side
    --
    -- * Creates and deletes a temporary file.
    -- * Prints warnings to STDERR.
    --
    -- @string fname A filename.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    -- @raise An error if no unused temporary filename could be generated
    --  in Pandoc < v2.8 or if the temporary directory could not be
    --  created in Pandoc ≥ v2.8; the latter error cannot be caught.
    -- @function file_write
    __file_write_legacy = type_check('string')(
        function (fname, ...)
            assert(fname ~= '', 'filename is the empty string.')
            local dir = path_split(fname)
            local data = {...}
            return with_tmp_file(function(tf)
                local ok, err, errno
                xwarn 'writing to temporary file ${tf|path_prettify}.'
                ok, err, errno = write(tf, unpack(data))
                if not ok then return nil, err, errno end
                ok, err, errno = os.rename(tf, fname)
                if not ok then return nil, err, errno end
                xwarn 'renamed ${tf|path_prettify} to ${fname|path_prettify}.'
                return true
            end, dir)
        end
    )

    __file_write_modern = type_check('string')(
        function (fname, ...)
            assert(fname ~= '', 'filename is the empty string.')
            local dir, base = path_split(path_make_abs(fname))
            local data = {...}
            local tmp_dir
            local ok, err, errno = with_temporary_directory(dir, 'tmp',
                function (td)
                    tmp_dir = td
                    xwarn 'made temporary directory ${td|path_prettify}.'
                    local tmp_file = path_join(td, base)
                    local ok, err, errno = write(tmp_file, unpack(data))
                    if not ok then return nil, err, errno end
                    return os.rename(tmp_file, fname)
                end
            )
            if tmp_dir and not file_exists(tmp_dir) then
                xwarn 'removed ${tmp_dir|path_prettify}.'
            end
            return ok, err, errno
        end
    )

    if not pandoc.types or PANDOC_VERSION < {2, 8}
        then file_write = __file_write_legacy
        else file_write = __file_write_modern
    end
end

do
    -- List of all alphanumeric characters.
    local alnum = {}

    do
        -- ASCII/UTF-8 ranges for alphanumeric characters.
        local ranges = {
            {48,  57},  -- 0-9.
            {65,  90},  -- A-Z.
            {97, 122}   -- a-z.
        }

        for i = 1, #ranges do
            local first, last = unpack(ranges[i])
            for j = first, last do alnum[#alnum + 1] = string.char(j) end
        end
    end

    math.randomseed(os.time())

    --- Generate a name for a temporary file.
    --
    -- @caveats
    --
    -- Another process may create a file of the same name between the time
    -- `tmp_fname` checks whether that name is in use and the time it returns.
    --
    -- @string[opt] dir A directory to prefix the filename with.
    -- @string[opt='tmp-XXXXXX'] templ A template for the filename.
    --  'X's are replaced with random alphanumeric characters.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the generated filename is in use.
    -- @treturn[2] string An error message.
    --
    -- @function tmp_fname
    tmp_fname = type_check('?string', '?string')(
        function (dir, templ)
            assert(dir ~= '', 'directory is the empty string.')
            if not templ then templ = 'tmp-XXXXXX' end
            if dir then templ = path_join(dir, templ) end
            local len = #templ
            for _ = 1, 32 do
                local fname = ''
                for i = 1, len do
                    local c = templ:sub(i, i)
                    if c == 'X' then c = alnum[math.random(1, 62)] end
                    fname = fname .. c
                end
                if not file_exists(fname) then return fname end
            end
            return nil, 'failed to find unused temporary filename.'
        end
    )
end

--- Run a function with a temporary file.
--
-- Generates a temporary filename. Does *not* create that file.
-- If the function raises an error or returns `nil` or `false`,
-- the file of that name is deleted.
--
-- @caveats
--
-- The temporary file may have been created by *another* process. If that
-- file is located within a directory that other users have write access
-- to (e.g., `/tmp`), this is a security issue!
--
-- Moreover, if Pandoc exits because it catches a signal (e.g., because
-- the user presses `Ctrl`-`c`), the file will *not* be deleted. This
-- is a [bug](https://github.com/jgm/pandoc/issues/7355) in Pandoc.
--
-- @side May print error messages to STDERR.
--
-- @func func Given the name of the temporary file.
--  Must *not* change the working directory!
-- @string[opt] dir A directory to prefix the name
--  of the temporary file with. See @{tmp_fname}.
-- @string[opt] templ A template for the name
--  of the temporary file. See @{tmp_fname}.
-- @return The values returned by the function.
-- @raise An error if no unused temporary filename could be generated.
--
-- @function with_tmp_file
with_tmp_file = type_check('function', '?string', '?string')(
    function (func, dir, templ)
        local tmp_file, err = tmp_fname(dir, templ)
        if not tmp_file then error(err, 0) end
        local results = pack(pcall(func, tmp_file))
        local ok, success = unpack(results, 1, 2)
        if not ok or not success then
            -- luacheck: ignore ok err
            local ok, err, errno = os.remove(tmp_file)
            if     ok         then xwarn 'removed ${tmp_file|path_prettify}.'
            elseif errno ~= 2 then xwarn('@error', '@plain', err)
            end
        end
        return unpack(results, 2)
    end
)


--- Paths
-- @section

-- Check whether a path is absolute.
--
-- @caveats Accepts the empty string as path since Pandoc v2.12.
--
-- @string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
--
-- @function path_is_abs
if not pandoc.types or PANDOC_VERSION < {2, 12} then
    path_is_abs = type_check('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            if PATH_SEP == '\\' and path:match '^.:\\' then return true end
            return path:match('^' .. PATH_SEP) ~= nil
        end
    )
else
    path_is_abs = pandoc.path.is_absolute
end

--- Join path segments.
--
-- @string ... Path segments.
-- @treturn string A path.
--
-- @function path_join
--
-- @usage
-- > path_join('foo', 'bar')
-- foo/bar
path_join = type_check('string', '...')(
    function (...)
        local segs = {...}
        for i = 1, #segs do
            if segs[i] == '' then
                error(format('segment %d is the empty string.', i))
            end
        end
        return path_normalise(concat(segs, PATH_SEP))
    end
)

-- Make a path absolute.
--
-- @require Pandoc v2.8
--
-- @string path An absolute or relative path.
-- @treturn string An absolute path.
-- @function path_make_abs
if pandoc.types and PANDOC_VERSION >= {2, 8} then
    path_make_abs = type_check('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            if path_is_abs(path) then return path end
            local cwd = pandoc.system.get_working_directory()
            assert(cwd ~= '', 'current working directory is the empty string.')
            return path_join(cwd, path)
        end
    )
end

do
    -- Patterns that normalise directory paths.
    -- Order is significant.
    local patterns = {
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        {PATH_SEP .. '+', PATH_SEP},
        -- @todo This could be replaced by a frontier pattern.
        --       However, Lua v5.1 does not know about frontier patterns.
        {'(.)' .. PATH_SEP .. '$', '%1'},
        {'^%.' .. PATH_SEP, ''}
    }

    --- Normalise a path.
    --
    -- @string path A path.
    -- @treturn string A normalised path.
    --
    -- @function path_normalise
    --
    -- @usage
    -- > path_normalise './foo/./bar//'
    -- foo/bar
    path_normalise = type_check('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            for i = 1, #patterns do path = path:gsub(unpack(patterns[i])) end
            return path
        end
    )
end

do
    local get_working_directory
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        get_working_directory = pandoc.system.get_working_directory
    end

    local home_dir
    do
        if PATH_SEP == '/' then
            local env_home = os.getenv('HOME')
            if env_home and env_home ~= '' and path_is_abs(env_home) then
                home_dir = path_normalise(env_home)
            end
        end
    end

    --- Prettify a path.
    --
    -- Steps:
    --
    --  1. The path is normalised.
    --  2. The current working directory is removed from its beginning.
    --  3. The user's home directory is replaced with '~',
    --     but only on POSIX systems.
    --
    -- @require
    --
    -- Pandoc ≥ v2.12 to remove the working directory from a path;
    -- in earlier versions, this step is skipped.
    --
    -- @string path A path.
    -- @treturn string A prettier path.
    --
    -- @function path_prettify
    --
    -- @usage
    -- > path_prettify(env_sub '$HOME/foo/./bar//')
    -- ~/foo/bar
    path_prettify = type_check('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            path = path_normalise(path)
            if get_working_directory then
                local cwd = get_working_directory()
                local pos = #cwd + 1
                if path:sub(1, pos) == cwd .. PATH_SEP then
                    return path:sub(pos + 1)
                end
            end
            if home_dir then
                local pos = #home_dir + 1
                if path:sub(1, pos) == home_dir .. PATH_SEP then
                    return '~' .. path:sub(pos)
                end
            end
            return path
        end
    )
end

do
    -- Pattern to split a path into a directory and a filename part.
    local pattern = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'

    --- Split a path into a directory and a filename.
    --
    -- @string path A path.
    -- @treturn string The directory the file is in.
    -- @treturn string The file's name.
    --
    -- @function path_split
    --
    -- @usage
    -- > path_split 'foo/bar'
    -- foo    bar
    path_split = type_check('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            local dir, fname = path:match(pattern)
            if     dir == ''   then dir = '.'
            elseif fname == '' then fname = '.'
            end
            return path_normalise(dir), fname
        end
    )
end

do
    local get_working_directory
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        get_working_directory = pandoc.system.get_working_directory
    end

    --- Guess the project directory.
    --
    -- The project directory is the directory of the first input file *not*
    -- named '-' (i.e., of the first actual input file). If there is no such
    -- file, the project directory is the current working directory.
    --
    -- @require The working directory is represented by '.' in Pandoc < v2.8.
    --
    -- @treturn string A directory.
    function project_dir ()
        local input_files = PANDOC_STATE.input_files
        for i = 1, #input_files do
            local fname = input_files[i]
            if fname ~= '-' then return path_split(fname), nil end
        end
        if get_working_directory then return get_working_directory() end
        return '.'
    end
end


--- Warnings
-- @section

do
    --- The filename of the script.
    local script_fname = select(2, path_split(PANDOC_SCRIPT_FILE))

    -- Priority levels for messages.
    local levels = {'error', 'warning', 'info'}

    -- What level if verbosity is desired.
    local verbosity
    if PANDOC_STATE and PANDOC_STATE.verbosity
        then verbosity = PANDOC_STATE.verbosity:lower()
        else verbisoty = 'warning'
    end

    -- Compare verbosity levels.
    --
    -- @string a A verbosity level.
    -- @string b Another verbosity level.
    -- @treturn bool Whether level A is smaller than level B.
    local is_quieter = order(levels)

    --- Print a message to STDERR.
    --
    -- <h3>Printout:</h3>
    --
    -- Prefixed with file of the script and ': ', and terminated with @{EOL}.
    -- Non-string values are coerced to strings.
    --
    -- <h3>Message priority:</h3>
    --
    -- Messages are only printed if their priority is greater or equal to
    -- `PANDOC_STATE.verbosity`.
    --
    -- <h3>Variable substitution:</h3>
    --
    -- If string values contain variable names, they are replaced with the
    -- values of the local variables, the upvalues of the calling function,
    -- or, if there are no local variables or upvalues of the given names,
    -- `_ENV`. See @{vars_sub} for the syntax and @{vars_get} for limitations.
    --
    -- <h3>Options:</h3>
    --
    -- String values starting with an '@' are interpreted as options:
    --
    -- * '@error', '@warning', '@info': Set the message's priority.
    --   (*default* 'warning')
    -- * '@noopts': Turn option processing off. (*default* on)
    -- * '@novars': Turn variable substitution off. (*default* on)
    -- * '@plain': Turn variable substitution *and* option processing off.
    -- * '@vars': Turn variable substitution on.
    --
    -- Options are case-sensitive. Unknown options are ignored silently.
    --
    -- @require
    --
    -- Pandoc ≥ v2.4 to respect `--quiet` and `--verbose`;
    -- in earlier versions, those options are ignored.
    --
    -- @param ... Messages. At least one must be given.
    --
    -- @function xwarn
    xwarn = type_check('*')(
        function (...)
            local prio = 'warning'
            local opts = {opts = true, vars = true}
            local function opts_set (msg)
                if not opts.opts or msg:sub(1, 1) ~= '@' then return end
                local opt = msg:sub(2)
                if     includes(levels, opt) then prio = opt
                elseif opt == 'plain'        then opts.vars = false
                                                  opts.opts = false
                elseif opt:match '^no'       then opts[opt:sub(3)] = false
                                             else opts[opt] = true
                end
                return true
            end
            local vars
            local msgs = pack(...)
            local nopt = 0
            for i = 1, msgs.n do
                local msg = msgs[i]
                if type(msg) ~= 'string' then
                    msgs[i] = tostring(msg)
                elseif opts_set(msg) then
                    msgs[i] = ''
                    nopt = nopt + 1
                elseif opts.vars then
                    if not vars then vars = vars_get(3) end
                    msgs[i] = assert(vars_sub(msg, vars))
                end
            end
            if is_quieter(verbosity, prio) or nopt == msgs.n then return end
            io.stderr:write(concat{script_fname, ': ', concat(msgs), EOL})
        end
    )
end


--- Elements
-- @section

--- Make a *shallow* copy of a Pandoc AST element.
--
-- @tparam pandoc.AstElement elem A Pandoc AST element.
-- @treturn pandoc.AstElement The clone.
--
-- @function elem_clone
if not pandoc.types or PANDOC_VERSION < {2, 15} then
    elem_clone = type_check('table')(
        function (elem)
            if elem.clone then return elem:clone() end
            assert(elem_type(elem) == 'Pandoc', 'expected a Pandoc document.')
            return update({}, elem)
        end
    )
else
    elem_clone = type_check('table|userdata')(
        function (elem)
            if elem.clone then return elem:clone() end
            assert(elem_type(elem) == 'Pandoc', 'expected a Pandoc document.')
            local clone = {}
            for k, v in pairs(elem) do
                local t = type(v)
                if t == 'userdata' or t == 'table' then
                    if v.clone then clone[k] = v:clone()
                               else clone[k] = update({}, v)
                    end
                end
            end
            return pandoc.Pandoc(clone.blocks, clone.meta)
        end
    )
end

do
    -- A mapping of types to their higher-order types.
    local super = {
        Meta = 'AstElement',
        MetaValue = 'AstElement',
        MetaBlocks = 'Meta',
        MetaBool = 'Meta',
        MetaInlines = 'Meta',
        MetaList = 'Meta',
        MetaMap = 'Meta',
        MetaString = 'Meta',
        Block = 'AstElement',
        BlockQuote = 'Block',
        BulletList = 'Block',
        CodeBlock = 'Block',
        DefinitionList = 'Block',
        Div = 'Block',
        Header = 'Block',
        HorizontalRule = 'Block',
        LineBlock = 'Block',
        Null = 'Block',
        OrderedList = 'Block',
        Para = 'Block',
        Plain = 'Block',
        RawBlock = 'Block',
        Values = 'Block',
        Inline = 'AstElement',
        Cite = 'Inline',
        Code = 'Inline',
        Emph = 'Inline',
        Image = 'Inline',
        LineBreak = 'Inline',
        Link = 'Inline',
        Math = 'Inline',
        Note = 'Inline',
        Quoted = 'Inline',
        RawInline = 'Inline',
        SmallCaps = 'Inline',
        SoftBreak = 'Inline',
        Space = 'Inline',
        Span = 'Inline',
        Str = 'Inline',
        Strikeout = 'Inline',
        Strong = 'Inline',
        Subscript = 'Inline',
        Superscript = 'Inline',
        Underline = 'Inline'
    }

    -- Get the type of the items an array.
    --
    -- @tparam pandoc.List items Items.
    -- @treturn[1] string A Pandoc AST type.
    -- @treturn[2] nil `nil` if the given value is not a list.
    -- @treturn[2] string An error message.
    local function items_type (items, ...)
        local cnt = {}
        local n = 0
        while true do
            local i = n + 1
            local item = items[i]
            if item == nil then break end
            n = i
            local et, est = elem_type(item, ...)
            if not et or not est then break end
            cnt[est] = (cnt[est] or 0) + 1
        end
        local st, idx = next(cnt)
        if st and n == idx then return st end
        return nil, 'not an array of Pandoc elements.'
    end

    -- Get the type of a Pandoc element (worker).
    --
    -- @tparam pandoc.AstElement el A Pandoc AST element.
    -- @treturn[1] string A type (e.g., 'Str').
    -- @treturn[2] nil `nil` if the given value is not a Pandoc AST element.
    -- @treturn[2] string An error message.
    --
    -- @function et_type
    local el_type
    if not pandoc.types or PANDOC_VERSION < {2, 15} then
        function el_type (el, ...)
            if type(el) == 'table' then
                -- This works even if elem.tag does not.
                local mt = getmetatable(el)
                if mt and mt.__type and mt.__type.name then
                    return mt.__type.name
                end

                -- Arrays of AST elements of the same type (e.g., 'Inlines').
                local at = items_type(el, ...)
                if at then return at .. 's' end
            end
            return nil, 'not a Pandoc AST element.'
        end
    elseif PANDOC_VERSION < {2, 17} then
        function el_type (el, ...)
            local t = type(el)
            if t == 'userdata' or t == 'table' then
                -- Use the tag, if there is one.
                if el.tag then return el.tag end

                -- Arrays of AST elements of the same type (e.g., 'Inlines').
                if t == 'table' then
                    local at = items_type(el, ...)
                    if at then return at .. 's' end
                end

                -- If this point is reached, then there is no better way to
                -- determine whether an element is a Pandoc document.
                if
                    el.meta   and
                    el.blocks and
                    t == 'userdata'
                then return 'Pandoc' end
            end
            return nil, 'not a Pandoc AST element.'
        end
    else
        local pandoc_type = pandoc.utils.type
        function el_type (el, ...)
            local t = type(el)
            if t == 'userdata' or t == 'table' then
                -- Use the tag, if there is one.
                if el.tag then return el.tag end

                -- Otherwise, use pandoc.utils.type.
                local et = pandoc_type(el)
                if
                    et:match '^[A-Z]' and
                    et ~= 'Meta'      and
                    et ~= 'List'
                then return et end

                -- pandoc.utils.type doesn't detect all arrays.
                if t == 'table' or et == 'List' then
                    local lt = items_type(el, ...)
                    if lt then return lt .. 's' end
                end
            end
            return nil, 'not a Pandoc AST element.'
        end
    end

    --- Get the type of a Pandoc AST element.
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn[1] string A type (e.g., 'Str').
    -- @treturn[1] string|nil A super-type (e.g., 'Block' or 'Meta').
    -- @treturn[1] string|nil ⋮.
    -- @treturn[2] nil `nil` if the given value is not a Pandoc AST element.
    -- @treturn[2] string An error message.
    --
    -- @function elem_type
    function elem_type (elem, _seen)
        if     not _seen   then _seen = {}
        elseif _seen[elem] then error 'cycle in data tree.'
        end
        _seen[elem] = true
        local et, err = el_type(elem, _seen)
        if not et then return nil, err end
        local ets = {}
        local n = 0
        while et do
            n = n + 1
            ets[n] = et
            et = super[et]
        end
        return unpack(ets)
    end
end

do
    -- Walk a Lua table.
    local function walk_table (tab, ...)
        for k, v in pairs(tab) do tab[k] = elem_walk(v, ...) end
    end

    --- Walk an AST list element (e.g., `pandoc.OrderedList`).
    local function walk_list_elem (elem, ...)
        local content = elem.content
        for i = 1, #content do walk_table(content[i], ...) end
    end

    -- Walk a document.
    local function walk_doc (doc, ...)
        doc.meta = elem_walk(doc.meta, ...)
        walk_table(doc.blocks, ...)
    end

    -- Walking functions by Pandoc AST element type.
    local walkers = {
        Meta = walk_table,
        MetaBlocks = walk_table,
        MetaList = walk_table,
        MetaInlines = walk_table,
        MetaMap = walk_table,
        BulletList = walk_list_elem,
        OrderedList = walk_list_elem,
        Inlines = walk_table,
        Blocks = walk_table,
        Metas = walk_table,
        Pandoc = walk_doc
    }

    --- Walk an AST and apply a filter to matching elements.
    --
    -- Differences to Pandoc's walkers:
    --
    -- * Walks AST elements of any type (inluding documents and metadata).
    -- * Walks the AST bottom-up.
    -- * Does *not* accept the `traverse` keyword.
    -- * Applies the filter to the given element itself.
    -- * Allows functions in the filter to return data of arbitrary types.
    -- * Never modifies the original element.
    -- * Accepts the type 'AstElement', which matches any element.
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @tparam {string=func,...} filter A filter.
    -- @return Typically but not necessarily, a new Pandoc AST element.
    --
    -- @function elem_walk
    elem_walk = type_check('*', 'table', '?table')(
        function (elem, filter, _seen)
            if not _seen then _seen = {} end
            assert(not _seen[elem], 'cycle in data tree.')
            local ets = {elem_type(elem)}
            local et = ets[1]
            if et then
                _seen[elem] = true
                elem = elem_clone(elem)
                local walker = walkers[et]
                if walker then
                    walker(elem, filter, _seen)
                elseif elem.content then
                    walk_table(elem.content, filter, _seen)
                end
                for i = 1, #ets do
                    local func = filter[ets[i]]
                    if func then
                        local new = func(elem)
                        if new ~= nil then elem = new end
                    end
                end
            elseif type(elem) == 'table' then
                _seen[elem] = true
                if elem.clone then elem = elem:clone()
                              else elem = update({}, elem)
                end
                walk_table(elem, filter, _seen)
            end
            return elem
        end
    )
end


--- Options
-- @section

do
    -- luacheck: ignore stringify
    local pandoc_type = pandoc.utils.type
    local stringify = protect(stringify)

    -- A mapping of configuration value types to parers.
    local converters = {}

    -- Convert a configuration value to a type.
    --
    -- @param[opt] val A value.
    -- @string[opt='string'] type A type declaration.
    --  See @{opts_parse} for the grammar.
    -- @return[1] A value of the given type.
    -- @treturn[2] nil `nil` if the value cannot be converted.
    -- @treturn[2] string An error message.
    -- @raise An error if a type declaration cannot be parsed.
    local function convert (val, decl)
        if not decl then decl = 'string' end
        local head, tail = decl:match '^%s*(%l+)%s*<?%s*([%l<>%s]-)%s*>?%s*$'
        if not head then error(decl .. ': cannot parse option type.', 3) end
        local conv = converters[head]
        if not conv then error(head .. ': no such option type.', 3) end
        if val ~= nil then return conv(val, tail or 'string') end
    end

    -- Convert a value to a Lua string.
    --
    -- @param val A value.
    -- @treturn[1] string A string.
    -- @treturn[2] nil `nil` if the value cannot be converted to a string.
    -- @treturn[2] string An error message.
    -- @todo Test whether stringify could do all the work.
    function converters.string (val)
        local t = type(val)
        if t == 'string' then
            return val
        elseif t == 'number' then
            return tostring(val)
        elseif elem_type(val) then
            local str = stringify(val)
            if str ~= '' then return str end
        end
        return nil, 'not a string or empty.'
    end

    -- Convert a value to a Lua number.
    --
    -- @param val A value.
    -- @treturn[1] number A number.
    -- @treturn[2] nil `nil` if the value cannot be converted to a number.
    -- @treturn[2] string An error message.
    function converters.number (val)
        if type(val) == 'number' then return val end
        if elem_type(val) then val = stringify(val) end
        local num = tonumber(val)
        if num then return num end
        return nil, 'not a number.'
    end

    -- Convert values to lists.
    --
    -- Tables are passed through as is.
    --
    -- @param val A value or list of values.
    -- @treturn pandoc.List A list of values.
    function converters.list (vals, decl)
        if decl == '' then decl = 'string' end
        if
            -- Pandoc ≥ v2.17.
            (pandoc_type and pandoc_type(vals) == 'List') or
            -- Old versions of Pandoc.
            elem_type(vals) == 'MetaList' or
            -- Ancient versions of Pandoc, maybe.
            (type(vals) == 'table' and select(2, keys(vals)) == #vals)
        then
            local list = pandoc.List:new()
            for i = 1, #vals do
                local v, err = convert(vals[i], decl)
                if not v then return nil, format('item no. %d: %s', i, err) end
                list[i] = v
            end
            return list
        end
        local v, err = convert(vals, decl)
        if not v then return nil, err end
        return pandoc.List:new{v}
    end

    --- An option list.
    --
    -- @see opts_parse
    -- @see Options:new
    -- @see Options:add
    -- @see Options:parse
    -- @object Options
    -- @proto @{Object}
    Options = Object:clone()

    --- Create a new option parser.
    --
    --    parser = Options:new{name = 'foo'}
    --
    -- is equivalent to:
    --
    --    parser = Options()
    --    parser:add{name = 'foo'}
    --
    -- @tab ... Option definitions.
    --
    -- @see Options:add
    -- @function Options:new
    Options.new = type_check('table', '?table', '...')(
        function (proto, ...)
            local obj = Object.new(proto)
            if select('#', ...) > 0 then obj:add(...) end
            return obj
        end
    )

    --- Add an option to the list.
    --
    -- @tab ... Option definitions.
    --
    -- @usage
    -- parser = Options()
    -- parser:add{
    --     name = 'bar',
    --     type = 'number',
    --     parse = function (x)
    --         if x < 1 return return nil, 'not a positive number.' end
    --         return x
    --     end
    -- }
    --
    -- @see opts_parse
    -- @see Options:parse
    -- @function Options:add
    Options.add = type_check('table', {
        name = 'string',
        type = '?string',
        parse = '?function',
        prefix = '?string'},
    '...')(
        function (self, ...)
            local opts = pack(...)
            for i = 1, opts.n do
                local opt = opts[i]
                convert(nil, opt.type)
                self[#self + 1] = opt
            end
        end
    )

    --- Read options from a metadata block.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @treturn[1] tab A mapping of option names to values.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    --
    -- @usage
    -- > meta = pandoc.MetaMap{
    -- >     ['foo-bar'] = pandoc.MetaInlines(pandoc.List{
    -- >         pandoc.Str "0123"
    -- >     })
    -- > parser = Options()
    -- > parser:add{
    -- >     name = 'bar',
    -- >     type = 'number',
    -- >     parse = function (x)
    -- >         if x < 1 return return nil, 'not a positive number.' end
    -- >         return x
    -- >     end
    -- > }
    -- > opts = parser:parse(meta)
    -- > opts.bars
    -- 123
    -- > type(opts.bar)
    -- number
    --
    -- @see opts_parse
    -- @see Options:add
    -- @function Options:parse
    Options.parse = type_check('table', 'table|userdata')(
        function (self, meta)
            return opts_parse(meta, unpack(self))
        end
    )

    --- Read configuration options from a metadata block.
    --
    -- <h3>Option definition syntax:</h3>
    --
    -- An option definition is a table with the following keys:
    --
    --  * `name`: (***@{string}***) An option name.
    --  * `type`: (***@{string}***) An option type. (*default* 'string')
    --  * `parse`: (***func***) A parser. (*optional*)
    --  * `prefix`: (***@{string}***) A prefix. (*optional*)
    --
    -- <h3>Mapping of option names to metadata fieldnames:</h3>
    --
    -- The name of the metadata field is the name of the option with
    -- underscores replaced by dashes. If the option has a prefix,
    -- then the fieldname is prefixed with that prefix and a dash *after*
    -- underscores have been replaced with dashes.
    --
    -- In Lua:
    --
    --    fieldname = name:gsub('_', '-')
    --    if prefix then fieldname = prefix .. '-' .. fieldname end
    --
    -- <h3>Type declaration grammar:</h3>
    --
    -- Configuration values can be of one of three types:
    --
    -- * 'number'
    -- * 'string'
    -- * 'list'
    --
    -- If you declare an option to be of the scalar types 'number' or
    -- 'string', its value is required to be of the Lua type of the
    -- same name. Values are converted automatically if possible.
    --
    -- If you declare an option to be of the type 'list', its value is
    -- required to be a `pandoc.List`. If a scalar is encountered where
    -- a list was expected, the value is wrapped in a single-item list.
    --
    -- The items of a list must all be of the same type, which you declare by
    -- appending '<*T*>' to the literal 'list', where *T* is either the name
    -- of a scalar type or another list declaration and defaults to 'string'.
    --
    -- In [Extended Backus-Naur Form](https://en.wikipedia.org/wiki/EBNF):
    --
    -- > Scalar = 'number' | 'string'
    -- >
    -- > List = 'list', [ '<', ( scalar | list ), '>' ]
    --
    -- No type checks or conversions are performed for `nil`.
    --
    -- <h3>Parse protocol:</h3>
    --
    -- Parsers take the *converted* value and either
    -- return a new value or `nil` and an error message.
    --
    -- They are *not* called for `nil`.
    --
    -- @caveats
    --
    -- @{Options:add} throws an error if it is given a wrong option type
    -- (e.g., 'int' or 'list[number]'). `opts_parse` accepts wrong option
    -- types and only throws an error if it encounters an option that is
    -- supposed to be of that type.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @tparam Option ... Option definitions.
    -- @treturn tab A mapping of option names to values.
    --
    -- @usage
    -- > meta = pandoc.MetaMap{
    -- >     ['foo-bar'] = pandoc.MetaInlines(pandoc.List{
    -- >         pandoc.Str "0123"
    -- >     })
    -- > opts = opts_parse(meta, {
    -- >     name = 'bar',
    -- >     type = 'number',
    -- >     parse = function (x)
    -- >         if x < 1 return return nil, 'not a positive number.' end
    -- >         return x
    -- >     end
    -- > })
    -- > opts.bars
    -- 123
    -- > type(opts.bar)
    -- number
    --
    -- @see Options
    -- @function opts_parse
    opts_parse = type_check('table|userdata', {
        name = 'string',
        type = '?string',
        parse = '?function',
        prefix = '?string'
    }, '...')(
        function (meta, ...)
            local opts = {}
            local defs = pack(...)
            if not meta or defs.n == 0 then return opts end
            for i = 1, defs.n do
                local def = defs[i]
                local key = def.name:gsub('_', '-')
                if def.prefix then key = def.prefix .. '-' .. key end
                local val = meta[key]
                if val ~= nil then
                    local err
                    for _, func in pairs{convert, def.parse} do
                        if not func then break end
                        val, err = func(val, def.type)
                        if not val then
                            return nil, key .. ': ' .. err
                        end
                    end
                    opts[def.name] = val
                end
            end
            return opts
        end
    )
end


-- Boilerplate
-- ===========

return M
