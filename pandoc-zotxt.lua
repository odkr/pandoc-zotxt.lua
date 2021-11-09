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
-- **pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
-- them either to a document's "references" metadata field or to a
-- bibliography file, where Pandoc can pick them up.
--
-- Cite your sources using "Better BibTeX Citation Keys" (provided by Better
-- BibTeX for Zotero) or "easy citekeys" (provided by *zotxt*). Then tell
-- **pandoc** to filter your document through **pandoc-zotxt.lua**
-- before processing citations (Zotero must be running).
-- That's all there is to it.
--
-- **pandoc-zotxt.lua** only looks up sources in Zotero that are defined
-- neither in the "references" metadata field nor in a bibliography file.
--
--
-- BIBLIOGRAPHY FILES
-- ==================
--
-- **pandoc-zotxt.lua** can add sources to a special bibliography file,
-- rather than to the "references" metadata field. This speeds up subsequen
-- processing of the same document, because sources that are in that file
-- already need not be fetched again from Zotero.
--
-- You tell **pandoc-zotxt.lua** to add sources to such a special bibliography
-- file by setting the "zotero-bibliography" metadata field to a filename.
-- If the filename is relative, it is interpreted as relative to the directory
-- of the first input file passed to **pandoc** or, if no input file was
-- given, as relative to the current working directory. The format of the
-- file is determined by its filename ending:
--
-- | **Ending** | **Format** | **Feature**                        |
-- | ---------- | ---------- | ---------------------------------- |
-- | `.json`    | CSL JSON   | More reliable.                     |
-- | `.yaml`    | CSL YAML   | Easier to edit with a text editor. |
--
--
-- The bibliography file is added to the "bibliography" metadata field
-- automatically. You can safely set "zotero-bibliography" and "bibliography"
-- at the same time.
--
-- The sources in the bibliography file are neither updated nor deleted.
-- If you want to update them, delete the file.
--
--
-- EXAMPLE
-- =======
--
--     pandoc -L pandoc-zotxt.lua -C <<EOF
--     See @doe2020Title for details.
--     EOF
--
--
-- This will look up "doe2020Title" in Zotero.
--
--
-- KNOWN ISSUES
-- ============
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that do not set the "User Agent" HTTP header. And **pandoc** does not.
-- As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
-- versions of Zotero unless you tell **pandoc** to set that header.
--
-- **pandoc-zotxt.lua** creates a temporary file when it adds sources to
-- a bibliography file. If Pandoc exits because it catches a signal, for
-- example, because you press **Ctrl**-**c**, then this file will *not*
-- be deleted (this is a bug in Pandoc and in the process of being fixed).
--
-- Moreover, if you are using Pandoc up to v2.7, another process may,
-- mistakenly, use the same temporary file at the same time, though this
-- is highly unlikely.
--
--
-- SECURITY
-- ========
--
-- If you are using Pandoc up to v2.7 and place the special bibliography file
-- in a directory that other users have write access to, then they can read
-- and change the content of that file, regardless of whether they have
-- permission to read or write the file itself.
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
-- @script pandoc-zotxt.lua
-- @release 1.1.0b3
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020, 2021 Odin Kroeger
-- @license MIT


-- INITIALISATION
-- ==============
--
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
local concat = table.concat
local unpack = table.unpack

local stringify = pandoc.utils.stringify

local List = pandoc.List
local MetaInlines = pandoc.MetaInlines
local MetaList = pandoc.MetaList
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
VERSION = '1.1.0b3'


-- Operating system
-- ----------------

--- The path segment seperator of your operating system.
-- @within File I/O
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence of your operating system.
-- @within File I/O
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- Modules
-- -------

do
    -- Patterns that sanitise directory paths.
    local sanitisation_patterns = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove './' at the beginning of a path.
        {'^%.' .. PATH_SEP, ''},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'}
    }


    --- Sanitise a path.
    --
    -- @string path The path.
    -- @treturn string A sanitised path.
    -- @within File I/O
    -- @fixme Untested.
    function path_sanitise (path)
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
    -- @treturn[1] string The directory the file is in.
    -- @treturn[1] string The file's name.
    -- @treturn[2] nil `nil` if `path` is the empty string ('').
    -- @treturn[2] string An error message.
    -- @raise An error if the path is the empty string.
    -- @within File I/O
    function path_split (path)
        if path == '' then return nil, 'path is the empty string ("").' end
        local dir, fname = path:match(split_pattern)
        dir = path_sanitise(dir)
        if     dir == ''   then dir = '.'
        elseif fname == '' then fname = '.' end
        assert(dir ~= '')
        assert(fname ~= '')
        return dir, fname
    end
end


do
    -- Join path segments (worker)
    --
    -- Has the same function signature as `path_join`.
    -- Does not sanitise the path it returns.
    local function join (a, b, ...)
        assert(type(a == 'string'), 'path segment is not a string.')
        assert(a ~= '', 'path segment is the empty string.')
        if not b then return a end
        return a .. PATH_SEP .. path_join(b, ...)
    end

    --- Join multiple path segments.
    --
    -- @string ... Path segments.
    -- @treturn string The complete path.
    -- @raise An error if no path segments are given or if
    --  a path segment is the empty string ('').
    -- @within File I/O
    function path_join (...)
        return path_sanitise(join(...))
    end
