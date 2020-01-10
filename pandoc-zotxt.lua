--- pandoc-zotxt.lua - Looks up citations in Zotero and adds references.
--
-- # SYNOPSIS
--
--      pandoc --lua-filter pandoc-zotxt.lua -F pandoc-citeproc
--
--
-- # DESCRIPTION
--
-- pandoc-zotxt.lua looks up sources of citations in Zotero and adds
-- them either to a document's `references` metadata field or to its
-- bibliography, where pandoc-citeproc can pick them up.
--
-- You cite your sources using so-called "easy citekeys" (provided by zotxt)
-- or "Better BibTeX Citekey Keys" (provided by Better BibTeX for Zotero) and
-- then tell pandoc to run pandoc-zotxt.lua before pandoc-citeproc.
-- That's all all there is to it. (See the documentation of zotxt and
-- Better BibTeX for Zotero respectively for details.)
--
-- You can also use pandoc-zotxt.lua to manage a bibliography file. This is
-- speeds up subsequent runs of pandoc-zotxt.lua for the same document,
-- because pandoc-zotxt.lua will only fetch those sources from Zotero that
-- aren't yet in that file. Simply set the `zotero-bibliography` metadata field
-- to a filename. pandoc-zotxt.lua will then add sources to that file, rather
-- than to the `references` metadata field. It will also add that file to the
-- document's `bibliography` metadata field, so that pandoc-citeproc can pick
-- them up. The biblography is stored as a JSON file, so the filename must end
-- in ".json".
--
-- pandoc-zotxt.lua takes relative filenames to be relative to the directory
-- of the first input file you pass to pandoc or, if you don't pass any input
-- files, as relative to the current working directory.
--
-- Note, pandoc-zotxt.lua only ever adds sources to bibliography files.
-- It never updates or deletes them. To update your bibliography file,
-- delete it. pandoc-zotxt.lua will then regenerate it from scratch.
--
--
-- # KNOWN ISSUES
--
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
-- that  don't set the "User Agent" HTTP header. And pandoc doesn't. As a
-- consequence, pandoc-zotxt.lua cannot retrieve data from these versions of
-- Zotero unless you tell pandoc to set the "User Agent" HTTP header.
--
-- If you cannot (or rather would not) upgrade to a more recent version of
-- Zotero, you can make pandoc set that header, thereby enabling
-- pandoc-zotxt.lua to connect to your version of Zotero, by passing
-- "--request-header User-Agent:Pandoc/2".
--
-- Note, from Zotero v5.0.71 onwards, Zotero doesn't allow browsers to access
-- its interface. It defines "browser" as any user agent that sets the "User
-- Agent" HTTP header to a string that starts with "Mozilla/". So, for
-- instance, "--request-header User-Agent:Mozilla/5" will not enable
-- pandoc-zotxt.lua to connect. If you must set the "User Agent" HTTP header to
-- a string that starts with "Mozilla/", you also have set the HTTP header
-- "Zotero-Allowed-Request". You can do so by "--request-header
-- Zotero-Allowed-Request:X".
--
--
-- # CAVEATS
--
-- pandoc-zotxt.lua is partly Unicode-agnostic.
--
--
-- # SEE ALSO
--
-- pandoc(1), pandoc-citeproc(1)
--
--
-- # AUTHOR
--
-- Copyright 2019 Odin Kroeger
--
--
-- # LICENSE
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--
--
-- @script pandoc-zotxt.lua
-- @release 0.3.18b
-- @author Odin Kroeger
-- @copyright 2018, 2019 Odin Kroeger
-- @license MIT


-- # INITIALISATION

local M = {}

local assert = assert
local ipairs = ipairs
local getmetatable = getmetatable
local pairs = pairs
local pcall = pcall
local require = require
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type

local io = io
local math = math
local package = package
local string = string
local table = table

