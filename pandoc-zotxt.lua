--- pandoc-zotxt.lua - Looks up citations in Zotero and adds references. 
--
-- @script pandoc-zotxt.lua
-- @release 0.3.14a
-- @author Odin Kroeger
-- @copyright 2018, 2019 Odin Kroeger
-- @license MIT
--
--
-- SYNOPSIS
-- ========
-- 
--      pandoc --lua-filter pandoc-zotxt.lua -F pandoc-citeproc
-- 
-- 
-- DESCRIPTION
-- ===========
-- 
-- pandoc-zotxt.lua looks up sources of citations in Zotero and adds them
-- either to a document's `references` metadata field or to its bibliography,
-- where pandoc-citeproc can pick them up.
-- 
-- You cite your sources using so-called "easy citekeys" (provided by zotxt) or
-- "BetterBibTex Citation Keys" (provided by BetterBibTex) and then tell pandoc
-- to run pandoc-zotxt.lua before pandoc-citeproc. That's all all there is to
-- it. (See the documentation of zotxt and BetterBibTex respectively for
-- details.)
-- 
-- You can also use pandoc-zotxt.lua to manage a bibliography file. This is
-- usually a lot faster. Simply set the `zotero-bibliography` metadata field 
-- to a filename. pandoc-zotxt.lua will then add the sources you cite to that
-- file, rather than to the `references` metadata field. It will also add 
-- that file to the document's `bibliography` metadata field, so that
-- pandoc-zotxt.lua picks it up. The biblography is stored in CSL JSON, 
-- so the filename must end in ".json".
-- 
-- pandoc-zotxt.lua takes relative filenames to be relative to the directory
-- of the first input file you pass to pandoc or, if you don't pass any input
-- files, as relative to the current working directory.
-- 
-- Note, pandoc-zotxt.lua only ever adds sources to bibliography files.
-- It doesn't update or delete them. To update your bibliography file,
-- delete it. pandoc-zotxt.lua will then regenerate it from scratch.
-- 
-- CAVEATS
-- =======
-- 
-- pandoc-zotxt.lua is Unicode-agnostic.
-- 
-- 
-- SEE ALSO
-- ========
-- 
-- pandoc(1), pandoc-citeproc(1)
--
--
-- LICENSE
-- =======
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


-- CONSTANTS
-- =========

-- The URL to lookup citation data.
-- See `get_source` and <https://github.com/egh/zotxt> for details.
local ZOTXT_QUERY_URL = 'http://localhost:23119/zotxt/items?'

-- Types of citation keys.
-- See `get_source` and <https://github.com/egh/zotxt> for details.
local ZOTXT_KEYTYPES = {'easykey', 'betterbibtexkey', 'key'}

-- The version of this script.
local VERSION = '0.3.14'


-- SHORTHANDS
-- ==========

local open = io.open
local concat = table.concat
local insert = table.insert
local remove = table.remove
local unpack = table.unpack


-- LIBRARIES
-- =========

local text = require 'text'
local sub = text.sub

-- The path seperator of the operating system
local PATH_SEP = sub(package.config, 1, 1)

--- Splits a file's path into its directory and its filename part.
--
-- @tparam string path The path to the file.
-- @treturn string The file's path.
-- @treturn string The file's name.
do
    local split_expr = '(.-)[\\' .. PATH_SEP .. ']([^\\' .. PATH_SEP .. ']-)$'
    function split_path (path) 
        return path:match(split_expr)
    end
end

do
    local sd = {'share', 'lua', '5.3', '?.lua'}
    local wd, fname = split_path(PANDOC_SCRIPT_FILE)
    if not wd then wd = '.' end
    package.path = concat({package.path, concat({wd, unpack(sd)}, PATH_SEP),
        concat({wd, fname .. '-' .. VERSION, unpack(sd)}, PATH_SEP)}, ';')
end

local json = require 'lunajson'
local encode = json.encode
local decode = json.decode


-- FUNCTIONS
-- =========

