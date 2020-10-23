--- pandoc-zotxt.lua - Looks up citations in Zotero and adds references.
--
-- SYNOPSIS
--
--  pandoc --lua-filter pandoc-zotxt.lua --citeproc
--
--  pandoc --lua-filter pandoc-zotxt.lua --filter pandoc-citeproc
--
-- DESCRIPTION
--
-- pandoc-zotxt.lua looks up sources of citations in Zotero and adds them
-- either to a document's references metadata field or to its bibliography,
-- where pandoc can pick them up.
--
-- You cite your sources using so-called "easy citekeys" (provided by
-- zotxt) or "Better BibTeX Citation Keys" (provided by Better BibTeX for
-- Zotero). Then, when running pandoc, you tell it to filter your document
-- through pandoc-zotxt.lua by passing --lua-filter pandoc-zotxt.lua.
-- That's all there is to it. You also have to tell pandoc to process
-- citations, of course. (How you do this depends on your version of
-- Pandoc.)
--
-- BIBLIOGRAPHY FILES
--
-- You can also use pandoc-zotxt.lua to manage a bibliography file. This
-- speeds up subsequent runs of pandoc-zotxt.lua for the same document,
-- because pandoc-zotxt.lua will only fetch sources from Zotero that aren't
-- yet in that file. Simply set the zotero-bibliography metadata field to a
-- filename. pandoc-zotxt.lua will then add sources to that file, rather
-- than to the references metadata field. It will also add that file to the
-- document's bibliography metadata field, so that pandoc picks up those
-- sources. The biblography is stored as a JSON file, so the filename must
-- end with ".json". You can safely set zotero-bibliography and
-- bibliography at the same time.
--
-- pandoc-zotxt.lua interprets relative filenames as relative to the
-- directory of the first input file that you pass to pandoc or, if you
-- don't pass any input file, as relative to the current working directory.
--
-- Note, pandoc-zotxt.lua only ever adds sources to bibliography files. It
-- doesn't update or delete them. If you want to update the sources in your
-- bibliography file, delete it. pandoc-zotxt.lua will then regenerate it
-- from scratch.
--
-- KNOWN ISSUES
--
-- Zotero, from v5.0.71 onwards, doesn't allow browsers to access its
-- interface. It defines "browser" as any user agent that sets the "User
-- Agent" HTTP header to a string that starts with "Mozilla/".
--
-- However, Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from
-- user agents that don't set the "User Agent" HTTP header. And pandoc
-- doesn't. As a consequence, pandoc-zotxt.lua cannot retrieve data from
-- these versions of Zotero, that is, unless you tell pandoc to set that
-- header.
--
-- If you cannot upgrade to a more recent version of Zotero, you can make
-- pandoc set that header by passing, for instance, --request-header
-- User-Agent:Pandoc/2. If you must set the "User Agent" HTTP header to a
-- string that starts with "Mozilla/", you can still get pandoc to connect
-- to Zotero by setting the HTTP header "Zotero-Allowed-Request". You do so
-- by passing --request-header Zotero-Allowed-Request:X.
--
-- CAVEATS
--
-- pandoc-zotxt.lua is for the most part Unicode-agnostic.
--
-- SEE ALSO
--
-- -   zotxt
-- -   Better BibTeX
--
-- pandoc(1), pandoc-citeproc(1)
--
-- @script pandoc-zotxt.lua
-- @release 0.3.19
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020 Odin Kroeger
-- @license MIT


-- # INITIALISATION
-- luacheck: allow defined top

local M = {}

local assert = assert
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local require = require
local select = select
local tostring = tostring
local type = type

local io = io
local math = math
local package = package
local table = table

-- luacheck: push ignore
local pandoc = pandoc
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end

local PANDOC_STATE = PANDOC_STATE
local PANDOC_SCRIPT_FILE = PANDOC_SCRIPT_FILE
local PANDOC_VERSION = PANDOC_VERSION
-- luacheck: pop

-- luacheck: ignore _ENV
local _ENV = M

local text = require 'text'


-- # CONSTANTS