-- luacheck: globals pandoc PANDOC_STATE PANDOC_SCRIPT_FILE
local pandoc = pandoc
local PANDOC_STATE = PANDOC_STATE
local PANDOC_SCRIPT_FILE = PANDOC_SCRIPT_FILE

local print = print

local _ENV = M

if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end


-- # LIBRARIES

-- luacheck: globals PATH_SEP
--- The path seperator of the operating system.
PATH_SEP = package.config:sub(1, 1)

do
    -- `string.match` expression that splits a path.
    local split_expr = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
    -- `string.gsub` expressions and substitutions that sanitise paths.
    local san_exprs = {
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP}, -- '/./' -> '/'
        {PATH_SEP .. '+', PATH_SEP},              -- '//'  -> '/'
        {'^%.' .. PATH_SEP, ''}                   -- '^./' -> ''
    }

    --- Splits a file's path into a directory and a filename part.
    --
    -- Makes an educated guess on the basis of the given path.
    -- It doesn't look at the filesystem.
    -- (The guess is educated enough though.)
    --
    -- @tparam string path The path to the file.
    -- @treturn string The file's path.
    -- @treturn string The file's name.
    -- @raise An error if `path` is the empty string.
    -- luacheck: globals split_path
    function split_path (path)
        assert(path ~= '', 'path is the empty string')
        for _, v in ipairs(san_exprs) do path = path:gsub(table.unpack(v)) end
        local dir, fname = path:match(split_expr)
        if #dir > 1 then dir = dir:gsub(PATH_SEP .. '$', '') end
        if dir   == '' then dir   = '.' end
        if fname == '' then fname = '.' end
        return dir, fname
    end
end


-- luacheck: globals SCRIPT_DIR
--- The directory this script resides in.
SCRIPT_DIR = split_path(PANDOC_SCRIPT_FILE)

-- luacheck: globals SCRIPT_NAME
--- The name of this script.
SCRIPT_NAME = 'pandoc-zotxt.lua'

-- luacheck: globals SCRIPT_VERSION
--- The version of this script.
SCRIPT_VERSION = '0.3.18b'

do
    local luarocks = {'share', 'lua', '5.3', '?.lua'}
    package.path = table.concat({
        package.path,
        table.concat({SCRIPT_DIR, table.unpack(luarocks)}, PATH_SEP),
        table.concat({SCRIPT_DIR, SCRIPT_NAME .. '-' .. SCRIPT_VERSION,
                      table.unpack(luarocks)}, PATH_SEP)
    }, ';')
end

-- A JSON parser.
-- (Pandoc doesn't expose it's own, so we need this.)
local json = require 'lunajson'


-- # CONSTANTS

-- luacheck: globals DEFAULT_CONNECTOR
--- Name of the database connector to use by default.
DEFAULT_CONNECTOR = 'Zotxt'

-- luacheck: globals ZOTXT_BASE_URL
--- `string.format` format to generate zotxt query URLs.
--
-- `Zotxt.get_source` replaces:
-- the first '%s' with the citation key type (e.g., 'easykey'),
-- the second '%s' with the citation key (e.g., 'doe:2000word').
--
-- @see Zotxt
ZOTXT_BASE_URL = 'http://localhost:23119/zotxt/items?%s=%s'

-- luacheck: globals ZOTXT_KEYTYPES
--- Types of zotxt citation keys.
--
-- @see Zotxt
ZOTXT_KEYTYPES = {
	'easykey',         -- zotxt easy citekey
	'betterbibtexkey', -- Better BibTeX citation key
	'key'              -- Zotero item ID
}

-- luacheck: globals EOL
--- The character sequence of the operating system to end a line.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- # LOW-LEVEL FUNCTIONS

-- ## Warnings