end


do
    local script_dir, script_name = path_split(PANDOC_SCRIPT_FILE)

    --- The directory the script is in.
    -- @within Metadata
    SCPT_DIR = script_dir

    --- The filename of the script.
    -- @within Metadata
    SCPT_NAME = script_name
end


do
    local repo = NAME .. '-' .. VERSION
    local sub_dir = path_join('share', 'lua', '5.4', '?.lua')
    package.path = concat({package.path,
        path_join(SCPT_DIR, sub_dir),
        path_join(SCPT_DIR, repo, sub_dir)
    }, ';')
end

local text = require 'text'
local json = require 'lunajson'


-- FUNCTIONS
-- =========

-- Warnings
-- --------

--- Print an error message to STDERR.
--
-- Prefixes the message with `SCPT_NAME` and ': ', and appends `EOL`.
--
-- @param msg The message. Coerced to `string`.
-- @param ... Arguments to that message (think `string.format`).
--  Only applied if `msg` is a `string`.
-- @within Warnings
function errf (msg, ...)
    if type(msg) ~= 'string' then msg = tostring(msg)
                             else msg = msg:format(...)
    end
    io.stderr:write(SCPT_NAME, ': ', msg , EOL)
end


--- Print a warning to STDERR.
--
-- Only prints values if `PANDOC_STATE.verbosity` is *not* 'ERROR'.
-- Otherwise the same as `errf`.
--
-- @param ... Takes the same arguments as `errf`.
-- @within Warnings
function warnf (...)
    if PANDOC_STATE.verbosity ~= 'ERROR' then errf(...) end
end


-- Meta-functions
-- --------------

--- Run cleanup code after a function.
--
-- The cleanup code runs regardless of whether an error occurs
-- in the function. But Lua filters cannot respond to signals,
-- so it is *not* run if Pandoc exits because of a signal.
--
-- @func ex The cleanup code. Its first argument indicates whether
--  the protected call to `func` exited with an error. The remaining
--  arguments are the values returned by `func`.
-- @func func The code itself. Called in protected mode.
-- @param ... Passed on to `func`.
-- @return The values that `func` returns.
-- @raise An error if `func` raises an error.
-- @within Higher-order functions
function do_after (ex, func, ...)
    local vs = {pcall(func, ...)}
    ex(unpack(vs))
    local ok, err = unpack(vs, 1, 2)
    if not ok then error(err) end
    return unpack(vs, 2)
end


-- Tables
-- ------

--- Return the keys and the length of a table.
--
-- @tab tab The table.
-- @treturn tab The keys of `tab`.
-- @treturn int `tab`'s length.
-- @within Table manipulation
function keys (tab)
    local ks = {}
    local n = 0
    local k = next(tab, nil)
    while k ~= nil do
        n = n + 1
        ks[n] = k
        k = next(tab, k)
    end
    return ks, n
end


--- Copy a data tree.
--
-- Handles metatables, recursive structures, tables as keys, and
-- avoids the `__pairs` and `__newindex` metamethods.
-- Copies are deep.
--
-- @param data Arbitrary data.
-- @return A deep copy of `data`.
-- @within Table manipulation
--
-- @usage
--      > x = {1, 2, 3}
--      > y = {x, 4}
--      > c = copy(y)
--      > table.insert(x, 4)
--      > table.unpack(c[1])
--      1       2       3
-- @todo Add an option to make shallow copies.
function copy (data, _seen)
    -- Borrows from:
    -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
    -- * <http://lua-users.org/wiki/CopyTable>
    if type(data) ~= 'table' then return data end
    if _seen and _seen[data] then return _seen[data] end
    local ret = setmetatable({}, getmetatable(data))
    _seen = _seen or {}
    _seen[data] = ret
    for k, v in next, data, nil do
        rawset(ret, copy(k, _seen), copy(v, _seen))
    end
    return ret
end


--- Recursively apply a function to every value of a tree.
--
-- The function is applied to *every* node of the data tree.
-- The tree is parsed bottom-up.
--
-- @func func A function that takes a value and returns a new one.
--  If the function returns `nil`, the original value is kept.
-- @param data A data tree.
-- @return `data` with `func` applied.
-- @raise An error if the data is nested too deeply.
-- @within Table manipulation
function rmap (func, data, _rd)
    if type(data) ~= 'table' then
        local nv = func(data)
        if nv == nil then return data end
        return nv
    end
    if not _rd then _rd = 0
               else _rd = _rd + 1
    end
    assert(_rd < 512, 'too much recursion.')
    local ret = {}
    local k = next(data, nil)
    while k ~= nil do
        local v = data[k]
        if type(v) == 'table' then v = rmap(func, v, _rd) end
        local nv = func(v)
        if nv == nil then ret[k] = v
                     else ret[k] = nv
        end
        k = next(data, k)
    end
    return ret
