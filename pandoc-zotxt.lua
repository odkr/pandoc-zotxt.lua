---
-- SYNOPSIS
-- --------
--
-- **pandoc** **-L** *pandoc-zotxt.lua* **-C**
--
--
-- DESCRIPTION
-- -----------
--
-- **pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
-- them either to a document's "references" metadata field or to a
-- bibliography file, where Pandoc can pick them up.
--
-- Cite your sources using "easy citekeys" (provided by *zotxt*) or
-- "Better BibTeX Citation Keys" (provided by Better BibTeX for Zotero).
-- Then tell **pandoc** to filter your document through **pandoc-zotxt.lua**
-- before processing citations. That's all there is to it.
-- Zotero bust be running, of course.
--
-- **pandoc-zotxt.lua** only fetches sources from Zotero that are defined
-- neither in the "references" metadata field nor in any bibliography file.
--
--
-- BIBLIOGRAPHY FILES
-- ------------------
--
-- **pandoc-zotxt.lua** can add sources to a special bibliography file,
-- rather than to the "references" metadata field. This speeds up subsequent
-- processing of the same document, because sources that are already in that
-- file need not be fetched from Zotero again.
--
-- You configure **pandoc-zotxt.lua** to add sources to a bibliography file by
-- setting the "zotero-bibliography" metadata field to a filename. If the
-- filename is relative, it is interpreted as relative to the directory of the
-- first input file passed to **pandoc** or, if no input file was given, as
-- relative to the current working directory. The format of the file is
-- determined by its filename ending:
--
-- **Ending** | **Format** | **Feature**
-- ---------- | ---------- | -----------------------
-- `.json`    | CSL JSON   | More robust.
-- `.yaml`    | CSL YAML   | Easier to edit manually.
--
-- The bibliography file is added to the "bibliography" metadata field
-- automatically. You can safely set "zotero-bibliography" and "bibliography"
-- at the same time.
--
-- The sources in the bibliography file are neither updated nor deleted.
-- If you want to update the file, delete it.
--
--
-- EXAMPLE
-- -------
--
--      pandoc -L pandoc-zotxt.lua -C <<EOF
--      See @doe2020Title for details.
--      EOF
--
-- This will look up "doe2020Title" in Zotero.
--
--
-- KNOWN ISSUES
-- ------------
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that do not set the "User Agent" HTTP header. And **pandoc** does not.
-- As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
-- versions of Zotero unless you tell **pandoc** to set that header.
--
--
-- CAVEATS
-- -------
--
-- **pandoc-zotxt.lua** is Unicode-agnostic.
--
--
-- SEE ALSO
-- --------
--
-- * [zotxt](https://github.com/egh/zotxt)
-- * [Better BibTeX](https://retorque.re/zotero-better-bibtex/)
--
-- pandoc(1)
--
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

--- The path segment seperator of the OS.
-- @within File I/O
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence of the OS.
-- @within File I/O
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- Modules
-- -------

do
    -- Pattern to split a path into a directory and a filename part.
    local split_pattern = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
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

    -- Sanitise a path.
    --
    -- @string path The path.
    -- @treturn string A sanitised path.
    local function sanitise (path)
        for i = 1, #sanitisation_patterns do
            local pattern, repl = unpack(sanitisation_patterns[i])
            path = path:gsub(pattern, repl)
        end
        return path
    end

    --- Split a file's path into a directory and a filename part.
    --
    -- @string path The file's path.
    -- @treturn[1] string The directory the file is in.
    -- @treturn[1] string The file's name.
    -- @treturn[2] nil `nil` if `path` is the empty string ('').
    -- @treturn[2] string An error message.
    -- @raise An error if the path is the empty string.
    -- @within File I/O
    function path_split (path)
        if path == '' then return nil, 'Path is the empty string ("").' end
        local dir, fname = path:match(split_pattern)
        dir = sanitise(dir)
        if     dir == ''   then dir = '.'
        elseif fname == '' then fname = '.' end
        assert(dir ~= '')
        assert(fname ~= '')
        return dir, fname
    end

    do
        -- Join path segments (worker)
        --
        -- Has the same function signature as `path_join`.
        -- Does not sanitise the path it returns.
        local function join (a, b, ...)
            assert(type(a == 'string'), 'Path segment is not a string.')
            assert(a ~= '', 'Path segment is the empty string.')
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
            return sanitise(join(...))
        end
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
function copy (data, _seen)
    -- Borrows from:
    -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
    -- * <http://lua-users.org/wiki/CopyTable>
    if type(data) ~= 'table' then return data end
    if _seen and _seen[data] then return _seen[data] end
    local copy = copy
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
    assert(_rd < 512, 'Too much recursion.')
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
        assert(_rd < 512, 'Too much recursion.')
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
    assert(path ~= '', 'Path is the empty string ("").')
    if PATH_SEP == '\\' and path:match '^.:\\' then return true end
    return path:match('^' .. PATH_SEP) ~= nil
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
    assert(fname ~= '', 'Filename is the empty string ("").')
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
        return nil, fname .. ': Not found in resource path.'
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


--- Write data to a file.
--
-- The data is first written to a temporary file,
-- that file is then renamed to the given name.
-- If the file exists, it is overwritten.
-- Tries to print a warning to STDERR if that happens
--
-- @string fname The name of the file.
-- @string ... The data.
-- @treturn[1] bool `true` if the data was written to the given file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
-- @within File I/O
function file_write (fname, ...)
    assert(fname ~= '', 'Filename is the empty string.')
    local tmp, ok, err, errno
    tmp, err, errno = tmp_file(path_split(fname), nil)
    if not tmp then return nil, err, errno end
    ok, err, errno = tmp.file:write(...)
    if not ok then return nil, err, errno end
    ok, err, errno = tmp.file:flush()
    if not ok then return nil, err, errno end
    ok, err, errno = tmp.file:close()
    if not ok then return nil, err, errno end
    if file_exists(fname) then warnf('Updating %s.', fname) end
    ok, err, errno = os.rename(tmp.fname, fname)
    if not ok then return nil, err, errno end
    tmp.fname = nil
    return true
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
    --  Cannot be the empty string ('').
    -- @string[optchain='tmp-XXXXXXXXXX'] templ A template for the filename.
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
            templ = 'tmp-XXXXXXXXXX'
        else
            assert(type(templ) == 'string')
            assert(templ ~= '', 'Template is the empty string.')
            local nxs = 0
            for _ in templ:gmatch 'X' do nxs = nxs + 1 end
            assert(nxs >= 6, 'Template must contain at least six "X"s.')
        end
        if dir ~= nil then
            assert(type(dir) == 'string')
            assert(dir ~= '', 'Directory is the empty string.')
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
        return nil, 'Could not find an unused filename.'
    end
end


do
    local mt = {}

    -- Closes and removes the file when its handle is garbage-collected.
    --
    -- If errors occur, prints them to STDERR.
    function mt.__gc (self)
        local file = self.file
        if not file then return end
        local fname = self.fname
        if fname then
            local ok, err = os.remove(fname)
            if not ok then errf(err) end
        end
        if io.type(file) == 'file' then
            local ok, err = file:close()
            if not ok then errf(err) end
        end
    end

    --- Create a temporary file.
    --
    -- The temporary file is removed when its file handle/filename pair is
    -- garbage-collected. If the file should *not* be removed, set `fname`
    -- to `nil`. Prints errors that occur during garbage collection to STDERR.
    -- If you call `os.exit` tell it to close the Lua state, so that Lua runs
    -- the garbage collector before exiting the script.
    --
    -- Tries not to overwrite existing files. This is subject to
    -- race conditions; there is no Lua equivalent to `O_CREAT | O_EXCL`.
    --
    -- @param ... Takes the same arguments as `tmp_fname`.
    --
    -- @treturn[1] {file=FILE*,fname=string} A file handle/filename pair.
    -- @treturn[2] nil `nil` if an error occurs.
    -- @treturn[2] string An error message.
    -- @treturn[2] ?int An error number if the error is an I/O error.
    -- @raise See `tmp_fname`.
    -- @within File I/O
    --
    -- @usage
    --      do
    --          local tmp, ok, err
    --          -- Create the file.
    --          tmp, err = tmp_file()
    --          if tmp then
    --              ok, err = tmp.file:write(data)
    --              if ok then ok, err = tmp.file:close() end
    --              if ok then ok, err = os.rename(tmp.fname, fname) end
    --              if ok then
    --                  -- Disable deletion (which would fail).
    --                  tmp.fname = nil
    --              else
    --                  print(err)
    --              end
    --          else
    --              print(err)
    --          end
    --      end
    --      -- If `tmp.fname` has not been set to nil, then the garbage
    --      -- collector deletes the file after (not "at") this point.
    function tmp_file (...)
        local tmp, err, errno
        tmp = setmetatable({}, mt)
        tmp.fname, err, errno = tmp_fname(...)
        if not tmp.fname then return nil, err, errno end
        tmp.file, err, errno = io.open(tmp.fname, 'w+')
        if not tmp.file then return nil, err, errno end
        return tmp
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
function url_read (url)
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

    -- Convert an arbitrary UTF-8 encoded string to a YAML scalar.
    --
    -- Does *not* escape *all* non-printable characters.
    --
    -- @string str The string.
    -- @treturn string A YAML scalar.
    local function scalarify (str)
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

    --- Generate a YAML representation of some data.
    --
    -- Uses `EOL` to end lines.
    -- Only parses UTF-8 encoded strings.
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
        assert(_rd < 1024, 'Too much recursion.')
        if not ind then ind = 4 end
        local t = type(data)
        if t == 'number' then
            return tostring(data)
        elseif t == 'string' then
            return scalarify(data)
        elseif t == 'table' then
            -- luacheck: ignore _rd
            local _rd = _rd + 1
            if not _col then _col = 0 end
            local ret = ''
            local n = #data
            local nkeys = select(2, keys(data))
            local sp = spaces(_col)
            if n == nkeys then
                local col = _col + 2
                for i = 1, n do
                    if i > 1 then ret = ret .. sp end
                    ret = ret .. '- '
                              .. yamlify(data[i], ind, sort_f, col, _rd)
                    if i ~= n then ret = ret .. EOL end
                end
            else
                local i = 0
                for k, v in sorted_pairs(data, sort_f) do
                    i = i + 1
                    if type(k) == 'number' then k = tostring(k) end
                    local kt = type(k)
                    assert(kt == 'string',
                           kt .. ': Cannot be expressed in YAML.')
                    k = scalarify(k)
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
        else
            error(t .. ': Cannot be expressed in YAML.')
        end
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
            return nil, 'Pseudo-HTML code is not a string.'
        end
        local sc_replaced = conv_sc_to_span(html)
        local doc = pandoc.read(sc_replaced, 'html')
        return markdownify(doc)
    end
end


-- zotxt
-- -----

--- The [zotxt](https://github.com/egh/zotxt) endpoint.
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

    -- Retrieve a source from Zotero (low-level).
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
            local mt, data = url_read(query_url)
            if mt and mt ~= '' then
                assert(match(mt, utf8_p),
                       'Data retrieved from zotxt is not encoded in UTF-8.')
                local ok, item = pcall(parse_f, data, mt)
                if ok then
                    if i ~= 1 then
                        key_ts[1], key_ts[i] = key_ts[i], key_ts[1]
                    end
                    return item
                end
            end
        end
        return nil, id .. ': Not found.'
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


    --- Retrieve a source from Zotero as CSL item.
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


    --- Retrieve a source from Zotero as Pandoc metadata.
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
BIBLIO_TYPES = {}

do
    local mt = {}
    function mt.__index (self, key)
        if type(key) == 'string' then return rawget(self, key:lower()) end
    end
    setmetatable(BIBLIO_TYPES, mt)
end


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
        elseif t ~= 'nil'    then error 'Cannot parse ID of item.'
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
    assert(fname ~= '', 'Filename is the empty string')
    local suffix = fname:match '%.(%w+)$'
    if not suffix then return nil, fname .. ': No filename suffix.' end
    local codec = BIBLIO_TYPES[suffix]
    if not codec then return nil, fname .. ': Unsupported format.' end
    local decode = codec.decode
    if not decode then return nil, fname .. ': Cannot parse format.' end
    local str, err, errno = file_read(fname)
    if not str then return nil, err, errno end
    local ok, items = pcall(decode, str)
    if not ok then return nil, fname ..  ': Parse error.' end
    return items
end


--- Write sources to a bibliography file.
--
-- The filename suffix determins what format the data is written as.
-- There must be an encoder for that suffix in `BIBLIO_TYPES`.
-- If the file exists, it is overwritten.
-- Tries to print a warning to STDERR if that happens.
-- Ends every file with `EOL`.
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
    assert(fname ~= '', 'Filename is the empty string')
    local suffix = fname:match '%.(%w+)$'
    if not suffix then return nil, fname .. ': No filename suffix.' end
    local codec = BIBLIO_TYPES[suffix]
    if not codec then return nil, fname .. ': Unsupported format.' end
    local encode = codec.encode
    if not encode then return nil, fname .. ': Cannot write format.' end
    if not items or #items == 0 then return suffix end
    local ok, str = pcall(encode, items)
    if not ok then return nil, fname .. ': Serialisation error.' end
    local ok, err, errno = file_write(fname, str, EOL)
    if not ok then return nil, err, errno end
    return suffix
end



do
    -- Recursively convert Zotero pseudo-HTML to Pandoc Markdown.
    --
    -- [Citeproc](https://github.com/jgm/citeproc) appears to recognise
    -- formatting in *every* CSL field, so `pandoc-zotxt.lua` does the same.
    --
    -- @tab item A CSL item.
    -- @treturn tab The CSL item, with pseudo-HTML replaced with Markdown.
    -- @see html_to_md
    -- @within Converters
    local function zotfmt_to_pdfmt (item)
        return rmap(html_to_md, item)
    end

    --- Add items from Zotero to a bibliography file.
    --
    -- If an item is already in the bibliography file, it won't be added again.
    -- Prints a warning to STDERR if it overwrites an existing file.
    -- Also prints an error to STDERR for every item that cannot be found.
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
        -- and was out in the open for a while.
        if fmt == 'yaml' or fmt == 'yml' then
            warnf 'YAML bibliography file support is EXPERIMENTAL!'
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
                    return nil, ret
                elseif ret then
                    if fmt == 'yaml' or fmt == 'yml' then
                        ret = zotfmt_to_pdfmt(ret)
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
end


-- PANDOC
-- ======

do
    local ts = {}
    for k, v in sorted_pairs(pandoc) do
        if type(v) == 'table' and not ts[v] then
            local t = {k}
            local mt = getmetatable(v)
            n = 1
            while mt and n < 16 do
                if not mt.name or mt.name == 'Type' then break end
                n = n + 1
                t[n] = mt.name
                mt = getmetatable(mt)
            end
            if t[n] == 'AstElement' then ts[v] = t end
        end
    end

    --- The type of a Pandoc AST element.
    --
    -- @tparam pandoc.AstElement elem A Pandoc AST element.
    -- @treturn[1] string The type
    --  (e.g., 'MetaMap', 'Plain').
    -- @treturn[1] string The higher-order type
    --  (i.e., 'Block', 'Inline', or 'MetaValue').
    -- @treturn[1] string 'AstElement'.
    -- @treturn[2] nil `nil` if `elem` is not a Pandoc AST element.
    -- @within Document parsing
    function elem_type (elem)
        if type(elem) ~= 'table' then return end
        local mt = getmetatable(elem)
        if not mt or not mt.__type then return end
        return unpack(ts[mt.__type])
    end
end

do
    local pack = table.pack

    -- Walk a mapping.
    local function w_map (tab, ...)
        for k, v in pairs(tab) do
            tab[k] = walk(v, ...)
        end
    end

    -- The difference between mappings and sequences must be honoured,
    -- because Pandoc may use custom __pairs and __len metamethods.
    local function w_seq (tab, ...)
        for i = 1, #tab do
            tab[i] = walk(tab[i], ...)
        end
    end

    --- Walk a list AST element (e.g., `pandoc.OrderedList`).
    local function w_list (elem, ...)
        local content = elem.content
        for i = 1, #content do
            w_seq(content[i], ...)
        end
    end

    local walker_fs = {
        Meta = w_map,
        MetaBlocks = w_seq,
        MetaList = w_seq,
        MetaInlines = w_seq,
        MetaMap = w_map,
        BulletList = w_list,
        OrderedList = w_list
    }

    -- Walk a document.
    function walker_fs.Doc (doc, ...)
        walk(doc.meta, ...)
        w_seq(doc.blocks, ...)
    end

    --- Walk the AST and apply functions to matching elements.
    --
    -- Differs from `pandoc.walk_block` and `pandoc.walk_inline` by never
    -- modifying the original element, by accepting AST elements of *any* type
    -- (including documents as a whole, the metadata block, and metadata
    -- fields), by walking the AST bottom-up (which implies that the filter is
    -- applied to every element, regardless of whether any of that elements's
    -- ancestors matches it), by applying the filter to the given element
    -- itself, and by allowing the functions in the filter to return data of
    -- arbitrary types (as opposed to either a Pandoc AST element or `nil`).
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
        if _rd == 0 then elem = copy(elem) end
        assert(_rd < 512, 'Too much recursion.')
        local ts = pack(elem_type(elem))
        if ts.n == 0 then return elem end
        local walker_f = walker_fs[ts[1]]
        if     walker_f     then walker_f(elem, filter, _rd)
        elseif elem.content then w_seq(elem.content, filter, _rd)
        end
        for i = 1, ts.n do
            local func = filter[ts[i]]
            if func then
                local new = func(elem)
                if new ~= nil then elem = new end
            end
        end
        return elem
    end
end


--- Collect sources from the document's metadata block.
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
            errf 'Cannot parse metadata field "bibliography".'
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
    -- @string[opt] flags If the flag 'u' is given, collects only
    --  citation keys of sources that are defined neither in the
    --  `references` metadata field nor in any bibliography file.
    -- @treturn {string,...} A list of citation keys.
    -- @treturn int The number of citation keys found.
    -- @raise An error if an item ID is of an illegal data type.
    -- @within Document parsing
    function doc_ckeys (doc, flags)
        local meta = doc.meta
        local blocks = doc.blocks
        local old = {}
        local new = {}
        if flags == 'u' then old = csl_items_ids(meta_sources(meta)) end
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

--- Add sources to a bibliography file and the file to the document's metadata.
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
        return nil, 'zotero-bibliography: Not a filename.'
    elseif fname == '' then
        return nil, 'zotero-bibliography: Filename is the empty string ("").'
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


--- Add sources to the `references` metadata field.
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
        if not ok  then return nil, ret
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
    local ckeys = doc_ckeys(doc, 'u')
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