do
    local line_pattern = '([^' .. EOL .. ']*)' .. EOL .. '?'

    --- Prints warnings to STDERR.
    --
    -- Prefixes every line with the global `SCRIPT_NAME` and ": ".
    -- Also appends an end of line sequence if needed.
    --
    -- @tparam string ... Strings to be written to STDERR.
    -- luacheck: globals warn
    function warn (...)
        local stderr = io.stderr
        local str = table.concat({...})
        for line in str:gmatch(line_pattern) do
            stderr:write(SCRIPT_NAME, ': ', line, EOL)
        end
    end
end


-- ## Lists

--- Returns the position of an element in a list.
--
-- @param elem The element.
-- @tparam table list The list.
-- @treturn[1] integer The index of the element.
-- @treturn[2] nil `nil` if the list doesn't contain the element.
-- luacheck: globals get_position
function get_position (elem, list)
    for i, v in ipairs(list) do
        if v == elem then return i end
    end
end


--- Applies a function to every element of a list.
--
-- @tparam func func The function.
-- @tparam table list The list.
-- @treturn table The return values of `f`.
-- luacheck: globals map
function map (func, list)
    local ret = {}
    for i, v in ipairs(list) do ret[i] = func(v) end
    return ret
end


-- ## Prototypes

--- Checks whether an object delegates to a particular prototype.
--
-- Assumes:
-- (1) `tbl` uses metatables to implement prototype inheritance.
-- (2) `__metatable` isn't set for `tbl` or any of its prototypes.
-- (3) `getmetatable` is available.
--
-- @tparam table tbl The table.
-- @tparam table proto The prototype.
-- @treturn bool Whether the table is delegates to the prototype.
-- @raise An error if the number of nested calls exceeds 512.
-- luacheck: globals delegates_to
function delegates_to(tbl, proto, depth)
    depth = depth or 1
    assert(depth < 512, 'too many recursions')
    local mt = getmetatable(tbl)
    if not mt then return false end
    if mt.__index == proto then return true end
    return delegates_to(mt.__index, proto, depth + 1)
end


-- ## Paths

--- Checks if a path is absolute.
--
-- @tparam string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
-- luacheck: globals is_path_absolute
function is_path_absolute (path)
    if PATH_SEP == '\\' and path:match('^.:\\') then return true end
    return path:match('^' .. PATH_SEP) ~= nil
end


--- Returns the directory of the first input file or '.'.
--
-- @treturn[1] string The directory of the first input file.
-- @treturn[2] string '.' if no input files were given.
-- luacheck: globals get_input_directory
function get_input_directory ()
    local file = PANDOC_STATE.input_files[1]
    if not file then return '.' end
    return split_path(file)
end


-- ## Converters

do
    local assert   = assert     -- luacheck: ignore
    local pairs    = pairs      -- luacheck: ignore
    local tostring = tostring   -- luacheck: ignore
    local type     = type       -- luacheck: ignore
    local floor    = math.floor -- luacheck: ignore

    --- Converts all numbers in a multi-dimensional table to strings.
    --
    -- Also converts floating point numbers to integers. This is needed
    -- because all numbers are floating point numbers in JSON, but older
    -- versions of Pandoc expect integers.
    --
    -- @param data Data.
    -- @return The given data, with all numbers converted into strings.
    -- @raise An error if the number of nested calls exceeds 512.
    -- luacheck: globals convert_numbers_to_strings
    function convert_numbers_to_strings (data, depth)
        if not depth then depth = 1 end
        assert(depth < 512, 'too many recursions')
        local data_type = type(data)
        if data_type == 'table' then
            local s = {}
            for k, v in pairs(data) do
                s[k] = convert_numbers_to_strings(v, depth + 1)
            end
            return s
        elseif data_type == 'number' then
            return tostring(floor(data))
        else
            return data
        end
    end
end

