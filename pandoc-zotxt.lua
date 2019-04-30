--- pandoc-zotxt.lua Looks up citations in Zotero and adds references. 
--
-- @release 0.2.3
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


-- Shorthands
-- ==========

local open = io.open
local floor = math.floor
local concat = table.concat
local insert = table.insert
local remove = table.remove


-- Libraries
-- =========

do
    local script_dir = PANDOC_SCRIPT_FILE:match('(.-)[\\/][^\\/]-$') or '.'
    local path_sep = package.config:sub(1, 1)
    local lua_vers = {}
    for _, v in ipairs({_VERSION:sub(5, 7), '5.3'}) do lua_vers[v] = true end
    for k, _ in pairs(lua_vers) do
        package.path = package.path .. ';' ..
            concat({script_dir, 'share', 'lua', k, '?.lua'}, path_sep)
    end
end

local json = require 'lunajson'
local decode = json.decode
local encode = json.encode


-- Functions
-- =========

--- Prints warnings to STDERR.
--
-- Prefixes messages with 'pandoc-zotxt.lua: ' and appends a linefeed.
function warn (...)
    io.stderr:write('pandoc-zotxt.lua: ', ..., '\n')
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
    -- @treturn string If the cited source was found, bibliographic data for
    --  that source as CSL JSON string. Otherwise, `nil`.
    -- @treturn string If no source was found, an error message.
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
function stringify (data)
    local data_type = type(data)
    if data_type == 'table' then
        local s = {}
        for k, v in pairs(data) do s[k] = stringify(v) end
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
-- @treturn table If the cited source was found, bibliographic data for
--  that source in CSL format. Otherwise, `nil` .
-- @treturn string If the cited source was not found, the error 
--  message of the lookup attempt for the first keytype.
function get_source (citekey)
    local data, err = get_source_json(citekey)
    if data == nil then
        return data, err
    else
        local source = stringify(decode(data)[1])
        source.id = citekey
        return source
    end
end


--- Retrieves bibliographic data for multiple sources from Zotero.
-- 
-- @tparam {string,...} citekeys A list of citation keys.
--
-- @treturn {table,...} The cited sources, in CSL data format.
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


    --- Adds all cited sources to the metadata block of a document.
    --
    -- Reads citekeys of cited sources from the variable `CITEKEYS`,
    -- which is shared with `collect_sources`.
    --
    -- @param meta The metadata block of a document, as pandoc.Meta.
    --
    -- @return If sources were found, an updated metadata block, 
    --  as pandoc.Meta, with the field `references` added.
    --  Otherwise, nil.
    function add_references (meta)
        local refs = get_sources(CITEKEYS)
        if #refs > 0 then
            meta['references'] = refs 
            return meta
        end
    end
    
    function update_bibliography (biblio)    
        local f, err, errno = open(biblio, 'r')
        local refs = {}
        if f then
            local data, err = f:read()
            if not data then return nil, err end
            local ret, err = f:close()
            if not ret then return nil, err end
            refs = stringify(decode(data))
        -- This works on POSIX systems, it might be wrong on Windows.
        elseif errno ~= 2
            return nil, err
        end
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
        local data, err = encode(refs)
        if not data then return nil, err end
        f, err = open(biblio, 'w')
        if not f then return nil, err end
        ret, err = f:write(data, '\n')
        if not ret then return nil, err end
        ret, err = f:close()
        if not ret then return nil, err end
        return true
    end
end

function add_sources (meta)
    if meta['bibliography'] then
        local biblio = meta['bibliography']
        if biblio.t == 'MetaList' then biblio = biblio[#biblio] end
        biblio = pandoc.utils.stringify(biblio)
        if biblio:sub(#biblio - 4, #biblio) == '.json' then
            local ret, err = update_bibliography(biblio)
            if not ret then warn(err) end
            return
        end
    end
    return add_references(meta)
end


return {{Cite = collect_sources, Meta = add_sources}}