--- Prints warnings to STDERR.
--
-- @tparam string ... Strings to be written to STDERR.
--
-- Prefixes messages with 'pandoc-zotxt.lua: ' and appends a linefeed.
function warn (...)
    io.stderr:write('pandoc-zotxt.lua: ', concat({...}), '\n')
end


--- Checks if a path is absolute.
--
-- @tparam string path A path.
-- @treturn bool `true` if the path is absolute, `false` otherwise.
function is_path_absolute (path)
    if PATH_SEP == '\\' and path:match('^.:\\') then return true end
    return sub(path, 1, 1) == PATH_SEP
end


--- Returns the directory of the first input file or '.'.
--
-- @treturn string The working directory.
function get_input_directory ()
    local file = PANDOC_STATE.input_files[1]
    if not file then return '.' end
    local dir = split_path(file)
    if not dir then return '.' end
    return dir 
end


--- Converts all numbers in a multi-dimensional table to strings.
--
-- Also converts floating point numbers to integers.
-- This is needed because in JavaScript, all numbers are
-- floating point numbers. But Pandoc expects integers.
--
-- @param data Data of any type.
-- @return The given data, with all numbers converted into strings.
do
    local pairs = pairs
    local tostring = tostring
    local floor = math.floor

    function numtostr (data)
        local data_type = type(data)
        if data_type == 'table' then
            local s = {}
            for k, v in pairs(data) do s[k] = numtostr(v) end
            return s
        elseif data_type == 'number' then
            return tostring(floor(data))
        else
            return data
        end
    end
end


---  Retrieves bibliographic data for a source from Zotero.
--
-- Retrieves bibliographic data by citation key, trying different
-- types of citation keys, starting with the last type for which
-- a lookup was successful.
--
-- The constant `ZOTXT_QUERY_URL` defines where to get data from.
-- The constant `ZOTXT_KEYTYPES` defines what keytypes to try.
-- See <https://github.com/egh/zotxt> for details.
--
-- @tparam string key The lookup key.
-- @treturn table Bibliographic data for that source in CSL format,
--  `nil` if the source wasn't found or an error occurred.
-- @treturn string An error message if the source was not found.
do
    local keytypes = ZOTXT_KEYTYPES
    local fetch = pandoc.mediabag.fetch
    local decode = decode
    local concat = concat
    local remove = remove
    local insert = insert

    function get_source (key)
        local _, reply
        for i = 1, #keytypes do
            local query_url = concat({ZOTXT_QUERY_URL, keytypes[i], '=', key})
            _, reply = fetch(query_url, '.')
            local ok, data = pcall(decode, reply)
            if ok then
                local keytype = remove(keytypes, i)
                insert(keytypes, 1, keytype)
                local source = numtostr(data[1])
                source.id = key
                return source
            end
        end
        return nil, reply
    end
end


--- Reads a JSON file.
--
-- @tparam string fname Name of the file.
-- @return The parsed data if reading the file succeeded, `nil `otherwise.
-- @treturn string An error message, if an error occurred.
-- @treturn number An error number. Positive numbers are OS error numbers, 
--  negative numbers indicate a JSON decoding error.
function read_json_file (fname)
    local f, err, errno = open(fname, 'r')
    if not f then return nil, err, errno end
    local json, err, errno = f:read('a')
    if not json then return nil, err, errno end
    local ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    local ok, data = pcall(decode, json) 
    if not ok then return nil, 'JSON parse error', -1 end
    return numtostr(data)
end


--- Writes data to a file in JSON.
--
-- @param data Arbitrary data.
-- @tparam string fname Name of the file.
-- @treturn bool `true` if saving that data in JSON succeeded, `nil` otherwise.
-- @treturn string An error message if an error occurred.
-- @treturn integer An error number. Positive numbers are OS error numbers, 
--  negative numbers indicate a JSON encoding error.
function write_json_file (data, fname)
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