do
    local assert = assert -- luacheck: ignore
    local pairs  = pairs  -- luacheck: ignore
    local type   = type   -- luacheck: ignore
    local str    = {    MetaBlocks = true,
                        MetaInlines = true,
                        MetaString = true   }
    local tab    = {    MetaList= true,
                        MetaMap = true      }

    --- Converts a document's metadata block to a table.
    --
    -- Converts Pandoc's metadata types to Lua data types in the process.
    --
    -- @tparam pandoc.Meta meta The document's metadata.
    -- @treturn tab The metadata as table.
    -- @raise An error if the number of nested calls exceeds 512.
    -- luacheck: globals convert_meta_to_table
    function convert_meta_to_table (meta, depth)
        if not depth then depth = 1 end
        assert(depth < 512, 'too many recursions')
        local ret = {}
        for k, v in pairs(meta) do
            if type(v) == 'table' then
                if v.t == nil or v.t == 'MetaBool' then
                    ret[k] = v
                elseif str[v.t] then
                    ret[k] = pandoc.utils.stringify(v)
                elseif tab[v.t] then
                    ret[k] = convert_meta_to_table(v, depth + 1)
                else
                    error('unknown type of metadata: ' .. v.t)
                end
            else
                ret[k] = v
            end
        end
        return ret
    end
end


-- ## JSON files

--- Reads a JSON file.
--
-- @tparam string fname Name of the file.
-- @return[1] The parsed data
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number. Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
-- @raise An error if `fname` is not a `string` or the empty string.
-- luacheck: globals read_json_file
function read_json_file (fname)
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    local f, str, data, ok, err, errno
    f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    str, err, errno = f:read('a')
    if not str then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    ok, data = pcall(json.decode, str)
    if not ok then return nil, 'JSON parse error', -1 end
    return convert_numbers_to_strings(data)
end


--- Writes data to a file in JSON.
--
-- @param data Data.
-- @tparam string fname Name of the file.
-- @treturn[1] bool `true` if the data was written to the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number. Positive numbers are OS error numbers,
--  negative numbers indicate a JSON encoding error.
-- @raise An error if `fname` is not a `string` or the empty string.
-- luacheck: globals write_json_file
function write_json_file (data, fname)
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    local f, str, ok, err, errno
    ok, str = pcall(json.encode, data)
    if not ok then return nil, 'JSON encoding error', -1 end
    f, err, errno = io.open(fname, 'w')
    if not f then return nil, err, errno end
    ok, err, errno = f:write(str, '\n')
    if not ok then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return true
end


-- ## Database connections

--- Look up a database connector by its name.
--
-- @tparam string name The name of a database connector.
-- @treturn[1] DbConnector A connector.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @raise An error if `name` is not a `string`.
-- luacheck: globals get_db_connector
function get_db_connector (name)
    assert(type(name) == 'string', 'given DB connector name is not a string.')
    if name == '' then return nil, 'given DB connector name is "".' end
    if not _ENV[name] then return nil, 'unkown DB connector: ' .. name end
    local c = _ENV[name]
    -- luacheck: globals DbConnector
    if type(c) == 'table' and delegates_to(c, DbConnector) then return c end
    return nil, name .. ': not a DB connector.'
end


-- # HIGH-LEVEL FUNCTIONS


-- ## Handling bibliographic data

