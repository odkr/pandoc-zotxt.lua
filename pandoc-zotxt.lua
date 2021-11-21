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
-- by Better BibTeX for Zotero) or "easy citekeys" (provided by zotxt). Then,
-- while Zotero is running, tell **pandoc** to filter your document through
-- **pandoc-zotxt.lua** before processing citations. That's all there is to it.
--
-- If a document's "references" metadata field or a bibliography file already
-- has bibliographic data for a citation, that citation will be ignored.
--
--
-- BIBLIOGRAPHY FILES
-- ==================
--
-- **pandoc-zotxt.lua** can add bibliographic data to a bibliography file,
-- rather than to the "references" metadata field. This speeds up subsequent
-- processing of the same document, because that data need not be fetched
-- again from Zotero.
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
-- "Better BibTeX citation keys", "easy citekeys" and Zotero item IDs.
--
-- However, it may happen that a Better BibTeX citation key is interpreted as
-- an easy citekey *and* yet picks out an item, if not the one that it
-- actually is the citation key of. That is to say, citation keys may be
-- matched with the wrong bibliographic data.
--
-- If this happens, you can disable citation keys by setting the
-- "zotero-citekey-types" metadata field to the citation key type or to the
-- list of citation key types that you actually use.
--
-- You can set the following citation key types:
--
-- | **Key**           | **Type**                   | **Comments** |
-- | ----------------- | -------------------------- | ------------ |
-- | `betterbibtexkey` | Better BibTeX citation key | -            |
-- | `easykey`         | easy citekey               | Deprecated.  |
-- | `key`             | Zotero item ID             | Hard to use. |
--
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
-- The above will look up "doe2020Title" in Zotero.
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-bibliography: bibliography.json
--     ...
--     See @doe2020Title for details.
--     EOF
--
--
-- The above will look up "doe2020Title" in Zotero and save its bibliographic
-- data into the file "bibliography.json" in the current working directory. If
-- the same command is run again, "doe2020Title" will *not* be looked up again.
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     ---
--     zotero-citekey-types: betterbibtexkey
--     ...
--     See @doe2020Title for details.
--     EOF
--
--
-- The above forces **pandoc-zotxt.lua** to interpret "doe2020Title" as a
-- Better BibTeX citation key.
--
--
-- KNOWN ISSUES
-- ============
--
-- Citation keys may, on rare occassions, be matched with the wrong Zotero
-- item. This happens if a citation key picks out a different record depending
-- on whether it is interpreted as a Better BibTeX citation key or as an easy
-- citekey. See **CITATION KEY TYPES** above on how to fix this.
--
-- **pandoc-zotxt.lua** creates a temporary file when it adds sources to a
-- bibliography file. If Pandoc exits because it catches a signal (e.g.,
-- because you press `Ctrl`-`c`), then this file will *not* be deleted. This
-- is a bug in Pandoc and in the process of being fixed. Moreover, if you are
-- using Pandoc up to v2.7, another process may, mistakenly, use the same
-- temporary file at the same time, though this is highly unlikely.
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that do not set the "User Agent" HTTP header. And **pandoc** does not. As a
-- consequence, **pandoc-zotxt.lua** cannot retrieve data from these versions
-- of Zotero unless you tell **pandoc** to set that header.
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

-- luacheck: allow defined top


-- INITIALISATION
-- ==============

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
local unpack = table.unpack
local stringify = pandoc.utils.stringify
local List = pandoc.List
local MetaInlines = pandoc.MetaInlines
local MetaList = pandoc.MetaList
local MetaMap = pandoc.MetaMap
local Str = pandoc.Str
local Span = pandoc.Span
local Pandoc = pandoc.Pandoc


-- Metadata
-- --------

--- The name of this script.
-- @within Metadata
NAME = 'pandoc-zotxt.lua'

--- The version of this script.
-- @within Metadata
VERSION = '1.1.0b4'


-- Operating system
-- ----------------

--- The path segment seperator of your OS.
-- @within File I/O
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence of your OS.
-- @within File I/O
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- Path operations
-- ---------------

--- Check if values could represent path segments.
--
-- @string ... Values.
-- @treturn[1] boolean `true` if the values could represent path segments.
-- @treturn[2] nil `nil` otherwise.
-- @treturn[3] string An error message.
-- @within File I/O
-- @fixme No unit test.
function path_verify (val, ...)
    if type(val) ~= 'string' then
        return nil, 'path is not a string.'
    elseif val == '' then
        return nil, 'path is the empty string.'
    elseif ... then
        return path_verify(...)
    end
    return true
end

do
    -- Patterns that sanitise directory paths.
    -- Note, the order of these patterns is significant.
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
    -- @raise An error if no path is given or if the path is the empty string.
    -- @within File I/O
    function path_sanitise (path)
        assert(path_verify(path))
        for i = 1, #sanitisation_patterns do
            local pattern, repl = unpack(sanitisation_patterns[i])
            path = path:gsub(pattern, repl)
        end
        return path
    end
end

do
    -- Pattern to split a path into a directory and a filename part.
    local split_pattern = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'

    --- Split a path into a directory and a filename.
    --
    -- @string path The file's path.
    -- @treturn string The directory the file is in.
    -- @treturn string The file's name.
    -- @raise An error if no path is given or if the path is the empty string.
    -- @within File I/O
    function path_split (path)
        assert(path_verify(path))
        local dir, fname = path:match(split_pattern)
        if     dir == ''   then dir = '.'
        elseif fname == '' then fname = '.' end
        return path_sanitise(dir), fname
    end
end

--- Join multiple path segments.
--
-- @string ... Path segments.
-- @treturn string The complete path.
-- @raise An error if no path segments are given or if
--  a path segment is the empty string.
-- @within File I/O
function path_join (...)
    assert(path_verify(...))
    return path_sanitise(concat({...}, PATH_SEP))
end


-- Modules
-- -------

do
    local script_dir, script_name = path_split(PANDOC_SCRIPT_FILE)

    --- The directory the script is in.
    -- @within Metadata
    SCRIPT_DIR = script_dir

    --- The filename of the script.
    -- @within Metadata
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


-- PROTOTYPES
-- ==========

--- Prototype for prototypes.
--
-- @type Prototype
-- @usage
--      > ObjA = Prototype()
--      > mt = getmetatable(ObjA)
--      > function mt:__tostring ()
--      >     return 'a string'
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
--      a string
Prototype = {}

--- Metatable for prototypes.
Prototype.mt = {}
setmetatable(Prototype, Prototype.mt)

--- Delegate to a prototype.
--
-- Sets the table's metatable to a copy of the prototype's metatable
-- and then sets the metatable's `__index` field to the prototype.
--
-- @tab tab A table.
-- @treturn tab A prototype.
function Prototype.mt:__call (tab)
    if not tab then tab = {} end
    local mt = {}
    for k, v in pairs(getmetatable(self)) do mt[k] = v end
    mt.__index = self
    return setmetatable(tab, mt)
end

--- Prototype for errors.
--
-- @type Error
-- @usage
--      FileOpenError = Error { message = 'failed to open $file.' }
Error = Prototype()

--- Default for error messages.
Error.message = 'something went wrong.'

--- Metatable for errors.
Error.mt = getmetatable(Error)

--- Convert an error into a string.
--
-- If the message contains variable names, they are replaced with the values
-- of the fields with those names. See `exapnd vars` for the syntax.
--
-- @usage
--      > err = Error {
--      >     message = 'Semething went $severity wrong.',
--      >     severity = 'terribly'
--      > }
--      > assert(false, err{severity = 'slightly'})
--      Something went slightly wrong.
--
-- @treturn string The error message.
function Error.mt:__tostring ()
    return expand_vars(self.message, self)
end

--- Prototype for connection errors.
--
-- @type ConnectionError
-- @usage
--      > ok, mt, data = pcall(pandoc.mediabag.fetch, url)
--      > assert(ok, ConnectionError{host = url})
ConnectionError = Error()

--- Error message for connection errors.
ConnectionError.message = 'failed to connect to $host.'

--- Stand-in value for the host.
ConnectionError.host = '<unspecified host>'

--- Prototype for Zotero user ID lookup errors.
--
-- @type UIDLookupError
-- @usage
--      > ok, data = pcall(json.decode, str)
--      > assert(ok, UIDLookupError{err = 'failed to parse: ' .. str})
UIDLookupError = Error()

--- Error message for user ID lookup errors.
UIDLookupError.message = 'Zotero user ID lookup: $err.'

--- Stand-in value for the error.
UIDLookupError.err = 'something went wrong.'

--- Prototype for Zotero group lookup errors.
--
-- @type GroupLookupError
-- @usage
--      > ok, data = pcall(json.decode, str)
--      > assert(ok, GroupLookupError{err = 'failed to parse: ' .. str})
GroupLookupError = Error()

--- Error message for user ID lookup errors.
GroupLookupError.message = 'Zotero group lookup: $err.'

--- Stand-in value for the error.
GroupLookupError.err = 'something went wrong.'


-- FUNCTIONS
-- =========

-- Warnings
-- --------