end


do
    local lower = text.lower

    --- Recursively convert table keys to lowercase.
    --
    -- @tab tab The table.
    -- @return A copy of `tab` with keys in lowercase.
    -- @raise An error if the data is nested too deeply.
    -- @within Table manipulation
    function lower_keys (tab, _rd)
        if not _rd then _rd = 0 end
        assert(_rd < 512, 'too much recursion.')
        local ret = {}
        for k, v in pairs(tab) do
            if type(k) == 'string' then k = lower(k)               end
            if type(v) == 'table'  then v = lower_keys(v, _rd + 1) end
            ret[k] = v
        end
        return ret
    end
end


--- Iterate over the keys of a table in a given order.
--
-- @tab tab A table.
-- @func[opt] func A sorting function.
--  If no function is given, sorts by number.
-- @treturn func A *stateful* iterator over `tab`.
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


-- File I/O
-- --------

--- Check whether a path is absolute.
--
-- @string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
-- @raise An error if the path is the empty string ('').
-- @within File I/O
function path_is_abs (path)
    assert(path ~= '', 'path is the empty string ("").')
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


    --- Prettify paths (worker).
    --
    -- Removes the current working directory from the beginning of a path
    -- and, on POSIX systems, replaces the user's home directory with '~'.
    --
    -- @string path A path.
    -- @treturn string A prettier path.
    local function prettify (path)
        assert(path ~= '', 'Path is the empty string ("").')
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

    --- Prettify paths.
    --
    -- Removes the current working directory from the beginning of a path
    -- and, on POSIX systems, replaces the user's home directory with '~'.
    --
    -- @string ... Paths.
    -- @treturn[...] string Prettier paths.
    -- @within File I/O
    function path_prettify (...)
        local paths = {...}
        assert(#paths > 0, 'No paths given.')
        return unpack(rmap(prettify, paths))
    end
end


--- Get a directory to use as working directory.
--
-- @treturn string The directory of the first input file
--  or '.' if none was given.
-- @within File I/O
function wd ()
    local fname = PANDOC_STATE.input_files[1]
    if not fname then return '.' end
    assert(type(fname) == 'string')
    assert(fname ~= '')
    local wd = path_split(fname)
    return wd
end


--- Check whether a filename refers to a file.
--
-- @string fname The filename.
-- @treturn[1] boolean `true` if the file exists.
-- @treturn[2] nil `nil` if the file does not exist.
-- @treturn[2] string An error message.
-- @treturn[2] int The error number 2.
-- @within File I/O
function file_exists (fname)
    assert(fname ~= '', 'filename is the empty string ("").')
    local file, err, errno = io.open(fname, 'r')
    if not file then return nil, err, errno end
    assert(file:close())
    return true
end


do
    local rsrc_path = PANDOC_STATE.resource_path

    --- Locate a file in Pandoc's resource path.
    --
    -- Absolute filenames are returned as they are.
    --
    -- @string fname A filename.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the file could not be found.
    -- @treturn[2] string An error message.
    -- @within File I/O
    function file_locate (fname)
        if not rsrc_path or file_exists(fname) then return fname end
        for i = 1, #rsrc_path do
            local f = path_join(rsrc_path[i], fname)
            if file_exists(f) then return f end
        end
        return nil, fname .. ': not found in resource path.'
    end
end


--- Read a file.
--
-- @string fname The name of the file.
-- @treturn[1] string The content of the file.
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
    local function path_mk_abs (path)
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
    -- @raise An error if `file` is neither a `string` nor a file handle.
    local function write_to_file (fname, ...)
        assert(fname ~= '', 'filename is the empty string.')
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
    -- Prints warnings and errors to STDERR.
    --
    -- **Caveats:** Data is first written to a temporary file, that file is
    -- then renamed to the given filename. This is safe and secure starting
    -- with Pandoc v2.8. If you are using an older version of Pandoc, then
    -- the caveats of `with_tmp_file` apply.
    --
    -- @string fname The name of the file.
    -- @string ... The data.
    -- @treturn[1] bool `true` if the data was written to the given file.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] int An error number.
    -- @within File I/O
    function file_write(fname, ...)
        assert(fname ~= '', 'filename is the empty string.')
        local dir, base = path_split(path_mk_abs(fname))
        local data = {...}
        local tmp_dir_copy
        local vs = {with_temporary_directory(dir, 'pdz', function (tmp_dir)
            tmp_dir_copy = tmp_dir
            warnf('created temporary directory %s.', path_prettify(tmp_dir))
            local tmp_file = path_join(tmp_dir, base)
            local ok, err, errno = write_to_file(tmp_file, unpack(data))
            if not ok then return nil, err, errno end
            if file_exists(fname) then
                warnf('replacing %s.', path_prettify(fname))
            end
            return os.rename(tmp_file, fname)
        end)}
        if tmp_dir_copy and not file_exists(tmp_dir_copy) then
            warnf('removed %s.', path_prettify(tmp_dir_copy))
        end
        return unpack(vs)
    end

    if not pandoc.types or PANDOC_VERSION < {2, 8} then
        function file_write(fname, ...)
            -- luacheck: ignore err
            assert(fname ~= '', 'filename is the empty string.')
            local dir = path_split(fname)
            local data = {...}
            local tmp_file_copy
            local vs = {with_tmp_file(dir, nil, function(tmp_file)
                tmp_file_copy = tmp_file
                warnf('writing data to temporary file %s.',
                      path_prettify(tmp_file))
                local ok, err, errno = write_to_file(tmp_file, unpack(data))
                if not ok then return nil, err, errno end
                if file_exists(fname) then
                    warnf('replacing %s.', path_prettify(fname))
                end
                return os.rename(tmp_file, fname)
            end)}
            if tmp_file_copy and not file_exists(tmp_file_copy) then
               warnf('%s renamed to %s.', path_prettify(tmp_file_copy, fname))
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
    --  Must not be the empty string ('').
    -- @string[optchain='pdz-XXXXXXXXXX'] templ A template for the filename.
    --  'X's are replaced with random alphanumeric characters.
    --  Must contain at least six 'X's.
    -- @treturn[1] string A filename.
    -- @treturn[2] nil `nil` if the generated filename is in use.
    -- @treturn[2] string An error message.
    -- @raise An error if the template or the directory is
    --  not a string or the empty string ('').
    -- @within File I/O
    function tmp_fname (dir, templ)
        if templ == nil then
            templ = 'pdz-XXXXXXXXXX'
        else
            assert(type(templ) == 'string')
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
        return nil, 'no unused filename.'
    end