--- Collects the citation keys occurring in a document.
--
-- @tparam pandoc.Doc doc A document.
-- @treturn {str,...} A list of citation keys.
-- luacheck: globals get_citekeys
function get_citekeys (doc)
    local citekeys = {}
    local seen = {}
    local function collect_citekeys (cite)
        local c = cite.citations
        for i = 1, #c do
            local id = c[i].id
            if not seen[id] then
                seen[id] = true
                citekeys[#citekeys + 1] = id
            end
        end
    end
    for _, v in ipairs(doc.blocks) do
        pandoc.walk_block(v, {Cite = collect_citekeys})
    end
    return citekeys
end


--- Adds cited sources to a bibliography file.
--
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tparam DbConnector db A connection to a reference manager.
-- @tparam {string,...} citekeys The citation keys of the sources to add,
--  e.g., 'name:2019word', 'name2019WordWordWord'.
-- @tparam string fname The filename of the bibliography.
-- @treturn[1] bool `true` if the bibliography file was updated
--  or no update was needed.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message.
-- @raise An uncatchable error if it cannot retrieve any data and
--  a catchable error if `fname` is not a string, `citekeys` is not a table,
--  `fname` is the empty string.
-- luacheck: globals update_bibliography
function update_bibliography (db, citekeys, fname)
    assert(type(citekeys) == 'table', 'given list of keys is not a table')
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    assert(fname:match '.json$', 'given filename does not end with ".json".')
    if #citekeys == 0 then return true end
    local refs, err, errno = read_json_file(fname)
    if not refs then
        if err and errno ~= 2 then return nil, err, errno end
        refs = {}
    end
    local ids = map(function (ref) return ref.id end, refs)
    for _, citekey in ipairs(citekeys) do
        if not get_position(citekey, ids) then
            local ref, err = db:get_source(citekey) -- luacheck: ignore
            if ref then
                table.insert(refs, ref)
            else
                warn(err)
            end
        end
    end
    if (#refs > #ids) then return write_json_file(refs, fname) end
    return true
end


--- Adds sources to metadata block of a document.
--
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tparam DbConnector db A connection to a reference manager.
-- @tparam {str,...} citekeys The citation keys of the sources to add.
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn[1] pandoc.Meta An updated metadata block, with the field
--  `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found.
-- @raise An uncatchable error if it cannot retrieve any data.
-- luacheck: globals add_references
--
-- @todo Add tests.
function add_references (db, citekeys, meta)
    if #citekeys == 0 then return end
    print(meta)
    if not meta.references then meta.references = {} end
    for _, citekey in ipairs(citekeys) do
        local ref, err = db:get_source(citekey)
        if ref then
            table.insert(meta.references, ref)
        else
            warn(err)
        end
    end
    return meta
end


--- Adds sources to bibliography and the bibliography to document's metadata.
--
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tparam DbConnector db A connection to a reference manager.
-- @tparam {str,...} citekeys The citation keys of the sources to add.
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn[1] pandoc.Meta An updated metadata block, with the field
--  `bibliography` added if needed.
-- @treturn[2] nil `nil` if no sources were found,
--  `zotero-bibliography` is not set, or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise May raise an uncatchable error if `zotero-bibliography` isn't a string.
-- luacheck: globals add_bibliography
-- @todo Add tests.
-- @todo Test whether a wrong type for `zotero-bibliography` raises an uncatchable error.
function add_bibliography (db, citekeys, meta)
    if not #citekeys or not meta['zotero-bibliography'] then return end
    local stringify = pandoc.utils.stringify
    local fname = stringify(meta['zotero-bibliography'])
    if fname == '' then
        return nil, 'filename of bibliography file is "".'
    elseif not fname:match '.json$' then
        return nil, fname .. ': does not end in ".json".'
    end
    if not is_path_absolute(fname) then
        fname = get_input_directory() .. PATH_SEP .. fname
    end
    local ok, err = update_bibliography(db, citekeys, fname)
    if ok then
        if not meta.bibliography then
            meta.bibliography = fname
        elseif meta.bibliography.tag == 'MetaInlines' then
            meta.bibliography = {stringify(meta.bibliography), fname}
        elseif meta.bibliography.tag == 'MetaList' then
            table.insert(meta.bibliography, fname)
        end
        return meta
    else
        return nil, err
    end
end


-- ## Main

--- Collects sources and adds bibliographic data to document.
--
-- Prints messages to STDERR if errors occur.
--
-- See the manual page for detais.
--
-- @tparam pandoc.Pandoc doc A document.
-- @treturn[1] pandoc.Pandoc `doc`, but with bibliographic data added.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @raise An uncatchable error if it cannot retrieve any data.
-- luacheck: globals Pandoc
--
-- @todo Add tests.
function Pandoc (doc)
    local db_connector = DEFAULT_CONNECTOR
    local meta = convert_meta_to_table(doc.meta)
    local reference_mgr = meta['reference-manager']
    if reference_mgr then
        local err
        db_connector, err = get_db_connector(reference_mgr)
        if not db_connector then
            warn(err)
            return nil
        end
    end
    local citekeys = get_citekeys(doc)
    if #citekeys == 0 then return nil end
    local db = db_connector:new(meta)
    for i = 1, 2 do
        local add
        if     i == 1 then add = add_bibliography
        elseif i == 2 then add = add_references   end
        local ret, err = add(db, citekeys, meta)
        if err then warn(err) end
        if ret then
            doc.meta = ret
            return doc
        end
    end
end


-- # PROTOTYPES

-- ## Database Connections

-- luacheck: globals DbConnector
--- Base prototype for database connections.
--
-- `pandoc-zotxt.lua` could, in principle, retrieve bibliographic data from
-- different reference managers. (It just so happens that it currently only
-- supports Zotero via zotxt.)
--
-- You can add support for other reference manangers (or other ways of
-- retrieving data from Zotero) by adding prototypes that implement the
--
-- # DATABASE CONNECTOR PROTOCOL
--
-- A database connector implements:
--
-- ## Method `new` (required)
--
-- Arguments:
--
--  Settings (as `table` of key-value pairs)
--  Document metadata (as `pandoc.Meta`)
--
-- Returns:
--
-- A database connection. The connection must delegate to `DbConncetor`.
--
-- On error:
--
-- Throw an error.
--
-- ## Method `get_source` (required)
--
-- Arguments:
--
--  Citation key (as `string`)
--
-- Returns:
--
-- A bibliographic item in CSL format (as `table`).
--
-- On error:
--
-- Return `nil` and an error message.
--
-- Behaviour:
--
-- If `get_source` retrieves data via HTTP GET requests it should do so
-- by calling `self:read_url`. `DbConnector` implements a `read_url` method,
-- so this will call `DbConnector:read_url`. This allows to test a database
-- connector using `FakeConnector`.
--
-- ## Method `add_settings` (optional)
--
-- Arguments:
--
-- A list of setting definitions (as `Settings`)
--
-- Behaviour:
--
-- Should add any settings for the database connector. `Pandoc` will then
-- look for those settings in the document's metadata and pass them to
-- `new`.
--
-- @type DbConnector
-- @see Zotxt
-- @see FakeConnector
DbConnector = {}

do
    local select = select    -- luacheck: ignore
    local fetch  = pandoc.mediabag.fetch

    --- Reads data from a URL.
    --
    -- @tparam string url The URL.
    -- @treturn string The data.
    -- @raise An uncatchable error if it cannot retrieve any data.
    function DbConnector:read_url (url)     -- luacheck: ignore
        return select(2, fetch(url, '.'))
    end
end


-- luacheck: globals Zotxt
--- Connect to local Zotero database using zotxt.
--
-- @type Zotxt
-- @see https://github.com/egh/zotxt
Zotxt = setmetatable({}, {__index = DbConnector})

--- Creates an connector instance to retrieve data from zotxt.
--
-- @treturn Zotxt The instance.
function Zotxt:new ()
    return setmetatable({}, {__index = self or Zotxt})
end

do
    local pcall    = pcall     -- luacheck: ignore
    local select   = select    -- luacheck: ignore
    local decode   = json.decode
    local insert   = table.insert
    local remove   = table.remove
    local format   = string.format
    local base_url = ZOTXT_BASE_URL
    local keytypes = ZOTXT_KEYTYPES

    ---  Retrieves bibliographic data for a source from zotxt.
    --
    -- Tries different types of citation keys, starting with the last one
    -- that a lookup was successful for.
    --
    -- @tparam string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An uncatchable error if it cannot retrieve any data and
    --  a catchable error if `citekey` is not a `string`.
    function Zotxt:get_source (citekey)
        assert(type(citekey) == 'string', 'given citekey is not a string')
        if citekey == '' then return nil, 'citation key is "".' end
        local reply
        for i = 1, #keytypes do
            local query_url = format(base_url, keytypes[i], citekey)
            reply = self:read_url(query_url)
            local ok, data = pcall(decode, reply)
            if ok then
                insert(keytypes, 1, remove(keytypes, i))
                local source = convert_numbers_to_strings(data[1])
                source.id = citekey
                return source
            end
        end
        return nil, reply
    end
end


-- luacheck: globals FakeConnector
--- Fake connections for testing.
--
-- Takes any database connector that connects to a reference manager via HTTP
-- GET requests and fakes connection to that reference manager by re-routing
-- those requests to the filesystem. This only works for database connectors
-- that use `self:read_url` to make HTTP GET requests.
--
-- @type FakeConnector
FakeConnector = setmetatable({}, {__index = DbConnector})


--- Creates an instance that establishes a fake connection.
--
-- Takes the same arguments as the database connectors it 'fakes' plus:
--
-- @tparam tab args
--
--  - `fake-db-connector`: (`string`)
--    The name of the database connector to 'fake'.
--  - `fake-data-dir`: (`string`)
--    The directory to look up files in.
--
-- @treturn[1] FakeConnector The 'connection'.
-- @treturn[2] nil `nil` if an error occurres
-- @treturn[2] string An error message.
--
-- @todo test error messages.
function FakeConnector:new (args)
    for _, v in ipairs({'fake-db-connector', 'fake-data-dir'}) do
        if args[v] == nil then
            return nil, string.format('missing argument: "%s".', v)
        elseif type(args[v]) ~= 'string' then
            return nil, string.format('value of "%s": not a string.', v)
        end
    end
    local db_connector = get_db_connector(args['fake-db-connector'])
    if not delegates_to(db_connector, DbConnector) then
        return nil, 'value of "fake-db-connector" is not a DB connector.'
    end
    local obj = setmetatable({data_dir = args['fake-data-dir']},
        {__index = self or FakeConnector})
    obj.db_connection = db_connector:new(args)
    function obj.db_connection:read_url(url)    -- luacheck: ignore
        return obj:read_url(url)
    end
    return obj
end


--- Returns canned responses for URL requests.
--
-- Takes the given URL, hashes it using SHA-1, truncates the hash to eight
-- characters and then returns the content of the file of that name
-- (in the directory passed to `FakeConnector:new` via `fake-data-dir`.)
--
-- Prints the requested URL and the file it serves to STDERR.
--
-- @tparam string url The URL.
-- @treturn[1] string The data.
-- @treturn[2] string An error message (*not* `nil`) if an error occurred.
function FakeConnector:read_url (url)
    local hash = pandoc.utils.sha1(url):sub(1, 8)
    warn(url, ' -> ', hash)
    local fname, f, data, ok, err
    fname = self.data_dir .. PATH_SEP .. hash
    f, err = io.open(fname, 'r')
    if not f then return err end
    data, err = f:read('a')
    if not data then return err end
    ok, err = f:close()
    if not ok then return err end
    return data
end


-- Returns canned bibliographic data.
--
-- @tparam string citekey The citation key of the source,
--  e.g., 'name:2019word', 'name2019TwoWords'.
-- @treturn[1] table A CSL item.
-- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
-- @treturn[2] string An error message.
function FakeConnector:get_source (...)
    return self.db_connection:get_source(...)
end


-- # BOILERPLATE
--
-- Returning the whole script, rather than only a list of mappings of
-- Pandoc data types to functions, allows for unit testing.

-- First (and only) pass.
M[1] = {Pandoc = Pandoc}

return M
