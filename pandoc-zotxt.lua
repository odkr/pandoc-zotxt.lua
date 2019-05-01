--- pandoc-zotxt.lua Looks up citations in Zotero and adds references. 
--
-- @release 0.3.3
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
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
-- See ``get_source_json`` and <https://github.com/egh/zotxt> for details.
local ZOTXT_QUERY_URL = 'http://localhost:23119/zotxt/items?'

-- Keytypes.
-- See ``get_source_json`` and <https://github.com/egh/zotxt> for details.
local ZOTXT_KEYTYPES = {'easykey', 'betterbibtexkey', 'key'}

-- The version of this script.
local VERSION = '0.3.3'

-- The path seperator of the operating system
local PATH_SEP = package.config:sub(1, 1)


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

function split_path (fname) 
    return fname:match('(.-)[\\' .. PATH_SEP .. ']([^\\' .. PATH_SEP .. ']-)$')
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

--- Prints warnings to STDERR.
--
-- @tparam string ... Strings to be written to STDERR.
--
-- Prefixes messages with 'pandoc-zotxt.lua: ' and appends a linefeed.
function warn (...)
    io.stderr:write('pandoc-zotxt.lua: ', concat({...}), '\n')
end


--- Checks if a file exists.
--
-- @tparam string fname Name of the file.
--
-- @return True or not `nil` if the file exists. `nil` otherwise.
-- @treturn Error code if the file does not exist. 
--
-- @see <https://stackoverflow.com/questions/1340230/>
function exists (fname)
    local ok, err, errno = os.rename(fname, fname)
    if not ok and errno == 13 then return true end
    return ok, err 
end


--- Checks if a filename points to a directory.
--
-- @tparam string fname Name of the directory.
--
-- @return True or not `nil` if the directory exists. `nil` otherwise.
-- @treturn Error code if the directory does not exist. 
--
-- @see <https://stackoverflow.com/questions/1340230/>
function is_dir (fname)
    if fname:sub(-#PATH_SEP) == PATH_SEP then
        return exists(fname)
    end
    return exists(fname .. PATH_SEP)
end


--- Returns the working directory of the first input file or '.'.
--
-- @treturn string The working directory.
function get_wd ()
    local first_input_file = PANDOC_STATE.input_files[1]
    if first_input_file then
        local first_input_dir = split_path(first_input_file)
        if is_dir(first_input_dir) then return first_input_dir end
    end
    return '.'
end


do
    local KEYTYPES = ZOTXT_KEYTYPES

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
    --
    -- @treturn string Bibliographic data for that source as CSL JSON string
    --  if the source was found, `nil` otherwise.
    -- @treturn string An error message if the soruce was not found.
    function get_source_json (key)
        local _, reply
        for i = 1, #KEYTYPES do
            local query_url = concat({ZOTXT_QUERY_URL, KEYTYPES[i], '=', key})
            _, reply = pandoc.mediabag.fetch(query_url, '.')
            if reply:sub(1, 1) == '[' then
                if i > 1 then
                    local keytype = remove(KEYTYPES, i)
                    insert(KEYTYPES, 1, keytype)
                end
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
--
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
--
-- @treturn table Bibliographic data for that source in CSL format,
--  if the source was found, `nil` otherwise.
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
--
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
    local SEEN = {}

    --- Collects all citekeys used in a document.
    --
    -- Saves them into the variable `CITEKEYS`, which is shared with
    -- `add_references` and `update_bibliography`.
    --
    -- @param citations A pandoc.Cite element.
    function collect_sources (citations)
        local c = citations.citations
        for i = 1, #c do
            id = c[i].id
            if SEEN[id] == nil then
                SEEN[id] = true
                insert(CITEKEYS, id)
            end
        end
    end


    --- Adds cited sources to the metadata block of a document.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam pandoc.Meta meta A metadata block.
    --
    -- @treturn pandoc.Meta An updated metadata block, with the field
    --  `references` added when needed, if sources were found;
    --  `nil` otherwise.
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
    -- Retrieves sources that aren't in the bibliography from Zotero
    -- and adds them. The bibliography must be a CSL JSON file.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @tparam string fname The filename of the biblography.
    --
    -- @treturn bool `true` if updating the biblography succeeded
    --  (or not update was needed), `nil` otherwise.
    -- @treturn string An error message if an error occurred.
    function update_bibliography (fname)
        if fname:sub(-5) ~= '.json' then
            return nil, fname .. ': not a JSON file.'
        end
        local f, err, errno = open(fname, 'r')
        local refs = {}
        if f then
            local data, err = f:read()
            if not data then return nil, err end
            local ok, err = f:close()
            if not ok then return nil, err end
            refs = numtostr(decode(data))
        elseif errno ~= 2 then
            return nil, err
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
        if (#refs > count) then
            local data, err = encode(refs)
            if not data then return nil, err end
            f, err = open(fname, 'w')
            if not f then return nil, err end
            ok, err = f:write(data, '\n')
            if not ok then return nil, err end
            ok, err = f:close()
            if not ok then return nil, err end
        end
        return true
    end
end


--- Adds sources as references or to the bibliography.
--
-- Checks whether the current documents uses a bibliography. If so, adds cited
-- sources that aren't in it yet to the file. Otherwise, adds all cited
-- sources to the document's metadata.
--
-- @tparam pandoc.Meta meta A metadata block.
--
-- @treturn pandoc.Meta An updated metadata block, with references or
--  a pointer to the bibliography file added or `nil`.
function add_sources (meta)
    local stringify = pandoc.utils.stringify
    if meta['zotero-bibliography'] then
        local biblio = meta['zotero-bibliography']
        if biblio.t == 'MetaList' then biblio = biblio[#biblio] end
        biblio = stringify(biblio)
        if biblio:sub(1, #PATH_SEP) ~= PATH_SEP then 
            biblio = get_wd() .. PATH_SEP .. biblio
        end
        local ok, err = update_bibliography(biblio)
        if not ok then warn(err) end
        if not meta.bibliography then
            meta.bibliography = biblio
        elseif meta.bibliography.t == 'MetaInlines' then
            meta.bibliography = {stringify(meta.bibliography), biblio}
        elseif meta.bibliography.t == 'MetaList' then
            insert(meta.bibliography, biblio)
        end
        return meta
    end
    return add_references(meta)
end


return {{Cite = collect_sources, Meta = add_sources}}