end


do
    -- Remove a file unless its second and third argument are `true`.
    --
    -- Prints an error to STDERR if the file could not be removed.
    local function clean_up (fname, status, result)
        if status and result then return end
        warnf('removing %s.', fname)
        local ok, err, errno = os.remove(fname)
        if not ok and errno ~= 2 then errf(err) end
    end

    --- Run a function with a temporary file.
    --
    -- If the function raises an error or returns `nil` or `false`, then the
    -- temporary file is deleted. Prints an error to STDERR if the file could
    -- not be removed.
    --
    -- The function passed to `with_tmp_file` must *not* change the working
    -- directory, say, by invoking, `pandoc.system.with_working_directory`.
    -- This could cause an abitrary file to be deleted instead of the
    -- temporary one; it could also cause the automatic deletion of the
    -- temporary file to fail.
    --
    -- **Caveats:** Any temporary file you `io.open` may have been created
    -- by *another* process. If you create a temporary file in a directory
    -- that others users have write access to, `/tmp`, for example, then
    -- this is a security issue.
    --
    -- @string[opt] dir A directory to prefix the name of the temporary
    --  file with. Must not be the empty string (''). See `tmp_fname`.
    -- @string[optchain='pdz-XXXXXXXXXX'] templ A template for the name of the
    --  temporary file. 'X's are replaced with random alphanumeric characters.
    --  Must contain at least six 'X's. See `tmp_fname`.
    -- @func func The function to run.
    --  Passed the name of the temporary file as first argument.
    -- @param ... Passed on to `func`.
    -- @return The values that `func` returns.
    -- @raise An error if `func` raises an error.
    -- @within File I/O
    function with_tmp_file (dir, templ, func, ...)
        local t_fname, err = tmp_fname(dir, templ)
        if not t_fname then return nil, err end
        local function my_clean_up (...) return clean_up(t_fname, ...) end
        return do_after(my_clean_up, func, t_fname, ...)
    end
end


-- Networking
-- ----------

