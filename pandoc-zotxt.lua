---
-- SYNOPSIS
-- ========
--
-- **pandoc** **-L** *pandoc-zotxt.lua* **-C**
--
--
-- DESCRIPTION
-- ===========
--
-- **pandoc-zotxt.lua** is a Lua filter for Pandoc that looks up citations in
-- Zotero and adds their bibliographic data to a document's "references"
-- metadata field or to a bibliography file, where Pandoc can pick it up.
--
-- Cite your sources using so-called "Better BibTeX citation keys" (provided
-- by Better BibTeX for Zotero) or "Easy Citekeys" (provided by zotxt). Then
-- tell **pandoc** to filter your document through **pandoc-zotxt.lua** before
-- processing citations. That's all there is to it.
--
-- If the "references" metadata field or a bibliography file already contains
-- bibliographic data for a citation, that citation will be ignored.
--
--
-- CONNECTING TO ZOTERO
-- ====================
--
--
-- Desktop client
-- --------------
--
-- By default, bibliographic data is fetched from your Zotero desktop client.
-- You have to install the zotxt plugin for Zotero for this to work. Zotero
-- must be running when you invoke **pandoc**. This is the preferred way to
-- fetch data from Zotero.
--
--
-- Web API
-- -------
--
-- Bibliographic data can also be fetched from the Zotero Web API. If you want
-- to access your Zotero database via the Web API, create a Zotero API key and
-- set the metadata field "zotero-api-key" to that key.
--
-- If you want to fetch bibliographic data from *public* Zotero groups, set
-- the metadata field "zotero-public-groups" to the a list of the IDs of the
-- groups that you want to fetch data from. These groups need to allow
-- non-members to access their libraries. You do *not* need an API key to do
-- so.
--
-- The Zotero Web API does *not* allow to search for citation keys. Therefore,
-- citation keys have to be converted into search terms; Better BibTeX
-- citation keys are split up at the first of each series of digits and at
-- uppercase letters ("DoeTitle2020" becomes "Doe", "Title", "2020"), Easy
-- Citekeys are split up at the first colon and at the last digit
-- ("doe:2020title" becomes "doe", "2020", "title").
--
-- If a search yields more than one item, add the citation key to the item's
-- "extra" field in Zotero, using either the field name "Citation key" or
-- "Citekey"; e.g., "Citation key: DoeTitle2020". If you use BetterBibTeX for
-- Zotero, you can do so by 'pinning' the citation key.
--
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
-- The format of the file is determined by its filename ending:
--
-- | **Ending** | **Format** | **Feature**     |
-- | ---------- | ---------- | --------------- |
-- | `.json`    | CSL JSON   | More reliable.  |
-- | `.yaml`    | CSL YAML   | Easier to edit. |
--
--
-- The bibliography file is added to the "bibliography" metadata field
-- automatically. You can safely set "zotero-bibliography" and "bibliography"
-- at the same time.
--
-- **pandoc-zotxt.lua** only adds bibliographic records to that file; it does
-- *not* change, update, or delete them. If you need to update or delete
-- records, delete the file; **pandoc-zotxt.lua** will then regenerate it.
--
--
-- CITATION KEY TYPES
-- ==================
--
-- **pandoc-zotxt.lua** supports multiple types of citation keys, namely,
-- "Better BibTeX citation keys", "Easy Citekeys" and Zotero item IDs.
--
-- However, it may happen that a Better BibTeX citation key is interpreted as
-- an Easy Citekey *and* yet picks out an item, though not the one that it
-- actually is the citation key of. That is, citation keys may be matched with
-- the wrong bibliographic data.
--
-- If this happens, you can disable citation key types by setting the
-- "zotero-citekey-types" metadata field to the citation key type or to the
-- list of citation key types that you actually use.
--
-- You can set the following citation key types:
--
-- | **Key**           | **Type**                   |
-- | ----------------- | -------------------------- |
-- | `betterbibtexkey` | Better BibTeX citation key |
-- | `easykey`         | Easy Citekey               |
-- | `key`             | Zotero item ID             |
--
--
--
-- SETTINGS
-- ========
--
-- <h3>zotero-api-key</h3>
--
-- A Zotero API key. Has to be set to fetch data from the Zotero Web API.
--
-- <h3>zotero-bibliography</h3>
--
-- A filename. See **BIBLIOGRAPHY FILES** for details.
--
-- <h3>zotero-citekey-types</h3>
--
-- A list of citation key types. See **CITATION KEY TYPES** for details.
--
-- <h3>zotero-connectors</h3>
--
-- A list of one or more Zotero connectors:
--
-- | **Name** | **Connects to**       |
-- | -------- | --------------------- |
-- | Zotxt    | Zotero desktop client |
-- | ZotWeb   | Zotero Web API        |
--
--
-- By default, the Zotero desktop client is tried first. If there remain
-- citations in your document for which no bibliographic data has been found
-- *and* you have given a Zotero API key, the Zotero Web API is tried next.
--
-- <h3>zotero-groups</h3>
--
-- A list of Zotero group IDs. These groups are searched if no item is found
-- in your personal library. Use this to limit the scope of the search. By
-- default, all groups you are a member of are searched.
--
-- <h3>zotero-public-groups</h3>
--
-- A list of Zotero group IDs. See **Zotero Web API** above for details.
--
-- <h3>zotero-user-id</h3>
--
-- A Zotero user ID. Needed to fetch data from the Zotero Web API, but looked
-- up automatically if not given.
--
--
--
-- If a metadata field takes a list of values, but you only want to give a
-- single value, you can enter that value as a scalar.
--
--
-- EXAMPLES
-- ========
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     See @doe2020Title for details.
--     EOF
--
--
-- The above will look up "DoeTitle2020" in Zotero.
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-bibliography: bibliography.json
--     ...
--     See @DoeTitle2020 for details.
--     EOF
--
--
-- The above will look up "DoeTitle2020" in Zotero and save its bibliographic
-- data into the file "bibliography.json" in the current working directory. If
-- the same command is run again, "DoeTitle2020" will *not* be looked up again.
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-citekey-types: betterbibtexkey
--     ...
--     See @doe:2020Title for details.
--     EOF
--
--
-- The above forces **pandoc-zotxt.lua** to interpret "doe:2020Title" as a
-- Better BibTeX citation key.
--
--
-- KNOWN ISSUES
-- ============
--
--
-- Wrong matches
-- -------------
--
-- Citation keys may, on rare occassions, be matched with the wrong Zotero
-- item. This happens if a citation key picks out a different record depending
-- on whether it is interpreted as a Better BibTeX citation key or as an easy
-- citekey. See **CITATION KEY TYPES** above on how to fix this.
--
--
-- Temporary files
-- ---------------
--
-- **pandoc-zotxt.lua** creates a temporary file when it adds sources to a
-- bibliography file. If Pandoc exits because it catches a signal (e.g.,
-- because you press `Ctrl`-`c`), then this file will *not* be deleted. This
-- is a bug in Pandoc and in the process of being fixed. Moreover, if you are
-- using Pandoc up to v2.7, another process may, mistakenly, use the same
-- temporary file at the same time, though this is highly unlikely.
--
--
-- Zotero desktop client
-- ---------------------
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that do not set the "User Agent" HTTP header. And **pandoc** does not. As a
-- consequence, **pandoc-zotxt.lua** cannot retrieve data from these versions
-- of Zotero unless you tell **pandoc** to set that header.
--
--
-- Zotero Web API
-- --------------
--
-- Support for group libraries is limited. They are only searched if no item
-- in your personal library matches the search terms derived from the citation
-- key. Also, the "extra" field of items in group libraries is ignored.
--
--
-- SECURITY
-- ========
--
-- If you are using Pandoc up to v2.7 and place the auto-generated
-- bibliography file in a directory that other users have write access to,
-- then they can read and change the content of that file, regardless of
-- whether they have permission to read or write the file itself.
--
--
-- CAVEATS
-- =======
--
-- **pandoc-zotxt.lua** is Unicode-agnostic.
--
--
-- SEE ALSO
-- ========
--
-- * [zotxt](https://github.com/egh/zotxt)
-- * [Better BibTeX](https://retorque.re/zotero-better-bibtex/)
--
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

--- Debugging
-- @section

--- Base prototype
-- @section

--- Higher-order functions
-- @section

--- Errors.
--
-- Used for exceptions that may happen during normal
-- operation and be reported to the user.
--
-- @section

--- Tables
-- @section

--- Strings
-- @section

--- Citation keys
-- @section

--- CSL items.
--
-- [Appendix IV](https://docs.citationstyles.org/en/stable/specification.html#appendix-iv-variables)
-- of the Citation Style Language (CSL) specification lists all CSL
-- variable names.
--
-- @section

--- Markup converters
-- @section

--- Warnings
-- @section

--- File I/O
-- @section

--- Networking
-- @section

--- Bibliography files
-- @section

--- Configuration
-- @section

--- Zotero connectors
-- @section

--- Document parsing
-- @section

--- Main
-- @section

-- Initialisation
-----------------

-- luacheck: allow defined top

-- Built-in functions.
local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local pairs = pairs
local pcall = pcall
local rawget = rawget
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

-- luacheck: ignore _ENV
local M = {}
local _ENV = M

-- Shorthands.
local format = string.format
local concat = table.concat
local pack = table.pack
local unpack = table.unpack

local stringify = pandoc.utils.stringify

local List = pandoc.List
local MetaInlines = pandoc.MetaInlines
local MetaList = pandoc.MetaList
local MetaMap = pandoc.MetaMap
local Str = pandoc.Str
local Span = pandoc.Span
local Pandoc = pandoc.Pandoc


------------
-- Debugging
--
-- @section

--- Type-check function arguments.
--
-- A type specification can be:
--
--  - a Lua type (e.g., 'string')
--  - a list of Lua types separated by pipes (e.g., 'string|number').
--  - '*' to indicate that any type is valid.
--
-- Prefix the specification with '?' to indicate that an argument is optional.
--
-- @string ... Type specifications.
-- @treturn func A function that takes a function and adds type checks.
-- @usage
--      > func = typed('number', '?number')(
--      >     function (a, b)
--      >         if b then return a + b end
--      >     return a
--      >     end
--      > )
function typed (...)
    local exprs, specs
    exprs = pack(...)
    specs = {}
    for i = 1, exprs.n do
        local expr
        expr = exprs[i]
        if expr == '*' then
            specs[i] = {any = true}
        else
            local opt, types
            opt, types = expr:match '(%??)([%l|]+)'
            assert(opt and types, 'cannot parse type specification.')
            specs[i] = {opt = opt ~= '', types = {}}
            for t in types:gmatch '[^|]+' do
                assert(t ~= '', 'typename is the empty string.')
                specs[i].types[t] = true
            end
        end
    end
    return function (f)
        return function (...)
            local args
            args = {...}
            for i = 1, exprs.n do
                local spec, arg, t
                spec = specs[i]
                arg = args[i]
                t = type(arg)
                if  not spec.any                  and
                    not (spec.opt and arg == nil) and
                    not spec.types[t]
                then
                    error(string.format('expected a %s, got a %s.',
                          concat(spec.types, ' or ', t)), 2)
                end
            end
            return f(...)
        end
    end
end


-----------
-- File I/O
--
-- @section

--- The path segment seperator of your operating system.
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence of your operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end

--- Join multiple path segments.
--
-- @string ... Path segments.
-- @treturn string The complete path.
-- @raise An error if a path segment is the empty string.
-- @function path_join
path_join = typed('string')(
    function (seg, ...)
        assert(seg ~= '', 'path segment is the empty string.')
        if not ... then return seg end
        return path_sanitise(seg .. PATH_SEP .. path_join(...))
    end
)

do
    -- Patterns that sanitise directory paths.
    -- The order of these patterns is significant.
    local sanitisation_patterns = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'},
        -- Remove './' at the beginning of a path.
        {'^%.' .. PATH_SEP, ''}
    }

    --- Sanitise a path.
    --
    -- @string path The path.
    -- @treturn string A sanitised path.
    -- @raise An error if the path is the empty string.
    -- @function path_sanitise
    path_sanitise = typed('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            for i = 1, #sanitisation_patterns do
                local pattern, repl = unpack(sanitisation_patterns[i])
                path = path:gsub(pattern, repl)
            end
            return path
        end
    )
end

do
    -- Pattern to split a path into a directory and a filename part.
    local split_pattern = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'

    --- Split a path into a directory and a filename.
    --
    -- @string path The file's path.
    -- @treturn string The directory the file is in.
    -- @treturn string The file's name.
    -- @raise An error if the path is the empty string.
    -- @function path_split
    path_split = typed('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            local dir, fname = path:match(split_pattern)
            if     dir == ''   then dir = '.'
            elseif fname == '' then fname = '.' end
            return path_sanitise(dir), fname
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

    --- The directory the script is in.
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


-----------------
-- Base prototype
--
-- @section

--- Prototype for prototypes.
--
-- @proto Prototype
-- @usage
--      > ObjA = Prototype()
--      > mt = getmetatable(ObjA)
--      > function mt:__tostring ()
--      >     return 'text'
--      > end
--      > ObjA.key = 'value'
--      > ObjB = ObjA()
--      > ObjB.key
--      value
--      > -- `ObjB` can override properties.
--      > ObjB.key = 'another value'
--      > ObjC = ObjB()
--      > ObjC.key
--      another value
--      > -- A more consise way to define objects.
--      > ObjD = ObjC { key = 'yet another value' }
--      > ObjD.key
--      yet another value
--      > -- Metatables are copied, save for "__index".
--      > tostring(ObjD)
--      text
Prototype = {}

--- Metatable for prototypes.
Prototype.mt = {}
setmetatable(Prototype, Prototype.mt)

--- Delegate to a prototype.
--
-- Sets the table's metatable to a copy of the prototype's metatable
-- and then sets the metatable's `__index` field to the prototype.
--
-- @tab obj An Object.
-- @treturn tab A prototype.
function Prototype.mt:__call (obj)
    if not obj then obj = {} end
    local mt = {}
    for k, v in pairs(getmetatable(self)) do mt[k] = v end
    mt.__index = self
    return setmetatable(obj, mt)
end


-------------------------
-- Higher-order functions
--
-- @section

--- Run one function after another regardless of whether an errors occurs.
--
-- <h3>Caveats:</h3>
--
-- Lua filters cannot respond to signals. So the code is *not* run
-- if Pandoc exits because it catches a signal.
--
-- @func ex A cleanup function.
--  Passed the values the protected call to the other function returns.
-- @func func The actual function. Called in protected mode.
-- @param ... Passed to the function.
-- @return The values the function returns.
-- @function do_after
do_after = typed('function', 'function')(
    function (ex, func, ...)
        local vs = {pcall(func, ...)}
        ex(unpack(vs))
        local ok, err = unpack(vs, 1, 2)
        if not ok then error(err) end
        return unpack(vs, 2)
    end
)

--- Define a sorting function from a list of values.
--
-- @param ... Values.
-- @treturn func A sorting function.
-- @usage
--      > tab = {a = 3, b = 4, c = 2, d = 1}
--      > for k, v in sorted(tab, in_order{'d', 'c'}) do
--      >     print(k, v)
--      > end
--      d   1
--      c   2
--      a   3
--      b   4
function in_order (...)
    local order = {}
    local list = {...}
    for i = 1, #list do order[list[i]] = i end
    return function (a, b)
        local i, j = order[a], order[b]
        if i and j then return i < j end
        if i then return true end
        if j then return false end
        return a < b
    end
end

--- Get the variables that a function can access.
--
-- @int[opt=2] level A stack level, where
--  1 points to the current function (i.e., `vars`),
--  2 to that function's caller, and so on.
-- @treturn table A mapping of variable names to values.
-- @raise An error if there is no function at the given stack level.
function vars (level)
    if not level then level = 2 end
    assert(type(level) == 'number', 'level is not a number.')
    assert(level > 0, 'level is not a positive number.')
    local vars = {}

    for k, v in pairs(_ENV) do vars[k] = v end

    local info = debug.getinfo(level)
    if not info then return nil, tostring(level) .. ': no such function.' end
    local func = info.func
    local i = 1
    while true do
        local k, v = debug.getupvalue(func, i)
        if not k then break end
        vars[k] = v
        i = i + 1
    end

    i = 1
    while true do
        local k, v = debug.getlocal(level, i)
        if not k then break end
        vars[k] = v
        i = i + 1
    end

    return vars
end


---------
-- Errors
--
-- @section

--- Abstract prototype for errors.
--
-- @proto Error
-- @usage
--      ConnectionError = Error{template = 'failed to connect to $host.'}
--      error(ConnectionError{host = 'www.host.example'})
Error = Prototype()

--- Default template for error messages.
Error.template = 'something went wrong.'

--- Metatable for errors.
Error.mt = getmetatable(Error)

--- Get a message that describes the error.
--
-- If the message template contains variable names, they are replaced with the
-- values of the fields with those names. See @{expand_vars} for the syntax.
--
-- @treturn string The error message.
-- @usage
--      > err = Error {
--      >     template = 'Semething went $severity wrong.',
--      >     severity = 'terribly'
--      > }
--      > assert(false, err{severity = 'slightly'})
--      Something went slightly wrong.
function Error.mt:__tostring ()
    assert(self.template, 'error has no message template.')
    return expand_vars(self.template, self)
end

--- Prototype for configuration errors.
-- @fixme
ConfigError = Error()

--- Template for configuration error messages.
ConfigError.template = 'metadata field "$field": $error'

--- Stand-in value for the error description.
ConfigError.error = 'something went wrong.'

--- Prototype for connection errors.
--
-- @proto ConnectionError
-- @usage
--      > ok, mt, data = pcall(pandoc.mediabag.fetch, url)
--      > assert(ok, ConnectionError{host = url})
ConnectionError = Error()

--- Template for connection error messages.
ConnectionError.template = 'failed to connect to $host$.'

--- Stand-in value for the host.
ConnectionError.host = '<unspecified host>'

--- Prototype for Zotero Web API user ID lookup errors.
--
-- @proto UserIDLookupError
-- @usage
--      > ok, data = pcall(json.decode, str)
--      > assert(ok, UserIDLookupError{err = 'cannot parse: ' .. str})
UserIDLookupError = Error()

--- Template for user ID lookup errors.
UserIDLookupError.template = 'Zotero user ID lookup: $error'

--- Stand-in value for the error.
UserIDLookupError.error = 'something went wrong.'

--- Prototype for Zotero Web API group lookup errors.
--
-- @proto GroupLookupError
-- @usage
--      > ok, data = pcall(json.decode, str)
--      > assert(ok, GroupLookupError{err = 'cannot parse: ' .. str})
GroupLookupError = Error()

--- Message for group lookup errors.
GroupLookupError.template = 'Zotero group lookup: $error'

--- Stand-in value for the error.
GroupLookupError.error = 'something went wrong.'


---------
-- Tables
--
-- @section

--- A simple list.
--
-- @proto Values
-- @usage
--      > list = Values()
--      > list:add 'a string'
--      > list.n
--      1
Values = Prototype()

--- The number of items in the list.
Values.n = 0

--- Add items to the sequence.
--
-- <h3>Side-effects:</h3>
--
-- Sets @{Values.n} to the number of items in the table.
--
-- @param ... Items.
function Values:add (item, ...)
    local n = self.n + 1
    self[n] = item
    self.n = n
    if ... then self:add(...) end
end

--- Apply a function to each element in a multi-dimensional data structure.
--
-- Can handle recursive data structures.
--
-- @func func A function that transforms a value.
--  An item is only changed if this function does *not* return `nil`.
-- @param data Data.
-- @return Transformed data.
-- @function apply
apply = typed('function', '*', '?table')(
    function (func, data, _s)
        if type(data) ~= 'table' then
            local ret = func(data)
            if ret == nil then return data end
            return ret
        end
        if     not _s   then _s = {}
        elseif _s[data] then return _s[data]
        end
        local ret = {}
        _s[data] = ret
        local k
        while true do
            k = next(data, k)
            if k == nil then break end
            local v = data[k]
            if type(v) == 'table' then v = apply(func, v, _s) end
            local nv = func(v)
            if nv == nil then ret[k] = v
                         else ret[k] = nv
            end
        end
        return ret
    end
)

--- Copy a multi-dimensional data structure.
--
-- Can handle metatables, recursive structures, tables as keys,
-- and avoids the `__pairs` and `__newindex` metamethods.
-- Copies are deep.
--
-- @param data Data.
-- @return A deep copy.
--
-- @usage
--      > x = {1, 2, 3}
--      > y = {x, 4}
--      > c = copy(y)
--      > table.insert(x, 4)
--      > table.unpack(c[1])
--      1       2       3
-- @function copy
copy = typed('*', '?table')(
    function (data, _s)
        -- Borrows from:
        -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
        -- * <http://lua-users.org/wiki/CopyTable>
        if type(data) ~= 'table' then return data end
        if     not _s   then _s = {}
        elseif _s[data] then return _s[data]
        end
        local ret = setmetatable({}, getmetatable(data))
        _s[data] = ret
        for k, v in next, data, nil do
            rawset(ret, copy(k, _s), copy(v, _s))
        end
        return ret
    end
)

--- Get the keys and the number of items in a table.
--
-- @tab tab A table.
-- @treturn tab The keys of the table.
-- @treturn int The number of items in the table.
-- @function keys
keys = typed('table')(
    function (tab)
        local ks = {}
        local n = 0
        local k
        while true do
            k = next(tab, k)
            if k == nil then break end
            n = n + 1
            ks[n] = k
        end
        return ks, n
    end
)

--- Iterate over the key-value pairs of a table in a given order.
--
-- @tab tab A table.
-- @func[opt] func A sorting function.
--  If no function is given, sorts lexically.
-- @treturn func A *stateful* iterator.
-- @usage
--      > for k, v in sorted{c = 3, b = 2, a = 1} do
--      >     print(k, v)
--      > end
--      a   1
--      b   2
--      c   3
-- @function sorted
sorted = typed('table', '?function')(
    function (tab, func)
        local ks = keys(tab)
        table.sort(ks, func)
        local n = 0
        local function iter ()
            n = n + 1
            local k = ks[n]
            if k == nil then return end
            local v = tab[k]
            if v == nil then return end
            return k, v
        end
        return iter, tab, nil
    end
)

--- Tabulate the values a stateful iterator returns.
--
-- @func iter A stateful iterator.
-- @treturn table The values returned by the iterator.
-- @usage
--      > str = 'key: value'
--      > k, v = tabulate(split(str, '%s*:%s*', 2))
--      > print(k, v)
--      key     value
-- @function tabulate
tabulate = typed('function')(
    function (iter)
        local tab = Values()
        while true do
            local v = iter()
            if v == nil then break end
            tab:add(v)
        end
        return unpack(tab)
    end
)


----------
-- Strings
--
-- @section

do
    -- Lookup a path in a namespace.
    --
    -- @tab ns A mapping of variable names to values.
    -- @string path A path. Seperate segments by dots.
    -- @return A value.
    local function lookup (ns, path)
        local v = ns
        for n in split(path, '%.') do
            if type(v) ~= 'table' then break end
            v = v[n]
        end
        return v
    end

    -- Expand a variable from a variable expression.
    --
    -- See @{expand_vars} for the expression syntax.
    --
    -- @int rd Current recursion depth.
    -- @tab ns A mapping of variable names to values.
    -- @string path The path of the variable to look up.
    -- @string pipe If the value of the variable should be passed on to a
    --  function, the literal `|`. Otherwise, the empty string.
    -- @string func If the value of the variable should be passed on to a
    --  function, the name of that function. Otherwise the empty string.
    -- @treturn string The value of the expression.
    -- @raise See `expand_vars`.
    local function eval (rd, ns, path, pipe, func)
        local v = lookup(ns, path)
        if func ~= '' then
            local f = lookup(ns, func)
            assert(f, func .. ': no such function.')
            v = f(v)
        end
        local s = tostring(v)
        assert(s, '$' .. path .. pipe .. func .. ': cannot coerce to string.')
        return expand_vars(s, ns, rd + 1)
    end

    --- Expand variables in strings.
    --
    -- If a word is preceded by a single '$' sign, that word is interpreted as
    -- a variable name, and the '$' sign and the word are replaced with the
    -- value of that variable.
    --
    --      > expand_vars(
    --      >     '$v1 is $v2.',
    --      >     {v1 = 'foo', v2 = 'bar'}
    --      > )
    --      foo is bar.
    --
    -- If a word is preceded by two or more '$' signs, it is *not* interpreted
    -- as a variable name and *not* replaced. If a magic character, that is,
    -- the pipe or the dot, are preceded by one or more '$' signs, they are
    -- interpreted as regular characters. Any series of *n* '$' signs is
    -- replaced with *n* -- 1 '$' signs.
    --
    --      > expand_vars(
    --      >   '$$v1 costs $$23 (and $- is just a dash).',
    --      >   {v1 = 'foo'}
    --      > )
    --      $v1 costs $23 (and - is just a dash).
    --
    -- If a variable expression is followed by a '|' character and another
    -- word, the second word is interpreted as a function name; the value of
    -- the given variable is then passed to that function, and the whole
    -- expression `$<variable>|<function>` is replaced with the first value
    -- that this function returns.
    --
    --      > expand_vars(
    --      >   '$v1|barify is bar!', {
    --      >       v1 = 'foo',
    --      >       barify = function (s)
    --      >           return s:gsub('foo', 'bar')
    --      >       end
    --      >   }
    --      > )
    --      bar is bar!
    --
    -- You can lookup values in tables by joining the name of the variable
    -- and that of the table field with a dot. If your string ends with a
    -- variable expression that is followed by a full stop, you need to
    -- escape the full stop using '$'.
    --
    --      > expand_vars(
    --      >   '$var.field is bar.', {
    --      >       var = { field = 'bar' }
    --      >   }
    --      > )
    --      bar is bar.
    --
    -- Expressions are evaluated recursively.
    --
    --      > expand_vars(
    --      >   '$1 is bar.', {
    --      >       ['1'] = '$2',
    --      >       ['2'] = 'foo'
    --      >   }
    --      > )
    --      foo is bar.
    --
    -- @string str A string.
    -- @tab ns A mapping of variable names to values.
    -- @treturn string A transformed string.
    -- @raise An error if there is no function of the given name or
    --  if the value of an expression cannot be coerced to a string.
    -- @function expand_vars
    expand_vars = typed('string', 'table', '?number')(
        function (str, ns, _rd)
            if not _rd then _rd = 0 end
            assert(_rd < 64, 'recursion limit exceeded.')
            local function e (...) return eval(_rd, ns, ...) end
            return str:gsub('%f[%$]%$([%w_%.]+)%f[%W](|?)([%w_%.]*)', e):
                       gsub('%$(%$*)', '%1')
        end
    )
end

--- Iterate over substrings of a string.
--
-- <h3>Caveats:</h3>
--
-- Does *not* support multi-byte characters.
--
-- @string str A string.
-- @string pattern A pattern that matches sequences of characters that
--  separate substrings. Must *not* contain frontier patterns.
-- @int[opt] max Split up the string into at most that many substrings.
-- @string[optchain] isep Whether to include seperators in substrings.
--  `l` includes seperators on the left, `r` on the right.
--  By default, seperators are *not* included in substrings.
-- @treturn func A *stateful* iterator.
-- @usage
--      > for s in split('CamelCase', '%u', nil, 'l') do
--      >   print(string.format("%s", s))
--      > end
--      ""
--      "Camel"
--      "Case"
-- @function split
split = typed('string', 'string', '?number', '?string')(
    function (str, pattern, max, isep)
        assert(not pattern:match '%f[%%]%%f', 'forbidden frontier pattern.')
        assert(not isep or isep == 'l' or isep == 'r', 'expecting "l" or "r".')
        local pos = 1
        local n = 0
        local i, j
        return function ()
            local sep, last
            if not pos then return end
            if isep == 'l' and i then sep = str:sub(i, j) end
            i = nil
            j = nil
            n = n + 1
            if n == max then
                last = -1
            else
                i, j = str:find(pattern, pos)
                if     not i       then last = -1
                elseif isep == 'r' then last = j
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
-- @treturn string The trimmed string.
-- @function trim
trim = typed('string')(
    function (str)
        return str:gsub('^%s+', ''):gsub('%s*$', '')
    end
)


----------------
-- Citation keys
-- @section

--- A mapping of citation key types to parsers.
--
-- A parser should take a citation key and either return search terms or
-- `nil` if no search terms can be guessed from the citation key.
CKEY_PARSERS = {}

do
    local len = utf8.len

    --- Guess search terms from a BetterBibTeX citation key.
    --
    -- Splits up a BetterBibTeX citation key at each uppercase letter
    -- and at each start of a string of digits.
    --
    -- <h3>Caveats:</h3>
    --
    -- BetterBibTeX citation keys must be encoded in ASCII.
    --
    -- @string ckey A BetterBibTeX citation key.
    -- @treturn[1] {string,...} A list of search terms.
    -- @treturn[2] nil `nil` if no search terms could be derived.
    -- @fixme No unit test.
    -- @function CKEY_PARSERS.betterbibtexkey
    -- @fixme Error not documented.
    CKEY_PARSERS.betterbibtexkey = typed('string')(
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
    -- Splits up an Easy Citekey into an author, a year, and a title.
    --
    -- <h3>Caveats:</h3>
    --
    -- Easy Citekeys must be encoded in UTF-8.
    --
    -- @string ckey A zotxt Easy Citekey.
    -- @treturn[1] {string,...} A list of search terms.
    -- @treturn[2] nil `nil` if no search terms could be derived.
    -- @function CKEY_PARSERS.easykey
    -- @fixme No unit test.
    -- @fixme Error message not documented.
    CKEY_PARSERS.easykey = typed('string')(
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
-- @string ckey A citation key.
-- @tparam {string,...} types A list of citation key types to try to parse
--  the citation key as. Must match keys in `CKEY_PARSERS`.
-- @treturn[1] {string,...} A list of search terms.
-- @treturn[2] nil `nil` if no search terms could be derived.
-- @treturn[2] string An error message.
-- @function ckey_guess_terms
ckey_guess_terms = typed('string', 'table')(
    function (ckey, types)
        assert(ckey ~= '', 'citation key is the empty string.')
        assert(#types > 0, 'citation key type list is empty.')
        local parsers = CKEY_PARSERS
        for i = 1, #types do
            local f = parsers[types[i]]
            if f then
                local terms = f(ckey)
                if terms then return terms end
            end
        end
        return nil, 'cannot derive search terms from ' .. ckey .. '.'
    end
)


------------
-- CSL items
--
-- @section

--- The preferred order of CSL variables.
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
    --- Create a function that iterates over "extra" field entries.
    --
    -- Uses the newer `<variable name>: <value><linefeed>` syntax.
    --
    -- @string extra The contents of a Zotero "extra" field.
    -- @treturn func A *stateful* iterator.
    local function make_iter (extra)
        local next_line = split(extra, '\r?\n')
        return function ()
            while true do
                local ln = next_line()
                while ln and ln:match '^%s*$' do ln = next_line() end
                if not ln then return end
                local k, v = tabulate(split(ln, '%s*:%s*'), 2)
                if k and v then
                    k = csl_varname_std(k)
                    if k then
                        v = trim(v)
                        if v ~= '' then return k, v end
                    end
                end
            end
        end
    end

    --- Create a function that iterates over legacy "extra" field entries.
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
                if k and v then
                    k = csl_varname_std(k)
                    if k then
                        v = trim(v)
                        if v ~= '' then return k, v end
                    end
                end
            end
        end
    end

    --- Iterate over every key-value pair in the "note" field of a CSL item.
    --
    -- @tab item A CSL item.
    -- @treturn func A *stateful* iterator.
    -- @function csl_item_extras
    csl_item_extras = typed('table')(
        function (item)
            -- luacheck: ignore next
            local note = item.note
            if not note then return function () return end end
            local next = make_iter(note)
            local legacy = false
            return function ()
                if not legacy then
                    local k, v = next()
                    if k then return k, v end
                    next = make_legacy_iter(note)
                    legacy = true
                end
                return next()
            end
        end
    )
end

do
    -- Parse a date in Zotero's extra field.
    --
    -- <h3>Caveats:</h3>
    --
    -- The given item is modified in-place.
    --
    -- @tab item A CSL item.
    -- @string k A field name.
    -- @string v A value.
    local function parse_date (item, k, v)
        local ps = {}
        local i = 0
        for ds in split(v, '/', 2) do
            i = i + 1
            local dt = {}
            local y, m, d = ds:match '^(%d%d%d%d)%-?(%d*)%-?(%d*)$'
            if y then
                dt[1] = y
                if m ~= '' then
                    dt[2] = m
                    if d ~= '' then
                        dt[3] = d
                    end
                end
                ps[i] = dt
            elseif i == 1 then
                warn 'item $item.id: extra field "$k": unparsable.'
                return
            end
        end
        item[k] = {['date-parts'] = ps}
    end

    --- Parse a name in Zotero's extra field.
    --
    -- <h3>Caveats:</h3>
    --
    -- The given item is modified in-place.
    --
    -- @tab item A CSL item.
    -- @string k A field name.
    -- @string v A value.
    local function parse_name (item, k, v)
        local family, given = tabulate(split(v, '%s*%|%|%s*', 2))
        if not item[k] then item[k] = {} end
        if family and family ~= '' and given and given ~= '' then
            table.insert(item[k], {family = family, given = given})
        else
            table.insert(item[k], v)
        end
    end

    -- Mapping of CSL field names to functions that take an item and a field
    -- name-value pair as it should be entered into the "extra" field, and
    -- that *add* that field to the CSL item *in-place*.
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

    --- Copy CSL variables from the "extra" field to the item proper.
    --
    -- Zotero's CSL JSON export puts CSL fields that have been entered
    -- into its "extra" field into the CSL "note" field, rather than to
    -- convert them to CSL fields.
    --
    -- See <https://www.zotero.org/support/kb/item_types_and_fields#citing_fields_from_extra>
    -- for the syntax of Zotero's "extra" field.
    --
    -- @tab item A CSL item.
    -- @treturn table The item with variables from "extra" copied.
    -- @function csl_item_parse_extras
    csl_item_parse_extras = typed('table')(
        function (item)
            local ret = copy(item)
            for k, v in csl_item_extras(item) do
                local f = parsers[k]
                if not ret[k] or f == parse_date or k == 'type' then
                    if f then
                        f(ret, k, v)
                    -- At least until CSL v1.2 is out.
                    elseif k ~= 'citation-key' and k ~= 'citekey' then
                        ret[k] = v
                    end
                end
            end
            return ret
        end
    )
end

--- Standardise variable names of a CSL item.
--
-- @tab item A CSL item.
-- @treturn tab A modified, deep copy of the item.
-- @see csl_varname_std
-- @function csl_item_std_vars
csl_item_std_vars = typed('table', '?table')(
    function (item, _s)
        if     not _s   then _s = {}
        elseif _s[item] then return _s[item]
        end
        local ret = {}
        _s[item] = ret
        local nkeys = select(2, keys(item))
        if nkeys == #item then
            for i = 1, nkeys do
                local v = item[i]
                if type(v) == 'table' then
                    v = csl_item_std_vars(item[i], _s)
                end
                ret[i] = v
            end
        else
            for k, v in pairs(item) do
                k = csl_varname_std(k)
                if k then
                    if type(v) == 'table' then
                        v = csl_item_std_vars(v, _s)
                    end
                    ret[k] = v
                end
            end
        end
        return ret
    end
)

do
    -- A mapping of Lua type names to constructors.
    -- @fixme Say more about this.
    local converters = {}

    --- Convert a CSL Item to a Pandoc metadata type (worker).
    --
    -- @tab item CSL item.
    -- @treturn pandoc.MetaValue A Pandoc metdata value.
    -- @fixme ... undocumtend
    local function conv (item, ...)
        local t = type(item)
        local f = converters[t]
        -- @fixme Undocumented.
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

    -- Convert a Lua string to a pandoc.MetaInlines string.
    --
    -- Zotero pseudo-HTML formatting is kept.
    --
    -- @string str A string.
    -- @treturn pandoc.MetaInlines The string.
    function converters.string (str)
        local html = zotero_to_html(str)
        local inlines = pandoc.read(html, 'html').blocks[1].content
        return MetaInlines(inlines)
    end

    -- Convert a Lua table to a pandoc.MetaMapping.
    --
    -- @tab tab A table.
    -- @treturn pandoc.MetaMapping The table.
    -- @fixme rd undocumented
    -- @fixme recursion protection untested.
    function converters.table (tab, _rd)
        if not _rd then _rd = 0 end
        assert(_rd < 128, 'recursion limit exceeded.')
        local nkeys = select(2, keys(tab))
        local n = #tab
        if n == nkeys then
            local list = MetaList{}
            for i = 1, n do
                list[i] = conv(tab[i], _rd + 1)
            end
            return list
        end
        local map = MetaMap{}
        for k, v in pairs(tab) do
            map[k] = conv(v, _rd + 1)
        end
        return map
    end

    --- Convert a CSL item to a Pandoc metadata value.
    --
    -- @tab item A CSL item.
    -- @treturn pandoc.MetaMap A Pandoc metadata value.
    -- @function csl_item_to_meta
    -- @fixme No unit test.
    csl_item_to_meta = typed('table')(conv)
end

--- Pick the IDs of CSL items out of a list of CSL items.
--
-- @tab items A list of CSL items.
-- @treturn {[string]=true,...} A [set](https://www.lua.org/pil/11.5.html)
--  of item IDs.
-- @raise An error if an item has an ID that cannot be coerced to a string.
-- @function csl_items_ids
csl_items_ids = typed('table')(
    function (items)
        local ids = {}
        for i = 1, #items do
            local id = items[i].id
            local t = type(id)
            if     t == 'string' then ids[id] = true
            elseif t == 'table'  then ids[stringify(id)] = true
            elseif t ~= 'nil'    then error 'cannot parse item ID.'
            end
        end
        return ids
    end
)

--- Sort CSL items by their ID.
--
-- @tab a A CSL item.
-- @tab b Another CSL item.
-- @treturn bool Whether `a` should come before `b`.
-- @function csl_items_sort
csl_items_sort = typed('table', 'table')(
    function (a, b)
        return a.id < b.id
    end
)


--- Trim CSL variable name, convert to lowercase, replace spaces with dashes.
--
-- @string varname A CSL variable name.
-- @treturn[1] string Standardised variable name.
-- @treturn[2] nil `nil` if the given string is not a CSL variable name.
-- @treturn[2] string An error message.
-- @function csl_varname_std
csl_varname_std = typed('string')(
    function (varname)
        assert(varname ~= '', 'variable name is the empty string.')
        varname = trim(varname):gsub(' ', '-'):lower()
        if varname:match '^[%a%-]+$' then return varname end
        return nil, varname .. ': not a variable name.'
    end
)

--- Sort CSL variables.
--
-- Sorts variables in the order in which they are listed in `CSL_VARS_ORDER`.
-- Unlisted variables are placed after listed ones in lexical order.
--
-- @string a A CSL variable name.
-- @string b Another CSL variable name.
-- @treturn bool Whether `a` should come before `b`.
-- @function csl_vars_sort
csl_vars_sort = typed('string', 'string')(in_order(unpack(CSL_VARS_ORDER)))

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
    -- @function csl_json_to_item
    csl_json_to_item = typed('string')(
        function (str)
            if str == '' then return nil, 'got the empty string.' end
            local ok, data = pcall(decode, str)
            if not ok then return nil, 'cannot parse: ' .. str end
            return csl_item_std_vars(apply(num_to_str, data))
        end
    )
end


--------------------
-- Markup converters
--
-- @section

do
    -- Escape bold and italics meta characters.
    local function esc_bold_italics (char, tail)
        return char:gsub('(.)', '\\%1') .. tail
    end

    -- Escape superscript and subscript meta characters.
    local function esc_sup_sub (head, body, tail)
        return head:gsub('(.)', '\\%1') .. body .. tail:gsub('(.)', '\\%1')
    end

    -- Escape brackets.
    local function esc_brackets (char, tail)
        return '\\[' .. char:sub(2, -2) .. '\\]' .. tail
    end

    -- Pairs of expressions and replacement functions.
    local esc_patterns = {
        -- Backslashes.
        {'(\\+)', '\\%1'},
        -- Bold and italics.
        -- This escapes liberally, but it is the only way to cover edge cases.
        {'(%*+)([^%s%*])', esc_bold_italics},
        {'(_+)([^%s_])', esc_bold_italics},
        -- Superscript and subscript.
        {'(%^+)([^%^%s]*)(%^+)', esc_sup_sub},
        {'(~+)([^~%s]+)(~+)', esc_sup_sub},
        -- Brackets (spans and links).
        {'(%b[])([%({])', esc_brackets}
    }

    --- Escape Markdown syntax.
    --
    -- Only escapes [Markdown Pandoc recognises in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @string str Non-markdown text.
    -- @treturn string Text with markdown syntax escaped.
    -- @function escape_markdown
    escape_markdown = typed('string')(
        function (str)
            for i = 1, #esc_patterns do
                local pattern, repl = unpack(esc_patterns[i])
                str = str:gsub(pattern, repl)
            end
            return str
        end
    )
end

do
    -- Filter to escape strings.
    local escape_str = {}

    -- Escape Markdown in a string element.
    --
    -- Works like `escape_markdown` but for Pandoc string elements.
    --
    -- @tparam pandoc.Str str A Pandoc string element.
    -- @treturn pandoc.Str A string with all Markdown syntax escaped.
    function escape_str.Str (str)
        str.text = escape_markdown(str.text)
        return str
    end

    -- Filter to convert to Markdown text.
    local to_markdown = {}

    -- Make a function that converts an element to Markdown.
    --
    -- @string char A Markdown markup character.
    -- @treturn func A conversion function.
    local function make_conv_f (char)
        return function (elem)
            local str = stringify(pandoc.walk_inline(elem, to_markdown))
            return Str(char .. str .. char)
        end
    end

    -- Convert AST elements into Markdown text.
    to_markdown.Emph = make_conv_f '*'
    to_markdown.Strong = make_conv_f '**'
    to_markdown.Subscript = make_conv_f '~'
    to_markdown.Superscript = make_conv_f '^'

    -- Convert HTML span elements to Markdown text.
    --
    -- @tparam pandoc.Span An HTML span element.
    -- @treturn pandoc.Str The element as Markdown.
    function to_markdown.Span (span)
        local str = stringify(pandoc.walk_inline(span, to_markdown))
        local attrs = ''

        local identifier = span.identifier
        if identifier then
            local id = stringify(identifier)
            if id ~= '' then attrs = '#' .. id end
        end

        local classes = span.classes
        if classes then
            for i = 1, #classes do
                if attrs ~= '' then attrs = attrs .. ' ' end
                attrs = attrs .. '.' .. classes[i]
            end
        end

        local attributes = span.attributes
        if attributes then
            for k, v in pairs(attributes) do
                if attrs ~= '' then attrs = attrs .. ' ' end
                attrs = attrs .. k .. '="' .. v .. '"'
            end
        end

        if attrs ~= '' then str = '[' .. str .. ']{' .. attrs .. '}' end
        return Str(str)
    end

    -- Convert a Pandoc small capitals elements to Markdown text.
    --
    -- @tparam pandoc.SmallCaps A SmallCaps element.
    -- @treturn pandoc.Str The element as Markdown.
    function to_markdown.SmallCaps (sc)
        local span = Span(sc.content)
        span.attributes.style = 'font-variant: small-caps'
        return to_markdown.Span(span)
    end

    --- Convert a Pandoc element to Markdown text.
    --
    -- Only recognises [elements Pandoc permits in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn string Markdown text.
    -- @function markdownify
    markdownify = typed('table|userdata')(
        function (elem)
            return stringify(walk(walk(elem, escape_str), to_markdown))
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
    -- Strings *must* be encoded in UTF-8.
    -- Does *not* escape *all* non-printable characters.
    --
    -- @string str The value.
    -- @treturn string A YAML scalar.
    -- @raise An error if `str` is not a `string`.
    local function scalarify (str)
        -- Simple strings need no special treatment.
        if
            tonumber(str) ~= nil    or -- Numbers
            str:match '^[%w-]+$'    or -- Simple words
            str:match '^[%w%./]+$'  or -- DOIs
            str:match '^%a+:[%w%./-]+' -- URLs
        then return str end

        -- Replace line breaks with the OS' EOL sequence.
        str = str:gsub('\r?\n', EOL)

        -- Escape special and forbidden characters.
        local n = 0
        local chars = {}
        for _, c in codes(str, true) do
            n = n + 1
            if
                c == 0x22 or -- '"'
                c == 0x5c    -- '\'
            then
                chars[n] = '\\' .. char(c)
            elseif
                c == 0x09 or -- TAB
                c == 0x0a or -- LF
                c == 0x0d or -- CR
                c == 0x85    -- NEL
            then
                chars[n] = char(c)
            elseif
                c <= 0x001f or -- C0 control block
                c == 0x007f    -- DEL
            then
                chars[n] = format('\\x%02x', c)
            elseif
                (0x0080 <= c and c <= 0x009f) or -- C1 control block
                (0xd800 <= c and c <= 0xdfff) or -- Surrogate block
                c == 0xfffe or
                c == 0xffff
            then
                chars[n] = format('\\u%04x', c)
            else
                chars[n] = char(c)
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
    -- Lines are termined with `EOL`.
    --
    -- <h3>Caveats:</h3>
    --
    -- Strings in other encodings other than UTF-8 will be mangled.
    -- Does *not* escape *all* non-printable characters (because Unicode).
    -- Does *not* recognise *all* end-of-line sequences (because Unicode).
    --
    -- @param val A value.
    -- @int[opt=4] ind How many spaces to indent blocks.
    -- @func[optchain] sort_f A function to sort keys of mappings.
    --  Defaults to sorting them lexically.
    -- @treturn[1] string A YAML string.
    -- @treturn[2] nil `nil` if the data cannot be represented in YAML.
    -- @treturn[2] string An error message.
    -- @raise An error if data cannot be expressed in YAML
    --  or if the graph is too high.
    -- @function yamlify
    -- @fixme Look up proper EOL sequence as given by Unicode consortium?
    -- @fixme indentation and sorting is not strictly unit-tested.
    yamlify = typed('*', '?number', '?function', '?number')(
        function (val, ind, sort_f, _col, _rd)
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
                    if i > 1 then strs:add(sp) end
                    strs:add('- ', yamlify(val[i], ind, sort_f, col, _rd + 1))
                    if i ~= n then strs:add(EOL) end
                end
            else
                local i = 0
                for k, v in sorted(val, sort_f) do
                    i = i + 1
                    if type(k) == 'number' then k = tostring(k)
                                           else k = scalarify(k)
                    end
                    if i > 1 then strs:add(sp) end
                    strs:add(k, ':')
                    local col = _col + ind
                    if type(v) == 'table' then strs:add(EOL, spaces(col))
                                          else strs:add ' '
                    end
                    strs:add(yamlify(v, ind, sort_f, col, _rd + 1))
                    if i ~= nkeys then strs:add(EOL) end
                end
            end
            return concat(strs)
        end
    )
end

--- Convert Zotero pseudo-HTML to proper HTML.
--
-- @string zhtml Zotero pseudo-HTML code.
-- @treturn string HTML code.
-- @function zotero_to_html
zotero_to_html = typed('string')(
    function (zhtml)
        local op, cl, n, m
        op, n = zhtml:gsub('<sc>', '<span style="font-variant: small-caps">')
        if n == 0 then return zhtml end
        cl, m = op:gsub('</sc>', '</span>')
        if m == 0 then return zhtml end
        return cl
    end
)

--- Convert Zotero pseudo-HTML to Markdown.
--
-- Only supports [pseudo-HTML that Pandoc recognises in bibliographic
-- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
--
-- @string zhtml Zotero pseudo-HTML code.
-- @treturn[1] string Markdown text.
-- @treturn[2] nil `nil` if `zhtml` cannot be parsed.
-- @treturn[2] string An error message.
function zotero_to_markdown (zhtml)
    local ok, ret = pcall(zotero_to_html, zhtml)
    if not ok then return nil, ret end
    local doc = pandoc.read(ret, 'html')
    return markdownify(doc)
end


-----------
-- Warnings
--
-- @section

--- Print a value to STDERR.
--
-- Prefixes the value with `SCRIPT_NAME` and ':', appends `EOL`.
--
-- If the value is a string and contains variable names, they are replaced
-- with the values of those variables as seen by the calling function.
-- See `expand_vars` for the syntax.
--
-- If the value is of another type, it is coerced to a string before printing.
--
-- @param val A value.
function log (val, _lvl)
    local msg
    if type(val) == 'string' then
        -- @fixme untested and undocumented.
        assert(val ~= '', 'value is the empty string.')
        if not _lvl then _lvl = 3 end
        local ns = vars(_lvl)
        msg = expand_vars(val, ns)
    else
        msg = tostring(val)
    end
    io.stderr:write(SCRIPT_NAME, ': ', msg, EOL)
end

--- Print a value to STDERR unless the user has requested less output.
--
-- The value is only printed if `PANDOC_STATE.verbosity` is *not* 'ERROR'.
-- Otherwise the same as `log`.
--
-- @param val The value.
function warn (val)
    if PANDOC_STATE.verbosity ~= 'ERROR' then log(val, 4) end
end

--- Print a value to STDERR if the user has requested more output.
--
-- The value is only printed if `PANDOC_STATE.verbosity` is 'INFO'.
-- Otherwise the same as `log`.
--
-- @param val The value.
function info (val)
    if PANDOC_STATE.verbosity == 'INFO' then log(val, 4) end
end


-----------
-- File I/O
--
-- @section

--- Check whether a path is absolute.
--
-- @string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
-- @raise An error if no path is given or if the path is the empty string.
-- @function path_is_abs
if pandoc.types and PANDOC_VERSION >= {2, 12} then
    path_is_abs = pandoc.path.is_absolute
else
    path_is_abs = typed('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            if PATH_SEP == '\\' and path:match '^.:\\' then return true end
            return path:match('^' .. PATH_SEP) ~= nil
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
            if env_home and path_is_abs(env_home) then
                home_dir = path_sanitise(env_home)
            end
        end
    end

    -- luacheck: ignore path_prettify
    --- Prettify paths.
    --
    -- Removes the current working directory from the beginning of a path and,
    -- on non-Windows systems, replace the user's home directory with '~'.
    --
    -- @string path Path.
    -- @treturn string A prettier path.
    -- @raise An error if no path is given or if the path is the empty string.
    -- @function path_prettify
    path_prettify = typed('string')(
        function (path)
            assert(path ~= '', 'path is the empty string.')
            path = path_sanitise(path)
            if get_working_directory then
                local wd = get_working_directory()
                local last = #wd + 1
                if path:sub(1, last) == wd .. PATH_SEP then
                    return path:sub(last + 1)
                end
            end
            if home_dir then
                local last = #home_dir + 1
                if path:sub(1, last) == home_dir .. '/' then
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
--  or '.' if none was given.
-- @raise An error if no path is given or if the path is the empty string.
function wd ()
    local fname = PANDOC_STATE.input_files[1]
    if not fname then return '.' end
    local wd = path_split(fname)
    return wd
end

--- Check whether a file exists.
--
-- <h3>Caveats:</h3>
--
-- Another process may create a file of the given name between the time
-- `file_exists` checks whether there is such a file and the time it
--
-- @string fname A filename.
-- @treturn[1] boolean `true` if the file exists.
-- @treturn[2] nil `nil` if the file does not exist.
-- @treturn[2] string An error message.
-- @treturn[2] int The error number 2.
-- @raise An error if no path is given or if the path is the empty string.
-- @function file_exists
file_exists = typed('string')(
    function (fname)
        assert(fname ~= '', 'filename is the empty string.')
        local file, err, errno = io.open(fname, 'r')
        if not file then return nil, err, errno end
        -- @fixme Undocumented.
        assert(file:close())
        return true
    end
)

do
    local resource_path = PANDOC_STATE.resource_path

    --- Locate a file in Pandoc's resource path.
    --
    -- Absolute filenames are returned as they are.
    --
    -- @string fname A filename.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the file could not be found.
    -- @treturn[2] string An error message.
    -- @raise An error if no path is given or if the path is the empty string.
    -- @function file_locate
    file_locate = typed('string')(
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
-- @function file_read
file_read = typed('string')(
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
    -- @treturn[1] bool `true` if the data was written to the given file.
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
    -- If a file of that name already exists, it is overwritten. If this
    -- happens, a warning will be printed to STDERR *most of the time*;
    -- another process may create a file *between* the time `file_write`
    -- checks whether a filename is in use and the time it starts writing.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Prints warnings to STDERR.
    --
    -- <h3>Caveats:</h3>
    --
    -- Data is first written to a temporary file, then that file is renamed to
    -- the given filename. This is safe and secure starting with Pandoc v2.8.
    -- If you are using an older version of Pandoc, then the caveats of
    -- ${with_tmp_file} apply.
    --
    -- @string fname A filename.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    -- @raise An error if no filename is given or
    --  if the filename is the empty string.
    -- @function file_write
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
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

        file_write = typed('string')(
            function (fname, ...)
                assert(fname ~= '', 'filename is the empty string.')
                local dir, base = path_split(path_make_abs(fname))
                local data = {...}
                local tmp_dir
                local vs = {with_temporary_directory(dir, 'pdz', function (td)
                    tmp_dir = td
                    warn 'created temporary directory $td|path_prettify$.'
                    local tmp_file = path_join(td, base)
                    local ok, err, errno = write(tmp_file, unpack(data))
                    if not ok then return nil, err, errno end
                    if file_exists(fname) then
                        warn 'replacing $fname|path_prettify ...'
                    end
                    return os.rename(tmp_file, fname)
                end)}
                if tmp_dir and not file_exists(tmp_dir) then
                    warn 'removed $fname|path_prettify$.'
                end
                return unpack(vs)
            end
        )

    else
        file_write = typed('string')(
            function (fname, ...)
                assert(fname ~= '', 'filename is the empty string.')
                local dir = path_split(fname)
                local data = {...}
                local tmp_file
                return with_tmp_file(dir, nil, function(tf)
                    local ok, err, errno
                    tmp_file = tf
                    warn 'writing to temporary file $tf|path_prettify$.'
                    ok, err, errno = write(tmp_file, unpack(data))
                    if not ok then return nil, err, errno end
                    if file_exists(fname) then
                        warn 'replacing $fname|path_prettify ...'
                    end
                    ok, err, errno = os.rename(tmp_file, fname)
                    if not ok then return nil, err, errno end
                    warn 'moved $tf|path_prettify to $fname|path_prettify$.'
                    return true
                end)
            end
        )
    end
end

do
    local alnum = {}

    do
        -- These are the ASCII/UTF-8 ranges for alphanumeric characters.
        local ranges = {
            {48,  57},  -- 0-9.
            {65,  90},  -- A-Z.
            {97, 122}   -- a-z.
        }

        -- Populate alnum.
        n = 0
        for i = 1, #ranges do
            local first, last = unpack(ranges[i])
            for j = first, last do
                n = n + 1
                alnum[n] = string.char(j)
            end
        end
        alnum.n = n
    end

    math.randomseed(os.time())

    --- Generate a name for a temporary file.
    --
    -- <h3>Caveats:</h3>
    --
    -- The generated filename is likely to *not* be in use. But another
    -- process may create a file of the same name between the time `tmp_fname`
    -- checks whether the name is in use and the time it returns.
    --
    -- @string[opt] dir A directory to prefix the filename with.
    --  Must not be the empty string.
    -- @string[opt='pdz-XXXXXX'] templ A template for the filename.
    --  'X's are replaced with random alphanumeric characters.
    --  Must contain at least six 'X's.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the generated filename is in use.
    -- @treturn[2] string An error message.
    -- @raise An error if the template or the directory is
    --  not a string or the empty string.
    -- @function tmp_fname
    tmp_fname = typed('?string', '?string')(
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
            return nil, 'failed to generate unused filename.'
        end
    )
end

do
    -- Remove a file unless its second argument is `true`.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Prints an error message to STDERR if the file could not be removed.
    --
    -- @string fname A filename.
    -- @bool success Whether a function call succeeded.
    local function remove_on_fail (fname, success)
        if success then return true end
        warn 'removing $fname|path_prettify$.'
        local ok, err, errno = os.remove(fname)
        if not ok and errno ~= 2 then log(err) end
        return ok, err, errno
    end

    --- Run a function with a temporary file.
    --
    -- Generates a temporary filename. Does *not* create that file.
    -- If the given function raises an error or returns `nil` or `false`,
    -- the file of that name is deleted.
    --
    -- <h3>Side-effects:</h3>
    --
    -- An error message is printed to STDERR if the temporary
    -- file could not be deleted.
    --
    -- <h3>Caveats:</h3>
    --
    -- The temporary file may have been created by *another* process. If that
    -- file is located within a directory that other users have write access
    -- to (e.g., `/tmp`), then is a security issue.
    --
    -- @string[opt] dir A directory to prefix the name
    --  of the temporary file with. See `tmp_fname`.
    -- @string[optchain] templ A template for the name
    --  of the temporary file. See `tmp_fname`.
    -- @func func A function to run.
    --  Given the name of the temporary file and `...` as arguments.
    --  Must *not* change the working directory.
    -- @param ... Passed on to the function.
    -- @return The values the function returns.
    -- @function with_tmp_file
    with_tmp_file = typed('?string', '?string', 'function')(
        function (dir, templ, func, ...)
            local tmp_file, err = tmp_fname(dir, templ)
            if not tmp_file then return nil, err end
            local function clean_up (...)
                return remove_on_fail(tmp_file, ...)
            end
            local function run (...)
                return assert(func(tmp_file, ...))
            end
            return do_after(clean_up, run, ...)
        end
    )
end


-------------
-- Networking
--
-- @section

do
    -- luacheck: ignore pcall
    local pcall = pcall
    local fetch = pandoc.mediabag.fetch

    --- Retrieve data from a URL via an HTTP GET request.
    --
    -- @string url The URL.
    -- @treturn string The MIME type of the HTTP content.
    -- @treturn string The HTTP content itself.
    -- @raise An error if the host cannot be reached. If you are running
    --  Pandoc v2.11 or later, this is a `ConnectionError`, which can be
    --  caught. If you a running an older version of Pandoc it is a
    --  Pandoc exception, which cannot be caught.
    -- @function http_get
    http_get = typed('string')(
        function (url)
            assert(url ~= '', 'URL is the empty string.')
            local ok, mt, data = pcall(fetch, url, '.')
            if not ok then
                local host = url:match '(.-)%f[:/]/+' or url
                error(ConnectionError{host = host})
            end
            return mt, data
        end
    )
end

--- Query a URL via an HTTP GET request.
--
-- @string url The URL.
-- @tparam[opt] {string=string,...} params Request parameters.
-- @treturn string The MIME type of the HTTP content.
-- @treturn string The HTTP content itself.
-- @raise See @{http_get}.
-- @function url_query
url_query = typed('string', '?table')(
    function (url, params)
        assert(url ~= '', 'URL is the empty string.')
        if params then
            local n = 0
            for k, v in sorted(params) do
                assert(v, 'parameter ' .. k .. ': is nil.')
                n = n + 1
                if n == 1 then url = url .. '?' .. k .. '=' .. v
                          else url = url .. '&' .. k .. '=' .. v
                end
            end
        end
        return http_get(url)
    end
)


---------------------
-- Bibliography files
-- @section

--- A mapping of filename suffices to codecs.
BIBLIO_TYPES = {}

--- Metatable for filename suffix lookups.
BIBLIO_TYPES.mt = {}
setmetatable(BIBLIO_TYPES, BIBLIO_TYPES.mt)

--- Convert keys to lowercase if they cannot be found.
--
-- @string key A key.
-- @treturn string The key in lowercase.
-- @fixme Is this tested?
function BIBLIO_TYPES.mt:__index(key)
    if type(key) == 'string' then return rawget(self, key:lower()) end
end

--- Decode BibLaTeX.
BIBLIO_TYPES.bib = {}

--- Read the IDs from the contents of a BibLaTeX file.
--
-- @string str The contents of a BibLaTeX file.
-- @treturn {{['id']=string},...} A list of key-value pairs.
-- @function BIBLIO_TYPES.bib.decode
BIBLIO_TYPES.bib.decode = typed('string')(
    function (str)
        local ret = {}
        local n = 0
        for id in str:gmatch '@%w+%s*{%s*([^%s,]+)' do
            n = n + 1
            ret[n] = {id = id}
        end
        return ret
    end
)

--- Decode BibTeX.
BIBLIO_TYPES.bibtex = {}

--- Read the IDs from the contents of a BibTeX file.
--
-- @string str The contents of a BibTeX file.
-- @treturn {{['id']=string},...} A list of key-value pairs.
-- @function BIBLIO_TYPES.bibtex.decode
BIBLIO_TYPES.bibtex.decode = BIBLIO_TYPES.bib.decode

--- De-/Encode CSL items in JSON.
BIBLIO_TYPES.json = {}

--- Parse a CSL JSON string.
--
-- @string str A CSL JSON file.
-- @treturn tab A list of CSL items.
-- @function BIBLIO_TYPES.json.decode
BIBLIO_TYPES.json.decode = csl_json_to_item

--- Serialise a list of CSL items to a JSON string.
--
-- @tab items A list of CSL items.
-- @treturn string A CSL YAML string.
-- @function BIBLIO_TYPES.json.encode
BIBLIO_TYPES.json.encode = json.encode

--- De-/Encode CSL items in YAML.
BIBLIO_TYPES.yaml = {}

--- Parse a CSL YAML string.
--
-- @string str A CSL YAML string.
-- @treturn tab A list of CSL items.
-- @function BIBLIO_TYPES.yaml.decode
BIBLIO_TYPES.yaml.decode = typed('string')(
    function (str)
        local next_line = str:gmatch '(.-)\r?\n'
        local ln = next_line(str, nil)
        while ln and ln ~= '---' do ln = next_line(str, ln) end
        if not ln then str = concat{'---', EOL, str, EOL, '...', EOL} end
        local doc = pandoc.read(str, 'markdown')
        if not doc.meta.references then return {} end
        local refs = walk(doc.meta.references, {MetaInlines = markdownify})
        for i = 1, #refs do refs[i] = csl_item_std_vars(refs[i]) end
        return refs
    end
)

--- Serialise a list of CSL items to a YAML string.
--
-- @tab items A list of CSL items.
-- @treturn string A CSL YAML string.
-- @raise See `yamlify`.
-- @function BIBLIO_TYPES.yaml.encode
BIBLIO_TYPES.yaml.encode = typed('table')(
    function (items)
        table.sort(items, csl_items_sort)
        return yamlify({references=items}, nil, csl_vars_sort)
    end
)

--- Alternative suffix for YAML files.
BIBLIO_TYPES.yml = BIBLIO_TYPES.yaml

--- Read a bibliography file.
--
-- The filename suffix determines what format the contents of the file are
-- parsed as. There must be a decoder for that suffix in `BIBLIO_TYPES`.
--
-- @string fname A filename.
-- @treturn[1] tab A list of CSL items.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is an I/O error.
-- @function biblio_read
biblio_read = typed('string')(
    function (fname)
        assert(fname ~= '', 'filename is the empty string')
        local suffix = fname:match '%.(%w+)$'
        if not suffix then return nil, fname .. ': no filename suffix.' end
        local codec = BIBLIO_TYPES[suffix]
        if not codec then return nil, fname .. ': unsupported format.' end
        local decode = codec.decode
        if not decode then return nil, fname .. ': cannot parse format.' end
        local str, err, errno = file_read(fname)
        if not str then return nil, err, errno end
        local ok, ret = pcall(decode, str)
        if not ok then return nil, fname ..  ': ' .. tostring(ret) end
        return ret
    end
)

--- Write bibliographic data to a bibliography file.
--
-- The filename suffix determins what format the data is written as.
-- There must be an encoder for that suffix in `BIBLIO_TYPES`.
-- Ends every file with `EOL`.
--
-- <h3>Caveats:</h3>
--
-- See @{file_write}.
--
-- @string fname A filename.
-- @tab[opt] items A list of CSL items. If no items are given,
--  tests whether data can be written in the corresponding format.
-- @treturn[1] str The filename suffix.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is an I/O error.
-- @raise An error if the filename is the empty string.
-- @function biblio_write
biblio_write = typed('string', 'table')(
    function (fname, items)
        local ok, err, errno, ret, suffix, codec, encode
        assert(fname ~= '', 'filename is the empty string')
        suffix = fname:match '%.(%w+)$'
        if not suffix then return nil, fname .. ': no filename suffix.' end
        codec = BIBLIO_TYPES[suffix]
        if not codec then return nil, fname .. ': unsupported format.' end
        encode = codec.encode
        if not encode then return nil, fname .. ': cannot write format.' end
        if #items == 0 then return suffix end
        ok, ret = pcall(encode, items)
        if not ok then return nil, fname .. ': ' .. tostring(ret) end
        ok, err, errno = file_write(fname, ret, EOL)
        if not ok then return nil, err, errno end
        return suffix
    end
)

--- Add items from Zotero to a bibliography file.
--
-- If an item is already in the bibliography file, it won't be added again.
--
-- [Citeproc](https://github.com/jgm/citeproc) appears to recognise
-- formatting in *every* CSL field, so `pandoc-zotxt.lua` does the same.
--
-- <h3>Side-effects:</h3>
--
-- If items cannot be found, an error is printed to STDERR.
--
-- <h3>Caveats:</h3>
--
-- See @{file_write}.
--
-- @string fname The name of the bibliography file.
-- @param handle A interface to Zotero or the Zotero Web API.
-- @tab ckeys The citation keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
-- @treturn[1] bool `true` if the file was updated or no update was required.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is a file I/O error.
-- @raise See @{http_get}.
-- @function biblio_update
biblio_update = typed('string', 'table', 'table')(
    function (fname, handle, ckeys)
        local ok, err, errno, ret, fmt, items
        assert(fname ~= '', 'filename is the empty string')
        if #ckeys == 0 then return true end
        -- @fixme This is a use-case for a named error!
        -- Just do it and see if it errors out!
        fmt, err = biblio_write(fname, {})
        if not fmt then return nil, err end
        items, err, errno = biblio_read(fname)
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
                ok, ret, err = pcall(handle.get_item, handle, ckey)
                if not ok then
                    return nil, tostring(ret)
                elseif ret then
                    if fmt == 'yaml' or fmt == 'yml' then
                        ret = apply(zotero_to_markdown, ret)
                    end
                    n = n + 1
                    items[n] = ret
                else
                    log(err)
                end
            end
        end
        if n == nitems then return true end
        fmt, err, errno = biblio_write(fname, items)
        if not fmt then return nil, err, errno end
        return true
    end
)


----------------
-- Configuration
-- @section

--- A configuration parser.
-- @fixme
Settings = Prototype()

--- A mapping of configuration setting names to specifications.
--
-- <h3>Caveats:</h3>
--
-- @fixme
Settings.specs = {}

--- A prefix for configuration setting names.
--
-- @fixme
Settings.prefix = 'zotero'


do
    -- A mapping of configuration value types to parers.
    local converters = {}

    -- Convert a value to a Lua String.
    --
    -- @param val A value.
    -- @treturn[1] string A string.
    -- @treturn[2] nil `nil` if the value cannot be coerced to a string.
    -- @treturn[2] string An error message.
    -- @fixme Test if we cannot let stringify do all of the work.
    function converters.string (val)
        local ok, str
        ok = true
        if     type(val) == 'string' then     str = val
        elseif elem_type(val)        then ok, str = pcall(stringify, val)
                                     else     str = tostring(val)
        end
        if not ok or type(str) ~= 'string' or str == '' then
            return nil, 'unparsable.'
        end
        return str
    end

    -- Convert plain values to single-item lists.
    --
    -- Tables are passed through as is.
    --
    -- @param val A value or list of values.
    -- @treturn tab A list of values.
    function converters.array (val)
        if type(val) == 'table' then return val end
        return {val}
    end

    -- Convert a configuration value to the given type.
    --
    -- @param val A value.
    -- @string tspec A type specification.
    -- @raise Conversion errors or wrong type spec.
    -- @fixme can multiple raises be used?
    local function conv (val, tspec)
        local t
        assert(type(tspec) == 'string', 'expecting a string.')
        t, tspec = tabulate(split(trim(tspec), '%s*<%-%s*', 2))
        assert(t and t ~= '', 'cannot parse type specification.')
        local f = converters[t]
        assert(f, t .. ': no such type.')
        local r, err = f(val)
        if r == nil then return nil, err end
        if not tspec then
            if t ~= 'array' then return r end
            tspec = 'string'
        end
        local function rconv (x) return conv(x, tspec) end
        return apply(rconv, r)
    end

    -- @fixme Undocumented.
    function Settings:define (args)
        assert(args, 'expecting arguments.')
        assert(type(args) == 'table', 'expecting a table.')
        local name = args.name
        assert(type(name) == 'string', 'name: not a string.')
        assert(name ~= '', 'name: is the empty string.')
        local test = args.test
        assert(not test or type(test) == 'function', 'test: not a function.')
        local opt = args.opt
        assert(not opt or type(opt) == 'boolean', 'opt: not boolean.')
        if not rawget(self, 'specs') then self.specs = {} end
        self.specs[name] = {
            type = args.type or 'string',
            test = test,
            opt = opt
        }
    end

    -- @fixme Undocumented.
    function Settings:parse (meta)
        local conf = {}
        for name, spec in pairs(self.specs) do
            local k = self.prefix .. '-' .. name:gsub('_', '-')
            if meta[k] then
                local v, err
                for i = 1, 2 do
                    if     i == 1 then v, err = conv(meta[k], spec.type)
                    elseif i == 2 then v, err = spec.test(v)
                    end
                    if not spec.test then break end
                end
                assert(v, ConfigError{field = k, error = err})
                conf[name] = v
            else
                assert(spec.opt, ConfigError{field = k, error = 'not set.'})
            end
        end
        return conf
    end
end


--------------------
-- Zotero connectors
-- @section

--- Interface to [zotxt](https://github.com/egh/zotxt).
--
-- @proto Zotxt
-- @usage
--      > handle = Zotxt()
--      > handle.citekey_types = pandoc.List{'betterbibtexkey'}
--      > csl_item = handle:get_item 'name2019TwoWords'
Zotxt = Prototype()

--- What types of citation keys to expect.
Zotxt.citekey_types = List {
    'betterbibtexkey',  -- Better BibTeX citation key
    'easykey',          -- zotxt easy citekey
    'key',              -- Zotero item ID
}

Zotxt.settings = Settings()

do
    Zotxt.settings:define{
        name = 'citekey_types',
        type = 'array',
        test = function (array)
            for i = 1, #array do
                if not Zotxt.citekey_types:includes(array[i]) then
                    return nil, array[i] .. ': not a citation key type.'
                end
            end
            return array
        end,
        opt = true
    }
end

-- @fixme
function Zotxt:configure (meta)
    local conf = self.settings:parse(meta)
    for k, v in pairs(conf) do self[k] = v end
    return true
end

do
    -- Shorthands.
    -- luacheck: ignore assert pcall tostring type
    local assert = assert
    local pcall = pcall
    local tostring = tostring
    local type = type

    -- URL of the endpoint to look up items at.
    local items_url = 'http://localhost:23119/zotxt/items'

    --- Retrieve a CSL item from zotxt.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See @{http_get}.
    function Zotxt:get_item (ckey)
        assert(type(ckey) == 'string', 'expecting a string.')
        assert(ckey ~= '', 'citation key is the empty string.')
        local citekey_types = self.citekey_types
        local err = nil
        for i = 1, #citekey_types do
            -- zotxt supports searching for multiple citation keys at once,
            -- but if a single one cannot be found, it replies with a cryptic
            -- error message (for Easy Citekeys) or an empty response
            -- (for Better BibTeX citation keys).
            local mt, str = url_query(items_url, {[citekey_types[i]] = ckey})
            if not mt or mt == '' then
                err = ckey .. ': response has no MIME type.'
            elseif not str or str == '' then
                err = ckey .. ': response is empty.'
            elseif not mt:match '^text/plain%f[%A]' then
                err = ckey .. ': response is of wrong type ' .. mt .. '.'
            elseif not mt:match ';%s*charset="?[Uu][Tt][Ff]%-?8"?%s*$' then
                err = ckey .. ': response is not encoded in UTF-8'
            else
                local data = csl_json_to_item(str)
                if data then
                    local n = #data
                    if n == 1 then
                        if i ~= 1 then
                            citekey_types[1], citekey_types[i] =
                            citekey_types[i], citekey_types[1]
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
end

--- Interface to [Zotero's Web API](https://www.zotero.org/support/dev/web_api)
--
-- @proto ZotWeb
-- @usage
--      > handle = ZotWeb{api_key = 'alongstringoflettersandnumbers'}
--      > handle.citekey_types = pandoc.List{'betterbibtexkey'}
--      > csl_item = handle:get_item 'name2019TwoWords'
ZotWeb = Zotxt()

--- What types of citation keys to expect.
ZotWeb.citekey_types = List {
    -- 'easykey' must go first, because it is unlikely that that the Easy
    -- Citekey parser parses a Better BibTeX citation key (most BetterBibTeX
    -- citation keys don't contain colons), but the BetterBibTeX citation key
    -- parser will happily parse an Easy Citekey, and it will do it wrong.
    'easykey',          -- zotxt Easy Citekey
    'key',              -- Zotero item ID
    'betterbibtexkey',  -- Better BibTeX citation key
}

-- @fixme Why can't I just have own prototype with Zotxt.settings()?
-- that should create a like object.
ZotWeb.settings = copy(Zotxt.settings)

do
    ZotWeb.settings:define{name = 'api_key', opt = true}
    ZotWeb.settings:define{name = 'user_id', opt = true}
    ZotWeb.settings:define{name = 'groups', type = 'array', opt = true}
    ZotWeb.settings:define{name = 'public_groups', type = 'array', opt = true}
end


do
    -- Shorthands.
    local len = utf8.len
    local decode = json.decode

    -- Zotero Web API base URL.
    local base_url = 'https://api.zotero.org'

    -- URL template for user ID lookups.
    local user_id_url = base_url .. '/keys/$api_key'

    -- URL template for group membership lookups.
    local groups_url = base_url .. '/users/$user_id/groups'

    -- User prefix.
    local user_prefix = '/users/$user_id'

    -- Group prefix.
    local group_prefix = '/groups/$group_id'

    -- URL template for item lookups.
    local items_url = base_url .. '$prefix/items/$id'

    --- Retrieve and parse data from the Zotero Web API.
    --
    -- @string url An endpoint URL.
    -- @tab params A mapping of request parameter names to values
    --  (e.g., `{v = 3, api_key = 'longstringoflettersandnumbers'}`).
    -- @return[1] The response of the Zotero Web API.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `http_get`
    local function zotero_query (url, params)
        local mt, str = url_query(url, params)
        if not mt or mt == '' then
            return nil, 'response has no MIME type.'
        elseif not str or str == '' then
            return nil, 'response is empty.'
        elseif mt:match '%f[%a]json%f[%A]' then
            return str
        elseif not mt:match '^text/' then
            return nil, 'response is of wrong type ' .. mt .. '.'
        elseif not mt:lower():match ';%s*charset="?utf%-?8"?%s*$' then
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
    local function is_zotero_id (str)
        if len(str) == 8 and str:match '^[%u%d]+$' then return true end
        if str == '' then return nil, 'item ID is the empty string.' end
        return nil, str .. ': not an item ID.'
    end

    --- Filter items by their citation key.
    --
    -- @tab items A list of CSL items.
    -- @string ckey A citation key.
    -- @treturn A list of those items that have that citation key.
    local function filter_by_ckey (items, ckey)
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

    --- Get the user ID for the given API key.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Sets `ZotWeb.user_id`.
    --
    -- @treturn string A Zotero user ID.
    -- @raise An error if the `api_key` field is not set, the Zotero Web API
    --  could not be reached, or if no Zotero user ID could be found.
    --  See `http_get` for details on the second error.
    function ZotWeb:get_user_id ()
        if self.user_id then return self.user_id end
        assert(self.api_key, UserIDLookupError{err = 'no Zotero API key set'})
        local ep = expand_vars(user_id_url, self)
        local str, err = zotero_query(ep, {v = 3})
        assert(str, UserIDLookupError{err = err})
        local ok, data = pcall(decode, str)
        assert(ok, UserIDLookupError{err = 'cannot parse response: ' .. str})
        local user_id = data.userID
        assert(user_id, UserIDLookupError{err = 'no user ID found'})
        self.user_id = user_id
        return user_id
    end

    --- Get the IDs of the groups the current user is a member of.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Sets `ZotWeb.groups`.
    --
    -- @treturn {string, ...} A list of Zotero group IDs.
    -- @raise An error if the `api_key` field is not set, the Zotero Web API
    --  could not be reached, or if the API response cannot be parsed.
    --  See `http_get` for details on the second error.
    -- @fixme @raise is inconsistent with others.
    function ZotWeb:get_groups ()
        if self.groups then return self.groups end
        assert(self.api_key, GroupLookupError{err = 'no Zotero API key set.'})
        local ep = expand_vars(groups_url, {user_id = self:get_user_id()})
        local str, err = zotero_query(ep, {v = 3, key = self.api_key})
        assert(str, GroupLookupError{err = err})
        local ok, data = pcall(decode, str)
        assert(ok, GroupLookupError{err = 'cannot parse response: ' .. str})
        local groups = Values()
        for i = 1, #data do
            if data[i] and data[i].data and data[i].data.id then
                groups:add(data[i].data.id)
            end
        end
        self.groups = groups
        return groups
    end

    --- Iterate over item endpoint URLs.
    --
    -- @string[opt] id A Zotero item ID.
    -- @treturn func A *stateful* iterator.
    function ZotWeb:endpoints (id)
        if not id then id = '' end
        assert(type(id) == 'string', 'expecting a string.')
        assert(id == '' or is_zotero_id(id))
        local n, groups
        local i = -1
        return function ()
            i = i + 1
            if i == 0 then
                if self.api_key then
                    return expand_vars(items_url, {
                        prefix = user_prefix,
                        user_id = self:get_user_id(),
                        id = id
                    })
                end
            else
                if not n then
                    groups = List()
                    if self.api_key then
                        groups:extend(self:get_groups())
                    end
                    if self.public_groups then
                        groups:extend(self.public_groups)
                    end
                    n = #groups
                end
                if i > n then return end
                return expand_vars(items_url, {
                    prefix = group_prefix,
                    group_id = groups[i],
                    id = id
                })
            end
        end
    end

    --- Search items by their author, publication year, and title.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string ... Search terms.
    -- @treturn[1] tab A list of CSL items that match the given search terms.
    -- @treturn[2] nil `nil` if no items were found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] An error message.
    -- @raise See `ZotWeb:get_user_id` and `ZotWeb:get_groups`.
    function ZotWeb:search (...)
        local q = concat({...}, '+')
        local params = {v = 3, key = self.api_key,
                        q = q, qmode = 'titleCreatorYear',
                        format ='csljson', itemType='-attachment'}
        for ep in self:endpoints() do
            local str, data, items, err
            str, err = zotero_query(ep, params)
            if not str then return nil, err end
            data, err = csl_json_to_item(str)
            if not data then return nil, err end
            items = data.items
            if items and #items > 0 then return items end
        end
        return nil, 'no matches.', 0
    end

    --- Searches for a CSL item that matches a citation key.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Search terms are printed to STDERR
    -- if the user has requested more output.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if less or more than one item was found or
    --  if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `ZotWeb:get_user_id` and `ZotWeb:get_groups`.
    function ZotWeb:match (ckey)
        local terms, items, n, err
        assert(type(ckey) == 'string', 'expecting a string.')
        assert(ckey ~= '', 'citation key is the empty string.')
        terms, err = ckey_guess_terms(ckey, self.citekey_types)
        if not terms then return nil, err end
        info('$ckey: searching for: ' .. concat(terms, ', '))
        items, err = self:search(unpack(terms))
        if not items then return nil, ckey .. ': ' .. err end
        n = #items
        if n == 0 then
            return nil, ckey .. ': no matches.'
        elseif n > 1 then
            items = filter_by_ckey(items, ckey)
            if not items or items.n == 0 then
                return nil, ckey .. ': too many matches.'
            elseif items.n > 1 then
                return nil, 'citation key ' .. ckey .. ': not unique.'
            end
        end
        return items[1]
    end

    --- Look up a CSL item by its Zotero ID.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string id A Zotero item ID.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if no or more than one item has been found.
    -- @treturn[2] string An error message.
    -- @raise See `ZotWeb:get_user_id` and `ZotWeb:get_groups`.
    function ZotWeb:lookup (id)
        assert(type(id) == 'string', 'expecting a string.')
        assert(is_zotero_id(id))
        local params = {v = 3, key = self.api_key,
                        format ='csljson', itemType='-attachment'}
        for ep in self:endpoints(id) do
            local str = zotero_query(ep, params)
            if str then
                local data, err = csl_json_to_item(str)
                if not data then return nil, err end
                local items = data.items
                if items then
                    local n = #items
                    if n == 1 then
                        return items[1]
                    elseif n > 1 then
                        return nil, 'item ID ' .. id .. ': is not unique.'
                    end
                end
            end
        end
        return nil, 'no matches.', 0
    end

    --- Retrieve a CSL item from Zotero.
    --
    -- <h3>Side-effects:</h3>
    --
    -- Search terms for citation keys are printed to STDERR
    -- if the user has requested more output.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `ZotWeb:get_user_id` and `ZotWeb:get_groups`.
    function ZotWeb:get_item (ckey)
        assert(type(ckey) == 'string', 'expecting a string.')
        assert(ckey ~= '', 'citation key is the empty string.')
        local item, err
        if self.citekey_types:includes 'key' and is_zotero_id(ckey)
            then item, err = self:lookup(ckey)
            else item, err = self:match(ckey)
        end
        if not item then return nil, err end
        item.id = ckey
        return csl_item_parse_extras(item)
    end

    --- Configure the connector.
    --
    -- See `Zotxt:configure` for details.
    --
    -- @tparam pandoc.MetaMap meta A Pandoc metadata block.
    function ZotWeb:configure (meta)
        Zotxt.configure(self, meta)
        -- @fixme Not nice.
        assert(self.api_key or self.public_groups,
               Error{error = 'no Zotero API key and no public Zotero groups given.'})
    end
end


-------------------
-- Document parsing
--
-- @section

do
    local super_types = {
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

    --- The type of a Pandoc AST element.
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn[1] string Type
    --  (e.g., 'MetaMap', 'Plain').
    -- @treturn[1] string Super-type
    --  (i.e., 'Block', 'Inline', or 'MetaValue').
    -- @treturn[1] string 'AstElement'.
    -- @treturn[2] nil `nil` if `elem` is not a Pandoc AST element.
    -- @treturn[2] string An error message.
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
                et = super_types[et]
            end
            if ets.n > 0 then return unpack(ets) end
        end
        return nil, 'not a Pandoc AST element.'
    end

    -- @fixme It's unclear whether this code ignores pandoc.Doc
    --        in favour of pandoc.Pandoc (as it should) in Pandoc <v2.15.
    if pandoc.types and PANDOC_VERSION < {2, 15} then
        -- luacheck: ignore super_types
        local super_types = {}

        for k, v in sorted(pandoc) do
            if type(v) == 'table' and not super_types[v] and k ~= 'Doc' then
                local t = {k}
                local mt = getmetatable(v)
                n = 1
                while mt and n < 16 do
                    if not mt.name or mt.name == 'Type' then break end
                    n = n + 1
                    t[n] = mt.name
                    mt = getmetatable(mt)
                end
                if t[n] == 'AstElement' then super_types[v] = t end
            end
        end

        function elem_type (elem)
            if type(elem) == 'table' then
                local mt = getmetatable(elem)
                if mt and mt.__type then
                    local ets = super_types[mt.__type]
                    if ets then return unpack(ets) end
                end
            end
            return nil, 'not a Pandoc AST element.'
        end
    end
end

do
    local clone

    -- Clone a Pandoc AST element.
    --
    -- @tparam pandoc.AstElement elem An original.
    -- @treturn pandoc.AstElement The copy.
    clone = function (elem)
        if elem.clone then return elem:clone() end
        return Pandoc(elem.blocks:clone(), elem.meta:clone())
    end

    -- @fixme This has not been tested for Pandoc <v2.15.
    if pandoc.types and PANDOC_VERSION < {2, 15} then
        clone = function (elem)
            if elem.clone then return elem:clone() end
            local copy = setmetatable({}, getmetatable(elem))
            for k, v in next, elem, nil do rawset(copy, k, v) end
            return copy
        end
    end

    -- Walk a Lua table.
    local function walk_table (tab, ...)
        for k, v in pairs(tab) do tab[k] = walk(v, ...) end
    end

    --- Walk a *List AST element (e.g., `pandoc.OrderedList`).
    local function walk_list_elem (elem, ...)
        local content = elem.content
        for i = 1, #content do walk_table(content[i], ...) end
    end

    -- Walk a document.
    function walk_doc (doc, ...)
        doc.meta = walk(doc.meta, ...)
        walk_table(doc.blocks, ...)
    end

    -- Walking functions by Pandoc AST element type.
    local walker_fs = {
        Meta = walk_table,
        MetaBlocks = walk_table,
        MetaList = walk_table,
        MetaInlines = walk_table,
        MetaMap = walk_table,
        BulletList = walk_list_elem,
        OrderedList = walk_list_elem,
        Pandoc = walk_doc
    }

    --- Walk the AST and apply functions to matching elements.
    --
    -- Differs from `pandoc.walk_block` and `pandoc.walk_inline` by never
    -- modifying the original element, by accepting AST elements of *any*
    -- type (including documents as a whole, the metadata block, and metadata
    -- fields), by accepting the higher-order type `AstElement`, by *not*
    -- accepting the filter keywords `Blocks` and `Inlines`, by walking
    -- the AST bottom-up (which implies that the filter is applied to every
    -- element, regardless of whether any of that elements's ancestors
    -- matches), by applying the filter to the given element itself, and by
    -- allowing the functions in the filter to return data of arbitrary types
    -- (as opposed to either a Pandoc AST element or `nil`).
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @tparam {string=func,...} filter A filter.
    -- @return The element, with the filter applied.
    walk = typed('*', 'table', '?number')(
        function (elem, filter, _rd)
            if not _rd then _rd = 0 end
            assert(_rd < 128, 'recursion limit exceeded.')
            local ets = {elem_type(elem)}
            local et = ets[1]
            if not et then return elem end
            elem = clone(elem)
            _rd = _rd + 1
            local walker_f = walker_fs[et]
            if     walker_f     then walker_f(elem, filter, _rd)
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


--- Collect bibliographic data from the document's metadata block.
--
-- <h3>Side-effects:</h3>
--
-- Prints errors to STDERR if a metadata field or a
-- bibliography file cannot be parsed.
--
-- @tparam pandoc.MetaMap meta A metadata block.
-- @treturn pandoc.List A list of CSL items.
-- @function meta_sources
meta_sources = typed('table|userdata')(
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
                log 'cannot parse metadata field "bibliography".'
                return data
            end
            for i = 1, #fnames do
                local fname, err = file_locate(fnames[i])
                if fname then
                    -- luacheck: ignore err
                    local items, err = biblio_read(fname)
                    if items then data:extend(items)
                             else log(err)
                    end
                else
                    log(err)
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
    -- @tab old A [set](https://www.lua.org/pil/11.5.html) of IDs
    --  that should be ignored.
    -- @tab new The set to save the IDs in.
    local function ids (cite, old, new)
        local citations = cite.citations
        for i = 1, #citations do
            local id = citations[i].id
            if id and not old[id] then new[id] = true end
        end
    end

    --- Collect the citation keys used in a document.
    --
    -- <h3>Side-effects:</h3>
    --
    -- See @{meta_sources}.
    --
    -- @tab doc A document.
    -- @bool[opt=false] undef Whether to collect only the citation keys of
    --  sources that are defined neither in the `references` metadata field
    --  nor in a bibliography file.
    -- @treturn {string,...} A list of citation keys.
    -- @treturn int The number of citation keys found.
    -- @raise An error if an item ID is of a wrong data type.
    -- @function doc_ckeys
    doc_ckeys = typed('table|userdata', '?boolean')(
        function (doc, undef)
            local meta = doc.meta
            local blocks = doc.blocks
            local old = {}
            local new = {}
            if undef then old = csl_items_ids(meta_sources(meta)) end
            local flt = {Cite = function (cite) return ids(cite, old, new) end}
            if meta then
                for k, v in pairs(meta) do
                    if k ~= 'references' then walk(v, flt) end
                end
            end
            for i = 1, #blocks do pandoc.walk_block(blocks[i], flt) end
            return keys(new)
        end
    )
end


-------
-- Main
--
-- @section

do
    local settings = Settings()
    settings:define{name = 'bibliography', opt = true}

    --- Add data to a bibliography file and the file to the document's metadata.
    --
    -- Updates the bibliography file as needed and adds it to the `bibliography`
    -- metadata field. Interpretes a relative filename as relative to the
    -- directory of the first input file passed to **pandoc**, or, if not input
    -- files were given, as relative to the current working directory.
    --
    -- <h3>Side-effects:</h3>
    --
    -- If a source cannot be found, an error is printed to STDERR.
    --
    -- <h3>Caveats:</h3>
    --
    -- See @{file_write}.
    --
    -- @fixme Documentation is bit iffy.
    -- @param handle A interface to Zotero or the Zotero Web API.
    -- @tparam pandoc.Pandoc doc A Pandoc document, with the metadata field
    --  `zotero-bibliography` set to the filename of the bibliography file.
    -- @treturn[1] pandoc.Meta An updated metadata block, with the field
    --  `bibliography` added if needed.
    -- @treturn[2] nil `nil` if no sources were found,
    --  `zotero-bibliography` is not set, or an error occurred.
    -- @treturn[2] string An error message, if applicable.
    -- @raise A @{ConfigError} if `zotero-bibliography` cannot be parsed.
    --  See also @{http_get}.
    -- @function add_biblio
    add_biblio = typed('table', 'table|userdata')(
        function (handle, doc)
            local ckeys = doc_ckeys(doc, true)
            if #ckeys == 0 then return end
            local meta = doc.meta
            local fname = settings:parse(meta).bibliography
            if not fname then return end
            if not path_is_abs(fname) then fname = path_join(wd(), fname) end
            local ok, err = biblio_update(fname, handle, ckeys)
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
end

--- Add bibliographic data to the `references` metadata field.
--
-- <h3>Side-effects:</h3>
--
-- If a source cannot be found, an error is printed to STDERR.
--
-- @param handle A interface to Zotero or the Zotero Web API.
-- @tparam pandoc.Pandoc doc A Pandoc document.
-- @treturn[1] table An updated metadata block,
--  with the field `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See @{http_get}.
-- @function add_refs
add_refs = typed('table', 'table|userdata')(
    function (handle, doc)
        local ckeys = doc_ckeys(doc, true)
        local meta = doc.meta
        if #ckeys == 0 then return end
        if not meta.references then meta.references = MetaList({}) end
        local n = #meta.references
        for i = 1, #ckeys do
            local ok, ret, err = pcall(handle.get_item, handle, ckeys[i])
            if     not ok then return nil, tostring(ret)
            elseif ret    then n = n + 1
                               meta.references[n] = csl_item_to_meta(ret)
                          else log(err)
            end
        end
        return meta
    end
)

do
    local settings = Settings()
    settings:define{name = 'bibliography', opt = true}
    settings:define{
        name = 'connectors',
        type = 'array',
        test = function (vs)
            local cs = Values()
            for i = 1, #vs do
                local v = vs[i]
                if  not v:match '^%u[%w_]+$' or
                    not M[v]                 or
                    not M[v].get_item
                then
                    return nil, v .. ': no such Zotero connector.'
                end
                cs:add(M[v])
            end
            return cs
        end,
        opt = true
    }

    --- Collect citations and add bibliographic data to a document.
    --
    -- See the manual for details.
    --
    -- <h3>Side-effects:</h3>
    --
    -- If errors occur, error messages are printed to STDERR.
    --
    -- @tparam table doc A document.
    -- @treturn[1] table `doc`, but with bibliographic data added.
    -- @treturn[2] nil `nil` if nothing was done or an error occurred.
    -- @raise See @{http_get}.
    function main (doc)
        local conf = settings:parse(doc.meta)

        local cs = conf.connectors
        if not cs then
            cs = Values{Zotxt()}
            if conf.api_key or conf.public_groups then cs:add(ZotWeb()) end
        end

        local n = #cs
        for i = 1, n do
            local handle = cs[i]
            if handle.configure then handle:configure(doc.meta) end
        end

        local add_srcs = add_refs
        if conf.bibliography then add_srcs = add_biblio end

        local chg = false
        for i = 1, n do
            local handle = cs[i]
            local meta, err = add_srcs(handle, doc)
            if meta then
                doc.meta = meta
                chg = true
            elseif err then
                log(err)
            end
        end
        if chg then return doc end
    end
end


-- BOILERPLATE
-- ===========
--
-- Returning the whole script, rather than only a list of mappings of
-- Pandoc data types to functions, allows to do unit testing.

M[1] = {Pandoc = main}

return M