--- Print a value to STDERR.
--
-- `SCRIPT_NAME` and ': ' are printed before and `EOL` after the value.
--
-- If the value is a string and contains variable names, they are replaced
-- with the values of those variables as seen by the calling function.
-- See `expand_vars` for the syntax.
--
-- If the value is of another type, it is coerced to a string before printing.
--
-- @param val The value.
-- @within Warnings
function log (val, _lvl)
    local msg
    if type(val) == 'string' then
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
-- @string val The value.
-- @within Warnings
function warn (val)
    if PANDOC_STATE.verbosity ~= 'ERROR' then log(val, 4) end
end

--- Print a value to STDERR if the user has requested more output.
--
-- The value is only printed if `PANDOC_STATE.verbosity` is 'INFO'.
-- Otherwise the same as `log`.
--
-- @string val The value.
-- @within Warnings
function info (val)
    if PANDOC_STATE.verbosity == 'INFO' then log(val, 4) end
end


-- Meta-programming
-- ----------------

--- Get the variables a function can access.
--
-- @int[opt=2] lvl A stack level, where
--  1 points to the current function (i.e., `vars`),
--  2 to that function's caller, and so on.
-- @treturn table A mapping of variable names to values.
-- @raise An error if there is no function at the given stack level.
-- @within Meta-programming
function vars (lvl)
    if not lvl then lvl = 2 end
    local vars = {}

    for k, v in pairs(_ENV) do vars[k] = v end

    local info = debug.getinfo(lvl)
    if not info then return nil, lvl .. ': no such function.' end
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
        local k, v = debug.getlocal(lvl, i)
        if not k then break end
        vars[k] = v
        i = i + 1
    end

    return vars
end


-- Higher-order functions
-- ----------------------

--- Run cleanup code after a function.
--
-- The cleanup code runs regardless of whether an error occurs. However, Lua
-- filters cannot respond to signals, so it is *not* run if Pandoc exits
-- because it catches a signal.
--
-- @func ex The cleanup code. Its first argument indicates whether
--  the protected call to `func` exited with an error. The remaining
--  arguments are the values returned by `func`.
-- @func func The code itself. Called in protected mode.
-- @param ... Passed on to `func`.
-- @return What the given functions returns.
-- @within Higher-order functions
function do_after (ex, func, ...)
    local vs = {pcall(func, ...)}
    ex(unpack(vs))
    local ok, err = unpack(vs, 1, 2)
    if not ok then error(err) end
    return unpack(vs, 2)
end


-- Strings
-- -------

--- Iterate over substrings of a string.
--
-- @string str The string.
-- @string pattern A pattern that matches the sequence of characters that
--  separates substrings. Must *not* contain frontier patterns (`%f`).
-- @int[opt] max Split up the string into at most that many substrings.
-- @string[opt] inc Whether to include the seperator in the substring.
--  `l` includes the seperator on the left, `r` on the right.
--  By default, the seperator is *not* included.
-- @treturn func A *stateful* iterator.
-- @usage
--      > for s in split('CamelCase', '%u', nil, 'l') do
--      >   print(s)
--      > end
--      Camel
--      Case
--
-- @within String manipulation
-- @fixme What does split do if the seperator is the last character?
-- @fixme No unit test.
function split (str, pattern, max, inc)
    local pos = 1
    local n = 0
    local i, j
    return function ()
        local sep, last
        if not pos then return end
        if inc == 'l' and i then sep = str:sub(i, j) end
        if max and n == max then
            last = -1
        else
            i, j = str:find(pattern, pos)
            if     not i      then last = -1
            elseif inc == 'r' then last = j
                              else last = i - 1
            end
        end
        local sub = str:sub(pos, last)
        if sep then sub = sep .. sub end
        n = n + 1
        if j then pos = j + 1
             else pos = nil
        end
        return sub
    end
end

do
    -- Lookup a variable from a variable expression.
    --
    -- See `expand_vars` for the expression syntax.
    --
    -- @tab ns A mapping of variable names to values.
    -- @string var The name of the variable to look up.
    -- @string _ If the value of the variable should be passed on to a
    --  function, the literal `|`. Otherwise, the empty string.
    -- @string func If the value of the variable should be passed on to a
    --  function, the name of that function. Otherwise the empty string.
    -- @treturn string The value of the expression.
    -- @raise See `expand_vars`.
    local function eval (ns, var, _, func)
        local v = ns
        for n in split(var, '%.') do
            if type(v) ~= 'table' then break end
            v = v[n]
        end
        if func ~= '' then
            local f = ns[func]
            assert(f, format('$%s%s%s: no such function.', var, _, func))
            v = f(v)
        end
        local s = tostring(v)
        assert(s, format('$%s%s%s: cannot coerce to a string.', var, _, func))
        return s
    end

    --- Expand variables in strings.
    --
    -- If a word is preceded by a single "$" sign, that word is interpreted as
    -- a variable name, and the "$" sign and the word are replaced with the
    -- value of that variable.
    --
    --      > return expand_vars(
    --      >     '$v1 is $v2.',
    --      >     {v1 = 'foo', v2 = 'bar'}
    --      > )
    --      foo is bar.
    --
    -- If a word is preceded by two or more "$" signs, it is *not* replaced.
    -- And any series of *n* "$" signs is replaced with *n* -- 1 "$" signs.
    --
    --      > expand_vars(
    --      >   '$$v1 costs $$23 (and $- is just a dash).',
    --      >   {v1 = 'foo'}
    --      > )
    --      $v1 costs $23 (and - is just a dash).
    --
    -- If a `$<variable>` expression is followed by a "|" character and
    -- another word, the second word is interpreted as a function name;
    -- the value of the given variable is then passed to that function,
    -- and the whole expression `$<variable>|$<function>` is replaced
    -- with the first value that this function returns.
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
    -- @string str A string.
    -- @tab ns A mapping of variable names to values.
    -- @treturn string A transformed string.
    -- @raise An error if there is no function of the given name or
    --  if the value of the expression cannot be coerced to a string.
    -- @within String manipulation
    function expand_vars (str, ns)
        assert(str, 'no string given.')
        assert(ns, 'no namespace given.')
        local function e (...) return eval(ns, ...) end
        return str:gsub('%f[%$]%$([%w_%.]+)%f[%A](|?)([%w_]*)', e):
                   gsub('%$(%$*)', '%1')
    end
end


-- Tables
-- ------

--- Get the keys and the length of a table.
--
-- @tab tab The table.
-- @treturn tab The keys of `tab`.
-- @treturn int `tab`'s length.
-- @within Table manipulation
function keys (tab)
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

--- Apply a function to every node of a graph.
--
-- The graph is walked bottom-up.
--
-- @func func A function that takes a value and returns a another one.
--  The node is *not* changed if the function returns `nil`.
-- @param graph A graph.
-- @treturn table A new graph.
-- @raise An error if the graph is too high.
-- @within Table manipulation
function mapr (func, graph, _rd)
    if type(graph) ~= 'table' then
        local nv = func(graph)
        if nv == nil then return graph end
        return nv
    end
    if not _rd then _rd = 0
               else _rd = _rd + 1
    end
    assert(_rd < 512, 'too much recursion.')
    local ret = {}
    local k
    while true do
        k = next(graph, k)
        if k == nil then break end
        local v = graph[k]
        if type(v) == 'table' then v = mapr(func, v, _rd) end
        local nv = func(v)
        if nv == nil then ret[k] = v
                     else ret[k] = nv
        end
    end
    return ret
end

--- Expand the values of an iterator.
--
-- @func iter An iterator.
-- @param[opt] val The value to start iterating with.
-- @treturn table The values generated by the iterator.
-- @usage
--      > str = 'key: value'
--      > k, v = tabulate(split(str, '%s*:%s*', 2))
--      > print(k, v)
--      key     value
--
-- @within Table manipulation
-- @fixme No unit test.
-- @todo Check if that function may be useful elsewhere.
function tabulate (iter, val)
    local tab = {}
    local n = 0
    local p
    repeat
        val, p = iter(val, p)
        if val then
            n = n + 1
            tab[n] = val
        end
    until not val
    tab.n = n
    return unpack(tab)
end

--- Iterate over the keys of a table in a given order.
--
-- @tab tab A table.
-- @func[opt] func A sorting function.
--  If no function is given, sorts lexically.
-- @treturn func A *stateful* iterator over the table.
-- @within Table manipulation
function sorted_pairs (tab, func)
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

--- Define a sorting function from a list of values.
--
-- The sorting function will sort the given values in the order in which
-- they were passed. Unlisted values are sorted lexically.
--
-- @param ... Values.
-- @treturn func A sorting function.
-- @usage
--      > tab = {a = 3, b = 4, c = 2, d = 1}
--      > for k, v in sorted_pairs(tab, in_order{'d', 'c'}) do
--      >>  print(k, v)
--      > end
--      d   1
--      c   2
--      a   3
--      b   4
--
-- @within Table manipulation
-- @fixme No unit test.
function in_order(...)
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


-- CSL items
-- ---------