--- Adds cited sources to a bibliography file.
--
-- @tparam string fname The filename of the biblography.
-- @tparam {string,...} citekeys The citation keys of the source to add.
-- @treturn bool `true` if updating the biblography succeeded
--  (or not update was needed), `nil` otherwise.
-- @treturn string An error message if an error occurred.
--
-- Prints an error message to STDERR for every source that cannot be found.
function update_bibliography (fname, citekeys)
    if #citekeys == 0 then return end
    local ipairs = ipairs
    local insert = insert
    local refs, err, errno = read_json_file(fname)
    if not refs then
        if err and errno ~= 2 then return nil, err, errno end
        refs = {}
    end
    local count = #refs
    for _, citekey in ipairs(citekeys) do
        local present = false
        for _, ref in ipairs(refs) do
            if citekey == ref.id then
                present = true
                break
            end
        end
        if not present then
            local ref, err = get_source(citekey)
            if ref then
                insert(refs, ref)
            else
                warn(err)
            end
        end
    end
    if (#refs > count) then return write_json_file(refs, fname) end
    return true
end


do
    local CITEKEYS = {}

    --- Collects all citekeys used in a document.
    --
    -- Saves them into the variable `CITEKEYS`, which is shared with
    -- `add_references` and `add_bibliography`.
    --
    -- @param citations A pandoc.Cite element.
    do
        local insert = insert
        local seen = {}
        
        function collect_sources (citations)
            local c = citations.citations
            for i = 1, #c do
                id = c[i].id
                if not seen[id] then
                    seen[id] = true
                    insert(CITEKEYS, id)
                end
            end
        end
    end


    --- Adds sources to the metadata block of a document.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam pandoc.Meta meta A metadata block.
    -- @treturn pandoc.Meta An updated metadata block, with the field
    --  `references` added when needed, `nil` if no sources were found.
    --
    -- Prints an error message to STDERR for every source that cannot be found.
    function add_references (meta)
        if #CITEKEYS == 0 then return end
        if not meta.references then meta.references = {} end
        for _, citekey in ipairs(CITEKEYS) do
            local ref, err = get_source(citekey)
            if ref then
                insert(meta.references, ref)
            else
                warn(err)
            end
        end
        return meta
    end
    

    --- Adds sources to a bibliography and the biblography to the document.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam pandoc.Meta A metadata block.
    -- @treturn pandoc.Meta An updated metadata block, with the field
    --  `bibliography` added when needed, `nil` if no sources were found
    --  or `zotero-bibliography` is not set.
    -- @treturn string An error message if an error occurred.
    --
    -- Prints an error message to STDERR for every source that cannot be found.
    function add_bibliography (meta)
        if not #CITEKEYS or not meta['zotero-bibliography'] then return end
        local stringify = pandoc.utils.stringify
        local fname = stringify(meta['zotero-bibliography'])
        if sub(fname, -5) ~= '.json' then
            return nil, fname .. ': not a JSON file'
        end 
        if not is_path_absolute(fname) then
            fname = get_input_directory() .. PATH_SEP .. fname
        end
        local ok, err = update_bibliography(fname, CITEKEYS)
        if ok then
            if not meta.bibliography then
                meta.bibliography = fname
            elseif meta.bibliography.t == 'MetaInlines' then
                meta.bibliography = {stringify(meta.bibliography), fname}
            elseif meta.bibliography.t == 'MetaList' then
                insert(meta.bibliography, fname)
            end
            return meta
        else
            return nil, err
        end
    end
end


--- Adds sources to the document's metadata or to the bibliography.
--
-- Checks whether the current documents uses a bibliography. If so, adds cited
-- sources that aren't in it yet to the file. Otherwise, adds all cited
-- sources to the document's metadata.
--
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn pandoc.Meta An updated metadata block, with references or
--  a pointer to the bibliography file, `nil` if nothing
--  was done or an error occurred.
--
-- Prints messages to STDERR if errors occur.
function add_sources (meta)
    do
        local meta, err = add_bibliography(meta)
        if meta then return meta end
        if err then warn(err) end
    end
    return add_references(meta)
end


return {{Cite = collect_sources}, {Meta = add_sources}}