--- The URL to lookup citation data.
--
-- See <https://github.com/egh/zotxt> for details.
--
-- `get_source_json` replaces:
--
-- * the first '%s' with the citation key type (e.g., 'easykey'),
-- * the second '%s' with the citation key (e.g., 'doe:2000word').
--
-- @see get_source_json
ZOTXT_BASE_URL = 'http://localhost:23119/zotxt/items?%s=%s'

--- Types of citation keys.
--
-- See <https://github.com/egh/zotxt> for details.
--
-- @table ZOTXT_KEYTYPES
-- @see get_source_json
ZOTXT_KEYTYPES = {
	'easykey',         -- zotxt easy citekey
	'betterbibtexkey', -- Better BibTeX citation key
	'key'              -- Zotero item ID
}

--- The name of this script.
NAME = 'pandoc-zotxt.lua'

--- The version of this script.
VERSION = '0.3.19'

--- The path seperator of the operating system.
PATH_SEP = text.sub(package.config, 1, 1)

--- The end of line sequence of the operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- # LIBRARIES

do
    -- Expression to split a path into a directory and a filename part.
    local split = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
    -- Expressions that sanitise directory paths.
    local sanitisers = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove './' at the beginning of paths.
        {'^%.' .. PATH_SEP, ''},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'}
    }

    --- Splits a file's path into a directory and a filename part.
    --
    -- @tparam string path The path to the file.
    -- @treturn string The file's path.
    -- @treturn string The file's name.
    --
    -- This function makes an educated guess given the string it's passed.
    -- It doesn't look at the filesystem. The guess is educated enough though.
    function split_path (path)
        assert(path ~= '', 'path is the empty string')
        local dir, fname = path:match(split)
        for i = 1, #sanitisers do
            dir = dir:gsub(table.unpack(sanitisers[i]))
        end
        if dir == '' then dir = '.' end
        if fname == '' then fname = '.' end
        return dir, fname
    end
end

do
    local path = table.concat({'share', 'lua', '5.3', '?.lua'}, PATH_SEP)
    local wd, fname = split_path(PANDOC_SCRIPT_FILE)
    package.path = package.path ..
        ';' .. table.concat({wd, path}, PATH_SEP) ..
        ';' .. table.concat({wd, fname .. '-' .. VERSION, path}, PATH_SEP)
end

local json = require 'lunajson'


-- # FUNCTIONS

-- ## UI

--- Prints warnings to STDERR.
--
-- Prefixes messages with `NAME` and ": ".
-- Also appends `EOL`.
--
-- @tparam string msg A message to write to STDERR.
-- @tparam string ... Arguments (think `string.format`) for `msg`.
function warn (msg, ...)
    io.stderr:write(NAME, ': ', msg:format(...), EOL)
end


-- ## List handling

--- Returns the position of an element in a list.
--
-- @param elem The element.
-- @tparam tab list The list.
-- @treturn[1] integer The index of the element,
-- @treturn[2] nil `nil` if the list doesn't contain the element.
function get_position (elem, list)
    assert(type(list) == 'table', 'given list is not of type "table".')
    for i, v in ipairs(list) do
        if v == elem then return i end
    end
    return nil
end


--- Applies a function to every element of a list.
--
-- @tparam func func The function.
-- @tparam tab list The list.
-- @treturn tab The return values of `func`.
function map (func, list)
    local ret = {}
    for k, v in pairs(list) do ret[k] = func(v) end
    return ret
end


-- ## Path Handling

--- Checks if a path is absolute.
--
-- @tparam string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
function is_path_absolute (path)
    if PATH_SEP == '\\' and path:match '^.:\\' then return true end
    return path:match('^' .. PATH_SEP) ~= nil
end


--- Returns the directory of the first input file or '.'.
--
-- @treturn string The directory the first input file is in.
function get_input_directory ()
    local file = PANDOC_STATE.input_files[1]
    if not file then return '.' end
    return select(1, split_path(file))
end


-- ## JSON files