--- The preferred order of keys in YAML bibliography files.
--
-- [Appendix IV](https://docs.citationstyles.org/en/stable/specification.html#appendix-iv-variables)
-- of the CSL specification lists all field names.
--
-- @see csl_keys_sort
-- @within CSL items
CSL_KEY_ORDER = {
    'id',                       -- Item ID.
    'type',                     -- For example, 'paper', 'book'.
    'author',                   -- Author(s).
    'recipient',                -- Recipient of the document.
    'status',                   -- Publication status (e.g., 'forthcoming').
    'issued',                   -- When the item was published.
    'title',                    -- The title.
    'title-short',              -- A short version of the title.
    'short-title',              -- Ditto.
    'original-title',           -- Original title.
    'translator',               -- Translator(s).
    'editor',                   -- The editor(s).
    'container-title',          -- Publication the item was published in.
    'container-title-short',    -- A short version of that title.
    'collection-editor',        -- E.g., the series editor(s).
    'collection-title',         -- E.g., a series.
    'collection-title-short',   -- A short version of the title.
    'edition',                  -- Container's edition.
    'volume',                   -- Volume no.
    'issue',                    -- Issue no.
    'page-first',               -- First page.
    'page',                     -- Pages or page range *or* number of pages.
    'publisher',                -- Publisher.
    'publisher-place',          -- City/cities the item was published in.
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

--- Iterate over key-value pairs in the "note" field of CSL items.
--
-- @tab item A CSL item.
-- @treturn func A *stateful* iterator.
-- @within CSL items
function csl_item_extras (item)
    if not item.note then return function () return end end
    local next_ln = split(item.note, '\r?\n')
    return function ()
        local ln = next_ln()
        if not ln or ln == '' then return end
        local k, v = tabulate(split(ln, '%s*:%s*'), 2)
        if not k then return nil end
        return k:lower(), v
    end
end

--- Sorting function for CSL field names.
--
-- Sorts field in the order in which they are listed in `CSL_KEY_ORDER`.
-- Unlisted fields are placed after listed ones in lexical order.
--
-- @string a A CSL fieldname.
-- @string b Another CSL fieldname.
-- @treturn bool Whether `a` should come before `b`.
-- @within CSL items
-- @function csl_keys_sort
csl_keys_sort = in_order(unpack(CSL_KEY_ORDER))

--- Sorting function for CSL items.
--
-- @tab a A CSL item.
-- @tab b Another CSL item.
-- @treturn bool Whether `a` should come before `b`.
-- @within CSL items
function csl_items_sort (a, b)
    return a.id < b.id
end

--- Pick the IDs of CSL items out of a list of CSL items.
--
-- @tab items A list of CSL items.
-- @treturn {[string]=true,...} A [set](https://www.lua.org/pil/11.5.html)
--  of item IDs.
-- @raise An error if an item has an ID that cannot be coerced to a string.
-- @within CSL items
function csl_items_ids (items)
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


-- File I/O
-- --------

--- Check whether a path is absolute.
--
-- @string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
-- @raise An error if no path is given or if the path is the empty string.
-- @within File I/O
function path_is_abs (path)
    assert(path_verify(path))
    if PATH_SEP == '\\' and path:match '^.:\\' then return true end
    return path:match('^' .. PATH_SEP) ~= nil
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

    --- Prettify paths.
    --
    -- More precisely, remove the current working directory from the
    -- beginning of a path and, on POSIX systems, replace the user's
    -- home directory with '~'.
    --
    -- @string ... Paths.
    -- @treturn string Prettier paths.
    -- @raise An error if no path is given or if the path is the empty string.
    -- @within File I/O
    function path_prettify (path, ...)
        assert(path_verify(path))
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
        if ... then return path, path_prettify(...) end
        return path
    end
end

--- Get a directory to use as working directory.
--
-- @treturn string The directory of the first input file
--  or '.' if none was given.
-- @raise An error if no path is given or if the path is the empty string.
-- @within File I/O
function wd ()
    local fname = PANDOC_STATE.input_files[1]
    if not fname then return '.' end
    assert(path_verify(fname))
    local wd = path_split(fname)
    return wd
end

--- Check whether a file exists.
--
-- @string fname A filename.
-- @treturn[1] boolean `true` if the file exists.
-- @treturn[2] nil `nil` if the file does not exist.
-- @treturn[2] string An error message.
-- @treturn[2] int The error number 2.
-- @raise An error if no path is given or if the path is the empty string.
-- @within File I/O
function file_exists (fname)
    assert(path_verify(fname))
    local file, err, errno = io.open(fname, 'r')
    if not file then return nil, err, errno end
    assert(file:close())
    return true
end

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
    -- @within File I/O
    function file_locate (fname)
        if not resource_path or file_exists(fname) then return fname end
        for i = 1, #resource_path do
            local f = path_join(resource_path[i], fname)
            if file_exists(f) then return f end
        end
        return nil, fname .. ': not found in resource path.'
    end
end

--- Read a file.
--
-- @string fname A filename.
-- @treturn[1] string The contents of the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
-- @within File I/O
function file_read (fname)
    local str, err, errno, file, ok
    file, err, errno = io.open(fname, 'r')
    if not file then return nil, err, errno end
    str, err, errno = file:read('a')
    if not str then return nil, err, errno end
    ok, err, errno = file:close()
    if not ok then return nil, err, errno end
    return str
end

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

    -- Write data to a file (worker).
    --
    -- @param file The name or handle of a file to write data to.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    local function write_to_file (fname, ...)
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
    -- `file_write` *tries* to print a warning to STDERR if that happens,
    -- but another process may create a file between the time `file_write`
    -- checks whether a filename is in use and the time it starts writing.
    --
    -- Some errors and warnings may be printed to STDERR.
    --
    -- <h3>Caveats:</h3>
    --
    -- Data is first written to a temporary file, that file is then renamed to
    -- the given filename. This is safe and secure starting with Pandoc v2.8.
    -- If you are using an older version of Pandoc, then the caveats of
    -- `with_tmp_file` apply.
    --
    -- @string fname A filename.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    -- @raise An error if no filename is given or
    --  if the filename is the empty string.
    -- @within File I/O
    function file_write (fname, ...)
        assert(path_verify(fname))
        local dir, base = path_split(path_make_abs(fname))
        local data = {...}
        local tmp_dir
        local vs = {with_temporary_directory(dir, 'pdz', function (td)
            tmp_dir = td
            warn 'created temporary directory $td|path_prettify.'
            local tmp_file = path_join(td, base)
            local ok, err, errno = write_to_file(tmp_file, unpack(data))
            if not ok then return nil, err, errno end
            if file_exists(fname) then
                warn 'replacing $fname|path_prettify ...'
            end
            return os.rename(tmp_file, fname)
        end)}
        if tmp_dir and not file_exists(tmp_dir) then
            warn 'removed $fname|path_prettify.'
        end
        return unpack(vs)
    end

    if not pandoc.types or PANDOC_VERSION < {2, 8} then
        function file_write (fname, ...)
            assert(path_verify(fname))
            local dir = path_split(fname)
            local data = {...}
            local tmp_file
            local vs = {with_tmp_file(dir, nil, function(tf)
                tmp_file = tf
                warn 'writing data to temporary file $tf|path_prettify'
                local ok, err, errno = write_to_file(tf, unpack(data))
                if not ok then return nil, err, errno end
                if file_exists(fname) then
                    warn 'replacing $fname|path_prettify'
                end
                return os.rename(tf, fname)
            end)}
            if tmp_file and not file_exists(tmp_file) then
                warn '$tmp_file|path_prettify renamed to $fname|path_prettify'
            end
            return unpack(vs)
        end
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
    -- Tries to make sure that there is no file with that name already.
    -- This is subject to race conditions.
    --
    -- @string[opt] dir A directory to prefix the filename with.
    --  Must not be the empty string.
    -- @string[optchain='pdz-XXXXXX'] templ A template for the filename.
    --  'X's are replaced with random alphanumeric characters.
    --  Must contain at least six 'X's.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the generated filename is in use.
    -- @treturn[2] string An error message.
    -- @raise An error if the template or the directory is
    --  not a string or the empty string.
    -- @within File I/O
    function tmp_fname (dir, templ)
        if templ == nil then
            templ = 'pdz-XXXXXX'
        else
            assert(type(templ) == 'string', 'template is not a string.')
            assert(templ ~= '', 'template is the empty string.')
            local nxs = 0
            for _ in templ:gmatch 'X' do nxs = nxs + 1 end
            assert(nxs >= 6, 'template must contain at least six "X"s.')
        end
        if dir ~= nil then
            assert(type(dir) == 'string')
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
        return nil, 'no filename available.'
    end
end

do
    -- Remove a file unless its second and third argument are `true`.
    --
    -- If the file could not be removed, an error message is printed to STDERR.
    --
    -- @string fname A filename.
    -- @bool Whether a function call succeeded.
    -- @param The return value of that function call.
    local function clean_up (fname, status, result)
        if status and result then return end
        warn 'removing $fname|path_prettify.'
        local ok, err, errno = os.remove(fname)
        if not ok and errno ~= 2 then log(err) end
    end

    --- Run a function with a temporary file.
    --
    -- If the function raises an error or returns `nil` or `false`, then the
    -- temporary file is deleted. If the file could not be removed, an error
    -- message is printed to STDERR.
    --
    -- The function passed to `with_tmp_file` must *not* change the working
    -- directory. This could cause an abitrary file to be deleted instead of
    -- the temporary one. And it would likely cause the automatic deletion
    -- of the temporary file to fail.
    --
    -- <h3>Caveats:</h3>
    --
    -- The temporary file may have been created by *another* process. If that
    -- file is located within a directory that users other than the one
    -- running this script have write access to (e.g., `/tmp`), then this
    -- is a security issue.
    --
    -- @string[opt] dir A directory to prefix the name
    --  of the temporary file with. See `tmp_fname`.
    -- @string[optchain='pdz-XXXXXX'] templ A template for the name
    --  of the temporary file. 'X's are replaced with random
    --  alphanumeric characters. See `tmp_fname`.
    -- @func func The function to run.
    --  Passed the name of the temporary file as first argument.
    -- @param ... Passed on to the function.
    -- @return The values that the function returns.
    -- @within File I/O
    function with_tmp_file (dir, templ, func, ...)
        local tmp_file, err = tmp_fname(dir, templ)
        if not tmp_file then return nil, err end
        local function my_clean_up (...) return clean_up(tmp_file, ...) end
        return do_after(my_clean_up, func, tmp_file, ...)
    end
end


-- Converters
-- ----------

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
    -- @within Converters
    function escape_markdown (str)
        for i = 1, #esc_patterns do
            local pattern, repl = unpack(esc_patterns[i])
            str = str:gsub(pattern, repl)
        end
        return str
    end
end

do
    -- Filter to escape strings.
    local esc = {}

    -- Escape Markdown in a string element.
    --
    -- Works like `escape_markdown` but for Pandoc string elements.
    --
    -- @tparam pandoc.Str str A string element.
    -- @treturn pandoc.Str A string with all Markdown syntax escaped.
    function esc.Str (str)
        str.text = escape_markdown(str.text)
        return str
    end

    -- Filter to convert to Markdown text.
    local md = {}

    -- Make a function that converts an element to Markdown.
    --
    -- @string char A Markdown markup character.
    -- @treturn func A conversion function.
    local function make_conv_f (char)
        return function (elem)
            local str = stringify(pandoc.walk_inline(elem, md))
            return Str(char .. str .. char)
        end
    end

    -- Convert AST elements into Markdown text.
    md.Emph = make_conv_f '*'
    md.Strong = make_conv_f '**'
    md.Subscript = make_conv_f '~'
    md.Superscript = make_conv_f '^'

    -- Convert <span> elements to Markdown text.
    --
    -- @tparam pandoc.Span A <span> element.
    -- @treturn pandoc.Str The element as Markdown.
    function md.Span (span)
        local str = stringify(pandoc.walk_inline(span, md))
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

    -- Convert SmallCaps elements to Markdown text.
    --
    -- @tparam pandoc.SmallCaps A SmallCaps element.
    -- @treturn pandoc.Str The element as Markdown.
    function md.SmallCaps (sc)
        local span = Span(sc.content)
        span.attributes.style = 'font-variant: small-caps'
        return md.Span(span)
    end

    --- Convert a Pandoc element to Markdown text.
    --
    -- Only recognises [elements Pandoc permits in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn string Markdown text.
    -- @within Converters
    function markdownify (elem)
        return stringify(walk(walk(elem, esc), md))
    end
end

do
    local rep = string.rep
    local char = utf8.char
    local codes = utf8.codes

    -- Create a number of spaces.
    --
    -- @int n The number of spaces.
    -- @treturn string `n` spaces.
    local function spaces (n)
        return rep(' ', n)
    end

    -- Convert a string to a YAML scalar.
    --
    -- Strings must be encoded in UTF-8.
    -- Does *not* escape *all* non-printable characters.
    --
    -- @string str The value.
    -- @treturn string A YAML scalar.
    -- @raise An error if `str` is not a `string`.
    function scalarify (str)
        -- Simple strings need no special treatment.
        if
            tonumber(str) ~= nil   or  -- Numbers
            str:match '^[%w-]+$'   or  -- Simple words
            str:match '^[%w%./]+$' or  -- DOIs
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

    --- Generate a YAML representation of a graph.
    --
    -- Lines are termined with `EOL` to end lines.
    -- Strings in other encodings other than UTF-8 will be mangled.
    -- Does *not* escape *all* non-printable characters (because Unicode).
    --
    -- @param graph A graph.
    -- @int[opt=4] ind How many spaces to indent blocks.
    -- @func[optchain] sort_f A function to sort keys of mappings.
    --  Defaults to sorting them lexically.
    -- @treturn[1] string A YAML string.
    -- @treturn[2] nil `nil` if the data cannot be represented in YAML.
    -- @treturn[2] string An error message.
    -- @raise An error if data cannot be expressed in YAML
    --  or if the graph is too high.
    -- @within Converters
    function yamlify (graph, ind, sort_f, _col, _rd)
        if not _rd then _rd = 0 end
        assert(_rd < 1024, 'too much recursion.')
        if not ind then ind = 4 end
        local t = type(graph)
        local conv = converters[t]
        if conv then return conv(graph) end
        if t ~= 'table' then error(t .. ': cannot be expressed in YAML.') end
        _rd = _rd + 1
        if not _col then _col = 0 end
        local str = ''
        local n = #graph
        local nkeys = select(2, keys(graph))
        local sp = spaces(_col)
        if n == nkeys then
            local col = _col + 2
            for i = 1, n do
                if i > 1 then str = str .. sp end
                str = str .. '- ' .. yamlify(graph[i], ind, sort_f, col, _rd)
                if i ~= n then str = str .. EOL end
            end
        else
            local i = 0
            for k, v in sorted_pairs(graph, sort_f) do
                i = i + 1
                if type(k) == 'number' then k = tostring(k)
                                       else k = scalarify(k)
                end
                if i > 1 then str = str .. sp end
                str = str .. k .. ':'
                local col = _col + ind
                if type(v) == 'table' then str = str .. EOL .. spaces(col)
                                      else str = str .. ' '
                end
                str = str .. yamlify(v, ind, sort_f, col, _rd)
                if i ~= nkeys then str = str .. EOL end
            end
        end
        return str
    end
end

do
    local converters = {}

    -- Convert a Lua boolean to a pandoc.MetaBool
    --
    -- @bool b A boolean value.
    -- @treturn pandoc.MetaBool The same boolean value.
    function converters.boolean (x)
        return pandoc.MetaBool(x)
    end

    -- Convert a Lua number to a pandoc.MetaInlines string.
    --
    -- @bool n A number.
    -- @treturn pandoc.MetaInlines The same number.
    function converters.number (n)
        return MetaInlines(List{Str(tostring(n))})
    end

    -- Convert a Lua string to a pandoc.MetaInlines string.
    --
    -- Zotero pseudo-HTML formatting is kept.
    --
    -- @string s A string.
    -- @treturn pandoc.MetaInlines The same string.
    function converters.string (s)
        local html = zot_to_html(s)
        local inlines = pandoc.read(html, 'html').blocks[1].content
        return MetaInlines(inlines)
    end

    --- Convert a CSL item to a Pandoc metadata value.
    --
    -- @tab item A CSL item.
    -- @treturn pandoc.MetaMap A Pandoc metadata value.
    -- @within Converters
    function csl_item_to_meta (item)
        local t = type(item)
        local conv = converters[t]
        if conv then return conv(item) end
        if t ~= 'table' then
            error(t .. ': cannot be converted to a Pandoc metadata type.')
        end
        local nkeys = select(2, keys(item))
        local n = #item
        if n == nkeys then
            local list = MetaList{}
            for i = 1, n do
                list[i] = csl_item_to_meta(item[i])
            end
            return list
        else
            local map = MetaMap{}
            for k, v in pairs(item) do
                map[k] = csl_item_to_meta(v)
            end
            return map
        end
    end
end

--- Convert Zotero pseudo-HTML to HTML.
--
-- @string zot Zotero pseudo-HTML code.
-- @treturn string HTML code.
-- @within Converters
function zot_to_html (zot)
    if type(zot) ~= 'string' then return nil, 'given code is not a string.' end
    local op, n = zot:gsub('<sc>', '<span style="font-variant: small-caps">')
    if n == 0 then return zot end
    local cl, m = op:gsub('</sc>', '</span>')
    if m == 0 then return zot end
    return cl
end

--- Convert Zotero pseudo-HTML to Markdown.
--
-- Only supports [pseudo-HTML that Pandoc recognises in bibliographic
-- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
--
-- @string zot Zotero pseudo-HTML code.
-- @treturn[1] string Markdown text.
-- @treturn[2] nil `nil` if `html` is not a `string`.
-- @treturn[2] string An error message.
-- @within Converters
function zot_to_md (zot)
    if type(zot) ~= 'string' then return nil, 'given code is not a string.' end
    local html = zot_to_html(zot)
    local doc = pandoc.read(html, 'html')
    return markdownify(doc)
end

do
    local floor = math.floor
    local decode = json.decode

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
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if the string cannot be parsed.
    -- @treturn[2] string An error message.
    -- @within Converters
    -- @fixme No unit test.
    function parse_csl_json (str)
        if str == '' then return nil, 'got the empty string.' end
        local ok, data = pcall(decode, str)
        if not ok then return nil, 'cannot parse: ' .. str end
        return mapr(num_to_str, data)
    end
end


-- Networking
-- ----------

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
    -- @within Networking
    function http_get (url)
        local ok, mt, data = pcall(fetch, url, '.')
        if not ok then
            local host = url:match '(.-)%f[:/]/+' or url
            error(ConnectionError{host = host})
        end
        return mt, data
    end
end


-- zotxt
-- -----

--- Interface to [zotxt](https://github.com/egh/zotxt).
--
-- @type Zotxt
-- @usage
--      > handle = Zotxt()
--      > handle.citekey_types = pandoc.List{'betterbibtexkey'}
--      > csl_item = handle:csl_item 'name2019TwoWords'
Zotxt = Prototype()

--- What types of citation keys to support.
Zotxt.citekey_types = List {
    'key',             -- Zotero item ID
    'betterbibtexkey', -- Better BibTeX citation key
    'easykey',         -- zotxt easy citekey
}

do
    -- Shorthands.
    -- luacheck: ignore assert pcall tostring type
    local assert = assert
    local pcall = pcall
    local tostring = tostring
    local type = type

    -- URL template for looking up items.
    local lookup_url = 'http://localhost:23119/zotxt/items?%s=%s'

    --- Retrieve a CSL item from zotxt.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `http_get`.
    function Zotxt:csl_item (ckey)
        local citekey_types = self.citekey_types
        local err = nil
        for i = 1, #citekey_types do
            -- zotxt supports searching for multiple citation keys at once,
            -- but if a single one cannot be found, it replies with a cryptic
            -- error message (for easy citekeys) or an empty response
            -- (for Better BibTeX citation keys).
            local query_url = lookup_url:format(citekey_types[i], ckey)
            local mt, str = http_get(query_url)
            if not mt or mt == '' then
                err = ckey .. ': response has no MIME type.'
            elseif not str or str == '' then
                err = ckey .. ': response is empty.'
            elseif not mt:match '^text/plain%f[%A]' then
                err = format('%s: response is of wrong type %s.', ckey, mt)
            elseif not mt:match ';%s*charset="?[Uu][Tt][Ff]%-?8"?%s*$' then
                err = ckey .. ': response is not encoded in UTF-8'
            else
                -- luacheck: ignore ok
                local data = parse_csl_json(str)
                if data then
                    if i ~= 1 then
                        citekey_types[1], citekey_types[i] =
                        citekey_types[i], citekey_types[1]
                    end
                    -- @fixme check the number of items!
                    local item = data[1]
                    item.id = ckey
                    return item
                else
                    err = 'Zotero responded: ' .. str
                end
            end
        end
        return nil, err
    end
end


-- Zotero Web API
-----------------

--- A mapping of citation key types to functions that guess search terms.
--
-- @within ZotWeb
local CITEKEY_TYPES = {}

do
    local codes = utf8.codes
    local len = utf8.len

    --- Guess search terms from a BetterBibTeX citation key.
    --
    -- Splits up a BetterBibTeX citation key at each uppercase letter and
    -- each start of a string of digits.
    --
    -- BetterBibTeX citation keys must be encoded in ASCII.
    --
    -- @string ckey A BetterBibTeX citation key.
    -- @treturn {string,...} A list of search terms.
    -- @within ZotWeb
    -- @fixme No unit test.
    function CITEKEY_TYPES.betterbibtexkey (ckey)
        local terms = {}
        local n = 0
        local function add (term)
            n = n + 1
            terms[n] = term
        end
        for str, num in ckey:gmatch '([%a%p]*)(%d*)' do
            if str and str ~= '' then
                for term in split(str, '%u', nil, 'l') do
                    local l = len(term)
                    if l and l > 3 then add(term) end
                end
            end
            if num and num ~= '' then
                local l = len(num)
                if l and l > 1 then add(num) end
            end
        end
        if n < 2 then return nil end
        return terms
    end

    --- Guess search terms from a zotxt Easy Citekey.
    --
    -- Splits up a zotxt Easy Citekey into an author, a year,
    -- and a title.
    --
    -- zotxt Easy Citekeys must be encoded in UTF-8.
    --
    -- @string ckey A zotxt Easy Citekey.
    -- @treturn {string,...} A list of search terms.
    -- @within ZotWeb
    -- @fixme No unit test.
    function CITEKEY_TYPES.easykey (ckey)
        local terms = {}
        local n = 0
        local function add (term)
            n = n + 1
            terms[n] = term
        end
        local q
        for p, c in codes(ckey) do
            if not q then
                -- 58 is the colon (:).
                if c == 58 then
                    local s = ckey:sub(1, p - 1)
                    if s and s ~= '' then add(s) end
                    q = p
                end
            else
                -- Digits start at 48 and end at 57.
                if c < 48 or c > 57 then
                    local s = ckey:sub(q + 1, p - 1)
                    if s and s ~= '' then add(s) end
                    s = ckey:sub(p)
                    if s and s ~= '' then add(s) end
                    break
                end
            end
        end
        if n < 2 then return end
        return terms
    end
end

--- Interface to the [Zotero Web API](https://www.zotero.org/support/dev/web_api/)
--
-- @type ZotWeb
-- @usage
--      > handle = ZotWeb{api_key = 'alongstringoflettersandnumbers'}
--      > handle.citekey_types = pandoc.List{'betterbibtexkey'}
--      > csl_item = handle:csl_item 'name2019TwoWords'
ZotWeb = Prototype()

--- What types of citation keys to support.
ZotWeb.citekey_types = List {
    -- 'easykey' must go first, because it's unlikely that that the
    -- citekey parser parses a Better BibTeX citation key (most BetterBibTeX
    -- citation keys don't contain colons), but the BetterBibTeX citation key
    -- parser will happily parse an Easy Citekey, and it will do it wrong.
    'easykey',
    'betterbibtexkey',
    'key'
}

do
    -- Shorthands.
    local len = utf8.len
    local decode = json.decode

    -- @todo Make expand_vars recursive and use it here!
    -- Zotero Web API base URL.
    local base_url = 'https://api.zotero.org'

    -- URL template for user ID lookups.
    -- %s is replaced with the API key.
    local user_id_url = base_url .. '/keys/%s'

    -- URL template for group membership lookups.
    -- %s is replaced with the user ID,
    -- the second with the API key.
    local group_url = base_url .. '/users/%s/groups?v=3&key=%s'

    -- User prefix.
    -- %s is replaced with the user ID.
    local user_prefix = '/users/%s'

    -- Group prefix.
    -- %s is replaced with the group ID.
    local group_prefix = '/groups/%s'

    -- Path for item lookups (relative to prefix).
    -- The first %s is replaced with the item ID,
    -- the second with the API key.
    local lookup_path = '/items/%s?v=3&key=%s&format=csljson'

    -- Path for item searches (relative to prefix).
    -- The first %s is replaced with the API key,
    -- the second with the search terms.
    local search_path = '/items/?v=3&key=%s&format=csljson&qmode=titleCreatorYear&q=%s&itemType=-attachment'

    -- Retrieve and parse data from the Zotero Web API.
    --
    -- @string query_url A URL.
    -- @return[1] The response of the Zotero WEB API.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raises See `http_get`
    local function get (query_url)
        local mt, str = http_get(query_url)
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

    --- Get the user ID for the given API key.
    --
    -- @treturn string A Zotero user ID.
    -- @raise An error if the `api_key` field is not set, the Zotero Web API
    --  could not be reached, or if no Zotero user ID could be found.
    --  See `http_get` for details on the second error.
    -- @fixme No unit test.
    function ZotWeb:user_id ()
        if self._user_id then return self._user_id end
        assert(self.api_key, 'no Zotero API key given.')
        local query_url = user_id_url:format(self.api_key)
        local str, err = get(query_url)
        assert(str, UIDLookupError{err = err})
        local ok, data = pcall(decode, str)
        assert(ok, UIDLookupError{err = 'cannot parse response: ' .. str})
        local user_id = data.userID
        assert(user_id, UIDLookupError{err = 'no user ID found.'})
        self._user_id = user_id
        return user_id
    end

    -- @fixme Undocumented.
    -- @fixme No unit test.
    function ZotWeb:group_ids ()
        if self._group_ids then return self._group_ids end
        assert(self.api_key, 'no Zotero API key given.')
        local query_url = group_url:format(self:user_id(), self.api_key)
        local str, err = get(query_url)
        assert(str, GroupLookupError{err = err})
        local ok, groups = pcall(decode, str)
        assert(ok, GroupLookupError{err = 'cannot parse response: ' .. str})
        local ids = {}
        local n = 0
        for i = 1, #groups do
            if groups[i] and groups[i].data and groups[i].data.id then
                n = n + 1
                ids[n] = groups[i].data.id
            end
        end
        self._group_ids = ids
        return ids
    end

    -- Search items by their author, publication year, and title (worker).
    --
    -- @string scope Where to search.
    --  'u' for in the user library,
    --  'g' for in a group library.
    -- @string id Depending on the scope, a user or a group ID.
    -- @string api_key A Zotero API key.
    -- @string ... Search terms.
    -- @treturn[1] tab A list of CSL items that match the given search terms.
    -- @treturn[2] nil `nil` if no items were found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number:
    --  0 if no items match the search terms,
    --  1 for fetch errors, and
    --  2 for parse errors.
    -- @raise An error if the given scope is neither 'u' nor 'g'.
    --  See also `ZotWeb:user_id` and `ZotWeb:group_ids`.
    -- @fixme No unit test.
    local function search (scope, id, api_key, ...)
        -- luacheck: ignore err
        local prefix
        if     scope == 'u' then prefix = user_prefix
        elseif scope == 'g' then prefix = group_prefix
        else                error(scope .. ': no such scope.')
        end
        local q = concat({...}, '+')
        local query_url = format(base_url .. prefix .. search_path,
                                 id, api_key, q)
        local str, err = get(query_url)
        if not str then return nil, err, 1 end
        local data, err = parse_csl_json(str)
        if not data then return nil, err, 2 end
        local items = data.items
        if not items or #items == 0 then return nil, 'no matches.', 0 end
        return items
    end

    --- Search items by their author, publication year, and title.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string scope Where to search.
    --  'u' for in the user's library,
    --  'g' for in group libraries, and
    --  'a' for both.
    -- @string ... Search terms.
    -- @treturn[1] tab A list of CSL items that match the given search terms.
    -- @treturn[2] nil `nil` if no items were found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number:
    --  0 if no items match the search terms,
    --  1 for fetch errors, and
    --  2 for parse errors.
    -- @treturn[2] An error message.
    -- @raise An error if the given scope is not one of 'u', 'g', or 'a'.
    --  See also `ZotWeb:user_id` and `ZotWeb:group_ids`.
    -- @fixme No unit test (test should include abort on, e.g., parse errors).
    function ZotWeb:search (scope, ...)
        -- luacheck: ignore err
        assert(self.api_key, 'no Zotero API key given.')
        if scope == 'a' or scope == 'u' then
            local items, err, errno = search('u', self:user_id(), self.api_key, ...)
            if items then return items end
            if errno > 0 then return nil, err, errno end
        end
        if scope == 'a' or scope == 'g' then
            local group_ids = self:group_ids()
            for i = 1, #group_ids do
                local items, err, errno = search('g', group_ids[i], self.api_key, ...)
                if items then return items end
                if errno > 0 then return nil, err, errno end
            end
        else
            error(scope .. ': no such scope.')
        end
        return nil, 'no matches.', 0
    end

    --- Guess search terms from a citation key.
    --
    -- The terms guessed are printed to STDERR
    -- if the user has requested more output.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] {string,...} A list of search terms.
    -- @treturn[2] nil `nil` if no search terms could be derived.
    -- @treturn[2] string An error message.
    -- @fixme No unit test.
    -- @todo Allow Lua expressions.
    function ZotWeb:search_terms(ckey)
        assert(self.citekey_types, 'no citation key types given.')
        local citekey_types = self.citekey_types
        for i = 1, #citekey_types do
            local f = CITEKEY_TYPES[citekey_types[i]]
            if f then
                local terms = f(ckey)
                if terms then
                    info('$ckey: searching for: ' .. concat(terms, ', '))
                    return terms
                end
            end
        end
        return nil, ckey .. ': failed to guess search terms.'
    end

    -- Filter items by their citation key.
    --
    -- @tab items A list of CSL items.
    -- @string A citation key.
    -- @treturn A list of those items that have that citation key.
    local function filter_by_ckey (items, ckey)
        local filtered = {}
        local n = 0
        for i = 1, #items do
            local item = items[i]
            for k, v in csl_item_extras(item) do
                if (k == 'citation key' or k == 'citekey') and v == ckey then
                    n = n + 1
                    filtered[n] = item
                    break
                end
            end
        end
        filtered.n = n
        return filtered
    end

    --- Searches for a CSL item that matches a citation key.
    --
    -- Search terms are printed to STDERR if
    -- if the user has requested more output.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string scope Where to search.
    --  'u' for in the user's library,
    --  'g' for in group libraries, and
    --  'a' for both.
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if less or more than one item was found or
    --  if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number:
    --  0 if no items match the citation key,
    --  1 for fetch errors,
    --  2 for parse errors,
    --  3 if more than one item matches the citation key, and
    --  4 if the citation key is not unique.
    -- @fixme No unit test.
    -- @raise An error if the given scope is not one of 'u', 'g', or 'a'.
    --  See also `ZotWeb:user_id` and `ZotWeb:group_ids`.
    function ZotWeb:match (scope, ckey)
        -- luacheck: ignore err
        assert(self.api_key, 'no Zotero API key given.')
        local terms = self:search_terms(ckey)
        if not terms then return nil, 'failed to parse "' .. ckey .. '".' end
        local items, err = self:search(scope, unpack(terms))
        if not items then return nil, ckey .. ': ' .. err end
        local n = #items
        if n == 0 then
            return nil, ckey .. ': no matches.', 0
        elseif n > 1 then
            items = filter_by_ckey(items, ckey)
            if not items or items.n == 0 then
                return nil, ckey .. ': too many matches.', 3
            elseif items.n > 1 then
                return nil, ckey .. ': citation key is not unique.', 4
            end
        end
        return items[1]
    end

    --- Look up a CSL item by its Zotero ID (worker).
    --
    -- @string scope Where to look for items.
    --  'u' for in the user library,
    --  'g' for in a group library.
    -- @string id Depending on the scope, a user or a group ID.
    -- @string api_key A Zotero API key.
    -- @string zot_id A Zotero item ID.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if no item was found or if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number:
    --  0 if there is no item with that item ID,
    --  1 for fetch errors,
    --  2 for parse errors, and
    --  5 if the item ID is not unique.
    -- @raise An error if the given scope is not one of 'u', 'g', or 'a'.
    --  See also `ZotWeb:user_id` and `ZotWeb:group_ids`.
    -- @fixme No unit test.
    local function lookup (scope, id, api_key, zot_id)
        -- luacheck: ignore err
        local prefix
        if     scope == 'u' then prefix = user_prefix
        elseif scope == 'g' then prefix = group_prefix
        else                error(scope .. ': no such scope.')
        end
        local query_url = format(base_url .. prefix .. lookup_path,
                                 id, zot_id, api_key)
        local str, err = get(query_url)
        if not str then return nil, zot_id .. ': ' .. err, 1 end
        local data, err = parse_csl_json(str)
        if not data then return nil, zot_id .. ': ' .. err, 2 end
        local items = data.items
        if items then
            local n = #items
            if n == 1    then return items[1]
            elseif n > 1 then return nil, zot_id .. ': ID is not unique.', 5
            end
        end
        return nil, zot_id .. ': no such item.', 0
    end

    --- Look up a CSL item by its Zotero ID.
    --
    -- <h3>Caveats:</h3>
    --
    -- Does *not* correct Zotero's CSL JSON export.
    --
    -- @string scope Where to look for items.
    --  'u' for in the user's library,
    --  'g' for in group libraries,
    --  and 'a' for both.
    -- @string id A Zotero item ID.
    -- @treturn[1] tab A CSL item.
    -- @treturn[2] nil `nil` if no or more than one item has been found.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number:
    --  0 if there is no item with that item ID,
    --  2 for parse errors, and
    --  5 if the item ID is not unique.
    -- @fixme No unit test.
    -- @raise An error if the given scope is not one of 'u', 'g', or 'a'.
    --  See also `ZotWeb:user_id` and `ZotWeb:group_ids`.
    function ZotWeb:lookup (scope, id)
        -- luacheck: ignore err
        assert(self.api_key, 'no Zotero API key given.')
        if scope == 'a' or scope == 'u' then
            local items, err, errno = lookup('u', self:user_id(), self.api_key, id)
            if items then return items end
            if errno > 1 then return nil, err, errno end
        end
        if scope == 'a' or scope == 'g' then
            local group_ids = self:group_ids()
            for i = 1, #group_ids do
                local items, err, errno = lookup('g', group_ids[i], self.api_key, id)
                if items then return items end
                if errno > 1 then return nil, err, errno end
            end
        else
            error(scope .. ': no such scope.')
        end
        return nil, id .. ': no such item.', 0
    end

    -- Zotero's CSL JSON export leaves CSL fields that have been entered
    -- into its "extra" field in the CSL "note" field, rather than including
    -- them as CSL fields proper. This table maps CSL field names to functions
    -- that take the value of an "extra" field and return a value that can
    -- be used as CSL field.
    local work_arounds = {}

    -- Work around for 'original-date'.
    work_arounds['original-date'] = function (v)
            return {['date-parts'] = {{v}}}
    end

    -- Convert sub-fields of Zotero's "extra" field to proper CSL fields.
    --
    -- Note, the given item is changed in-place.
    -- See `work_arounds` above for more details.
    --
    -- @tab item A CSL item.
    -- @treturn tab The same CSL item.
    local function apply_workarounds (item)
        for k, v in csl_item_extras(item) do
            local f = work_arounds[k]
            if f then
                v = f(v)
                if v then item[k] = v end
            end
        end
        return item
    end

    --- Retrieve a CSL item from Zotero.
    --
    -- @string ckey A citation key, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @fixme No unit test.
    -- @raise See `ZotWeb:user_id` and `ZotWeb:group_ids`.
    function ZotWeb:csl_item (ckey)
        -- luacheck: ignore err
        assert(ckey ~= '', 'citation key is the empty string.')
        assert(self.api_key, 'no Zotero API key given.')
        local item, err
        if  self.citekey_types:includes 'key' and
            len(ckey) == 8                    and
            ckey:match '^[%u%d]+$'
        then
            item, err = self:lookup('a', ckey)
        else
            item, err = self:match('a', ckey)
        end
        if not item then return nil, err end
        apply_workarounds(item)
        item.id = ckey
        return item
    end
end


-- Bibliography files
-- ------------------

--- A mapping of filename suffices to codecs.
--
-- If a key is not found, it is looked up again in lowercase.
-- @within Bibliography files
BIBLIO_TYPES = setmetatable({}, {
    __index = function(self, key)
        if type(key) == 'string' then return rawget(self, key:lower()) end
    end
})

--- Decode BibLaTeX.
-- @within Bibliography files
BIBLIO_TYPES.bib = {}

--- Read the IDs from the contents of a BibLaTeX file.
--
-- @string str The contents of a BibLaTeX file.
-- @treturn {{id=string},...} A list of item IDs.
-- @within Bibliography files
function BIBLIO_TYPES.bib.decode (str)
    local ret = {}
    local n = 0
    for id in str:gmatch '@%w+%s*{%s*([^%s,]+)' do
        n = n + 1
        ret[n] = {id = id}
    end
    return ret
end

--- Decode BibTeX.
-- @within Bibliography files
BIBLIO_TYPES.bibtex = {}

--- Read the IDs from the contents of a BibTeX file.
--
-- @string str The contents of a BibTeX file.
-- @treturn {{id=string},...} A list of item IDs.
-- @within Bibliography files
-- @function BIBLIO_TYPES.bibtex.decode
BIBLIO_TYPES.bibtex.decode = BIBLIO_TYPES.bib.decode

--- De-/Encode CSL items in JSON.
-- @within Bibliography files
BIBLIO_TYPES.json = json

--- De-/Encode CSL items in YAML.
-- @within Bibliography files
BIBLIO_TYPES.yaml = {}

--- Parse a CSL YAML string.
--
-- @string str A CSL YAML string.
-- @treturn tab A list of CSL items.
-- @within Bibliography files
function BIBLIO_TYPES.yaml.decode (str)
    local next_ln = str:gmatch '(.-)\r?\n'
    local ln = next_ln(str, nil)
    while ln and ln ~= '---' do ln = next_ln(str, ln) end
    if not ln then str = concat{'---', EOL, str, EOL, '...', EOL} end
    local doc = pandoc.read(str, 'markdown')
    if not doc.meta.references then return {} end
    return walk(doc.meta.references, {MetaInlines = markdownify})
end

--- Serialise a list of CSL items to a YAML string.
--
-- @tab items A list of CSL items.
-- @treturn string A CSL YAML string.
-- @raise See `yamlify`.
-- @within Bibliography files
function BIBLIO_TYPES.yaml.encode (items)
    table.sort(items, csl_items_sort)
    return yamlify({references=items}, nil, csl_keys_sort)
end

--- Alternative suffix for YAML files.
-- @within Bibliography files
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
-- @within Bibliography files
function biblio_read (fname)
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

--- Write bibliographic data to a bibliography file.
--
-- The filename suffix determins what format the data is written as.
-- There must be an encoder for that suffix in `BIBLIO_TYPES`.
-- Ends every file with `EOL`. The caveats of `file_write` apply.
--
-- @string fname A filename.
-- @tab[opt] items A list of CSL items. If no items are given,
--  tests whether data can be written in the corresponding format.
-- @treturn[1] str The filename suffix.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is an I/O error.
-- @raise An error if the filename is the empty string.
-- @within Bibliography files
function biblio_write (fname, items)
    -- luacheck: ignore ok
    assert(fname ~= '', 'filename is the empty string')
    local suffix = fname:match '%.(%w+)$'
    if not suffix then return nil, fname .. ': no filename suffix.' end
    local codec = BIBLIO_TYPES[suffix]
    if not codec then return nil, fname .. ': unsupported format.' end
    local encode = codec.encode
    if not encode then return nil, fname .. ': cannot write format.' end
    if not items or #items == 0 then return suffix end
    local ok, ret = pcall(encode, items)
    if not ok then return nil, fname .. ': ' .. tostring(ret) end
    local ok, err, errno = file_write(fname, ret, EOL)
    if not ok then return nil, err, errno end
    return suffix
end

--- Add items from Zotero to a bibliography file.
--
-- If an item is already in the bibliography file, it won't be added again.
-- If items cannot be found, an error is printed to STDERR.
--
-- [Citeproc](https://github.com/jgm/citeproc) appears to recognise
-- formatting in *every* CSL field, so `pandoc-zotxt.lua` does the same.
--
-- The caveats of `file_write` apply.
--
-- @param handle A interface to Zotero or the Zotero Web API.
-- @string fname The name of the bibliography file.
-- @tab ckeys The citation keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
-- @treturn[1] bool `true` if the file was updated or no update was required.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is a file I/O error.
-- @raise See `http_get`.
-- @within Bibliography files
function biblio_update (handle, fname, ckeys)
    -- luacheck: ignore ok fmt err errno
    if #ckeys == 0 then return true end
    local fmt, err = biblio_write(fname)
    if not fmt then return nil, err end
    -- @todo Remove this warning once the script has been dogfooded,
    --       and was out in the open for a while.
    if fmt == 'yaml' or fmt == 'yml' then
        warn 'YAML bibliography file support is experimental!'
    end
    local items, err, errno = biblio_read(fname)
    if not items then
        if errno ~= 2 then return nil, err, errno end
        items = {}
    end
    local item_ids = csl_items_ids(items)
    local nitems = #items
    local n = nitems
    for i = 1, #ckeys do
        local ckey = ckeys[i]
        if not item_ids[ckey] then
            local ok, ret, err = pcall(handle.csl_item, handle, ckey)
            if not ok then
                return nil, tostring(ret)
            elseif ret then
                if fmt == 'yaml' or fmt == 'yml' then
                    ret = mapr(zot_to_md, ret)
                end
                n = n + 1
                items[n] = ret
            else
                log(err)
            end
        end
    end
    if (n == nitems) then return true end
    fmt, err, errno = biblio_write(fname, items)
    if not fmt then return nil, err, errno end
    return true
end


-- PANDOC
-- ======

-- Document parsing
-- ----------------

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
        Table = 'Block',
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
    -- @within Document parsing
    function elem_type (elem)
        local t = type(elem)
        if t ~= 'table' and t ~= 'userdata' then return end
        local et = elem.tag
        -- There is no better way.
        if  not et          and
            elem.meta       and
            elem.blocks     and
            t == 'userdata'
        then
            et = 'Pandoc'
        end
        local ets = {}
        local n = 0
        while et do
            n = n + 1
            ets[n] = et
            et = super_types[et]
        end
        return unpack(ets)
    end

    if pandoc.types and PANDOC_VERSION < {2, 15} then
        -- @fixme It's unclear whether this code ignores pandoc.Doc
        --        in favour of pandoc.Pandoc (as it should) in Pandoc <v2.15.
        -- luacheck: ignore super_types
        local super_types = {}
        for k, v in sorted_pairs(pandoc) do
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
            if type(elem) ~= 'table' then return end
            local mt = getmetatable(elem)
            if not mt or not mt.__type then return end
            return unpack(super_types[mt.__type])
        end
    end
end

do
    -- Clone a Pandoc AST element.
    --
    -- @tparam pandoc.AstElement elem The original.
    -- @treturn pandoc.AstElement The copy.
    local function clone (elem)
        assert(type(elem), 'userdata', 'element is not a Pandoc AST element.')
        if elem.clone then return elem:clone() end
        return Pandoc(elem.blocks:clone(), elem.meta:clone())
    end

    -- @fixme This has not been tested for Pandoc <v2.15.
    if pandoc.types and PANDOC_VERSION < {2, 15} then
        function clone (elem)
            assert(type(elem), 'table', 'element is not a Pandoc AST element.')
            if elem.clone then return elem:clone() end
            local copy = setmetatable({}, getmetatable(elem))
            for k, v in next, elem, nil do rawset(copy, k, v) end
            return copy
        end
    end

    -- Walk a mapping.
    local function walk_lua_mapping (tab, ...)
        for k, v in pairs(tab) do tab[k] = walk(v, ...) end
    end

    -- Walk a sequence.
    local function walk_lua_sequence (tab, ...)
        for i = 1, #tab do tab[i] = walk(tab[i], ...) end
    end

    --- Walk a *List AST element (e.g., `pandoc.OrderedList`).
    local function walk_pandoc_list (elem, ...)
        local content = elem.content
        for i = 1, #content do walk_lua_sequence(content[i], ...) end
    end

    -- Walk a Pandoc document.
    function walk_pandoc_doc (doc, ...)
        doc.meta = walk(doc.meta, ...)
        walk_lua_sequence(doc.blocks, ...)
    end

    -- Walking functions by Pandoc AST element type.
    local walker_fs = {
        Meta = walk_lua_mapping,
        MetaBlocks = walk_lua_sequence,
        MetaList = walk_lua_sequence,
        MetaInlines = walk_lua_sequence,
        MetaMap = walk_lua_mapping,
        BulletList = walk_pandoc_list,
        OrderedList = walk_pandoc_list,
        Pandoc = walk_pandoc_doc
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
    -- @within Document parsing
    function walk (elem, filter, _rd)
        if not _rd then _rd = 0
                   else _rd = _rd + 1
        end
        assert(_rd < 512, 'too much recursion.')
        local ets = {elem_type(elem)}
        local et = ets[1]
        local n = #ets
        if n == 0 then return elem end
        elem = clone(elem)
        local walker_f = walker_fs[et]
        if     walker_f     then walker_f(elem, filter, _rd)
        elseif elem.content then walk_lua_sequence(elem.content, filter, _rd)
        end
        for i = 1, n do
            local func = filter[ets[i]]
            if func then
                local new = func(elem)
                if new ~= nil then elem = new end
            end
        end
        return elem
    end
end

--- Collect bibliographic data from the document's metadata block.
--
-- If a metadata field or a bibliography file cannot be parsed,
-- an error is printed to STDERR.
--
-- @tparam pandoc.MetaMap meta A metadata block.
-- @treturn pandoc.List A list of CSL items.
-- @within Document parsing
function meta_sources (meta)
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

do
    -- Save citation keys that are not in one set into another one.
    --
    -- @tparam pandoc.Cite A citation.
    -- @tab old A set of IDs that should be ignored.
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
    -- If it cannot parse a bibliography file, an error is printed to STDERR.
    --
    -- @tab doc A document.
    -- @bool[opt=false] undef Whether to collect only the citation keys of
    --  sources that are defined neither in the `references` metadata field
    --  nor in a bibliography file.
    -- @treturn {string,...} A list of citation keys.
    -- @treturn int The number of citation keys found.
    -- @raise An error if an item ID is of a wrong data type.
    -- @within Document parsing
    function doc_ckeys (doc, undef)
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
end


-- MAIN
-- ====

--- Add data to a bibliography file and the file to the document's metadata.
--
-- Updates the bibliography file as needed and adds it to the `bibliography`
-- metadata field. Interpretes a relative filename as relative to the
-- directory of the first input file passed to **pandoc**, or, if not input
-- files were given, as relative to the current working directory.
--
-- @param handle A interface to Zotero or the Zotero Web API.
-- @tparam pandoc.MetaMap meta A metadata block, with the field
--  `zotero-bibliography` set to the filename of the bibliography file.
-- @tab ckeys The citaton keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
-- @treturn[1] pandoc.Meta An updated metadata block, with the field
--  `bibliography` added if needed.
-- @treturn[2] nil `nil` if no sources were found,
--  `zotero-bibliography` is not set, or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `http_get`.
-- @within Main
function add_biblio (handle, meta, ckeys)
    -- luacheck: ignore err
    if #ckeys == 0 then return end
    local fname, err = meta_param(meta, 'bibliography')
    if not fname then return nil, err end
    local ok, err = biblio_update(handle, fname, ckeys)
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

--- Add bibliographic data to the `references` metadata field.
--
-- If a source cannot be found, an error is printed to STDERR.
--
-- @param handle A interface to Zotero or the Zotero Web API.
-- @tparam pandoc.MetaMap meta A metadata block.
-- @tab ckeys The citation keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
-- @treturn[1] table An updated metadata block,
--  with the field `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `http_get`.
-- @within Main
function add_refs (handle, meta, ckeys)
    if #ckeys == 0 then return end
    if not meta.references then meta.references = MetaList({}) end
    local n = #meta.references
    for i = 1, #ckeys do
        local ok, ret, err = pcall(handle.csl_item, handle, ckeys[i])
        if not ok  then return nil, tostring(ret)
        elseif ret then n = n + 1
                        meta.references[n] = csl_item_to_meta(ret)
                   else log(err)
        end
    end
    return meta
end

do
    -- Convert a Pandoc metadata value to a string.
    --
    -- @param pandoc.MetaValue v The value.
    function from_string (v)
        local ok, str = pcall(stringify, v)
        if not ok then return nil, str end
        if str == '' then return nil, 'is the empty string.' end
        return str
    end

    -- A mapping of key names to functions that parse and verify values.
    local keys = {}

    -- Get the bibliography file to use.
    function keys.bibliography (v)
        local fname, err = from_string(v)
        if not fname then return nil, err end
        if not path_is_abs(fname) then fname = path_join(wd(), fname) end
        return fname
    end

    -- Get citation key types to use.
    --
    -- Citation key types are taken from the `zotero-citekey-types`
    -- metadata field. If a value of that field does *not* pick out a
    -- citation key type listed in `Zotxt.citekey_types`, it is ignored.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @treturn[1] pandoc.List A list of citation key types.
    -- @treturn[2] nil If no valid citation key types were found.
    -- @treturn[2] string An error message, if applicable.
    function keys.citekey_types (v)
        if v.tag == 'MetaInlines'  then
            v = MetaList{v}
        elseif v.tag ~= 'MetaList' then
            return nil, 'neither a scalar nor a list.'
        end
        local citekey_types = List()
        local n = 0
        for i = 1, #v do
            local str, err = from_string(v[i])
            if not str then return nil, err end
            if not Zotxt.citekey_types:includes(str) then
                return nil, str .. ': not a citation key type.'
            end
            n = n + 1
            citekey_types[n] = str
        end
        if n > 0 then return citekey_types end
    end

    -- Get the Zotero API key to use.
    keys.api_key = from_string

    -- Get the Zotero user ID to use.
    keys.user_id = from_string

    -- Get the Zotero Connector to use.
    keys.connector = from_string

    --- Lookup a parameter in the document's metadata field.
    --
    -- Parameter names are translated to metadata field names by
    -- prefixing them with 'zotero-' and by replacing underscores
    -- with dashes.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @string key A parameter name.
    -- @return[1] The value of that parameter.
    -- @treturn[2] nil `nil` if there is no such parameter.
    -- @treturn[2] string An error message.
    -- @within Main
    function meta_param(meta, key)
        local f = keys[key]
        local mk = 'zotero-' .. key:gsub('_', '-')
        if not f then return nil, mk .. ': no such parameter.' end
        local mv = meta[mk]
        if not mv then return end
        local v, err = f(mv)
        if err then return nil, mk .. ': ' .. err end
        return v
    end

    --- Get parameters from the document's metadata field.
    --
    -- See `meta_param` on how parameter names are translated to
    -- metadata field names.
    --
    -- @tparam pandoc.MetaMap meta A metadata block.
    -- @treturn {string=tab,...} A mapping of keys to values.
    -- @within Main
    function meta_params (meta)
        local conf = {}
        for k in pairs(keys) do
            local v, err = meta_param(meta, k)
            if err then return nil, err end
            if v then conf[k] = v end
        end
        return conf
    end
end

--- Collect citations and add bibliographic data to a document.
--
-- If errors occur, error messages are printed to STDERR.
--
-- See the manual for details.
--
-- @tparam table doc A document.
-- @treturn[1] table `doc`, but with bibliographic data added.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @raise See `http_get`.
-- @within Main
function main (doc)
    local ckeys = doc_ckeys(doc, true)
    if next(ckeys) == nil then return end

    local conf, err = meta_params(doc.meta)
    if not conf then
        log(err)
        return
    end

    local zotxt, zotweb
    if not conf.connector then
        zotxt = Zotxt()
        if conf.api_key then
            zotweb = ZotWeb{api_key = conf.api_key, _user_id = conf.user_id}
        end
    else
        if conf.connector == 'zotxt' then
            zotxt = Zotxt()
        elseif conf.connector == 'zotweb' then
            if not conf.api_key then
                log 'you need to set an API key to use the Zotero Web API.'
                return
            end
            zotweb = ZotWeb{api_key = conf.api_key, _user_id = conf.user_id}
        else
            log '$conf.connector: no such Zotero connector.'
            return
        end
    end

    local add_srcs = add_refs
    if conf.bibliography then add_srcs = add_biblio end

    if conf.citekey_types then
        if zotxt  then zotxt.citekey_types = conf.citekey_types  end
        if zotweb then zotweb.citekey_types = conf.citekey_types end
    end

    for i = 1, 2 do
        local handle
        if     i == 1 then handle = zotxt
        elseif i == 2 then handle = zotweb
        end
        if handle then
            -- @todo Remove this warning once:
            --       (1) The test suite is complete.
            --       (2) The script has been out for a while.
            --       (3) The script has been dogfooded.
            if handle == zotweb then
                warn 'fetching data from the Zotero Web API is experimental!'
            end
            -- luacheck: ignore err
            local meta, err = add_srcs(handle, doc.meta, ckeys)
            if meta then
                doc.meta = meta
                return doc
            elseif err then
                log(err)
            end
        end
    end
end


-- BOILERPLATE
-- ===========
--
-- Returning the whole script, rather than only a list of mappings of
-- Pandoc data types to functions, allows to do unit testing.

M[1] = {Pandoc = main}

return M