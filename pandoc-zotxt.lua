---
-- SYNOPSIS
-- ========
--
-- **pandoc** **-L** *pandoc-zotxt.lua* **-C**
--
-- DESCRIPTION
-- ===========
--
-- **pandoc-zotxt.lua** is a Lua filter for Pandoc that looks up citations in
-- Zotero and adds their bibliographic data to the "references" metadata field
-- or to a bibliography file, where Pandoc can pick it up.
--
-- You cite your sources using so-called "Better BibTeX citation keys"
-- (provided by Better BibTeX for Zotero) or "Easy Citekeys" (provided by
-- zotxt) and then tell **pandoc** to filter your document through
-- **pandoc-zotxt.lua** before processing citations. That's all there is to it.
--
-- If the "references" metadata field or a bibliography file already contains
-- bibliographic data for a citation, that citation will be ignored.
--
-- CONNECTING TO ZOTERO
-- ====================
--
-- Desktop client
-- --------------
--
-- By default, bibliographic data is fetched from the Zotero desktop client,
-- which must be running when you invoke **pandoc**. This is the faster,
-- easier, and less error-prone method to lookup citations in Zotero. However,
-- you need to install the zotxt add-on for the Zotero desktop client to use
-- it.
--
-- Web API
-- -------
--
-- Bibliographic data can also be fetched from the Zotero Web API. If you want
-- to access your Zotero library via the Web API, create a Zotero API key and
-- set the metadata field "zotero-api-key" to that key.
--
-- If you want to fetch bibliographic data from *public* Zotero groups, list
-- the IDs of those groups in the metadata field "zotero-public-groups". The
-- groups have to allow non-members to access their libraries; however, you do
-- not need an API key to access them.
--
-- The Zotero Web API does *not* allow to search for citation keys other than
-- Zotero item IDs. Therefore, BetterBibTeX citation keys and Easy Citekeys
-- have to be translated into search terms: Better BibTeX citation keys are
-- split up at the first of each series of digits and at uppercase letters
-- ("DoeTitle2020" becomes "Doe", "Title", "2020"). Easy Citekeys are split up
-- at the first colon and at the last digit ("doe:2020title" becomes "doe",
-- "2020", "title").
--
-- If a search yields more than one item, you need to add the citation key to
-- the item's "extra" field in Zotero to disambiguate, using either the field
-- name "Citation key" or "Citekey"; e.g., "Citation key: DoeTitle2020". If
-- you added the BetterBibTeX for Zotero add-on to the Zotero desktop client,
-- you can do so by 'pinning' the citation key. Alternatively, you can cite
-- the source using its Zotero item ID.
--
-- BIBLIOGRAPHY FILES
-- ==================
--
-- Bibliographic data can be added to a bibliography file, rather than to the
-- "references" metadata field. This speeds up subsequent processing of the
-- same document, because that data need not be fetched again from Zotero.
--
-- To use such a bibliography file, set the "zotero-bibliography" metadata
-- field to a filename. If the filename is relative, it is interpreted as
-- relative to the directory of the first input file passed to **pandoc** or,
-- if no input file was given, as relative to the current working directory.
--
-- The format of the file is determined by its filename ending:
--
-- | **Ending** | **Format** |
-- | ---------- | ---------- |
-- | `.json`    | CSL JSON   |
-- | `.yaml`    | CSL YAML   |
--
-- The bibliography file is added to the "bibliography" metadata field
-- automatically. You can safely set "zotero-bibliography" and "bibliography"
-- at the same time.
--
-- Records are only ever added to the bibliography file, never changed or
-- deleted. If you need to change or delete a record, delete the bibliography
-- file, so that it will be regenerated from scratch.
--
-- CITATION KEY TYPES
-- ==================
--
-- You can use citation keys of multitple types:
--
-- | **Name**          | **Type**                   | **Example**   |
-- | ----------------- | -------------------------- | ------------- |
-- | `betterbibtexkey` | Better BibTeX citation key | DoeTitle2020  |
-- | `easykey`         | Easy Citekey               | doe:2020title |
-- | `key`             | Zotero item ID             | A1BC23D4      |
--
-- However, Better BibTeX citation keys are sometimes, if rarely,
-- misinterpreted as Easy Citekeys and still match an item, though *not* the
-- one that they are the citation key of.
--
-- If this happens, disable Easy Citekeys by only listing BetterBibTeX
-- citation keys and, if you use them, Zotero item IDs in the
-- "zotero-citekey-types" metadata field:
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-citekey-types: betterbibtexkey
--     ...
--     Forces @DoeTitle to be treated as a BetterBibTeX citation key.
--     EOF
--
-- SETTINGS
-- ========
--
-- You configure how bibligraphic data is fetched by setting the following
-- metadata fields:
--
-- * `zotero-api-key`: A Zotero API key. Needed to access your personal
-- library via the Zotero Web API, but not needed to access public groups.
--
-- * `zotero-bibliography`: A bibliography filename. Fetched bibliographic
-- data is added to this file. (See "BIBLIOGRAPHY FILES" above for details.)
--
-- * `zotero-citekey-types`: A list of citation key types. Citation keys are
-- treated as being of any of the listed types only. (See "CITATION KEY TYPES"
-- above for details.)
--
-- * `zotero-connectors`: One or more Zotero connectors:
--
--   | *Key*  | *Connect to*          |
--   | ------ | --------------------- |
--   | zotxt  | Zotero desktop client |
--   | zotweb | Zotero Web API        |
--
--   Data is fetched via the listed connectors only.
--
--   By default, the Zotero desktop client is searched first. If you have set
--   a Zotero API key and the client could not be reached or some citations
--   not be found, the Zotero Web API is searched next.
--
-- * `zotero-groups`: A list of Zotero group IDs. Only the listed groups are
-- searched. By default, all groups that you are a member of are searched.
--
-- * `zotero-public-groups`: A list of Zotero group IDs. Listed groups are
-- searched in addition to the groups that you are a member of, if any. These
-- groups must be public. (See "Zotero Web API" above for details.)
--
-- * `zotero-user-id`: A Zotero user ID. Needed to fetch data via the Zotero
-- Web API, but looked up automatically if not given.
--
-- If a metadata field takes a list of values, but you only want to give one,
-- you can enter that value as a scalar.
--
-- EXAMPLES
-- ========
--
-- Look up "DoeTitle2020" in Zotero:
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     See @doe2020Title for details.
--     EOF
--
-- Add bibliographic data to the file "bibliography.json":
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-bibliography: bibliography.json
--     ...
--     See @DoeTitle2020 for details.
--     EOF
--
-- Interpret "doe:2020title" as a Better BibTeX citation key:
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-citekey-types: betterbibtexkey
--     ...
--     See @doe:2020title for details.
--     EOF
--
-- Fetch data from the Zotero Web API, too:
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
--     ...
--     See @DoeTitle2020 for details.
--     EOF
--
-- Fetch data from the Zotero Web API *only*:
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
--     zotero-connectors: zotweb
--     ...
--     See @DoeTitle2020 for details.
--     EOF
--
-- KNOWN ISSUES
-- ============
--
-- Citation keys may, on rare occassions, be matched with the wrong Zotero
-- item. This happens if a citation key picks out a different record depending
-- on whether it is interpreted as a Better BibTeX citation key or as an easy
-- citekey. See "CITATION KEY TYPES" above on how to address this.
--
-- **pandoc-zotxt.lua** creates a temporary file when it adds bibliographic
-- data to a bibliography file. If Pandoc exits because it catches a signal
-- (e.g., because you press `Ctrl`-`c`), then this file will *not* be deleted.
-- This is a bug in Pandoc and in the process of being fixed. Moreover, if you
-- are using Pandoc up to v2.7, another process may, mistakenly, use the same
-- temporary file at the same time, though this is highly unlikely.
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that do not set the "User Agent" HTTP header. And **pandoc** does not. As a
-- consequence, **pandoc-zotxt.lua** cannot retrieve data from these versions
-- of Zotero unless you tell **pandoc** to set that header.
--
-- Support for accessing group libraries via the Zotero Web API is limited.
-- They are only searched if no item in your personal library matches. Also,
-- the "extra" field of items in group libraries is ignored.
--
-- SECURITY
-- ========
--
-- If you are using Pandoc up to v2.7 and place the auto-generated
-- bibliography file in a directory that other users have write access to,
-- then they can read and change the content of that file, regardless of
-- whether they have permission to read or write the file itself.
--
-- CAVEATS
-- =======
--
-- **pandoc-zotxt.lua** is Unicode-agnostic.
--
-- SEE ALSO
-- ========
--
-- * [zotxt](https://github.com/egh/zotxt)
-- * [Better BibTeX](https://retorque.re/zotero-better-bibtex/)
--
-- pandoc(1)
--
-- @script pandoc-zotxt.lua
-- @release 1.1.0b4
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020, 2021 Odin Kroeger
-- @license MIT

-- Table of Contents
--------------------

--- Metadata
-- @section Metadata

--- Types
-- @section

--- Meta-programming
-- @section

--- Tables
-- @section

--- Strings
-- @section

--- Basic prototypes
-- @section

--- Warnings
-- @section

--- File I/O
-- @section

--- Networking
-- @section

--- Markup converters
-- @section

--- CSL items.
--
-- [Appendix IV](https://perma.cc/7LPL-F4XD) of the Citation Style Language
-- (CSL) specification lists all CSL variable names.
--
-- @section

--- Citation keys
-- @section

--- Bibliography files
-- @section

--- Document parsing
-- @section

--- Configuration parsing
-- @section

--- Zotero connectors
-- @section

--- Main
-- @section

-- Initialisation
-----------------

-- luacheck: allow defined top
-- luacheck: ignore path_prettify

-- Run in debugging mode?
-- luacheck: push ignore DEBUG
local DEBUG = DEBUG or false
-- luacheck: pop

-- Built-in functions.
local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local pairs = pairs
local pcall = pcall
local rawset = rawset
local require = require
local select = select
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type

-- Modules.
local debug = debug
local io = io
local math = math
local os = os
local package = package
local string = string
local table = table
local utf8 = utf8

-- Pandoc.
-- luacheck: push ignore
local pandoc = pandoc
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end

if pandoc.types then
    if PANDOC_VERSION >= {2, 8} and not pandoc.system then
        pandoc.system = require 'pandoc.system'
    end
    if PANDOC_VERSION >= {2, 12} and not pandoc.path then
        pandoc.path = require 'pandoc.path'
    end
end

local PANDOC_STATE = PANDOC_STATE
local PANDOC_SCRIPT_FILE = PANDOC_SCRIPT_FILE
local PANDOC_VERSION = PANDOC_VERSION
-- luacheck: pop

local M = {}
local _ENV = M

-- Shorthands.
local format = string.format
local concat = table.concat
local pack = table.pack
local unpack = table.unpack
local sort = table.sort

local read = pandoc.read
local stringify = pandoc.utils.stringify

local List = pandoc.List
local MetaInlines = pandoc.MetaInlines
local MetaList = pandoc.MetaList
local MetaMap = pandoc.MetaMap
local Str = pandoc.Str
local Span = pandoc.Span
local Pandoc = pandoc.Pandoc


--------
-- Types
--
-- @section

--- Check whether a value is of a type.
--
-- <h3>Type declaration grammar:</h3>
--
-- Give one or more Lua type names separated by '|' to declare that the given
-- value may be of any of those types (e.g., `'string|table'`). Use '`*`' to
-- declare that the value may be of any type oter than `nil`. '`?T`' is short
-- for '`nil|T`' (e.g., `'?table'` is equivalent to `'nil|table'`). '`?*`' is
-- a special case; it signifies that the value may be of any type, even `nil`.
--
-- In [Extended Backus-Naur Form](https://en.wikipedia.org/wiki/EBNF):
--
-- > Type = 'boolean' | 'function' | 'nil'    | 'number'   |
-- >        'string'  | 'table'    | 'thread' | 'userdata'
-- >
-- > List of types = (type, {'|', type}) | '*'
-- >
-- > Type declaration = ['?'], list of types
--
-- @caveats Wrong type names (e.g., 'int') do *not* raise an error.
--
-- @param val A value.
-- @string decl A type declaration (e.g., `'?number|string'`).
-- @treturn[1] bool `true` if the value is of the declared type(s).
-- @treturn[2] nil `nil` otherwise.
-- @treturn[2] string An error message.
function type_match (val, decl)
    if decl == '?*' then return true end
    if decl == '*' then
        if val ~= nil then return true end
        return nil, 'expected type other than nil.'
    end
    local ts = decl:gsub('^%?', 'nil|'):match ('^([%l|]+)$')
    if not ts then error(format('cannot parse type "%s".', decl), 3) end
    local obs = type(val)
    for exp in ts:gmatch '[^|]+' do if obs == exp then return true end end
    return nil, format('expected %s, but got %s.', ts:gsub('|', ' or '), obs)
end

--- Type-check function arguments when running in debugging mode.
--
-- <h3>Type declaration grammar:</h3>
--
-- The type declaration syntax is that of @{type_match}, save for that
-- you can use '`...`' to declare that an argument is of the same type
-- as the previous one; if '`...`' is the last type declaration, then
-- the previous type declaration applies to all remaning arguments.
--
-- @caveats Wrong type names do *not* raise an error on declaration.
--
-- @string ... Type declarations.
-- @treturn func A function that adds type checks to a function.
--
-- @usage
-- copy = typed_args('?*', '?table')(
--     function (val, _seen)
--         if type(val) ~= 'table' then return val end
--         if     not _seen  then _seen = {}
--         elseif _seen[val] then return _seen[val]
--         end
--         local ret = setmetatable({}, getmetatable(val))
--         _seen[val] = ret
--         for k, v in next, val do
--             rawset(ret, copy(k, _seen), copy(v, _seen))
--         end
--         return ret
--     end
-- )
--
-- @function typed_args
-- @fixme No unit-test.
function typed_args (...)
    local types = pack(...)
    return function (func)
        return function (...)
            -- luacheck: ignore type
            local args = pack(...)
            local type, prev
            for i = 1, math.max(types.n, args.n) do
                if     types[i] == '...' then prev = true
                elseif types[i]          then type = types[i]
                elseif not prev          then break
                end
                local ok, err = type_match(args[i], type)
                if not ok then
                    error(format('argument %d: %s', i, err), 2)
                end
            end
            return func(...)
        end
    end
end

if not DEBUG then
    function typed_args ()
        return function (...) return ... end
    end
end

--- Type-check keyword arguments when running in debugging mode.
--
-- @caveats Wrong type names do *not* raise an error on declaration.
--
-- @tparam {string=string,...} types A mapping of keywords
--  to [type declarations](#type_match).
-- @treturn func A function that adds type checks to a function.
--
-- @usage
-- Foo = Object()
-- Foo.new = typed_keyword_args{
--     bar = 'number',
--     baz = '?string'
-- }(getmetatable(Foo).__call)
--
-- @function typed_keyword_args
-- @fixme No unit test!
typed_keyword_args = typed_args('table')(
    function (types)
        return function (const)
            return typed_args('table', '?table')(
                function (proto, args)
                    do
                        -- luacheck: ignore args type
                        local args = args
                        if not args then args = {} end
                        for key, type in pairs(types) do
                            if proto[key] == nil then
                                local ok, err = type_match(args[key], type)
                                if not ok then
                                    error(key .. ': ' .. err, 2)
                                end
                            end
                        end
                    end
                    return const(proto, args)
                end
            )
        end
    end
)

function typed_keyword_args ()
    return function (...) return ... end
end


-----------
-- File I/O
--
-- @section

--- The path segment separator used by the operating system.
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence used on the given operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end

--- Join multiple path segments.
--
-- @string ... Path segments.
-- @treturn string A path.
--
-- @function path_join
path_join = typed_args('string', '...')(
    function (...)
        local segs = pack(...)
        for i = 1, segs.n do
            assert(segs[i] ~= '', format('segment %d is the empty string.', i))
        end
        return path_normalise(concat(segs, PATH_SEP))
    end
)

do
    -- Patterns that normalise directory paths.
    -- The order of these patterns is significant.
    local patterns = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'},
        -- Remove './' at the beginning of a path.
        {'^%.' .. PATH_SEP, ''}
    }

    --- Normalise a path.
    --
    -- @string path A path.
    -- @treturn string A normalised path.
    --
    -- @function path_normalise
    path_normalise = typed_args('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            for i = 1, #patterns do path = path:gsub(unpack(patterns[i])) end
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
    path_split = typed_args('string')(
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


-----------
-- Metadata
--
-- @section

--- The name of this script.
NAME = 'pandoc-zotxt.lua'

--- The version of this script.
VERSION = '1.1.0b4'

do
    local script_dir, script_name = path_split(PANDOC_SCRIPT_FILE)

    --- The directory the script is located in.
    SCRIPT_DIR = script_dir

    --- The filename of the script.
    SCRIPT_NAME = script_name
end

do
    local repo = NAME .. '-' .. VERSION
    local sub_dir = path_join('share', 'lua', '5.4', '?.lua')
    package.path = concat({package.path,
        path_join(SCRIPT_DIR, sub_dir),
        path_join(SCRIPT_DIR, repo, sub_dir)
    }, ';')
end

local json = require 'lunajson'


-------------------
-- Meta-programming
--
-- @section

--- Get a copy of the variables that a function can access.
--
-- @int[opt=2] level A stack level, where
--
--  * 1 = `vars_get`,
--  * 2 = the function calling `vars_get`,
--  * ⋮
--  * *n* = the function calling the function at level *n* – 1.
--
-- @treturn[1] table A mapping of variable names to values.
-- @treturn[2] nil `nil` if there is no function at that level of the stack.
-- @treturn[2] string An error message.
--
-- @usage
-- > function bar ()
-- >     print(get_vars(3)['foo'])
-- > end
-- > function foo ()
-- >     foo = 'foo'
-- >     bar()
-- > end
-- > foo()
-- foo
--
-- @function vars_get
vars_get = typed_args('?number')(
    function (level)
        if not level then level = 2 end
        assert(level > 0, 'level is not a positive number.')
        local info = debug.getinfo(level, 'f')
        if not info then return nil, tostring(level) .. ': no such level.' end
        local vars = copy(_ENV)
        for i = 1, 2 do
            local iter, arg
            if     i == 1 then iter, arg = debug.getupvalue, info.func
            elseif i == 2 then iter, arg = debug.getlocal, level
            end
            local j = 1
            while true do
                local k, v = iter(arg, j)
                if not k then break end
                vars[k] = copy(v)
                j = j + 1
            end
        end
        return vars
    end
)


---------
-- Tables
--
-- @section

--- A metatable to make tables ignore case.
--
-- @usage
--
-- > tab = setmetatable({}, ignore_case)
-- > tab.FOO = 'bar'
-- > tab.foo
-- bar
--
-- @fixme No unit test.
ignore_case = {}

--- Look up an item.
--
-- @tab tab A table.
-- @param key A key.
-- @return The item.
-- @fixme No unit test.
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
-- @fixme No unit test.
function ignore_case.__newindex (tab, key, val)
    if type(key) == 'string' then rawset(tab, key:lower(), val)
                             else rawset(tab, key, val)
    end
end

--- Make a deep copy of a value.
--
-- @caveats Bypasses metamethods.
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
copy = typed_args('?*', '?table')(
    function (val, _seen)
        -- Borrows from:
        -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
        -- * <http://lua-users.org/wiki/CopyTable>
        if type(val) ~= 'table' then return val end
        if     not _seen  then _seen = {}
        elseif _seen[val] then return _seen[val]
        end
        local ret = setmetatable({}, getmetatable(val))
        _seen[val] = ret
        for k, v in next, val do
            rawset(ret, copy(k, _seen), copy(v, _seen))
        end
        return ret
    end
)

--- Get the keys and the number of items in a table.
--
-- @tab tab A table.
-- @treturn tab The keys of the table.
-- @treturn int The number of items in the table.
--
-- @function keys
keys = typed_args('table')(
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

--- Define a sorting function from a list of values.
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
order = typed_args('table')(
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
--  If no function is given, sorts lexically.
-- @treturn func A *stateful* iterator.
--
-- @usage
-- > for k, v in sorted{c = 3, b = 2, a = 1} do
-- >     print(k, v)
-- > end
-- a    1
-- b    2
-- c    3
--
-- @function sorted
sorted = typed_args('table', '?function')(
    function (tab, func)
        local ks = keys(tab)
        sort(ks, func)
        local n = 0
        local function iter ()
            n = n + 1
            local k = ks[n]
            if k == nil then return end
            return k, tab[k]
        end
        return iter, tab
    end
)

--- Tabulate the values an iterator returns.
--
-- The iterator must accept the same arguments as @{next}.
--
-- @func iter An iterator.
-- @param[opt] tab A table to iterate over.
-- @param[opt] key The index to start iterating at.
-- @return The values returned by the iterator.
--
-- @usage
-- > str = 'key: value'
-- > k, v = tabulate(split(str, '%s*:%s*', 2))
-- > print(k, v)
-- key    value
--
-- @function tabulate
-- @fixme Stateless iterators are untested.
tabulate = typed_args('function')(
    function (iter, tab, key)
        local vals = Values()
        for v in iter, tab, key do vals:add(v) end
        return unpack(vals)
    end
)

--- Walk a graph and apply a function to every node.
--
-- A node is only changed if the function does *not* return `nil`.
--
-- @param val A value.
-- @func func A function.
-- @return The transformed graph.
--
-- @function walk
walk = typed_args('*', 'function', '?table')(
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


----------
-- Strings
--
-- @section

--- Iterate over substrings of a string.
--
-- @caveats Supports neither multi-byte characters nor frontier patterns.
--
-- @string str A string.
-- @string pattern Where to split the string.
-- @int[opt] max Split the string into at most that many substrings.
-- @string[opt] include Include separators in substrings?
--
--  * `l` includes separators on the left,
--  * `r` on the right.
--
--  By default, separators are *not* included.
-- @treturn func A *stateful* iterator.
--
-- @usage
-- > for s in split('CamelCase', '%u', nil, 'l') do
-- >     print(string.format("%s", s))
-- > end
-- ""
-- "Camel"
-- "Case"
--
-- @function split
split = typed_args('string', 'string', '?number', '?string')(
    function (str, pattern, max, include)
        assert(not pattern:match '%f[%%]%%f', 'split does not support %f.')
        assert(not include or include:match '^[lr]$', 'expecting "l" or "r".')
        local pos = 1
        local n = 0
        local i, j
        return function ()
            local sep, last
            if not pos then return end
            if include == 'l' and i then sep = str:sub(i, j) end
            i = nil
            j = nil
            n = n + 1
            if n == max then
                last = -1
            else
                i, j = str:find(pattern, pos)
                if     not i          then last = -1
                elseif include == 'r' then last = j
                                      else last = i - 1
                end
            end
            local sub = str:sub(pos, last)
            if sep then sub = sep .. sub end
            if j then pos = j + 1
                 else pos = nil
            end
            return sub
        end
    end
)

--- Remove leading and trailing whitespace.
--
-- @string str A string.
-- @treturn string A trimmed string.
--
-- @function trim
trim = typed_args('string')(
    function (str)
        return str:gsub('^%s+', ''):gsub('%s*$', '')
    end
)


do
    -- Lookup a path in a namespace.
    --
    -- @tab vars A mapping of variable names to values.
    -- @string path A path. Seperate segments by dots.
    -- @return A value.
    local function lookup (vars, path)
        local v = vars
        for n in split(path, '%.') do
            if n == '' then break end
            v = v[n]
        end
        return v
    end

    -- Expand a variable from a variable expression.
    --
    -- See @{vars_sub} for the expression syntax.
    --
    -- @int rd The current recursion depth.
    -- @tab vars A mapping of variable names to values.
    -- @string exp A variable expression.
    -- @treturn string The value of the expression.
    -- @raise See @{vars_sub}.
    local function evaluate (rd, vars, exp)
        local path, func = tabulate(split(exp:sub(2, -2), '|', 2))
        local v = lookup(vars, path)
        if func then v = lookup(vars, func)(v) end
        return vars_sub(tostring(v), vars, rd + 1)
    end

    --- Substitute variables in strings.
    --
    -- If a string of characters is placed within braces ('{...}') and the
    -- opening brace ('{') immediately follows a single dollar ('$') sign,
    -- then that string is treated as a variable name and the whole
    -- expression is replaced with the value of that variable.
    --
    --    > vars_sub(
    --    >     '${v1} is ${v2}.',
    --    >     {v1 = 'foo', v2 = 'bar'}
    --    > )
    --    foo is bar.
    --
    -- If a braced string is preceded by two or more dollar signs, it is *not*
    -- *not* treated as a variable name and *not* replaced. Any series of *n*
    -- dollar signs is replaced with *n* – 1 dollar signs.
    --
    --    > vars_sub(
    --    >     '$${v1} costs $$23.',
    --    >     {v1 = 'foo'}
    --    > )
    --    ${v1} costs $23.
    --
    -- If a variable name is followed by a pipe symbol ('|'), then the string
    -- of characters between the pipe symbol and the closing brace ('}') is
    -- treated as a function name; the value of the variable is then passed to
    -- that function, and the whole expression `${<variable>|<function>}` is
    -- replaced with the first value that this function returns. Variable
    -- names must *not* contain the pipe symbol, but function names may.
    --
    --    > vars_sub(
    --    >     '${v1|barify} is bar!', {
    --    >         v1 = 'foo',
    --    >         barify = function (s)
    --    >             return s:gsub('foo', 'bar')
    --    >         end
    --    >     }
    --    > )
    --    bar is bar!
    --
    -- You can lookup values in tables by joining the name of the variable
    -- and that of the table index with a dot ('.'). Neither variable nor
    -- function names may contain dots.
    --
    --    > vars_sub(
    --    >     '${foo.bar} is baz.', {
    --    >         foo = { bar = 'baz' }
    --    >     }
    --    > )
    --    baz is baz.
    --
    -- Expressions are evaluated recursively.
    --
    --    > vars_sub(
    --    >     '${foo} is bar.', {
    --    >         foo = '${bar}',
    --    >         bar = 'baz'
    --    >     }
    --    > )
    --    baz is bar.
    --
    -- @caveats
    --
    -- * If there is no variable of a given name,
    --   the expression is quietly replaced with `nil`.
    --
    --       > vars_sub('foo is ${bar}.', {})
    --       foo is nil.
    --
    -- * The empty string is a valid variable name.
    --
    --       > vars_sub('foo is ${}.', {[''] = bar})
    --       foo is bar.
    --
    -- * Error messages are cryptic.
    --
    -- @string str A string.
    -- @tab vars Variables.
    -- @treturn string A transformed string.
    --
    -- @function vars_sub
    -- @fixme Improve error messages.
    vars_sub = typed_args('string', 'table', '?number')(
        function (str, vars, _rd)
            if not _rd then _rd = 0 end
            assert(_rd < 64, 'recursion limit exceeded.')
            local function eval (...) return evaluate(_rd, vars, ...) end
            return str:gsub('%f[%$]%$(%b{})', eval):gsub('%$(%$*)', '%1')
        end
    )
end


-------------------
-- Basic prototypes
--
-- @section

--- Base prototype.
--
-- @usage
-- > -- Delegate to Object.
-- > Foo = Object()
-- > mt = getmetatable(Foo)
-- > mt.__tostring = function () return 'foo' end
-- > Foo.bar = 'bar'
-- > -- Objects inherit the prototype's properties.
-- > foo = Foo()
-- > tostring(obj)
-- foo
-- > foo.bar
-- bar
-- > -- The prototype's metatable is copied, so
-- > -- changing it does not alter a delegating object's behaviour.
-- > mt.__tostring = function () return 'baz' end
-- > tostring(obj)
-- foo
-- > -- But changing non-overriden properties does.
-- > Foo.bar = 'baz'
-- > foo.bar
-- baz
-- > -- The object can override properties, of course.
-- > foo.bar = 'bam!'
-- > foo.bar
-- bam!
-- > -- And objects can be prototypes.
-- > bar = foo()
-- > bar.bar
-- bam!
--
-- @object Object
Object = {}

--- Metatable for prototypes.
Object.mt = {}
setmetatable(Object, Object.mt)

--- Delegate to a prototype.
--
-- Set a table's metatable to a copy of the prototype's metatable
-- and then set the `__index` field of that metatable to the prototype.
--
-- @caveats If a table is given, it is modified *in-place*.
--
-- @tab proto A prototype.
-- @tab[opt] tab A table.
-- @treturn Object An object.
--
-- @usage
-- > foo = Object{foo = 'foo', bar = 'bar'}
-- > foo.foo
-- foo
-- > foo.bar
-- bar
-- > bar = foo{bar = 'bam!'}
-- > bar.foo
-- foo
-- > bar.bar
-- bam!
--
-- @function Object.mt.__call
-- @fixme DEBUG
Object.mt.__call = typed_args('table', '?table')(
    function (proto, tab)
        local mt = copy(getmetatable(proto))
        mt.__index = proto
        return setmetatable(tab or {}, mt)
    end
)

--- A simple list.
--
-- @usage
-- > list = Values()
-- > list:add 'a string'
-- > list.n
-- 1
--
-- @object Values
-- @proto @{Object}
Values = Object()

--- The number of items in the list.
Values.n = 0

--- Add items to the list.
--
-- @side Sets @{Values.n} to the number of items in the list.
--
-- @param ... Items.
--
-- @function Values:add
Values.add = typed_args('table')(
    function (self, ...)
        local items = pack(...)
        local n = self.n
        for i = 1, items.n do self[n + i] = items[i] end
        self.n = n + items.n
    end
)

--- Add getters to a table.
--
-- <h3>Getter protocol:</h3>
--
-- If an index is not present in a the table, look for a function of the same
-- name in the table's `getters` metavalue. That metavalue must be a mapping
-- of indices to functions. If it contains a function of the same name as the
-- index, then that function is called with the table as only argument and
-- whatever it returns is returned as the value for the index. If `getters`
-- contains no function of that name, the name is looked up in the table's
-- `__index` metavalue.
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
-- > -- Enable getters for an object.
-- > foo = getterify(Object{foo = 'bar'})
-- > mt = getmetatable(foo)
-- > mt.getters = {}
-- > function mt.getters.bar () return self.foo end
-- > foo.bar
-- bar
-- > -- The getter is reached via the prototype chain,
-- > -- so it sees foo.foo, not bar.foo:
-- > baz = foo{foo = 'bam!'}
-- > baz.bar
-- bar
-- > -- But you can make getters quasi-inheritable:
-- > mt.__call = delegate_with_getters
-- > baz = foo{foo = 'bam!'}
-- > baz.bar
-- bam!
--
-- @function getterify
-- @fixme Untested.
getterify = typed_args('table')(
    function (tab)
        local mt = copy(getmetatable(tab))
        local index = mt.__index
        mt.__index = typed_args('table')(
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
                    local err = 'table\'s "__index" metavalue points to a %s.'
                    error(err:format(t), 2)
                end
            end
        )
        return setmetatable(tab, mt)
    end
)

--- Delegate to a prototype and add getters.
--
-- @tab proto A prototype.
-- @tab[opt] tab A table.
-- @treturn Object A getterified table.
--
-- @see getterify
-- @function delegate_with_getters
delegate_with_getters = typed_args('table', '?table')(
    function (...)
        return getterify(getmetatable(Object).__call(...))
    end
)


-----------
-- Warnings
--
-- @section

do
    -- Priority levels for messages.
    local levels = List{'error', 'warning', 'info'}

    -- What level if verbosity is desired.
    local verbosity = PANDOC_STATE.verbosity:lower()

    --- Write strings to STDERR.
    --
    -- @param ... Strings to write to STDERR.
    local function write (...) io.stderr:write(...) end

    --- Compare verbosity levels.
    --
    -- @string a A verbosity level.
    -- @string b Another verbosity level.
    -- @treturn bool Whether level A is smaller than level B.
    local verbosity_lt = order(levels)

    --- Print a message to STDERR.
    --
    -- <h3>Printout:</h3>
    --
    -- The message is prefixed with `SCRIPT_NAME .. ': '` and terminated
    -- with @{EOL}. Non-string values are coerced to strings.
    --
    -- <h3>Message priority:</h3>
    --
    -- Messages are only printed if their priority is equal to or greater than
    -- `PANDOC_STATE.verbostiy`, where 'error' > 'warning' > 'info'.
    --
    -- <h3>Variable substitution:</h3>
    --
    -- If string values contain variable names, they are replaced with the
    -- values of those variables as seen by the function calling `xwarn`.
    -- See @{vars_sub} for the syntax.
    --
    -- <h3>Options:</h3>
    --
    -- String values that start with an '@' are interpreted as options:
    --
    -- * `'@error'`, `'@warning'`, `'@info'`: Set the message's
    --   priority. (*default* 'warning')
    -- * `'@novars'`: Turn variable substitution off. (*default* on)
    -- * `'@vars'`: Turn variable substitution on.
    -- * `'@noopts'`: Turn option processing off. (*default* on)
    -- * `'@plain'`: Turn variable substitution *and* option processing off.
    --
    -- Unknown options are ignored.
    --
    -- @param ... Messages. At least one must be given.
    --
    -- @function xwarn
    xwarn = typed_args('*')(
        function (...)
            local priority = 'warning'
            local do_opts_get = true
            local do_vars_sub = true
            local vars
            local function opts_get (msg)
                if not do_opts_get or msg:sub(1, 1) ~= '@' then return end
                local opt = msg:sub(2)
                if     levels:includes(opt) then priority = opt
                elseif opt == 'vars'        then do_vars_sub = true
                elseif opt == 'novars'      then do_vars_sub = false
                elseif opt == 'noopts'      then do_opts_get = false
                elseif opt == 'plain'       then do_vars_sub = false
                                                 do_opts_get = false
                end
                return true
            end
            local msgs = pack(...)
            local i = 1
            while i <= msgs.n do
                local msg = msgs[i]
                if
                    type(msg) ~= 'string' or
                    not opts_get(msg)
                then break end
                i = i + 1
            end
            if i > msgs.n or verbosity_lt(verbosity, priority) then return end
            write(SCRIPT_NAME, ': ')
            for j = i, msgs.n do
                local msg = msgs[j]
                if type(msg) == 'string' then
                    if not opts_get(msg) then
                        if do_vars_sub then
                            if not vars then vars = vars_get(3) end
                            msg = vars_sub(msg, vars)
                        end
                        write(msg)
                    end
                else
                    write(tostring(msg))
                end
            end
            write(EOL)
        end
    )
end


-----------
-- File I/O
--
-- @section

--- Check whether a path is absolute.
--
-- @string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
--
-- @function path_is_abs
if not pandoc.types or PANDOC_VERSION < {2, 12} then
    path_is_abs = typed_args('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            if PATH_SEP == '\\' and path:match '^.:\\' then return true end
            return path:match('^' .. PATH_SEP) ~= nil
        end
    )
else
    path_is_abs = pandoc.path.is_absolute
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
            if env_home and path_is_abs(env_home) then
                home_dir = path_normalise(env_home)
            end
        end
    end

    --- Prettify paths.
    --
    -- Removes the working directory from the beginning of the path. On
    -- non-Windows systems, also replaces the user's home directory with '~'.
    --
    -- @string path A path.
    -- @treturn string A prettier path.
    -- @require The working directory is removed from the
    --  beginning of the path since Pandoc v2.12.
    --
    -- @function path_prettify
    path_prettify = typed_args('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            path = path_normalise(path)
            if get_working_directory then
                local wd = get_working_directory()
                local last = #wd + 1
                if path:sub(1, last) == wd .. PATH_SEP then
                    return path:sub(last + 1)
                end
            end
            if home_dir then
                local last = #home_dir + 1
                if path:sub(1, last) == home_dir .. PATH_SEP then
                    return '~' .. path:sub(last)
                end
            end
            return path
        end
    )
end

--- Get a directory to use as working directory.
--
-- @treturn string The directory of the first input file
--  or '.' if no input files were given.
function wd ()
    local fname = PANDOC_STATE.input_files[1]
    if not fname then return '.' end
    local wd = path_split(fname)
    return wd
end

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
file_exists = typed_args('string')(
    function (fname)
        assert(fname ~= '', 'filename is the empty string.')
        local file, err, errno = io.open(fname, 'r')
        if not file then return nil, err, errno end
        assert(file:close())
        return true
    end
)

do
    local resource_path = PANDOC_STATE.resource_path

    --- Locate a file in Pandoc's resource path.
    --
    -- @caveats Absolute filenames are returned as is.
    --
    -- @string fname A filename.
    -- @treturn[1] string A filename in Pandoc's resource path.
    -- @treturn[2] nil `nil` if the file could not be found.
    -- @treturn[2] string An error message.
    --
    -- @function file_locate
    file_locate = typed_args('string')(
        function (fname)
            assert(fname ~= '', 'filename is the empty string.')
            if not resource_path or file_exists(fname) then return fname end
            for i = 1, #resource_path do
                local f = path_join(resource_path[i], fname)
                if file_exists(f) then return f end
            end
            return nil, fname .. ': not found in resource path.'
        end
    )
end

--- Read a file.
--
-- @string fname A filename.
-- @treturn[1] string The contents of the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--
-- @function file_read
file_read = typed_args('string')(
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

    --- Write data to a file.
    --
    -- If a file of that name already exists, it is overwritten.
    --
    -- @caveats
    --
    -- Data is first written to a temporary file, that file is then renamed
    -- to the given filename. This is safe and secure starting with Pandoc
    -- v2.8. If you are using an older version of Pandoc, the caveats of
    -- @{with_tmp_file} apply.
    --
    -- @side Typically creates and deletes a temporary file.
    --
    -- @string fname A filename.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    --
    -- @function file_write
    -- @fixme Legacy version is untested.
    file_write_legacy = typed_args('string')(
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

    do
        local with_temporary_directory = pandoc.system.with_temporary_directory
        local get_working_directory = pandoc.system.get_working_directory

        -- Turn a relative path into an absolute one.
        --
        -- Absolute paths are returned as they are.
        --
        -- @string path The path.
        -- @treturn string An absolute path.
        local function path_make_abs (path)
            if path_is_abs(path) then return path end
            return path_join(get_working_directory(), path)
        end

        file_write_modern = typed_args('string')(
            function (fname, ...)
                assert(fname ~= '', 'filename is the empty string.')
                local dir, base = path_split(path_make_abs(fname))
                local data = {...}
                local tmp_dir
                local vs = {with_temporary_directory(dir, 'pdz', function (td)
                    tmp_dir = td
                    xwarn 'created temporary directory ${td|path_prettify}.'
                    local tmp_file = path_join(td, base)
                    local ok, err, errno = write(tmp_file, unpack(data))
                    if not ok then return nil, err, errno end
                    return os.rename(tmp_file, fname)
                end)}
                if tmp_dir and not file_exists(tmp_dir) then
                    xwarn 'removed ${tmp_dir|path_prettify}.'
                end
                return unpack(vs)
            end
        )
    end

    if not pandoc.types or PANDOC_VERSION < {2, 8}
        then file_write = file_write_legacy
        else file_write = file_write_modern
    end
end

do
    local alnum = Values()

    do
        -- These are the ASCII/UTF-8 ranges for alphanumeric characters.
        local ranges = {
            {48,  57},  -- 0-9.
            {65,  90},  -- A-Z.
            {97, 122}   -- a-z.
        }

        -- Populate alnum.
        for i = 1, #ranges do
            local first, last = unpack(ranges[i])
            for j = first, last do alnum:add(string.char(j)) end
        end
    end

    math.randomseed(os.time())

    --- Generate a name for a temporary file.
    --
    -- @caveats
    --
    -- The filename generated is only *likely* not to be in use. Another
    -- process may create a file of the same name between the time `tmp_fname`
    -- checks whether that name is in use and the time it returns.
    --
    -- @string[opt] dir A directory to prefix the filename with.
    --  Must *not* be the empty string.
    -- @string[opt='pdz-XXXXXX'] templ A template for the filename.
    --  'X's are replaced with random alphanumeric characters.
    --  Must contain at least six 'X's.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the generated filename is in use.
    -- @treturn[2] string An error message.
    --
    -- @function tmp_fname
    tmp_fname = typed_args('?string', '?string')(
        function (dir, templ)
            if templ == nil then
                templ = 'pdz-XXXXXX'
            else
                assert(templ ~= '', 'template is the empty string.')
                local nxs = 0
                for _ in templ:gmatch 'X' do nxs = nxs + 1 end
                assert(nxs >= 6, 'template must contain at least six "X"s.')
            end
            if dir ~= nil then
                assert(dir ~= '', 'directory is the empty string.')
                templ = path_join(dir, templ)
            end
            for _ = 1, 1024 do
                local fname = ''
                for c in templ:gmatch '.' do
                    if c == 'X' then c = alnum[math.random(1, alnum.n)] end
                    fname = fname .. c
                end
                if not file_exists(fname) then return fname end
            end
            return nil, 'failed to generate an unused filename.'
        end
    )
end

--- Run a function with a temporary file.
--
-- Generates a temporary filename. Does *not* create that file.
-- If the function raises an error or returns `nil` or `false`,
-- the temporary file is deleted.
--
-- @caveats
--
-- The temporary file may have been created by *another* process. If that
-- file is located within a directory that other users have write access
-- to (e.g., `/tmp`), then this is a security issue.
--
-- @side May print error messages to STDERR.
--
-- @func func Given the name of the temporary file.
--  Must *not* change the working directory.
-- @string[opt] dir A directory to prefix the name
--  of the temporary file with. See @{tmp_fname}.
-- @string[opt] templ A template for the name
--  of the temporary file. See @{tmp_fname}.
-- @return The values returned by the function.
--
-- @function with_tmp_file
with_tmp_file = typed_args('function', '?string', '?string')(
    function (func, dir, templ)
        local tmp_file, err = tmp_fname(dir, templ)
        if not tmp_file then return nil, err end
        local vs = pack(pcall(func, tmp_file))
        local ok, ret = unpack(vs)
        if not ok or not ret then
            -- luacheck: no redefined
            xwarn 'removing ${fname|path_prettify}.'
            local ok, err, errno = os.remove(tmp_file)
            if not ok and errno ~= 2 then xwarn('@error', '@plain', err) end
        end
        return unpack(vs, 2)
    end
)


-------------
-- Networking
--
-- @section

--- Retrieve data from a URL via an HTTP GET request.
--
-- @string url The URL.
-- @treturn string The MIME type of the HTTP content.
-- @treturn string The HTTP content itself.
-- @raise An error if the host cannot be reached.
--  This error can only be caught since Pandoc v2.11.
--
-- @function http_get
http_get = typed_args('string')(
    function (url)
        assert(url ~= '', 'URL is the empty string.')
        return pandoc.mediabag.fetch(url, '.')
    end
)

--- Query a URL via an HTTP GET request.
--
-- @string url The URL.
-- @tparam[opt] {string=string,...} params Request parameters.
-- @treturn string The MIME type of the HTTP content.
-- @treturn string The HTTP content itself.
-- @raise See @{http_get}.
--
-- @usage
-- > -- Query <https://site.example?foo=1&bar=2>.
-- mt, con = url_query('https://site.example', {foo = 1, bar = 2})
--
-- @function url_query
url_query = typed_args('string', '?table')(
    function (url, params)
        assert(url ~= '', 'URL is the empty string.')
        if params then
            local query = Values()
            for k, v in sorted(params) do query:add(k .. '=' ..v) end
            url = url .. '?' .. concat(query, '&')
        end
        return http_get(url)
    end
)


--------------------
-- Markup converters
--
-- @section

do
    -- Escape bold and italics meta characters.
    local function escape_bold_italics (char, tail)
        return char:gsub('(.)', '\\%1') .. tail
    end

    -- Escape superscript and subscript meta characters.
    local function escape_sup_sub (head, body, tail)
        return head:gsub('(.)', '\\%1') .. body .. tail:gsub('(.)', '\\%1')
    end

    -- Escape brackets.
    local function escape_brackets (char, tail)
        return '\\[' .. char:sub(2, -2) .. '\\]' .. tail
    end

    -- Pairs of expressions and replacement functions.
    local patterns = {
        -- Backslashes.
        {'(\\+)', '\\%1'},
        -- Bold and italics.
        -- This escapes liberally, but it is the only way to cover edge cases.
        {'(%*+)([^%s%*])', escape_bold_italics},
        {'(_+)([^%s_])', escape_bold_italics},
        -- Superscript and subscript.
        {'(%^+)([^%^%s]*)(%^+)', escape_sup_sub},
        {'(~+)([^~%s]+)(~+)', escape_sup_sub},
        -- Brackets (spans and links).
        {'(%b[])([%({])', escape_brackets}
    }

    local npatterns = #patterns

    --- Escape Markdown syntax.
    --
    -- @caveats
    --
    -- Only escapes [Markdown that Pandoc recognises in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @string str Non-markdown text.
    -- @treturn string Text with markdown syntax escaped.
    --
    -- @usage
    -- > escape_markdown '*text*'
    -- \*text*
    --
    -- @function escape_markdown
    escape_markdown = typed_args('string')(
        function (str)
            for i = 1, npatterns do
                local pattern, repl = unpack(patterns[i])
                str = str:gsub(pattern, repl)
            end
            return str
        end
    )
end

do
    -- Filter to escape Markdown in Pandoc string elements.
    local escape_str = {}

    -- Escape Markdown in a string element.
    --
    -- Works like @{escape_markdown} but for Pandoc string elements.
    --
    -- @tparam pandoc.Str str A Pandoc string element.
    -- @treturn pandoc.Str A string with all Markdown syntax escaped.
    function escape_str.Str (str)
        str.text = escape_markdown(str.text)
        return str
    end

    -- Filter to convert to Markdown.
    local to_markdown = {}

    -- Make a function that converts an element to Markdown.
    --
    -- @string char A Markdown markup character.
    -- @treturn func A conversion function.
    local function make_converter (char)
        return function (elem)
            local str = stringify(pandoc.walk_inline(elem, to_markdown))
            return Str(char .. str .. char)
        end
    end

    -- Convert AST elements into Markdown text.
    to_markdown.Emph = make_converter '*'
    to_markdown.Strong = make_converter '**'
    to_markdown.Subscript = make_converter '~'
    to_markdown.Superscript = make_converter '^'

    -- Convert HTML span elements to Markdown text.
    --
    -- @tparam pandoc.Span An HTML span element.
    -- @treturn pandoc.Str A Markdown representation.
    function to_markdown.Span (span)
        local str = stringify(pandoc.walk_inline(span, to_markdown))
        local attrs = Values()

        local identifier = span.identifier
        if identifier and identifier ~= '' then
            attrs:add('#' .. identifier)
        end

        local classes = span.classes
        if classes then
            for i = 1, #classes do
                attrs:add('.' .. classes[i])
            end
        end

        local attributes = span.attributes
        if attributes then
            for k, v in pairs(attributes) do
                attrs:add(format('%s="%s"', k, v))
            end
        end

        if attrs.n > 0 then
            str = '[' .. str ..                ']' ..
                  '{' .. concat(attrs, ' ') .. '}'
        end
        return Str(str)
    end

    -- Convert a Pandoc small capitals elements to Markdown text.
    --
    -- @tparam pandoc.SmallCaps A SmallCaps element.
    -- @treturn pandoc.Str A Markdown representation.
    function to_markdown.SmallCaps (sc)
        local span = Span(sc.content)
        span.attributes.style = 'font-variant: small-caps'
        return to_markdown.Span(span)
    end

    --- Convert a Pandoc element to Markdown text.
    --
    -- @caveats
    --
    -- Only recognises [elements Pandoc permits in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn string Markdown text.
    --
    -- @function markdownify
    markdownify = typed_args('table|userdata')(
        function (elem)
            local escaped = elem_walk(elem, escape_str)
            return stringify(elem_walk(escaped, to_markdown))
        end
    )
end

do
    local rep = string.rep
    local char = utf8.char
    local codes = utf8.codes

    --- Create a number of spaces.
    --
    -- @int n The number of spaces.
    -- @treturn string `n` spaces.
    local function spaces (n)
        return rep(' ', n)
    end

    --- Convert a string to a YAML scalar.
    --
    -- @caveats
    --
    -- * Strings *must* be encoded in UTF-8.
    -- * Does *not* escape *all* non-printable characters.
    --
    -- @string str A string.
    -- @bool[opt] unquoted Quote strings only when needed?
    -- @treturn string A YAML scalar.
    local function scalarify (str, unquoted)
        -- Simple strings may need no special treatment.
        if
            unquoted                and
            not str:match '^%d+$'   and
            str:match '^[%w%s%-]+$'
        then return str end

        -- Replace line breaks with the OS' EOL sequence.
        str = str:gsub('\r?\n', EOL)

        -- Escape special and forbidden characters.
        local chars = Values()
        for _, c in codes(str, true) do
            if
                c == 0x22 or -- '"'
                c == 0x5c    -- '\'
            then
                chars:add('\\' .. char(c))
            elseif
                c == 0x09 or -- TAB
                c == 0x0a or -- LF
                c == 0x0d or -- CR
                c == 0x85    -- NEL
            then
                chars:add(char(c))
            elseif
                c <= 0x001f or -- C0 control block
                c == 0x007f    -- DEL
            then
                chars:add(format('\\x%02x', c))
            elseif
                (0x0080 <= c and c <= 0x009f) or -- C1 control block
                (0xd800 <= c and c <= 0xdfff) or -- Surrogate block
                c == 0xfffe or
                c == 0xffff
            then
                chars:add(format('\\u%04x', c))
            else
                chars:add(char(c))
            end
        end
        str = concat(chars)

        -- Quote.
        return '"' .. str .. '"'
    end

    -- Convert Lua to YAML types.
    local converters = {}
    converters.boolean = tostring
    converters.number = tostring
    converters.string = scalarify

    --- Generate a YAML representation of a value.
    --
    -- Lines are termined with @{EOL}.
    --
    -- @caveats
    --
    -- * Mangles strings in encodings other than UTF-8.
    -- * Does *not* escape *all* non-printable characters (because Unicode).
    --
    -- @param val A value.
    -- @int[opt=4] ind How many spaces to indent blocks.
    -- @func[opt] sort A function to sort keys of mappings.
    --  Defaults to lexical sorting.
    -- @treturn[1] string A YAML string.
    -- @treturn[2] nil `nil` if the data cannot be represented in YAML.
    -- @treturn[2] string An error message.
    --
    -- @function yamlify
    -- @fixme Indentation and sorting is not unit-tested.
    yamlify = typed_args('*', '?number', '?function', '?number')(
        -- luacheck: ignore sort
        function (val, ind, sort, _col, _rd)
            if not _rd then _rd = 0 end
            if not ind then ind = 4 end
            assert(_rd < 64, 'recursion limit exceeded.')
            local t = type(val)
            local conv = converters[t]
            if conv then return conv(val) end
            assert(t == 'table', t .. ': cannot be expressed in YAML.')
            if not _col then _col = 0 end
            local strs = Values()
            local n = #val
            local nkeys = select(2, keys(val))
            local sp = spaces(_col)
            if n == nkeys then
                local col = _col + 2
                for i = 1, n do
                    local v = val[i]
                    if i > 1 then strs:add(sp) end
                    strs:add('- ', yamlify(v, ind, sort, col, _rd + 1))
                    if i ~= n then strs:add(EOL) end
                end
            else
                local i = 0
                for k, v in sorted(val, sort) do
                    i = i + 1
                    if type(k) == 'number' then k = tostring(k)
                                           else k = scalarify(k, true)
                    end
                    if i > 1 then strs:add(sp) end
                    strs:add(k, ':')
                    local col = _col + ind
                    if type(v) == 'table' then strs:add(EOL, spaces(col))
                                          else strs:add ' '
                    end
                    strs:add(yamlify(v, ind, sort, col, _rd + 1))
                    if i ~= nkeys then strs:add(EOL) end
                end
            end
            if _rd == 0 then return concat(strs) end
            return unpack(strs)
        end
    )
end

--- Convert Zotero pseudo-HTML to proper HTML.
--
-- @string pseudo Zotero pseudo-HTML code.
-- @treturn string HTML code.
--
-- @function zotero_to_html
-- @raise An error if opening `<sc>` and closing `</sc>` tags are unbalanced.
zotero_to_html = typed_args('string')(
    function (pseudo)
        local opened, closed, n, m
        opened, n = pseudo:gsub('<sc>',
                                '<span style="font-variant: small-caps">')
        if n == 0 then return pseudo end
        closed, m = opened:gsub('</sc>',
                                '</span>')
        if m ~= n then
            error(format('%s: contains %d <sc>, but %d </sc> tags.',
                         pseudo, n, m), 0)
        end
        return closed
    end
)

--- Convert Zotero pseudo-HTML to Markdown.
--
-- @caveats
--
-- Only supports [pseudo-HTML that Pandoc recognises in bibliographic
-- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
--
-- @string pseudo Zotero pseudo-HTML code.
-- @treturn string Markdown text.
-- @raise See @{zotero_to_html}.
--
-- @function zotero_to_markdown
zotero_to_markdown = typed_args('string')(
    function (pseudo)
        local html = zotero_to_html(pseudo)
        local ok, doc = pcall(read, html, 'html')
        if not ok then
            error(pseudo .. ': cannot parse Zotero pseudo-HTML.', 0)
        end
        return markdownify(doc)
    end
)


------------
-- CSL items
--
-- @section

--- Preferred order of CSL variables.
--
-- @see csl_vars_sort
CSL_VARS_ORDER = {
    'id',                       -- Item ID.
    'type',                     -- For example, 'paper', 'book'.
    'author',                   -- Author(s).
    'original-author',          -- Original author(s).
    'recipient',                -- Recipient of the document.
    'status',                   -- Publication status (e.g., 'forthcoming').
    'issued',                   -- When the item was published.
    'original-date',            -- Original date.
    'title',                    -- The title.
    'title-short',              -- A short version of the title.
    'short-title',              -- Ditto.
    'translator',               -- Translator(s).
    'editor',                   -- The editor(s).
    'container-title',          -- Publication the item was published in.
    'container-title-short',    -- A short version of that title.
    'collection-title',         -- E.g., a series.
    'collection-title-short',   -- A short version of the title.
    'edition',                  -- Container's edition.
    'volume',                   -- Volume no.
    'issue',                    -- Issue no.
    'page-first',               -- First page.
    'page',                     -- Pages or page range *or* number of pages.
    'publisher',                -- Publisher.
    'publisher-place',          -- City/cities the item was published in.
    'original-title',           -- Original title.
    'original-publisher',       -- Original publisher.
    'original-publisher-place', -- Place the item was originally published in.
    'doi',                      -- The DOI.
    'pmcid',                    -- PubMed Central reference number.
    'pmid',                     -- PubMed reference number.
    'url',                      -- The URL.
    'accessed',                 -- When the URL was last accessed.
    'isbn',                     -- The ISBN of the item.
    'issn',                     -- The ISSN of the container.
    'call-number',              -- Call number (of a library).
    'language',                 -- Language the item is in.
    'abstract',                 -- The abstract.
}

do
    --- Normalise a CSL key-value pair.
    --
    -- @string key A CSL key.
    -- @string val A value.
    -- @treturn[1] string A normalised CSL key.
    -- @treturn[1] string A trimmed value
    -- @see csl_varname_normalise
    local function normalise (key, val)
        if not key or not val then return end
        key = csl_varname_normalise(key)
        if not key then return end
        val = trim(val)
        if val == '' then return end
        return key, val
    end

    -- Create a function that iterates over "extra" field entries.
    --
    -- Uses the newer `<variable name>: <value><linefeed>` syntax.
    --
    -- @string extra Contents of a Zotero "extra" field.
    -- @treturn func A *stateful* iterator.
    local function make_iter (extra)
        local next_line = split(extra, '\r?\n')
        return function ()
            while true do
                local ln = next_line()
                while ln and ln:match '^%s*$' do ln = next_line() end
                if not ln then return end
                local k, v = normalise(tabulate(split(ln, '%s*:%s*'), 2))
                if k then return k, v end
            end
        end
    end

    -- Create a function that iterates over legacy "extra" field entries.
    --
    -- Uses the older `{:<variable name>: <value>}` syntax.
    --
    -- @string note The contents of a Zotero "extra" field.
    -- @treturn func A *stateful* iterator.
    local function make_legacy_iter (note)
        local next_pair = note:gmatch '{:([%a-]+):%s*([^}]+)}'
        return function ()
            while true do
                local k, v = next_pair()
                if not k then return end
                k, v = normalise(k, v)
                if k then return k, v end
            end
        end
    end

    --- Iterate over every key-value pair in the "note" field of a CSL item.
    --
    -- @caveats
    --
    -- Assumes that the "note" field is used to store entries that
    -- were added to Zotero's ["extra" field](https://perma.cc/EGN3-78CH).
    --
    -- @tab item A CSL item.
    -- @treturn func A *stateful* iterator.
    --
    -- @see csl_item_add_extras
    -- @function csl_item_extras
    csl_item_extras = typed_args('table')(
        function (item)
            local note = item.note
            if not note then return function () return end end
            local i = 1
            local next_pair = make_iter(note)
            return function ()
                while true do
                    local k, v = next_pair()
                    if k then return k, v end
                    i = i + 1
                    if i > 2 then break end
                    next_pair = make_legacy_iter(note)
                end
            end
        end
    )
end

do
    local insert = table.insert

    -- Parse a date in Zotero's extra field.
    --
    -- @caveats The item is modified in-place.
    --
    -- @tab item A CSL item.
    -- @string key A field name.
    -- @string val A value.
    local function parse_date (item, key, val)
        local parts = {}
        local i = 0
        for iso in split(val, '/', 2) do
            i = i + 1
            local year, month, day = iso:match '^(%d%d%d%d)%-?(%d*)%-?(%d*)$'
            if year then
                local date = {year}
                if month and month ~= '' then
                    date[2] = month
                    if day and day ~= '' then
                        date[3] = day
                    end
                end
                parts[i] = date
            elseif i == 1 then
                xwarn('@error', '${item.id}: cannot parse extra field ${key}.')
                return
            end
        end
        item[key] = {['date-parts'] = parts}
    end

    -- Parse a name in Zotero's extra field.
    --
    -- @caveats The item is modified in-place.
    --
    -- @tab item A CSL item.
    -- @string key A field name.
    -- @string val A value.
    local function parse_name (item, key, val)
        local family, given = tabulate(split(val, '%s*%|%|%s*', 2))
        if not item[key] then item[key] = {} end
        if family and family ~= '' and given and given ~= '' then
            insert(item[key], {family = family, given = given})
        else
            insert(item[key], val)
        end
    end

    -- Mapping of CSL field names to functions that take an item and a field
    -- name-value pair and *add* that field to the CSL item *in-place*.
    local parsers = {
        ['accessed'] = parse_date,
        ['container'] = parse_date,
        ['event-date'] = parse_date,
        ['issued'] = parse_date,
        ['original-date'] = parse_date,
        ['submitted'] = parse_date,
        ['author'] = parse_name,
        ['collection-editor'] = parse_name,
        ['composer'] = parse_name,
        ['container-author'] = parse_name,
        ['director'] = parse_name,
        ['editor'] = parse_name,
        ['editorial-director'] = parse_name,
        ['managing-editor'] = parse_name,
        ['illustrator'] = parse_name,
        ['interviewer'] = parse_name,
        ['original-author'] = parse_name,
        ['recipient'] = parse_name,
        ['reviewed-author'] = parse_name,
        ['translator'] = parse_name
    }

    --- Add CSL variables from the "note" field to the item proper.
    --
    -- @tab item A CSL item.
    -- @treturn table The item with variables from "extra" copied.
    --
    -- @function csl_item_add_extras
    csl_item_add_extras = typed_args('table')(
        function (item)
            local ret = copy(item)
            for k, v in csl_item_extras(item) do
                local f = parsers[k]
                if not ret[k] or f == parse_date or k == 'type' then
                    if f then
                        f(ret, k, v)
                    -- At least until CSL v1.2 is out and
                    -- 'citekey' becomes official.
                    elseif k ~= 'citation-key' and k ~= 'citekey' then
                        ret[k] = v
                    end
                end
            end
            return ret
        end
    )
end

--- Normalise variable names of a CSL item.
--
-- @tab item A CSL item.
-- @treturn tab A normalised item.
-- @see csl_varname_normalise
--
-- @function csl_item_normalise_vars
csl_item_normalise_vars = typed_args('table', '?table')(
    function (item, _seen)
        if     not _seen   then _seen = {}
        elseif _seen[item] then return _seen[item]
        end
        local ret = {}
        _seen[item] = ret
        for k, v in pairs(item) do
            if type(k) == 'string' then
                k = csl_varname_normalise(k)
            end
            if k then
                if type(v) == 'table' then
                    v = csl_item_normalise_vars(v, _seen)
                end
                ret[k] = v
            end
        end
        return ret
    end
)

do
    -- A mapping of Lua type names to functions that construct Pandoc types.
    local converters = {}

    --- Convert a CSL Item to a Pandoc metadata type (worker).
    --
    -- @tab item CSL item.
    -- @param ... Passed on to per-type conversion function.
    -- @treturn pandoc.MetaValue A Pandoc metadata value.
    -- @raise An error if a type cannot be converted to a Pandoc metadata type.
    local function convert (item, ...)
        local t = type(item)
        local f = converters[t]
        assert(f, t .. ': cannot be converted to a Pandoc metadata type.')
        return f(item, ...)
    end

    -- Convert a Lua boolean to a pandoc.MetaBool
    --
    -- @bool bool A boolean value.
    -- @treturn pandoc.MetaBool The value.
    function converters.boolean (bool)
        return pandoc.MetaBool(bool)
    end

    -- Convert a Lua number to a pandoc.MetaInlines string.
    --
    -- @bool num A number.
    -- @treturn pandoc.MetaInlines The number.
    function converters.number (num)
        return MetaInlines(List{Str(tostring(num))})
    end

    -- Convert Zotero pseudo-HTML to a pandoc.MetaInlines string.
    --
    -- @string str A string.
    -- @treturn pandoc.MetaInlines A string.
    function converters.string (str)
        local html = zotero_to_html(str)
        local inlines = read(html, 'html').blocks[1].content
        return MetaInlines(inlines)
    end

    -- Convert a Lua table to a pandoc.MetaMapping.
    --
    -- @tab tab A table.
    -- @treturn pandoc.MetaMapping The table.
    -- @fixme Recursion protection is not tested.
    function converters.table (tab, _rd)
        if not _rd then _rd = 0 end
        assert(_rd < 128, 'recursion limit exceeded.')
        local nkeys = select(2, keys(tab))
        local n = #tab
        if n == nkeys then
            local list = MetaList{}
            for i = 1, n do
                list[i] = convert(tab[i], _rd + 1)
            end
            return list
        end
        local map = MetaMap{}
        for k, v in pairs(tab) do map[k] = convert(v, _rd + 1) end
        return map
    end

    --- Convert a CSL item to a Pandoc metadata value.
    --
    -- @tab item A CSL item.
    -- @treturn pandoc.MetaMap A Pandoc metadata value.
    -- @raise An error if an item cannot be converted to
    --  a Pandoc metadata value.
    --
    -- @function csl_item_to_meta
    -- @fixme No unit test.
    csl_item_to_meta = typed_args('table')(convert)
end

--- Filter CSL items by their citation key.
--
-- @tparam {tab,...} items CSL items.
-- @string ckey A citation key (e.g., `'doe:2020word'`, `'DoeWord2020'`).
-- @treturn {tab,...} Items with that citation key.
--
-- @function csl_items_filter_by_ckey
-- @fixme No unit test.
csl_items_filter_by_ckey = typed_args('table', 'string')(
    function (items, ckey)
        local filtered = Values()
        for i = 1, #items do
            local item = items[i]
            for k, v in csl_item_extras(item) do
                if (k == 'citation-key' or k == 'citekey') and v == ckey then
                    filtered:add(item)
                    break
                end
            end
        end
        return filtered
    end
)

--- Pick the IDs of CSL items out of a list of CSL items.
--
-- @side May print error messages to STDERR.
--
-- @tparam {tab,...} items CSL items.
-- @treturn {[string]=true,...}
--  A [set](https://www.lua.org/pil/11.5.html) of item IDs.
--
-- @function csl_items_ids
csl_items_ids = typed_args('table')(
    function (items)
        local ids = {}
        for i = 1, #items do
            local id = items[i].id
            local t = type(id)
            if     t == 'number' then id = tostring(id)
            elseif t == 'table'  then id = stringify(id)
            end
            if type(id) == 'string' and id ~= ''
                then ids[id] = true
                else xwarn('@error', 'ignoring CSL item witout parsable ID.')
            end
        end
        return ids
    end
)

--- Sort CSL items by their ID.
--
-- @caveats Assumes that CSL item IDs are of the same type.
--
-- @tab a A CSL item.
-- @tab b Another CSL item.
-- @treturn bool Whether item A comes before item B.
--
-- @function csl_items_sort
csl_items_sort = typed_args('table', 'table')(
    function (a, b)
        return a.id < b.id
    end
)

--- Normalise a CSL variable name.
--
-- Trim the variable name, lowercase it, and replace spaces with dashes.
--
-- @string var A CSL variable name.
-- @treturn[1] string A normalised variable name.
-- @treturn[2] nil `nil` if the string is not a CSL variable name.
-- @treturn[2] string An error message.
--
-- @usage
-- > csl_varname_normalise 'Original date'
-- original-date
--
-- @function csl_varname_normalise
csl_varname_normalise = typed_args('string')(
    function (var)
        var = trim(var):gsub(' ', '-'):lower()
        if var:match '^[%a%-]+$' then return var end
        if var == '' then return nil, 'variable name is the empty string.' end
        return nil, var .. ': not a variable name.'
    end
)

--- Sort CSL variables.
--
-- Sorts variables in the order in which they are listed in @{CSL_VARS_ORDER}.
-- Unlisted variables are placed after listed ones in lexical order.
--
-- @string a A CSL variable name.
-- @string b Another CSL variable name.
-- @treturn bool Whether variable A should come before variable B.
--
-- @function csl_vars_sort
csl_vars_sort = typed_args('string', 'string')(order(CSL_VARS_ORDER))

do
    local decode = json.decode
    local floor = math.floor

    -- Convert numbers to strings.
    --
    -- Floating point numbers are converted to integers.
    -- Data of other types is returned as is.
    --
    -- @tab data The data.
    -- @return The converted data.
    local function num_to_str (data)
        if type(data) ~= 'number' then return data end
        return tostring(floor(data))
    end

    --- Parse a CSL JSON string.
    --
    -- @string str A CSL JSON string.
    -- @treturn[1] tab A single CSL item or a list of CSL items.
    -- @treturn[2] nil `nil` if the string cannot be parsed.
    -- @treturn[2] string An error message.
    --
    -- @function csl_json_to_items
    csl_json_to_items = typed_args('string')(
        function (str)
            if str == '' then return nil, 'got the empty string.' end
            local ok, data = pcall(decode, str)
            if not ok then return nil, 'cannot parse: ' .. str end
            return csl_item_normalise_vars(walk(data, num_to_str))
        end
    )
end


----------------
-- Citation keys
-- @section

--- An interface for parsing citation keys.
--
-- @object citekey
-- @proto @{Object}
citekey = Object()

--- A mapping of citation key types to parsers.
--
-- A parser must take a citation key and return search terms or `nil` and
-- an error message if no search terms can be derived from the citation key.
citekey.parsers = {}

do
    local len = utf8.len

    --- Guess search terms from a BetterBibTeX citation key.
    --
    -- Splits up a BetterBibTeX citation key at each uppercase letter
    -- and at each start of a string of digits.
    --
    -- @caveats BetterBibTeX citation keys must be encoded in ASCII.
    --
    -- @string ckey A BetterBibTeX citation key (e.g., `'DoeWord2020'`).
    -- @treturn[1] {string,...} Search terms.
    -- @treturn[2] nil `nil` if no search terms could be derived.
    -- @treturn[2] string An error message.
    --
    -- @function citekey.parsers.betterbibtexkey
    -- @fixme No unit test.
    citekey.parsers.betterbibtexkey = typed_args('string')(
        function (ckey)
            assert(ckey ~= '', 'citation key is the empty string.')
            local terms = Values()
            for str, num in ckey:gmatch '([%a%p]*)(%d*)' do
                if str and str ~= '' then
                    for term in split(str, '%u', nil, 'l') do
                        local l = len(term)
                        if l and l >= 3 then terms:add(term) end
                    end
                end
                if num and num ~= '' then
                    local l = len(num)
                    if l and l > 1 then terms:add(num) end
                end
            end
            if terms.n < 1 then
                return nil, 'not a BetterBibTex citation key.' end
            return terms
        end
    )
end

do
    local codes = utf8.codes

    --- Guess search terms from an Easy Citekey.
    --
    -- Splits up an Easy Citekey into an author, a year, and a word.
    --
    -- @caveats Easy Citekeys must be encoded in UTF-8.
    --
    -- @string ckey A zotxt Easy Citekey (e.g., `'doe:2020word'`).
    -- @treturn[1] {string,...} Search terms.
    -- @treturn[2] nil `nil` if no search terms could be derived.
    -- @treturn[2] string An error message.
    --
    -- @function Citekey.parsers.easykey
    -- @fixme No unit test.
    citekey.parsers.easykey = typed_args('string')(
        function (ckey)
            assert(ckey ~= '', 'citation key is the empty string.')
            local terms = Values()
            local colon = false
            for p, c in codes(ckey) do
                if not colon then
                    -- 58 is the colon (:).
                    if c == 58 then
                        local s = ckey:sub(1, p - 1)
                        if s and s ~= '' then terms:add(s) end
                        colon = true
                    end
                else
                    -- Digits start at 48 and end at 57.
                    if c >= 48 and c <= 57 then
                        if terms.n < 2 then terms:add '' end
                        terms[2] = terms[2] .. tostring(c - 48)
                    else
                        local s = ckey:sub(p)
                        if s and s ~= '' then terms:add(s) end
                        break
                    end
                end
            end
            if terms.n < 2 then
                return nil, 'not an Easy Citekey.'
            end
            return terms
        end
    )
end

--- Guess search terms from a citation key.
--
-- @caveats
--
-- The citation key types 'key' and 'easykey' go before 'betterbibtexkey',
-- for while it is unlikely for the Zotero item ID parser or the Easy Citekey
-- parser to parse a Better BibTeX citation key, it is possible for the
-- BetterBibTeX citation parser to parse a Zotero item ID and quite likely
-- for it to parse an Easy Citekey -- and it would do it wrong.
--
-- @string ckey A citation key (e.g., `'doe:2020word'`, `'DoeWord2020'`).
-- @tparam {string,...} types Types to try to parse the citation key as.
--  If @{citekey.parsers} contains no parser for a type, it is ignored.
--  Order is significant.
-- @treturn[1] {string,...} Search terms.
-- @treturn[2] nil `nil` if no search terms could be derived.
-- @treturn[2] string An error message.
--
-- @function citekey:guess_terms
citekey.guess_terms = typed_args('table', 'string', 'table')(
    function (self, ckey, types)
        assert(ckey ~= '', 'citation key is the empty string.')
        assert(#types > 0, 'list of citation key types is empty.')
        for i = 1, #types do
            local parse = self.parsers[types[i]]
            if parse then
                local terms = parse(ckey)
                if terms then return terms end
            end
        end
        return nil, format('cannot guess search terms for %s.', ckey)
    end
)


---------------------
-- Bibliography files
-- @section

--- An interface for reading, writing, and updating bibliography files.
--
-- @object biblio
-- @proto @{Object}
biblio = Object()

--- A case-insensitive mapping of filename suffices to codecs.
biblio.types = setmetatable({}, ignore_case)

--- Decode BibLaTeX.
biblio.types.bib = {}

--- Read the IDs from the contents of a BibLaTeX file.
--
-- @string str The contents of a BibLaTeX file.
-- @treturn {{['id']=string},...} Key-value pairs.
--
-- @function biblio.types.bib.decode
biblio.types.bib.decode = typed_args('string')(
    function (str)
        local ids = Values()
        for id in str:gmatch '@%w+%s*{%s*([^%s,]+)' do ids:add{id = id} end
        return ids
    end
)

--- Decode BibTeX.
biblio.types.bibtex = {}

--- Read the IDs from the contents of a BibTeX file.
--
-- @string str The contents of a BibTeX file.
-- @treturn {{['id']=string},...} Key-value pairs.
--
-- @function biblio.types.bibtex.decode
biblio.types.bibtex.decode = biblio.types.bib.decode

--- De-/Encode CSL items in JSON.
biblio.types.json = {}

--- Parse a CSL JSON string.
--
-- @string str A CSL JSON file.
-- @treturn {tab,...} CSL items.
--
-- @function biblio.types.json.decode
biblio.types.json.decode = csl_json_to_items

--- Serialise a list of CSL items to a JSON string.
--
-- @tparam {tab,...} items CSL items.
-- @treturn string A CSL YAML string.
--
-- @function biblio.types.json.encode
biblio.types.json.encode = json.encode

--- De-/Encode CSL items in YAML.
biblio.types.yaml = {}

--- Parse a CSL YAML string.
--
-- @caveats Converts formatting to Markdown, not Zotero pseudo-HTML.
--
-- @string str A CSL YAML string.
-- @treturn {tab,...} CSL items.
--
-- @function biblio.types.yaml.decode
biblio.types.yaml.decode = typed_args('string')(
    function (str)
        local next_line = str:gmatch '(.-)\r?\n'
        local ln = next_line(str, nil)
        while ln and ln ~= '---' do ln = next_line(str, ln) end
        if not ln then str = concat{'---', EOL, str, EOL, '...', EOL} end
        local doc = read(str, 'markdown')
        if not doc.meta.references then return {} end
        local refs = elem_walk(doc.meta.references,
                                {MetaInlines = markdownify})
        for i = 1, #refs do refs[i] = csl_item_normalise_vars(refs[i]) end
        return refs
    end
)

do
    -- Convert Zotero pseudo-HTML to Markdown in CSL fields.
    --
    -- @param value A field value.
    -- @treturn[1] string Markdown text if the value contained pseudo-HTML.
    -- @treturn[2] nil `nil` if the value is not a `string`.
    local function to_markdown (value)
        if type(value) ~= 'string' then return end
        return zotero_to_markdown(value)
    end

    --- Serialise a list of CSL items to a YAML string.
    --
    -- @tparam {tab,...} items CSL items.
    -- @treturn string A CSL YAML string.
    -- @raise See @{yamlify} and @{zotero_to_markdown}.
    --
    -- @function biblio.types.yaml.encode
    biblio.types.yaml.encode = typed_args('table')(
        function (items)
            sort(items, csl_items_sort)
            items = walk(items, to_markdown)
            return yamlify({references=items}, nil, csl_vars_sort)
        end
    )
end

--- Alternative suffix for YAML files.
biblio.types.yml = biblio.types.yaml

--- Read a bibliography file.
--
-- The filename suffix determines the file's format.
-- @{biblio.types} must contain a matching decoder.
--
-- @string fname A filename.
-- @treturn[1] tab CSL items.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is an I/O error.
--
-- @function biblio:read
biblio.read = typed_args('table', 'string')(
    function (self, fname)
        assert(fname ~= '', 'filename is the empty string')
        local suffix = fname:match '%.(%w+)$'
        if not suffix then return nil, fname .. ': no filename suffix.' end
        local codec = self.types[suffix]
        if not codec then return nil, fname .. ': unsupported format.' end
        local decode = codec.decode
        if not decode then return nil, fname .. ': cannot parse format.' end
        local str, err, errno = file_read(fname)
        if not str then return nil, err, errno end
        local ok, ret = pcall(decode, str)
        if not ok then return nil, format('%s: %s', fname, ret) end
        return ret
    end
)

--- Write bibliographic data to a bibliography file.
--
-- The filename suffix determines the file's format.
-- @{biblio.types} must contain a matching encoder.
--
-- @caveats See @{file_write}.
--
-- @string fname A filename.
-- @tab[opt] items CSL items. If none are given, tests
--  whether the data can be written in the given format.
-- @treturn[1] string The filename suffix.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is an I/O error.
--
-- @function biblio:write
biblio.write = typed_args('table', 'string', '?table')(
    function (self, fname, items)
        local ok, err, errno, ret, suffix, codec, encode
        assert(fname ~= '', 'filename is the empty string')
        suffix = fname:match '%.(%w+)$'
        if not suffix then return nil, fname .. ': no filename suffix.' end
        codec = self.types[suffix]
        if not codec then return nil, fname .. ': unsupported format.' end
        encode = codec.encode
        if not encode then return nil, fname .. ': cannot write format.' end
        if not items or #items == 0 then return suffix end
        ok, ret = pcall(encode, items)
        if not ok then return nil, format('%s: %s', fname, ret) end
        ok, err, errno = file_write(fname, ret, EOL)
        if not ok then return nil, err, errno end
        return suffix
    end
)

--- Add new items from Zotero to a bibliography file.
--
-- @caveats See @{file_write}.
-- @side May print error messages to STDERR.
--
-- @tparam connectors.Zotxt|connectors.ZotWeb handle An interface to Zotero.
-- @string fname The name of the bibliography file.
-- @tparam {string,...} ckeys The citation keys of the items to add
--  (e.g., `{'doe:2020word'}`).
-- @treturn[1] bool `true` if the file was updated or no update was required.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is a file I/O error.
-- @raise See @{http_get}.
--
-- @function biblio:update
-- @todo Move markup conversion to the YAML codec.
-- @todo Use sets so that the loop gets simpler.
biblio.update = typed_args('table', 'table', 'string', 'table')(
    function (self, handle, fname, ckeys)
        -- luacheck: no redefined
        assert(fname ~= '', 'filename is the empty string')
        if #ckeys == 0 then return true end
        local fmt, err = self:write(fname)
        if not fmt then return nil, err end
        local items, err, errno = biblio:read(fname)
        if not items then
            if errno ~= 2 then return nil, err, errno end
            items = {}
        end
        local ids = csl_items_ids(items)
        local nitems = #items
        local n = nitems
        for i = 1, #ckeys do
            local ckey = ckeys[i]
            if not ids[ckey] then
                local vs = pack(pcall(handle.fetch, handle, ckey))
                local ok, err = unpack(vs)
                if not ok then return nil, tostring(err) end
                local item, err = unpack(vs, 2)
                if item then
                    n = n + 1
                    items[n] = item
                else
                    xwarn('@error', '@plain', err)
                end
            end
        end
        if n == nitems then return true end
        local vs = pack(pcall(self.write, self, fname, items))
        local ok, err = unpack(vs)
        if not ok then return nil, err end
        local fmt, err, errno = unpack(vs, 2)
        if not fmt then return nil, err, errno end
        return true
    end
)


-------------------
-- Document parsing
--
-- @section

--- Make a shallow copy of a Pandoc AST element.
--
-- @tparam pandoc.AstElement elem A Pandoc AST element.
-- @treturn pandoc.AstElement The clone.
-- @fixme No unit test.
--
-- @function elem_clone
if not pandoc.types or PANDOC_VERSION < {2, 15} then
    elem_clone = typed_args('table')(
        function (elem)
            if elem.clone then return elem:clone() end
            local copy = setmetatable({}, getmetatable(elem))
            for k, v in next, elem do rawset(copy, k, v) end
            return copy
        end
    )
else
    elem_clone = typed_args('table|userdata')(
        function (elem)
            if elem.clone then return elem:clone() end
            return Pandoc(elem.blocks:clone(), elem.meta:clone())
        end
    )
end

--- Get the type of a Pandoc AST element.
--
-- @tparam pandoc.AstElement elem A Pandoc AST element.
-- @treturn[1] string A type (e.g., 'MetaMap', 'Plain').
-- @treturn[1] string A super-type (e.g., 'Block' or 'MetaValue').
-- @treturn[1] string 'AstElement'.
-- @treturn[2] nil `nil` if the given value is not a Pandoc AST element.
-- @treturn[2] string An error message.
--
-- @function elem_type
-- @fixme It's unclear whether this code ignores pandoc.Doc
--        in favour of pandoc.Pandoc (as it should) in Pandoc <v2.15/2.14.
if not pandoc.types or PANDOC_VERSION < {2, 15} then
    local super = {}

    for k, v in sorted(pandoc) do
        if type(v) == 'table' and not super[v] and k ~= 'Doc' then
            local t = Values()
            t:add(k)
            local mt = getmetatable(v)
            while mt and t.n < 16 do
                if not mt.name or mt.name == 'Type' then break end
                t:add(mt.name)
                mt = getmetatable(mt)
            end
            if t[t.n] == 'AstElement' then super[v] = t end
        end
    end

    function elem_type (elem)
        if type(elem) == 'table' then
            local mt = getmetatable(elem)
            if mt and mt.__type then
                local ets = super[mt.__type]
                if ets then return unpack(ets) end
            end
        end
        return nil, 'not a Pandoc AST element.'
    end
else
    local super = {
        Pandoc = 'AstElement',
        Meta = 'AstElement',
        MetaValue = 'AstElement',
        MetaBlocks = 'MetaValue',
        MetaBool = 'MetaValue',
        MetaInlines = 'MetaValue',
        MetaList = 'MetaValue',
        MetaMap = 'MetaValue',
        MetaString = 'MetaValue',
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

    function elem_type (elem)
        local t = type(elem)
        if t == 'table' or t == 'userdata' then
            local et = elem.tag
            -- There is no better way.
            if  not et          and
                elem.meta       and
                elem.blocks     and
                t == 'userdata'
            then
                et = 'Pandoc'
            end
            local ets = Values()
            while et do
                ets:add(et)
                et = super[et]
            end
            if ets.n > 0 then return unpack(ets) end
        end
        return nil, 'not a Pandoc AST element.'
    end
end

do
    -- Walk a Lua table.
    local function walk_table (tab, ...)
        for k, v in pairs(tab) do tab[k] = elem_walk(v, ...) end
    end

    --- Walk a *List AST element (e.g., `pandoc.OrderedList`).
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
        Pandoc = walk_doc
    }

    --- Walk an AST and apply a filter to matching elements.
    --
    -- Differs from `pandoc.walk_block` and `pandoc.walk_inline` by:
    --
    --  * accepting AST elements of any type (inluding documents and metadata),
    --  * walking the AST bottom-up and
    --    applying the filter to the given element itself,
    --  * allowing functions in the filter to return data of arbitrary types,
    --  * never modifying the original element, and
    --  * accepting 'AstElement' as filter keyword,
    --    but not 'Blocks' or 'Inlines'.
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @tparam {string=func,...} filter A filter.
    -- @return Typically but not necessarily, a new Pandoc AST element.
    --
    -- @todo Try to make the filter more similar to Pandoc's walkers,
    --  so that some of the documentation can be removed.
    -- @function elem_walk
    elem_walk = typed_args('*', 'table', '?number')(
        function (elem, filter, _rd)
            if not _rd then _rd = 0 end
            assert(_rd < 128, 'recursion limit exceeded.')
            local ets = {elem_type(elem)}
            local et = ets[1]
            if not et then return elem end
            elem = elem_clone(elem)
            _rd = _rd + 1
            local walker = walkers[et]
            if     walker       then walker(elem, filter, _rd)
            elseif elem.content then walk_table(elem.content, filter, _rd)
            end
            for i = 1, #ets do
                local func = filter[ets[i]]
                if func then
                    local new = func(elem)
                    if new ~= nil then elem = new end
                end
            end
            return elem
        end
    )
end

--- Collect bibliographic data.
--
-- Reads the `references` metadata field and every bibliography file.
--
-- @side May print error messages to STDERR.
--
-- @tparam pandoc.MetaMap meta A metadata block.
-- @treturn pandoc.List CSL items.
--
-- @function meta_sources
meta_sources = typed_args('table|userdata')(
    function (meta)
        local data = List()
        if not meta then return data end
        if meta.references then data:extend(meta.references) end
        if meta.bibliography then
            local fnames
            local bibliography = meta.bibliography
            if bibliography.tag == 'MetaInlines' then
                fnames = {stringify(bibliography)}
            elseif bibliography.tag == 'MetaList' then
                fnames = bibliography:map(stringify)
            else
                xwarn('@error', 'cannot parse metadata field "bibliography".')
                return data
            end
            for i = 1, #fnames do
                -- luacheck: no redefined
                local fname, err = file_locate(fnames[i])
                if fname then
                    local items, err = biblio:read(fname)
                    if items then data:extend(items)
                             else xwarn('@error', '@plain', err)
                    end
                else
                    xwarn('@error', '@plain', err)
                end
            end
        end
        return data
    end
)

do
    -- Save citation keys that are *not* members of one set into another one.
    --
    -- @tparam pandoc.Cite A citation.
    -- @tparam {string=boolean,...} old
    --  A [set](https://www.lua.org/pil/11.5.html) of
    --  IDs that should be ignored.
    -- @treturn {string=boolean,...} new The set to save the IDs in.
    local function ids (cite, old, new)
        local citations = cite.citations
        for i = 1, #citations do
            local id = citations[i].id
            if id and not old[id] then new[id] = true end
        end
    end

    --- Collect the citation keys used in a document.
    --
    -- @side May print error messages to STDERR.
    --
    -- @tparam pandoc.Pandoc doc A document.
    -- @bool[opt] undef Collect only undefind citation keys?
    -- @treturn {string,...} Citation keys.
    -- @treturn int The number of citation keys found.
    --
    -- @function doc_ckeys
    doc_ckeys = typed_args('table|userdata', '?boolean')(
        function (doc, undef)
            local meta = doc.meta
            local blocks = doc.blocks
            local old = {}
            local new = {}
            if undef then old = csl_items_ids(meta_sources(meta)) end
            local flt = {Cite = function (cite) return ids(cite, old, new) end}
            if meta then
                for k, v in pairs(meta) do
                    if k ~= 'references' then elem_walk(v, flt) end
                end
            end
            for i = 1, #blocks do pandoc.walk_block(blocks[i], flt) end
            return keys(new)
        end
    )
end


------------------------
-- Configuration parsing
-- @section

--- A configuration setting.
--
-- @see Setting:new
-- @object Setting
-- @proto @{Object}
Setting = Object()

do
    -- A mapping of configuration value types to parers.
    local converters = {}

    -- Convert a configuration value to a type.
    --
    -- @param val A value.
    -- @string type A type declaration. See @{Setting:new} for the grammar.
    -- @return[1] A value of the given type.
    -- @treturn[2] nil `nil` if the value cannot be converted.
    -- @treturn[2] string An error message.
    -- @raise An error if a type declaration cannot be parsed.
    local function convert (val, decl)
        local head, tail = decl:match '^%s*(%l+)%s*<?%s*([%l<>%s]-)%s*>?%s*$'
        if not head then error(format('cannot parse type "%s".', decl), 3) end
        local conv = converters[head]
        if not conv then error(head .. ': no such type.', 3) end
        return conv(val, tail or 'string')
    end

    -- Convert a value to a Lua string.
    --
    -- @param val A value.
    -- @treturn[1] string A string.
    -- @treturn[2] nil `nil` if the value cannot be converted to a string.
    -- @treturn[2] string An error message.
    -- @fixme Test if we cannot let stringify do all of the work.
    function converters.string (val)
        local t = type(val)
        if t == 'string' then
            return val
        elseif t == 'number' then
            return tostring(val)
        elseif elem_type(val) then
            local ok, str = pcall(stringify, val)
            if ok and str ~= '' then return str end
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
        local ok = true
        if elem_type(val) then ok, val = pcall(stringify, val) end
        if ok then
            local num = tonumber(val)
            if num then return num end
        end
        return nil, 'not a number.'
    end

    -- Convert values to lists.
    --
    -- Tables are passed through as is.
    --
    -- @param val A value or list of values.
    -- @treturn pandoc.List A list of values.
    function converters.list (val, decl)
        if decl == '' then decl = 'string' end
        local function conv (v) return convert(v, decl) end
        -- @fixme and not elem_type is to deal with Pandoc <v2.14?
        -- @this is only needed for some versions, not all < something.
        -- 2.14? 2.15? check!
        local et = elem_type(val)
        if
            type(val) == 'table' and
            not et               or
            et == 'MetaMap'      or
            et == 'MetaList'
        then return List(val):map(conv) end
        return List{conv(val)}
    end

    --- Create a new setting.
    --
    -- <h3>Mapping of setting names to metadata fieldnames:</h3>
    --
    -- Every setting has a name. The metadata fieldname that is looked up by
    -- @{Setting:get} is that name with underscores replaced by dashes.
    --
    -- Settings may have prefixes. If so, the setting name is prefixed with
    -- that prefix *and* '-' before being translated into a fieldname. In Lua:
    --
    --    if prefix and prefix ~= '' then name = prefix .. '-' .. name end
    --    fieldname = name:gsub('_', '-')
    --
    -- <h3>Type declaration grammar:</h3>
    --
    -- Configuration values can be of one of three types: 'number', 'string',
    -- or 'list'.
    --
    -- The scalar types 'number' and 'string' declare that a value must be of
    -- (and should be coerced to) the Lua type of the same name.
    --
    -- The type 'list' declares that a value must be a `pandoc.List`. All
    -- items in a list must be of the same type, which you declare by
    -- appending '<*T*>' to a 'list', where *T* is either the name of a
    -- scalar type or 'list<...>'. If you do not declare that type, it
    -- defaults to 'string'. If a scalar value is encountered, but a list
    -- is expected, the scalar value is put into a single-item list.
    --
    -- Prefix a type with '?' to declare that a setting is optional.
    --
    -- Whitespace is ignored.
    --
    -- In [Extended Backus-Naur Form](https://en.wikipedia.org/wiki/EBNF):
    --
    -- > Whitespace = ' ' | TAB | CR | LF
    -- >
    -- > Simple type = 'number' | 'string'
    -- >
    -- > List = 'list', {whitespace},
    -- >        ['<', {whitespace}, (simple type | list), {whitespace}, ['>'] ]
    -- >
    -- > Type declaration = {whitespace},
    -- >                    ['?'], {whitespace},
    -- >                    (simple type | list), {whitespace}
    --
    -- <h3>Check protocol:</h3>
    --
    -- You can give a function that checks whether a setting's value is
    -- valid. That function is run after the value has been coerced to the
    -- requested type. It must return `true` if the value is valid and `nil`
    -- and an error message otherwise.
    --
    -- @string name A name.
    -- @string[opt='?string'] type A type to coerce the setting's value to.
    -- @func[opt] check A function that checks the setting's value.
    -- @string[opt] prefix A prefix.
    --
    -- @usage
    -- setting = Setting:new{
    --     name = 'bar',
    --     type = '?number',
    --     check = function (x)
    --         if x > 0 return true end
    --         return nil, 'not a positive number.'
    --     end
    -- }
    --
    -- @see Setting:get
    -- @const Setting:new
    Setting.new = typed_keyword_args{
        name = 'string',
        type = '?string',
        check = '?function',
        prefix = '?string',
    }(
        function (proto, args)
            for _, key in pairs{'name', 'prefix', 'type'} do
                local val = args[key]
                if val and val == '' then
                    error(format('%s: is the empty string.', key), 2)
                end
            end
            if args.type then
                args.optional, args.type = args.type:match '(%??)(.*)'
                -- Raise an error if the type declaration is wrong.
                local cycle = {}
                cycle[1] = cycle
                convert(cycle, args.type)
            else
                args.optional = true
                args.type = 'string'
            end
            return proto(args)
        end
    )

    --- Get a setting's value from a metadata block.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @return[1] The value of the setting.
    -- @treturn[2] nil `nil` if the settings was not given.
    -- @raise An error if the setting is missing,
    --  of the wrong type, or invalid.
    --
    -- @usage
    -- > setting = Setting:new{
    -- >    prefix = 'foo',
    -- >    name = 'bar',
    -- >    type = 'number'
    -- > }
    -- > meta = pandoc.MetaMap{
    -- >   ['foo-bar'] = pandoc.MetaInlines(pandoc.List{
    -- >           pandoc.Str "0123"
    -- >   })
    -- > bar = setting:get(meta)
    -- > bar
    -- 123
    -- > type(bar)
    -- number
    --
    -- @see Setting:new
    -- @function Setting:get
    Setting.get = typed_args('table', 'table')(
        function (self, meta)
            local name = self.name
            if self.prefix then name = self.prefix .. '-' .. name end
            local key = name:gsub('_', '-')
            local val = meta[key]
            local err
            if val ~= nil then
                val, err = convert(val, self.type)
                if val then
                    if not self.check then return val end
                    local ok
                    ok, err = self.check(val)
                    if ok then return val end
                end
            elseif self.optional then
                return
            else
                err = 'not set, but required'
            end
            error(format('metadata field "%s": ' .. err, key), 0)
        end
    )
end

--- A configuration parser.
--
-- @see Settings:add
-- @see Settings:parse
-- @object Settings
-- @proto @{Object}
Settings = Object()

--- Add settings to the parser.
--
-- @tparam Setting ... Settings.
-- @see Settings:parse
--
-- @usage
-- settings = Settings()
-- settings:add(Setting:new{
--     name = 'bar',
--     type = '?number',
--     check = function (x)
--         if x > 0 return true end
--         return nil, 'not a positive number.'
--     end
-- })
--
-- @function Settings:add
Settings.add = typed_args('table', '...')(
    function (self, ...)
        local settings = pack(...)
        for i = 1, settings.n do
            local setting = settings[i]
            local name = setting.name
            if self[name] then
                error(format('setting name "%s" is already in use.', name), 2)
            end
            self[name] = setting
        end
    end
)

--- Get configuration settings from a metadata block.
--
-- @tparam pandoc.MetaMap meta A metadata block.
-- @treturn tab A mapping of setting names to values.
--
-- @usage
-- > settings = Settings()
-- > settings:add(Setting:new{
-- >     name = 'bar',
-- >     type = '?number',
-- >     check = function (x)
-- >         if x > 0 return true end
-- >         return nil, 'not a positive number.'
-- >     end
-- > })
-- > meta = pandoc.MetaMap{
-- >     ['foo-bar'] = pandoc.MetaInlines(pandoc.List{
-- >         pandoc.Str "0123"
-- >     })
-- > conf = settings:get(meta)
-- > conf.bar
-- 123
-- > type(conf.bar)
-- number
--
-- @see Settings:add
-- @function Settings:parse
Settings.parse = typed_args('table', 'table|userdata')(
    function (self, meta)
        local conf = {}
        if meta then
            for name, setting in pairs(self) do
                conf[name] = setting:get(meta)
            end
        end
        return conf
    end
)

--- A configuration setting prototype with the prefix 'zotero'.
--
-- @object ZotSetting
-- @proto Setting
ZotSetting = Setting()

--- Set to 'zotero'.
ZotSetting.prefix = 'zotero'


--------------------
-- Zotero connectors
-- @section

--- A case-insensitive namespace for connector prototypes.
connectors = setmetatable({}, ignore_case)

--- Interface to [zotxt](https://github.com/egh/zotxt).
--
-- @usage
-- handle = connectors.Zotxt()
-- item = handle:fetch 'DoeWord2020'
--
-- @object connectors.Zotxt
-- @proto @{Object}
connectors.Zotxt = Object()

--- Types of citation keys to expect.
connectors.Zotxt.citekey_types = List{
    'betterbibtexkey',  -- Better BibTeX citation key
    'easykey',          -- zotxt easy citekey
    'key',              -- Zotero item ID
}

--- Settings of the connector.
--
-- Defines `zotero-citekey-types`.
-- See the manual for details.
--
-- @object connectors.Zotxt.settings
-- @proto @{Settings}
connectors.Zotxt.settings = Settings()
connectors.Zotxt.settings:add(ZotSetting:new{
    name = 'citekey_types',
    type = '?list',
    check = function (tab)
        for i = 1, #tab do
            if not connectors.Zotxt.citekey_types:includes(tab[i]) then
                return nil, tab[i] .. ': not a citation key type.'
            end
        end
        return true
    end
})

do
    -- URL of the endpoint to look up items at.
    local items_url = 'http://localhost:23119/zotxt/items'

    --- Fetch a CSL item via zotxt.
    --
    -- @string ckey A citation key (e.g., `'doe:2020word'`, `'DoeWord2020'`).
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See @{http_get}.
    --
    -- @function connectors.Zotxt:fetch
    connectors.Zotxt.fetch = typed_args('table', 'string')(
        function (self, ckey)
            local ckey_types = self.citekey_types
            local err = nil
            for i = 1, #ckey_types do
                -- zotxt supports searching for multiple citation keys at once,
                -- but if a single one cannot be found, it replies with a
                -- cryptic error message (for Easy Citekeys) or an empty
                -- response (for Better BibTeX citation keys).
                local ok, mt, str = pcall(url_query, items_url,
                                          {[ckey_types[i]] = ckey})
                if not ok then
                    error('failed to connect to Zotero desktop client.', 0)
                end
                if not mt or mt == '' then
                    err = ckey .. ': response has no MIME type.'
                elseif not str or str == '' then
                    err = ckey .. ': response is empty.'
                elseif not mt:match '^text/plain%f[%A]' then
                    err = format('%s: response is of wrong MIME type %s.',
                                 ckey, mt)
                elseif not mt:match ';%s*charset="?[Uu][Tt][Ff]%-?8"?%s*$' then
                    err = ckey .. ': response is not encoded in UTF-8.'
                else
                    local data = csl_json_to_items(str)
                    if data then
                        local n = #data
                        if n == 1 then
                            if i ~= 1 then
                                ckey_types[1], ckey_types[i] =
                                ckey_types[i], ckey_types[1]
                            end
                            local item = data[1]
                            item.id = ckey
                            return item
                        end
                        if n == 0 then err = ckey .. ': no matches.'
                                  else err = ckey .. ': too many matches.'
                        end
                    else
                        err = ckey .. ': got unparsable response: ' .. str
                    end
                end
            end
            return nil, err
        end
    )
end

--- Configure the connector.
--
-- @tparam pandoc.MetaMap meta A metadata block.
-- @treturn[1] bool `true` if the connector was configured.
-- @treturn[2] nil `nil` if a configuration setting is missing.
-- @treturn[2] string An error message.
-- @raise An error if the configuration cannot be parsed.
--
-- @function connectors.Zotxt:configure
-- @see connectors.Zotxt.settings
connectors.Zotxt.configure = typed_args('table', 'table|userdata')(
    function (self, meta)
        for k, v in pairs(self.settings:parse(meta)) do self[k] = v end
        return true
    end
)

--- Interface to [Zotero's Web API](https://www.zotero.org/support/dev/web_api)
--
-- @string[opt] api_key A Zotero Web API key.
-- @number[opt] user_id A Zotero user ID.
-- @tparam[opt] {number,...} groups Zotero groups to search in.
-- @tparam[opt] {number,...} public_groups Public Zotero groups to search in.
--
-- @usage
-- handle = connectors.ZotWeb{api_key = 'lettersandnumbers'}
-- item = handle:fetch 'DoeWord2020'
--
-- @object connectors.ZotWeb
-- @proto @{connectors.Zotxt}
connectors.ZotWeb = connectors.Zotxt()

--- Types of citation keys to expect.
--
-- See @{citekey:guess_terms} for caveats.
connectors.ZotWeb.citekey_types = List {
    'key',              -- Zotero item IDs
    'easykey',          -- zotxt Easy Citekey
    'betterbibtexkey',  -- Better BibTeX citation key
}

--- Zotero Web API settings.
--
-- Defines:
--
--  * `zotero-api-key`
--  * `zotero-user-id`
--  * `zotero-groups`
--  * `zotero-public-groups`
--
-- See the manual for details.
--
-- @object connectors.ZotWeb.settings
-- @proto Copy of @{connectors.Zotxt.settings}.
connectors.ZotWeb.settings = copy(connectors.Zotxt.settings)

do
    local settings = connectors.ZotWeb.settings
    settings:add(
        ZotSetting:new{name = 'api_key'},
        ZotSetting:new{name = 'user_id', type = '?number'},
        ZotSetting:new{name = 'groups', type = '?list<number>'},
        ZotSetting:new{name = 'public_groups', type = '?list<number>'}
    )
end

do
    -- Shorthands.
    local len = utf8.len
    local decode = json.decode

    -- Zotero Web API base URL.
    local base_url = 'https://api.zotero.org'

    -- URL template for user ID lookups.
    local user_id_url = base_url .. '/keys/${api_key}'

    -- URL template for group membership lookups.
    local groups_url = base_url .. '/users/${user_id}/groups'

    -- User prefix.
    local user_prefix = '/users/${user_id}'

    -- Group prefix.
    local group_prefix = '/groups/${group_id}'

    -- URL template for item lookups.
    local items_url = base_url .. '${prefix}/items/${id}'

    --- Retrieve and parse data from the Zotero Web API.
    --
    -- @string url An endpoint URL.
    -- @tparam {string=string,...} params A mapping of request parameter
    --  names to values (e.g., `{v = 3, api_key = 'lettersandnumbers'}`).
    -- @return[1] The response of the Zotero Web API.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `http_get`.
    local function zotero_query (url, params)
        local ok, mt, str = pcall(url_query, url, params)
        if not ok then error('failed to connect to Zotero Web API.', 0) end
        if not mt or mt == '' then
            return nil, 'response has no MIME type.'
        elseif not str or str == '' then
            return nil, 'response is empty.'
        elseif mt:match '%f[%a]json%f[%A]' then
            return str
        elseif not mt:match '^text/' then
            return nil, format('response is of wrong MIME type %s.', mt)
        elseif not mt:match ';%s*charset="?[Uu][Tt][Ff]%-?8"?%s*$' then
            return nil, 'response is not encoded in UTF-8.'
        end
        return nil, 'got error: ' .. str
    end

    --- Check if a string is a Zotero item ID.
    --
    -- @string str A string.
    -- @treturn[1] bool `true` if the string is a Zotero item ID.
    -- @treturn[2] nil `nil` Otherwise.
    -- @treturn[2] string An error message.
    local function zotero_is_id (str)
        if len(str) == 8 and str:match '^[%u%d]+$' then return true end
        if str == '' then return nil, 'item ID is the empty string.' end
        return nil, str .. ': not an item ID.'
    end

    --- Metatable for Zotero Web API connectors.
    connectors.ZotWeb.mt = getmetatable(connectors.ZotWeb)

    --- Delegate to the Zotero Web API interface.
    --
    -- @see delegate_with_getters
    -- @function connectors.ZotWeb.mt.__call
    connectors.ZotWeb.mt.__call = delegate_with_getters

    --- Getters for Zotero Web API connectors.
    --
    -- @see getterify
    connectors.ZotWeb.mt.getters = {}

    --- Get the user ID for the given API key.
    --
    -- @tparam connectors.ZotWeb obj A Zotero Web API handle.
    -- @treturn string A Zotero user ID.
    -- @raise An error if:
    --
    --  * the `api_key` field is not set,
    --  * the Zotero Web API could not be reached
    --    (see @{http_get} for details),
    --  * the API's response cannot be parsed,
    --  * no user ID could be found for the given Zotero API key.
    --
    -- @function connectors.ZotWeb.mt.getters.user_id
    connectors.ZotWeb.mt.getters.user_id = typed_args('table')(
        function (obj)
            assert(obj.api_key, 'no Zotero API key given.')
            local ep = vars_sub(user_id_url, obj)
            local str, err = zotero_query(ep, {v = 3})
            if str then
                local ok, data = pcall(decode, str)
                if not ok then
                    err = 'cannot parse response: ' .. str
                else
                    local user_id = data.userID
                    if not user_id then
                        err = format('no user for API key %s.', obj.api_key)
                    else
                        obj.user_id = user_id
                        return user_id
                    end
                end
            end
            error('Zotero user ID lookup: ' .. err, 0)
        end
    )

    --- Get the IDs of the groups the current user is a member of.
    --
    -- @tparam connectors.ZotWeb obj A Zotero Web API handle.
    -- @treturn {string,...} Zotero group IDs.
    -- @raise An error if:
    --
    --  * the `api_key` field is not set,
    --  * the Zotero Web API could not be reached
    --    (see @{http_get} for details),
    --  * the API's response cannot be parsed.
    --
    -- @function connectors.ZotWeb.mt.getters.groups
    connectors.ZotWeb.mt.getters.groups = typed_args('table')(
        function (obj)
            assert(obj.api_key, 'no Zotero API key given.')
            local ep = vars_sub(groups_url, obj)
            local str, err = zotero_query(ep, {v = 3, key = obj.api_key})
            if str then
                local ok, data = pcall(decode, str)
                if not ok then
                    err = 'cannot parse response: ' .. str
                else
                    local groups = Values()
                    for i = 1, #data do
                        if data[i] and data[i].data and data[i].data.id then
                            groups:add(data[i].data.id)
                        end
                    end
                    obj.groups = groups
                    return groups
                end
            end
            error('Zotero groups lookup: ' .. err, 0)
        end
    )

    --- Iterate over item endpoint URLs.
    --
    -- @string[opt] id A Zotero item ID.
    -- @treturn func A *stateful* iterator.
    --
    -- @function connectors.ZotWeb:endpoints
    connectors.ZotWeb.endpoints = typed_args('table', '?string')(
        function (self, id)
            if id then assert(zotero_is_id(id))
                  else id = ''
            end
            local groups, ngroups
            local i = -1
            return function ()
                i = i + 1
                if i == 0 then
                    if self.api_key then
                        return vars_sub(items_url, {
                            prefix = user_prefix,
                            user_id = self.user_id,
                            id = id
                        })
                    end
                else
                    if not groups then
                        groups = List()
                        if self.api_key then
                            groups:extend(self.groups)
                        end
                        if self.public_groups then
                            groups:extend(self.public_groups)
                        end
                        ngroups = #groups
                    end
                    if i > ngroups then return end
                    return vars_sub(items_url, {
                        prefix = group_prefix,
                        group_id = groups[i],
                        id = id
                    })
                end
            end
        end
    )

    --- Search items by their author, publication year, and title.
    --
    -- @caveats Does *not* correct Zotero's CSL JSON export.
    --
    -- @string ... Search terms.
    -- @treturn[1] tab CSL items that match the given search terms.
    -- @treturn[2] nil `nil` if no items were found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] An error message.
    -- @raise See @{connectors.ZotWeb.mt.getters.user_id} and
    --  @{connectors.ZotWeb.mt.getters.groups}.
    --
    -- @function connectors.ZotWeb:search
    connectors.ZotWeb.search = typed_args('table', 'string', '?string', '...')(
        function (self, ...)
            local q = concat({...}, '+')
            local params = {v = 3, key = self.api_key,
                            q = q, qmode = 'titleCreatorYear',
                            format ='csljson', itemType='-attachment'}
            for ep in self:endpoints() do
                -- luacheck: ignore err
                local str, err = zotero_query(ep, params)
                if not str then return nil, err end
                local data, err = csl_json_to_items(str)
                if not data then return nil, err end
                local items = data.items
                if items and #items > 0 then return items end
            end
            return nil, 'no matches.'
        end
    )

    --- Look up a CSL item by its Zotero ID.
    --
    -- @string id A Zotero item ID.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if no or more than one item has been found.
    -- @treturn[2] string An error message.
    -- @raise See @{connectors.ZotWeb.mt.getters.user_id} and
    --  @{connectors.ZotWeb.mt.getters.groups}.
    --
    -- @function connectors.ZotWeb:lookup
    connectors.ZotWeb.lookup = typed_args('table', 'string')(
        function (self, id)
            assert(zotero_is_id(id))
            local params = {v = 3, key = self.api_key,
                            format ='csljson', itemType='-attachment'}
            for ep in self:endpoints(id) do
                local str = zotero_query(ep, params)
                if str then
                    local data, err = csl_json_to_items(str)
                    if not data then return nil, err end
                    local items = data.items
                    if items then
                        local n = #items
                        if n == 1 then
                            local item = items[1]
                            item.id = id
                            return csl_item_add_extras(item)
                        elseif n > 1 then
                            return nil, format('item ID %s: not unique.', id)
                        end
                    end
                end
            end
            return nil, 'no matches.'
        end
    )

    --- Fetch a CSL item from Zotero.
    --
    -- @side
    --
    -- Search terms for citation keys are printed to STDERR
    -- if the user has requested verbose output.
    --
    -- @string ckey A citation key (e.g., `'doe:2020word'`, `'DoeWord2020'`).
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See @{connectors.ZotWeb.mt.getters.user_id} and
    --  @{connectors.ZotWeb.mt.getters.groups}.
    --
    -- @function connectors.ZotWeb:fetch
    connectors.ZotWeb.fetch = typed_args('table', 'string')(
        function (self, ckey)
            -- luacheck: ignore err
            assert(ckey ~= '', 'citation key is the empty string.')
            if self.citekey_types:includes 'key' and zotero_is_id(ckey) then
                return self:lookup(ckey)
            end
            local terms, err = citekey:guess_terms(ckey, self.citekey_types)
            if not terms then return nil, err end
            xwarn('@info', '${ckey}: searching for: ',
                  '@plain', concat(terms, ', '))
            local items, err = self:search(unpack(terms))
            if not items then return nil, ckey .. ': ' .. err end
            local n = #items
            if n == 0 then
                return nil, ckey .. ': no matches.'
            elseif n > 1 then
                items = csl_items_filter_by_ckey(items, ckey)
                if not items or items.n == 0 then
                    return nil, ckey .. ': too many matches.'
                elseif items.n > 1 then
                    return nil, format('citation key %s: not unique.', ckey)
                end
            end
            local item = items[1]
            item.id = ckey
            return csl_item_add_extras(item)
        end
    )

    --- Configure the connector.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @treturn[1] bool `true` if the connector was configured.
    -- @treturn[2] nil `nil` if a configuration setting is missing.
    -- @treturn[2] string An error message.
    -- @raise An error if the configuration cannot be parsed.
    --
    -- @function connectors.ZotWeb:configure
    connectors.ZotWeb.configure = typed_args('table', 'table|userdata')(
        function (self, meta)
            local ok, err = connectors.Zotxt.configure(self, meta)
            if not ok then return nil, err end
            if not (self.api_key or self.public_groups) then
                return nil, 'neither Zotero API key nor public groups given.'
            end
            return true
        end
    )
end


-------
-- Main
--
-- @section

--- Add data to a bibliography file and the file to the document's metadata.
--
-- Updates the bibliography file as needed and adds its to the `bibliography`
-- metadata field. Interpretes relative filenames as relative to the directory
-- of the first input file passed to **pandoc**, or, if no input files were
-- given, as relative to the current working directory.
--
-- @caveats @{file_write}.
-- @side May print error messages to STDERR.
--
-- @string fname A filename for the bibliography file.
-- @tparam connectors.Zotxt|connectors.ZotWeb handle An interface to Zotero.
-- @tparam pandoc.Pandoc doc A Pandoc document.
-- @treturn[1] pandoc.Meta An updated metadata block.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See @{connectors.Zotxt} and @{connectors.ZotWeb}.
--
-- @function add_biblio
add_biblio = typed_args('string', 'table', 'table|userdata')(
    function (fname, handle, doc)
        local ckeys = doc_ckeys(doc, true)
        if #ckeys == 0 then return end
        local meta = doc.meta
        if not path_is_abs(fname) then fname = path_join(wd(), fname) end
        local ok, err = biblio:update(handle, fname, ckeys)
        if not ok then return nil, err end
        if not meta.bibliography then
            meta.bibliography = fname
        elseif meta.bibliography.tag == 'MetaInlines' then
            meta.bibliography = List{fname, meta.bibliography}
        elseif meta.bibliography.tag == 'MetaList'
            then meta.bibliography = List{unpack(meta.bibliography), fname}
        end
        return meta
    end
)

--- Add bibliographic data to the `references` metadata field.
--
-- @side May print error messages to STDERR.
--
-- @tparam connectors.Zotxt|connectors.ZotWeb handle An interface to Zotero.
-- @tparam pandoc.Pandoc doc A Pandoc document.
-- @treturn[1] table An updated metadata block.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See @{connectors.Zotxt} and @{connectors.ZotWeb}.
--
-- @function add_refs
add_refs = typed_args('table', 'table|userdata')(
    function (handle, doc)
        local ckeys = doc_ckeys(doc, true)
        local meta = doc.meta
        if #ckeys == 0 then return end
        if not meta.references then meta.references = MetaList({}) end
        local n = #meta.references
        for i = 1, #ckeys do
            local ok, ret, err = pcall(handle.fetch, handle, ckeys[i])
            if     not ok then return nil, tostring(ret)
            elseif ret    then n = n + 1
                               meta.references[n] = csl_item_to_meta(ret)
                          else xwarn('@error', '@plain', err)
            end
        end
        return meta
    end
)

do
    local settings = Settings()
    settings:add(
        ZotSetting:new{
            name = 'bibliography',
        },
        ZotSetting:new{
            name = 'connectors',
            type = '?list',
            check = function (names)
                for i = 1, #names do
                    local name = names[i]
                    if not name:match '^%a[%w_]+$' then
                        return nil, name .. ': not a connector name.'
                    end
                    local conn = connectors[name]
                    if not conn then
                        return nil, name .. ': no such connector.'
                    elseif not conn.fetch then
                        return nil, name .. ': connector violates protocol.'
                    end
                end
                return true
            end
        }
    )

    --- Collect citations and add bibliographic data to the document.
    --
    -- See the manual for details.
    --
    -- @side May print error messages to STDERR.
    --
    -- @tparam pandoc.Pandoc doc A document.
    -- @treturn[1] pandoc.Pandoc The document with bibliographic data added.
    -- @treturn[2] nil `nil` if nothing was done or an error occurred.
    -- @raise See @{connectors.Zotxt} and @{connectors.ZotWeb}.
    function main (doc)
        local conf = settings:parse(doc.meta)

        local handles = Values()
        local conns = conf.connectors
        if not conns then
            for _, conn in sorted(connectors, order{'zotxt'}) do
                local handle = conn()
                if not handle.configure or handle:configure(doc.meta) then
                    handles:add(handle)
                end
            end
        else
            for i = 1, #conns do
                local handle = connectors[conns[i]]()
                if handle.configure then assert(handle:configure(doc.meta)) end
                handles:add(handle)
            end
        end

        local add_sources
        if conf.bibliography then
            function add_sources (...)
                return add_biblio(conf.bibliography, ...)
            end
        else
            add_sources = add_refs
        end

        local chg = false
        for i = 1, handles.n do
            local meta, err = add_sources(handles[i], doc)
            if meta then
                doc.meta = meta
                chg = true
            elseif err then
                xwarn('@error', '@plain', err)
            end
        end
        if chg then return doc end
    end
end


-- Returning the whole script, rather than only a list of mappings of
-- Pandoc data types to functions, allows to do unit testing.

M[1] = {Pandoc = function (doc)
    if DEBUG then return main(doc) end
    local ok, ret = pcall(main, doc)
    if ok then return ret end
    xwarn('@error', '@plain', ret)
    os.exit(69, true)
end}

return M