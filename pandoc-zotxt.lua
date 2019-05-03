--- pandoc-zotxt.lua Looks up citations in Zotero and adds references. 
--
-- @script pandoc-zotxt.lua
-- @release 0.3.11
-- @author Odin Kroeger
-- @copyright 2018, 2019 Odin Kroeger
-- @license MIT
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

-- Constants
-- =========

-- The URL to lookup citation data.
-- See `get_source_json` and <https://github.com/egh/zotxt> for details.
local ZOTXT_QUERY_URL = 'http://localhost:23119/zotxt/items?'

-- Types of citation keys.
-- See `get_source_json` and <https://github.com/egh/zotxt> for details.
local ZOTXT_KEYTYPES = {'easykey', 'betterbibtexkey', 'key'}

-- The version of this script.
local VERSION = '0.3.11'


-- Shorthands
-- ==========

local open = io.open
local floor = math.floor
local concat = table.concat
local insert = table.insert
local remove = table.remove
local unpack = table.unpack


-- Libraries
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
local decode = json.decode
local encode = json.encode


-- Functions
-- =========

--- Moves an element to the beginning of a list.
--
-- @tparam list The list.
-- @tparam integer The index of the element.
-- @treturn table The list.
function move_to_front (list, i)
    local element = remove(list, i)
    insert(list, 1, element)
    return list
end


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
    local data, err, errno = f:read("a")
    if not data then return nil, err, errno end
    local ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    data, err = decode(data)
    if not data then return nil, err, -1 end
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
    local json, err = encode(data)
    if not json then return nil, err, -1 end
    local f, err, errno = open(fname, 'w')
    if not f then return nil, err, errno end
    local ok, err, errno = f:write(json, '\n')
    if not ok then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return true
end


---  Retrieves bibliographic data from Zotero.
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
-- @treturn string Bibliographic data for that source as CSL JSON string,
--  `nil` if the source wasn't found.
-- @treturn string An error message if the source was not found.
do
    local keytypes = ZOTXT_KEYTYPES

    function get_source_json (key)
        local _, reply
        for i = 1, #keytypes do
            local query_url = concat({ZOTXT_QUERY_URL, keytypes[i], '=', key})
            _, reply = pandoc.mediabag.fetch(query_url, '.')
            if sub(reply, 1, 1) == '[' then
                if i > 1 then move_to_front(keytypes, i) end
                return reply
            end
        end
        return nil, reply
    end
end


--- Converts all numbers in a multi-dimensional table to strings.
--
-- Also converts floating point numbers to integers.
-- This is needed because in JavaScript, all numbers are
-- floating point numbers. But Pandoc expects integers.
--
-- @param data Data of any type.
-- @return The given data, with all numbers converted into strings.
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


--- Retrieves bibliographic data for sources from Zotero.
-- 
-- @tparam string citekey A citation key.
-- @treturn table Bibliographic data for that source in CSL format,
--  `nil` if the source wasn't found.
-- @treturn string The error message of the lookup attempt for the first
--  keytype if the source wasn't found.
function get_source (citekey)
    local data, err = get_source_json(citekey)
    if data == nil then
        return data, err
    else
        local source = numtostr(decode(data)[1])
        source.id = citekey
        return source
    end
end


--- Retrieves bibliographic data for multiple sources from Zotero.
-- 
-- @tparam {string,...} citekeys A list of citation keys.
-- @treturn {table,...} The cited sources found, in CSL format.
--
-- Prints an error message to STDERR for every source that cannot be found.
function get_sources (citekeys)
    local sources = {}
    for _, citekey in ipairs(citekeys) do
        local source, err = get_source(citekey)
        if source then 
            insert(sources, source)
        else
            warn(err)
        end
    end
    return sources
end


do
    local CITEKEYS = {}

    --- Collects all citekeys used in a document.
    --
    -- Saves them into the variable `CITEKEYS`, which is shared with
    -- `add_references` and `update_bibliography`.
    --
    -- @param citations A pandoc.Cite element.
    do
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


    --- Adds cited sources to the metadata block of a document.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam pandoc.Meta meta A metadata block.
    -- @treturn pandoc.Meta An updated metadata block, with the field
    --  `references` added when needed, `nil` if no sources were found.
    function add_references (meta)
        local refs = get_sources(CITEKEYS)
        if #refs > 0 then
            if meta.references then
                insert(meta.references, refs)
            else
                meta.references = refs 
            end
            return meta
        end
    end
    
    
    --- Adds cited sources to a bibliography file.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam string fname The filename of the biblography.
    -- @treturn bool `true` if updating the biblography succeeded
    --  (or not update was needed), `nil` otherwise.
    -- @treturn string An error message if an error occurred.
    function update_bibliography (fname)
        local refs, err, errno = read_json_file(fname)
        if not refs then
            if errno ~=2 then return nil, err, errno end
            refs = {}
        end
        local count = #refs
        for _, citekey in ipairs(CITEKEYS) do
            local found = false
            for _, ref in ipairs(refs) do
                if citekey == ref.id then
                    found = true
                    break
                end
            end
            if not found then refs[#refs + 1] = get_source(citekey) end
        end
        if (#refs > count) then return write_json_file(refs, fname) end
        return true
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
    if meta['zotero-bibliography'] then
        local stringify = pandoc.utils.stringify
        local biblio = stringify(meta['zotero-bibliography'])
        if sub(biblio, -5) == '.json' then            
            if not is_path_absolute(biblio) then
                biblio = get_input_directory() .. PATH_SEP .. biblio
            end
            local ok, err = pcall(update_bibliography, biblio)
            if ok then
                if not meta.bibliography then
                    meta.bibliography = biblio
                elseif meta.bibliography.t == 'MetaInlines' then
                    meta.bibliography = {stringify(meta.bibliography), biblio}
                elseif meta.bibliography.t == 'MetaList' then
                    insert(meta.bibliography, biblio)
                end
                return meta
            else
                warn(err)
            end
        else
            warn(biblio, ': not a JSON file.')
        end
    end
    return add_references(meta)
end


return {{Cite = collect_sources}, {Meta = add_sources}}
