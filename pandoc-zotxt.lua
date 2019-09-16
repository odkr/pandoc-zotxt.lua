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

local io = io
local math = math
local package = package

local open = io.open
local concat = table.concat
local insert = table.insert
local remove = table.remove
local sort = table.sort
local unpack = table.unpack
local format = string.format

local PANDOC_STATE = PANDOC_STATE
local PANDOC_SCRIPT_FILE = PANDOC_SCRIPT_FILE
local pandoc = pandoc
local stringify = pandoc.utils.stringify
local sha1 = pandoc.utils.sha1
local walk_block = pandoc.walk_block

local _ENV = M

local text = require 'text'
local lower = text.lower
local upper = text.upper
local sub = text.sub


-- # LIBRARIES

--- The path seperator of the operating system.
PATH_SEP = sub(package.config, 1, 1)

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
    function split_path (path)
        assert(path ~= '', 'path is the empty string')
        for _, v in ipairs(san_exprs) do path = path:gsub(unpack(v)) end
        local dir, fname = path:match(split_expr)
        if #dir > 1 then dir = dir:gsub(PATH_SEP .. '$', '') end
        if dir   == '' then dir   = '.' end
        if fname == '' then fname = '.' end
        return dir, fname
    end
end


--- The directory this script resides in.
BASE_DIR = split_path(PANDOC_SCRIPT_FILE)

--- The name of this script.
NAME = 'pandoc-zotxt.lua'

--- The version of this script.
VERSION = '0.3.18b'

do
    local lib_expr = {'share', 'lua', '5.3', '?.lua'}
    
    package.path = concat({
        package.path,
        concat({BASE_DIR, unpack(lib_expr)}, PATH_SEP),
        concat({BASE_DIR, NAME .. '-' .. VERSION, unpack(lib_expr)}, PATH_SEP)
    }, ';')
end

-- A JSON parser. 
-- (Pandoc doesn't expose it's own, so we need this.)
local json = require 'lunajson'
local encode = json.encode
local decode = json.decode


-- # CONSTANTS

--- Name of the database connector to use by default.
DEFAULT_CONNECTOR = 'Zotxt'

--- `string.format` format to generate zotxt query URLs. 
--
-- `Zotxt.get_source` replaces:
-- the first '%s' with the citation key type (e.g., 'easykey'),
-- the second '%s' with the citation key (e.g., 'doe:2000word').
--
-- @see Zotxt
ZOTXT_BASE_URL = 'http://localhost:23119/zotxt/items?%s=%s'

--- Types of zotxt citation keys.
--
-- @see Zotxt
ZOTXT_KEYTYPES = {
	'easykey',	       -- zotxt easy citekey 
	'betterbibtexkey', -- Better BibTeX citation key
	'key'		       -- Zotero item ID
}


-- # HIGH-LEVEL FUNCTIONS

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
    doc.meta = add_sources(db, citekeys, doc.meta)
    return doc
end


-- ## Handling bibliographic data

--- Collects the citation keys occurring in a document.
--
-- @tparam pandoc.Doc doc A document.
-- @treturn {str,...} A list of citation keys.
function get_citekeys (doc)
    local walk_block = walk_block
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
        walk_block(v, {Cite = collect_citekeys})
    end
    return citekeys
end