--- Reads a JSON file.
--
-- @tparam string fname Name of the file.
--
-- @return[1] The parsed data.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number. Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
function read_json_file (fname)
    -- luacheck: no redefined
    assert(fname ~= '', 'given filename is the empty string')
    local f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    local str, err, errno = f:read('a')
    if not str then return nil, err, errno end
    local ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    local ok, data = pcall(json.decode, str)
    if not ok then return nil, 'JSON parse error', -1 end
    return convert_numbers_to_strings(data)
end


--- Writes data to a file in JSON.
--
-- It terminates files with `EOL`.
--
-- @param data Data.
-- @tparam string fname Name of the file.
-- @treturn[1] bool `true` if `data` was written to the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number. Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
function write_json_file (data, fname)
    -- luacheck: no redefined
    assert(fname ~= '', 'given filename is the empty string')
    local ok, str = pcall(json.encode, data)
    if not ok then return nil, 'JSON encoding error', -1 end
    local f, err, errno = io.open(fname, 'w')
    if not f then return nil, err, errno end
    local ok, err, errno = f:write(str, EOL)
    if not ok then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return true
end



-- ## Retrieving data from REST APIs.

do
    local select = select -- luacheck: ignore
    local fetch = pandoc.mediabag.fetch

    --- Retrieves data via an HTTP GET request from a URL.
    --
    -- This is a function of its own only in order for the test scripts to
    -- be able to easily replace it with a function that redirects HTTP GET
    -- requests to canned responses.
    --
    -- @tparam string url The URL.
    -- @treturn string The data.
    -- @raise An uncatchable error if it cannot retrieve any data.
    function read_url (url)
        return select(2, fetch(url, '.'))
    end
end


-- ## Converters

do
    local pairs = pairs -- luacheck: ignore
    local tostring = tostring -- luacheck: ignore
    local type = type -- luacheck: ignore
    local floor = math.floor

    --- Converts all numbers in a multi-dimensional table to strings.
    --
    -- Also converts floating point numbers to integers. This is needed
    -- because all numbers are floating point numbers in JSON, but older
    -- versions of Pandoc expect integers.
    --
    -- @param data Data of any type.
    -- @return The given data, with all numbers converted into strings.
    function convert_numbers_to_strings (data, depth)
        if not depth then depth = 1 end
        assert(depth < 512, 'too many recursions')
        local t = type(data)
        if t == 'table' then
            local s = {}
            for k, v in pairs(data) do
                s[k] = convert_numbers_to_strings(v, depth + 1)
            end
            return s
        elseif t == 'number' then
            return tostring(floor(data))
        else
            return data
        end
    end
end


-- ## Retrieving sources

do
    local insert = table.insert
    local remove = table.remove
    local sub = text.sub
    local base_url = ZOTXT_BASE_URL
    local keytypes = ZOTXT_KEYTYPES

    ---  Retrieves bibliographic data in CSL JSON for a source.
    --
    -- Tries different types of citation keys, starting with the last
    -- one that a lookup was successful for.
    --
    -- @tparam string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] string A CSL JSON string.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An uncatchable error if it cannot retrieve any data and
    --  a catchable error if `citekey` is not a `string`.
    function get_source_json (citekey)
        assert(type(citekey) == 'string', 'given citekey is not a string')
        if citekey == '' then return nil, 'citation key is "".' end
        local reply
        for i = 1, #keytypes do
            local query_url = base_url:format(keytypes[i], citekey)
            reply = read_url(query_url)
            if sub(reply, 1, 1) == '[' then
                local kt = remove(keytypes, i)
                insert(keytypes, 1, kt)
                return reply
            end
        end
        return nil, reply
    end
end


do
    local pcall = pcall -- luacheck: ignore
    local decode = json.decode

    ---  Retrieves bibliographic data in CSL for a source.
    --
    -- @tparam string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An uncatchable error if it cannot retrieve any data and
    --  a catchable error if `citekey` is not a `string`.
    function get_source_csl (citekey)
        local reply, err = get_source_json(citekey)
        if not reply then return nil, err end
        local ok, data = pcall(decode, reply)
        if not ok then return nil, reply end
        local entry = convert_numbers_to_strings(data[1])
        entry.id = citekey
        return entry
    end