--- Retrieve data from a URL via an HTTP GET request.
--
-- @string url The URL.
-- @treturn string The MIME type of the HTTP content.
-- @treturn string The HTTP content itself.
-- @raise An error if no data can be retrieved.
--  This error can only be caught since Pandoc v2.11.
-- @within Networking
function http_get (url)
    return pandoc.mediabag.fetch(url, '.')
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

    -- Pairs of expressions and replacements to escape Markdown.
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

    --- Escape Markdown.
    --
    -- Only escapes [Markdown that Pandoc recognises in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @string str A string.
    -- @treturn string `str` with Markdown escaped.
    -- @within Converters
    function esc_md (str)
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
    -- Works like `esc_md` but for Pandoc string elements.
    --
    -- @tparam pandoc.Str str A string element.
    -- @treturn pandoc.Str A string with Markdown markup escaped.
    function esc.Str (str)
        str.text = esc_md(str.text)
        return str
    end


    -- Filter to conver to Markdown text.
    local md = {}

    -- Make a function that converts an element to Markdown.
    --
    -- @string char The Markdown markup character for that element.
    -- @treturn func The conversion function.
    local function mk_elem_conv_f (char)
        return function (elem)
            local str = stringify(pandoc.walk_inline(elem, md))
            return Str(char .. str .. char)
        end
    end


    -- Convert AST elements into Markdown text.
    md.Emph = mk_elem_conv_f '*'
    md.Strong = mk_elem_conv_f '**'
    md.Subscript = mk_elem_conv_f '~'
    md.Superscript = mk_elem_conv_f '^'


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
    -- @fixme no longer works. Might be due to walk
    function markdownify (elem)
        return stringify(walk(walk(elem, esc), md))
    end
end


do
    local rep = string.rep
    local format = string.format
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


    --- Generate a YAML representation of a data tree.
    --
    -- Uses `EOL` to end lines. Only parses UTF-8 encoded strings.
    -- Strings in other encodings will be mangled.
    -- Does *not* escape *all* non-printable characters (because Unicode).
    --
    -- @param data The data.
    -- @int[opt=4] ind How many spaces to indent blocks.
    -- @func[optchain] sort_f A function to sort keys of mappings.
    --  Defaults to sorting them lexically.
    -- @treturn[1] string A YAML string.
    -- @treturn[2] nil `nil` if the data cannot be represented in YAML.
    -- @treturn[2] string An error message.
    -- @raise An error if the data cannot be expressed in YAML
    --  or is nested too deeply.
    -- @within Converters
    function yamlify (data, ind, sort_f, _col, _rd)
        if not _rd then _rd = 0 end
        assert(_rd < 1024, 'too much recursion.')
        if not ind then ind = 4 end
        local t = type(data)
        local conv = converters[t]
        if conv then return conv(data) end
        if t ~= 'table' then error(t .. ': cannot be represented in YAML.') end
        _rd = _rd + 1
        if not _col then _col = 0 end
        local ret = ''
        local n = #data
        local nkeys = select(2, keys(data))
        local sp = spaces(_col)
        if n == nkeys then
            local col = _col + 2
            for i = 1, n do
                if i > 1 then ret = ret .. sp end
                ret = ret .. '- ' .. yamlify(data[i], ind, sort_f, col, _rd)
                if i ~= n then ret = ret .. EOL end
            end
        else
            local i = 0
            for k, v in sorted_pairs(data, sort_f) do
                i = i + 1
                if type(k) == 'number' then k = tostring(k)
                                       else k = scalarify(k)
                end
                if i > 1 then ret = ret .. sp end
                ret = ret .. k .. ':'
                local col = _col + ind
                if type(v) == 'table' then ret = ret .. EOL .. spaces(col)
                                      else ret = ret .. ' '
                end
                ret = ret .. yamlify(v, ind, sort_f, col, _rd)
                if i ~= nkeys then ret = ret .. EOL end
            end
        end
        return ret
    end
end


do
    -- Replace '<sc>...</sc>' pseudo-HTML with <span> tags.
    --
    -- Zotero supports using '<sc>...</sc>' to set text in small caps.
    -- Pandoc throws those tags out.
    --
    -- @string str A string.
    -- @treturn string `str` with `<sc>...</sc>` replaced with <span> tags.
    local function conv_sc_to_span (str)
        local tmp, n = str:gsub('<sc>',
            '<span style="font-variant: small-caps">')
        if n == 0 then return str end
        local ret, m = tmp:gsub('</sc>', '</span>')
        if m == 0 then return str end
        return ret
    end


    --- Convert Zotero pseudo-HTML to Markdown.
    --
    -- Only supports [pseudo-HTML that Pandoc recognises in bibliographic
    -- data](https://pandoc.org/MANUAL.html#specifying-bibliographic-data).
    --
    -- @string html Pseudo-HTML code.
    -- @treturn[1] string Text formatted in Markdown.
    -- @treturn[2] nil `nil` if `html` is not a `string`.
    -- @treturn[2] string An error message.
    -- @within Converters
    function html_to_md (html)
        if type(html) ~= 'string' then
            return nil, 'pseudo-HTML code is not a string.'
        end
        local sc_replaced = conv_sc_to_span(html)
        local doc = pandoc.read(sc_replaced, 'html')
        return markdownify(doc)
    end
end


-- zotxt
-- -----

--- The URL of the [zotxt](https://github.com/egh/zotxt) endpoint.
--
-- @within zotxt
ZOTXT_BASE_URL = 'http://localhost:23119/zotxt/items?'


--- Types of citation keys [zotxt](https://github.com/egh/zotxt) supports.
--
-- @table ZOTXT_KEYTYPES
-- @within zotxt
ZOTXT_KEYTYPES = {
    'key',             -- Zotero item ID
    'betterbibtexkey', -- Better BibTeX citation key
    'easykey',         -- zotxt easy citekey
}


do
    -- luacheck: ignore assert pcall tostring type
    local assert = assert
    local pcall = pcall
    local tostring = tostring
    local type = type
    local floor = math.floor
    local match = string.match
    local read = pandoc.read
    local decode = json.decode
    local base_url = ZOTXT_BASE_URL
    local key_ts = ZOTXT_KEYTYPES
    local n_key_ts = #key_ts
    local utf8_p = ';%s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]="?[Uu][Tt][Ff]%-8"?%s*$'


    -- Prototype for zotxt errors.
    --
    -- @type err
    local err = {}

    -- Metatable for zotxt errors.
    err.mt = {}
    setmetatable(err, err.mt)

    -- Create a zotxt error object.
    --
    -- @string id The ID of the source that triggered the error.
    -- @treturn err A zotxt error object.
    function err.mt:__call(id)
            return setmetatable({id = id}, self)
    end

    -- Convert a zotxt error into an error message.
    --
    -- @treturn string An error message.
    function err:__tostring ()
        local mt = getmetatable(self)
        return mt.template:gsub('$([%a%w_]*)', self)
    end


    -- Prototype for fetch errors.
    --
    -- @see `err`.
    fetch_err = copy(err)
    fetch_err.template = '$id: failed to fetch data from Zotero.'


    -- Prototype for UTF-8 errors.
    --
    -- @see `err`.
    utf8_err = copy(err)
    utf8_err.template = '$id: data fetched from zotxt is not encoded in UTF-8.'


    -- Retrieve bibliographic data from Zotero (worker).
    --
    -- Takes an item ID and a parsing function, queries *zotxt* for that ID,
    -- passes whatever *zotxt* returns to the parsing function, and then
    -- returns whatever the parsing function returns. The parsing function
    -- should raise an error if its argument cannot be interpreted as
    -- bibliographic data.
    --
    -- Tries every citation key type defined in `ZOTXT_KEYTYPES` until the
    -- query is successful or no more citation key types are left.
    --
    -- @func parse_f A function that takes an HTTP GET response,
    --  typically, a CSL JSON string, and a MIME type,
    --  returns a CSL item, and raises an error if, and only if,
    --  it cannot interpret the HTTP get response as a CSL item.
    -- @string id An item ID, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An error if the data retrieved from *zotxt* is *not* encoded
    --  in UTF-8 or if no data can be retrieved from *zotxt* at all.
    --  The latter error can only be caught since Pandoc v2.11.
    -- @within zotxt
    local function get (parse_f, id)
        for i = 1, n_key_ts do
            -- zotxt supports searching for multiple citation keys at once,
            -- but if a single one cannot be found, it replies with a cryptic
            -- error message (for easy citekeys) or an empty response
            -- (for Better BibTeX citation keys).
            local query_url = concat{base_url, key_ts[i], '=', id}
            local ok, mt, data = pcall(http_get, query_url)
            assert(ok, fetch_err(id))
            assert(mt or match(mt, utf8_p), utf8_err(id))
            if mt ~= '' then
                -- luacheck: ignore ok
                local ok, item = pcall(parse_f, data, mt)
                if ok then
                    if i ~= 1 then
                        key_ts[1], key_ts[i] = key_ts[i], key_ts[1]
                    end
                    return item
                end
            end
        end
        return nil, id .. ': not found.'
    end


    -- Convert numbers to strings.
    --
    -- Also converts floating point numbers to integers. This is needed
    -- because all numbers are floating point numbers in JSON, but some
    -- versions of Pandoc expect integers.
    --
    -- @tab data The data.
    -- @return A copy of `data` with numbers converted to strings.
    -- @raise An error if the data is nested too deeply.
    -- @within Converters
    local function num_to_str (data)
        if type(data) ~= 'number' then return data end
        return tostring(floor(data))
    end


    --- Convert a CSL JSON string to a Lua data structure.
    --
    -- @string str A CSL JSON string.
    -- @return A Lua data structure.
    local function json_to_lua (str)
        assert(str ~= '')
        return rmap(num_to_str, decode(str)[1])
    end


    --- Retrieve bibliographic data from Zotero as CSL item.
    --
    -- Returns bibliographic data as a Lua table. That table can be
    -- passed to `biblio_write`; it should *not* be used in the `references`
    -- metadata field (unless you are using Pandoc prior to v2.11).
    --
    -- @string id An item ID, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An error if the data retrieved from *zotxt* is *not* encoded
    --  in UTF-8 or if no data can be retrieved from *zotxt* at all.
    --  The latter error can only be caught since Pandoc v2.11.
    -- @within zotxt
    function zotxt_csl_item (id)
        assert(id ~= '', 'ID is the empty string ("").')
        local ref, err = get(json_to_lua, id)
        if not ref then return nil, err end
        ref.id = id
        return ref
    end


    --- Convert a CSL JSON string to Pandoc metadata.
    --
    -- @string str A CSL JSON string.
    -- @treturn pandoc.MetaMap Pandoc metadata.
    local function json_to_meta (str)
        assert(str ~= '')
        return read(str, 'csljson').meta.references[1]
    end


    --- Retrieve bibliographic data from Zotero as Pandoc metadata.
    --
    -- Returns bibliographic data as a Pandoc metadata value. That value
    -- can be used in the `references` metadata field; it should *not* be
    -- passed to `biblio_write`.
    --
    -- @string id An item ID, e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] pandoc.MetaMap Bibliographic data for that source.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @raise See `zotxt_csl_item`.
    -- @within zotxt
    function zotxt_source (id)
        assert(id ~= '', 'ID is the empty string ("").')
        local ref, err, errtype = get(json_to_meta, id)
        if not ref then return nil, err, errtype end
        ref.id = MetaInlines{Str(id)}
        return ref
    end

    -- (a) The CSL JSON reader is only available since Pandoc v2.11.
    -- (b) However, pandoc-citeproc had a (useful) bug and parses formatting
    --     tags in metadata fields, so there is no need to treat metadata
    --     fields and bibliography files differently before Pandoc v2.11.
    -- See <https://github.com/jgm/pandoc/issues/6722> for details.
    if not pandoc.types or PANDOC_VERSION < {2, 11} then
        zotxt_source = zotxt_csl_item
    end
end


-- Bibliography files
-- ------------------

--- The preferred order of keys in YAML bibliography files.
--
-- [Appendix IV](https://docs.citationstyles.org/en/stable/specification.html#appendix-iv-variables)
-- of the CSL specification lists all field names.
--
-- @see csl_keys_sort
-- @within Bibliography files
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


--- Read the IDs from the content of a BibLaTeX file.
--
-- @string str The content of a BibLaTeX file.
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


--- Read the IDs from the content of a BibTeX file.
--
-- @string str The content of a BibTeX file.
-- @treturn {{id=string},...} A list of item IDs.
-- @within Bibliography files
BIBLIO_TYPES.bibtex = BIBLIO_TYPES.bib


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


do
    local key_order = {}
    for i = 1, #CSL_KEY_ORDER do key_order[CSL_KEY_ORDER[i]] = i end

    --- Sorting function for CSL field names.
    --
    -- Sorts field in the order in which they are listed in `CSL_KEY_ORDER`.
    -- Unlisted fields are placed after listed ones in lexical order.
    --
    -- @string a A CSL fieldname.
    -- @string b Another CSL fieldname.
    -- @treturn bool Whether `a` should come before `b`.
    -- @within Bibliography files
    function csl_keys_sort (a, b)
        local i, j = key_order[a], key_order[b]
        if i and j then return i < j end
        if i then return true end
        if j then return false end
        return a < b
    end
end


--- Sorting function for CSL items.
--
-- @tab a A CSL item.
-- @tab b Another CSL item.
-- @treturn bool Whether `a` should come before `b`.
-- @within Bibliography files
function csl_items_sort (a, b)
    return a.id < b.id
end


--- Pick the IDs of CSL items out of a list of CSL items.
--
-- @tab items A list of CSL items.
-- @treturn {[string]=true,...} A [set](https://www.lua.org/pil/11.5.html)
--  of item IDs.
-- @raise An error if an item has an ID that cannot be coerced to a string.
-- @within Bibliography files
function csl_items_ids (items)
    local ids = {}
    for i = 1, #items do
        local id = items[i].id
        local t = type(id)
        if     t == 'string' then ids[id] = true
        elseif t == 'table'  then ids[stringify(id)] = true
        elseif t ~= 'nil'    then error 'cannot parse ID of item.'
        end
    end
    return ids
end


--- Read a bibliography file.
--
-- The filename suffix determines what format the contents of the file are
-- parsed as. There must be a decoder for that suffix in `BIBLIO_TYPES`.
--
-- @string fname The filename.
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
-- Prints errors to STDERR if items cannot be found.
--
-- [Citeproc](https://github.com/jgm/citeproc) appears to recognise
-- formatting in *every* CSL field, so `pandoc-zotxt.lua` does the same.
--
-- The caveats of `file_write` apply.
--
-- @string fname The name of the bibliography file.
-- @tab ids The IDs of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
-- @treturn[1] bool `true` if the file was updated or no update was required.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message.
-- @treturn[2] ?int An error number if the error is a file I/O error.
-- @raise See `zotxt_csl_item`.
-- @within Bibliography files
function biblio_update (fname, ids)
    -- luacheck: ignore ok fmt err errno
    if #ids == 0 then return true end
    local fmt, err = biblio_write(fname)
    if not fmt then return nil, err end
    -- @todo Remove this warning once the script has been dogfooded,
    --       and was out in the open for a while.
    if fmt == 'yaml' or fmt == 'yml' then
        warnf 'YAML bibliography file support is experimental!'
    end
    local items, err, errno = biblio_read(fname)
    if not items then
        if errno ~= 2 then return nil, err, errno end
        items = {}
    end
    local item_ids = csl_items_ids(items)
    local nitems = #items
    local n = nitems
    for i = 1, #ids do
        local id = ids[i]
        if not item_ids[id] then
            local ok, ret, err = pcall(zotxt_csl_item, id)
            if not ok then
                return nil, tostring(ret)
            elseif ret then
                if fmt == 'yaml' or fmt == 'yml' then
                    ret = rmap(html_to_md, ret)
                end
                n = n + 1
                items[n] = lower_keys(ret)
            else
                errf(err)
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

do
    -- @fixme This has not been tested for Pandoc <=v2.14.
    if pandoc.types and PANDOC_VERSION <= {2, 14} then
        local super_types = {}
        for k, v in sorted_pairs(pandoc) do
            if type(v) == 'table' and not super_types[v] then
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
            if type(elem) ~= 'table' then return end
            local mt = getmetatable(elem)
            if not mt or not mt.__type then return end
            return unpack(super_types[mt.__type])
        end
    else
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
    end
end

do
    local clone
    -- @fixme This has not been tested for Pandoc <=v2.14.
    if pandoc.types and PANDOC_VERSION <= {2, 14} then
        function clone (elem)
            assert(type(elem), 'table')
            local ret = setmetatable({}, getmetatable(elem))
            for k, v in next, elem, nil do rawset(ret, k, v) end
            return ret
        end
    else
        function clone (elem)
            assert(type(elem), 'userdata')
            if elem.clone then return elem:clone() end
            return Pandoc(elem.blocks:clone(), elem.meta:clone())
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
    -- @fixme Undertested.
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
-- Reads the `references` metafata field and every bibliography file
-- referenced by the `bibliography` metadata field.
--
-- Prints errors to STDERR if it cannot parse a bibliography file.
--
-- @tab meta A metadata block.
-- @treturn pandoc.List A list of CSL items.
-- @within Document parsing
function meta_sources (meta)
    local ret = List()
    if not meta then return ret end
    if meta.references then ret:extend(meta.references) end
    if meta.bibliography then
        local fnames
        local bibliography = meta.bibliography
        if bibliography.tag == 'MetaInlines' then
            fnames = {stringify(bibliography)}
        elseif bibliography.tag == 'MetaList' then
            fnames = bibliography:map(stringify)
        else
            errf 'cannot parse metadata field "bibliography".'
            return ret
        end
        for i = 1, #fnames do
            local fname, err = file_locate(fnames[i])
            if fname then
                -- luacheck: ignore err
                local items, err = biblio_read(fname)
                if items then ret:extend(items)
                         else errf(err)
                end
            else
                errf(err)
            end
        end
    end
    return ret
end


do
    -- Save IDs that are not in a given set into another.
    --
    -- @tparen pandoc.Cite A citation.
    -- @tab old A set of IDs that should be ignroed.
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
    -- Prints errors to STDERR if it cannot parse a bibliography file.
    --
    -- @tab doc A document.
    -- @bool[opt=false] undef Whether to collect only the citation keys of
    --  sources that are defined neither in the `references` metadata field
    --  nor in a bibliography file.
    -- @treturn {string,...} A list of citation keys.
    -- @treturn int The number of citation keys found.
    -- @raise An error if an item ID is of an illegal data type.
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
-- directory of the first input file passed to **pandoc**, *not* as relative
-- to the current working directory (unless no input files are given).
--
-- @tab meta A metadata block, with the field
--  `zotero-bibliography` set to the filename of the bibliography file.
-- @tab ckeys The citaton keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
--  Citation keys are just item IDs.
-- @treturn[1] tab An updated metadata block, with the field
--  `bibliography` added if needed.
-- @treturn[2] nil `nil` if no sources were found,
--  `zotero-bibliography` is not set, or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `zotxt_csl_item`.
-- @within Main
function add_biblio (meta, ckeys)
    -- luacheck: ignore ok
    if #ckeys == 0 then return end
    if meta['zotero-bibliography'] == nil then return end
    local ok, fname = pcall(stringify, meta['zotero-bibliography'])
    if not ok or not fname then
        return nil, 'zotero-bibliography: not a filename.'
    elseif fname == '' then
        return nil, 'zotero-bibliography: filename is the empty string ("").'
    end
    if not path_is_abs(fname) then fname = path_join(wd(), fname) end
    local ok, err = biblio_update(fname, ckeys)
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
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tab meta A metadata block.
-- @tab ckeys The citation keys of the items that should be added,
--  e.g., `{'name:2019word', 'name2019WordWordWord'}`.
--  Citation keys are just item IDs.
-- @treturn[1] table An updated metadata block,
--  with the field `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `zotxt_csl_item`.
-- @within Main
function add_refs (meta, ckeys)
    if #ckeys == 0 then return end
    if not meta.references then meta.references = MetaList({}) end
    local n = #meta.references
    for i = 1, #ckeys do
        local ok, ret, err = pcall(zotxt_source, ckeys[i])
        if not ok  then return nil, tostring(ret)
        elseif ret then n = n + 1
                        meta.references[n] = ret
                   else errf(err)
        end
    end
    return meta
end


--- Collect sources and adds bibliographic data to a document.
--
-- Prints messages to STDERR if errors occur.
--
-- See the manual for details.
--
-- @tparam table doc A document.
-- @treturn[1] table `doc`, but with bibliographic data added.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @raise See `zotxt_csl_item`.
-- @within Main
function main (doc)
    local ckeys = doc_ckeys(doc, true)
    if next(ckeys) == nil then return end
    for i = 1, 2 do
        local add_srcs
        if     i == 1 then add_srcs = add_biblio
        elseif i == 2 then add_srcs = add_refs
        end
        local meta, err = add_srcs(doc.meta, ckeys)
        if meta then
            doc.meta = meta
            return doc
        elseif err then
            errf(err)
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