--- Adds sources to document's metadata or its bibliography.
--
-- Checks whether the given document uses a bibliography. If so, adds
-- sources that aren't in it yet. Otherwise, adds all cited sources
-- to the given metadata block.
--
-- Prints messages to STDERR if errors occur.
--
-- @tparam DbConnector db A connection to a reference manager.
-- @tparam {string,...} citekeys The citation keys of the sources to add.
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn[1] pandoc.Meta An updated metadata block, with references or
--  a pointer to the bibliography file
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @raise An uncatchable error if it cannot retrieve any data.
--
-- @todo Add tests.
function add_sources (db, citekeys, meta)
    if #citekeys == 0 then return nil end
    do
        local meta, err = add_bibliography(db, citekeys, meta)
        if meta then return meta end
        if err then warn(err) end
    end
    return add_references(db, citekeys, meta)
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
--
-- @todo Add tests.
function add_references (db, citekeys, meta)
    if #citekeys == 0 then return end
    if not meta.references then meta.references = {} end
    for _, citekey in ipairs(citekeys) do
        local ref, err = db:get_source(citekey)
        if ref then
            insert(meta.references, ref)
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
-- @todo Add tests.
-- @todo test uncatchable error thingy!
function add_bibliography (db, citekeys, meta)
    if not #citekeys or not meta['zotero-bibliography'] then return end
    local fname = stringify(meta['zotero-bibliography'])
    -- @fixme test if this is a string.
    if fname == '' then
        return nil, 'filename of bibliography file is "".'
    elseif not fname:match('.json$') then
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
            insert(meta.bibliography, fname)
        end
        return meta
    else
        return nil, err
    end
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
-- @raise An uncatchable error if it cannot retrieve any data.
-- @raise An error if `citekeys` is not a `table`.
-- @raise An error if `fname` is not a `string`.
-- @raise An error if `fname` is the empty string.
--
-- @todo Add tests.
function update_bibliography (db, citekeys, fname)
    assert(type(citekeys) == 'table', 'given list of keys is not a table')
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    if #citekeys == 0 then return end
    local refs, err, errno = read_json_file(fname)
    if not refs then
        if err and errno ~= 2 then return nil, err, errno end
        refs = {}
    end
    local ids = map(function (x) return x.id end, refs)
    for _, citekey in ipairs(citekeys) do
        if not get_position(citekey, ids) then
            local ref, err = db:get_source(citekey)
            if ref then
                insert(refs, ref)
            else
                warn(err)
            end
        end
    end
    if (#refs > #ids) then return write_json_file(refs, fname) end
    return true
end


-- # LOW-LEVEL FUNCTIONS

-- ## Database connections

--- Look up a database connector by its name.
--
-- @tparam string name The name of a database connector.
-- @treturn[1] DbConnector A connector.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @raise An error if `name` is not a `string`.
function get_db_connector (name)
    assert(type(name) == 'string', 'given DB connector name is not a string.')
    if name == '' then return nil, 'given DB connector name is "".' end
    if not _ENV[name] then return nil, 'unkown DB connector: ' .. name end
    local c = _ENV[name]
    if type(c) == 'table' and delegates_to(c, DbConnector) then return c end
    return nil, name .. ': not a DB connector.'
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
-- @raise An error if `fname` is not a `string`.
-- @raise An error if `fname` is the empty string.
function read_json_file (fname)
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    local f, err, errno = open(fname, 'r')
    if not f then return nil, err, errno end
    local json, err, errno = f:read('a')
    if not json then return nil, err, errno end
    local ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    local ok, data = pcall(decode, json) 
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
-- @raise An error if `fname` is not a `string`.
-- @raise An error if `fname` is the empty string.
function write_json_file (data, fname)
    assert(type(fname) == 'string', 'given filename is not a string')
    assert(fname ~= '', 'given filename is the empty string')
    local ok, json = pcall(encode, data)
    if not ok then return nil, 'JSON encoding error', -1 end
    local f, err, errno = open(fname, 'w')
    if not f then return nil, err, errno end
    local ok, err, errno = f:write(json, '\n')
    if not ok then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return true
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
-- @raise An error if `tbl` or `proto` is not a `table`.
-- @raise An error if the number of nested calls exceeds 512.
function delegates_to(tbl, proto, depth)
    depth = depth or 1
    assert(type(tbl) == 'table', 'given object is not a table')
    assert(type(proto) == 'table', 'given prototype is not a table')
    assert(depth < 512, 'too many recursions')
    local mt = getmetatable(tbl)
    if not mt then return false end
    if mt.__index == proto then return true end
    return delegates_to(mt.__index, proto, depth + 1)
end


-- ## Converters

do
    local assert = assert
    local pairs = pairs
    local tostring = tostring
    local type = type
    local floor = math.floor

    --- Converts all numbers in a multi-dimensional table to strings.
    --
    -- Also converts floating point numbers to integers. This is needed 
    -- because all numbers are floating point numbers in JSON, but older
    -- versions of Pandoc expect integers.
    --
    -- @param data Data.
    -- @return The given data, with all numbers converted into strings.
    -- @raise An error if the number of nested calls exceeds 512.
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
    local assert = assert
    local pairs = pairs
    local type = type
    local str = {MetaBlocks = true, MetaInlines = true, MetaString = true}
    local tab = {MetaList = true, MetaMap = true}

    --- Converts a document's metadata block to a table.
    --
    -- Converts Pandoc's metadata types to Lua data types in the process.
    --
    -- @tparam pandoc.Meta meta The document's metadata.
    -- @treturn tab The metadata as table.
    -- @raise If `meta` is not a `table`.
    -- @raise An error if the number of nested calls exceeds 512.
    function convert_meta_to_table (meta, depth)
        if not depth then depth = 1 end
        assert(type(meta) == 'table', 'given metadata is not a table')
        assert(depth < 512, 'too many recursions')
        local ret = {}
        for k, v in pairs(meta) do
            if type(v) == 'table' then
                if v.t == nil or v.t == 'MetaBool' then
                    ret[k] = v
                elseif str[v.t] then
                    ret[k] = stringify(v)
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


-- ## Paths

--- Checks if a path is absolute.
--
-- @tparam string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
function is_path_absolute (path)
    if PATH_SEP == '\\' and path:match('^.:\\') then return true end
    return path:match('^' .. PATH_SEP) ~= nil
end


--- Returns the directory of the first input file or '.'.
--
-- @treturn[1] string The directory of the first input file.
-- @treturn[2] string '.' if no input files were given.
function get_input_directory ()
    local file = PANDOC_STATE.input_files[1]
    if not file then return '.' end
    return split_path(file)
end


-- ## Lists

--- Returns the position of an element in a list.
--
-- @param elem The element.
-- @tparam table list The list.
-- @treturn[1] integer The index of the element.
-- @treturn[2] nil `nil` if the list doesn't contain the element.
-- @raise An error if `list` is not a `table`.
function get_position (elem, list)
    assert(type(list) == 'table', 'given list is not a table.')
    for i, v in ipairs(list) do
        if v == elem then return i end
    end
    return nil
end


--- Applies a function to every element of a list.
--
-- @tparam func func The function.
-- @tparam table list The list.
-- @treturn table The return values of `f`.
function map (func, list)
    local ret = {}
    for i, v in ipairs(list) do ret[i] = func(v) end
    return ret
end


-- ## Warnings

--- Prints warnings to STDERR.
--
-- Prefixes every line with the global `NAME` and ": ".
-- Also, appends a single linefeed if needed.
--
-- @tparam string ... Strings to be written to STDERR.
function warn (...)
    local stderr = io.stderr
    local str = concat({...})
    for line in str:gmatch('([^\n]*)\n?') do
        stderr:write(NAME, ': ', line, '\n')
    end
end


-- # PROTOTYPES

-- ## Database Connections

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
    local select = select
    local fetch = pandoc.mediabag.fetch

    --- Reads data from a URL.
    --
    -- @tparam string url The URL.
    -- @treturn string The data.
    -- @raise An uncatchable error if it cannot retrieve any data.
    function DbConnector:read_url (url)
        return select(2, fetch(url, '.'))
    end
end


--- Connect to local Zotero database using zotxt.
--
-- See <https://github.com/egh/zotxt> for details.
--
-- @type Zotxt
Zotxt = setmetatable({}, {__index = DbConnector})

--- Creates an connector instance to retrieve data from zotxt.
--
-- @treturn Zotxt The instance.
function Zotxt:new ()
    return setmetatable({}, {__index = self or Zotxt})
end

do
    local pcall = pcall
    local concat = concat
    local insert = insert
    local remove = remove
    local select = select
    local format = format
    local decode = decode
    local fetch = pandoc.mediabag.fetch
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
    -- @raise An uncatchable error if it cannot retrieve any data.
    -- @raise An error if `citekey` is not a `string`.
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
            return nil, format('missing argument: "%s".', v)
        elseif type(args[v]) ~= 'string' then
            return nil, format('value of "%s": not a string.')
        end
    end
    local db_connector = get_db_connector(args['fake-db-connector'])
    if not delegates_to(db_connector, DbConnector) then
        return nil, 'value of "fake-db-connector" is not a DB connector.'
    end
    local obj = setmetatable({data_dir = args['fake-data-dir']},
        {__index = self or FakeConnector})
    obj.db_connection = db_connector:new(args)
    function obj.db_connection:read_url(url) return obj:read_url(url) end
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
    local hash = sub(sha1(url), 1, 8)
    warn(url, ' -> ', hash)
    local fname = self.data_dir .. PATH_SEP .. hash
    local f, err = open(fname, 'r')
    if not f then return err end
    local data, err = f:read('a')
    if not data then return err end
    local ok, err = f:close()
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