end


do
    local read = pandoc.read

    ---  Retrieves bibliographic data for a source.
    --
    -- Bibliography entries are different to references,
    -- because Pandoc, starting with version 2.11,
    -- parses them differently.
    --
    -- @tparam string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table Bibliographic data for that item.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @raise An uncatchable error if it cannot retrieve any data or cannot
    --  parse the reply, and a catchable error if `citekey` is not a `string`.
    function get_source (citekey)
        local reply, err = get_source_json(citekey)
        if not reply then return nil, err end
        local ref = read(reply, 'csljson').meta.references[1]
        ref.id = citekey
        return ref
    end

    -- (a) The CSL JSON reader is only available in recent versions of Pandoc.
    -- (b) pandoc-citeproc had a (rather useful) bug and parses CSL even in
    --     metadata, so there is no need to treat metadata differently.
    -- See <https://github.com/jgm/pandoc/issues/6722> for details.
    if not pandoc.types or PANDOC_VERSION < pandoc.types.Version '2.11' then
        get_source = get_source_csl
    end
end


-- ## Handling bibliographic data

--- Collects the citation keys occurring in a document.
--
-- @tparam pandoc.Doc doc A document.
-- @treturn {string,...} A list of citation keys.
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
function update_bibliography (citekeys, fname)
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
            -- luacheck: ignore err
            local ref, err = get_source_csl(citekey)
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


do
    local stringify = pandoc.utils.stringify

    --- Adds sources to a bibliography.
    --
    -- Also adds that bibliography to the document's metadata.
    -- Prints an error message to STDERR for every source that cannot be found.
    --
    -- @tparam {string,...} citekeys The citation keys of the sources to add.
    -- @tparam pandoc.Meta meta A metadata block.
    -- @treturn[1] pandoc.Meta An updated metadata block, with the field
    --  `bibliography` added if needed.
    -- @treturn[2] nil `nil` if no sources were found,
    --  `zotero-bibliography` is not set, or an error occurred.
    -- @treturn[2] string An error message, if applicable.
    -- @raise An uncatchable error if `zotero-bibliography` isn't a string.
    function add_bibliography (citekeys, meta)
        if not #citekeys or not meta['zotero-bibliography'] then return end
        local fname = stringify(meta['zotero-bibliography'])
        if fname == '' then
            return nil, 'filename of bibliography file is "".'
        elseif not fname:match '.json$' then
            return nil, fname .. ': does not end in ".json".'
        end
        if not is_path_absolute(fname) then
            fname = get_input_directory() .. PATH_SEP .. fname
        end
        local ok, err = update_bibliography(citekeys, fname)
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
end


--- Adds sources to metadata block of a document.
--
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tparam {string,...} citekeys The citation keys of the sources to add.
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn[1] pandoc.Meta An updated metadata block, with the field
--  `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found.
-- @raise An uncatchable error if it cannot retrieve any data.
function add_references (citekeys, meta)
    if #citekeys == 0 then return end
    if not meta.references then meta.references = {} end
    for _, citekey in ipairs(citekeys) do
        local ref, err = get_source(citekey)
        if ref then
            table.insert(meta.references, ref)
        else
            warn(err)
        end
    end
    return meta
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
-- @raise An uncatchable error if it cannot retrieve any data or,
--  depending on your version of Pandoc, when it cannot parse
--  zotxt's reponse as JSON.
function main (doc)
    local meta = doc.meta

    local citekeys = get_citekeys(doc)
    if #citekeys == 0 then return nil end

    for i = 1, 2 do
        local add_sources
        if     i == 1 then add_sources = add_bibliography
        elseif i == 2 then add_sources = add_references   end
        local ret, err = add_sources(citekeys, meta)
        if err then warn(err) end
        if ret then
            doc.meta = ret
            return doc
        end
    end
end


-- # BOILERPLATE
--
-- Returning the whole script, rather than only a list of mappings of
-- Pandoc data types to functions, allows to do unit testing.

M[1] = {Pandoc = main}

return M
