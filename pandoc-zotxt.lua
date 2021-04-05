--- pandoc-zotxt.lua - Looks up sources of citations in Zotero
--
-- SYNOPSIS
-- --------
--
-- **pandoc** **-L** *pandoc-zotxt.lua* **-C**
--
--
-- DESCRIPTION
-- -----------
--
-- **pandoc-zotxt.lua** looks up sources of citations in Zotero and adds them
-- either to a document's "references" metadata field or to a bibliography file,
-- where **pandoc** can pick them up.
--
-- Cite your sources using "easy citekeys" (provided by zotxt) or "Better BibTeX
-- Citation Keys" (provided by Better BibTeX for Zotero). Then tell **pandoc** to
-- filter your document through **pandoc-zotxt.lua** before processing citations;
-- Zotero must be running. That's all there is to it.
--
--
-- BIBLIOGRAPHY FILES
-- ------------------
--
-- **pandoc-zotxt.lua** can also add sources to a bibliography file, rather
-- than the "references" metadata field. This speeds up subsequent runs of
-- **pandoc-zotxt.lua** for the same document, because **pandoc-zotxt.lua**
-- will only fetch those sources from Zotero that are not yet in that file.
-- Simply set the "zotero-bibliography" metadata field to a filename.
-- **pandoc-zotxt.lua** will then add sources to that file. It will also add
-- that file to the document's "bibliography" metadata field, so that
-- **pandoc** picks up those sources. The biblography is stored as a JSON
-- file, so the filename must end with ".json". You can safely set
-- "zotero-bibliography" and "bibliography" at the same time. But you
-- will need to make sure that citation keys are unique accross files.
--
-- **pandoc-zotxt.lua** interprets relative filenames as relative to the
-- directory of the first input file that you pass to **pandoc** or, if you
-- do not pass any input file, as relative to the current working directory.
--
-- Note: **pandoc-zotxt.lua** only ever adds sources to the bibliography file.
-- It doesn't update or delete them. If you want to update the sources in your
-- bibliography file, delete it. **pandoc-zotxt.lua** will then regenerate
-- it from scratch.
--
--
-- EXAMPLES
-- --------
--
--      pandoc -L pandoc-zotxt.lua -C <<EOF
--      See @crenshaw1989DemarginalizingIntersectionRace for details.
--      EOF
--
-- This instructs Pandoc to filter the input through **pandoc-zotxt.lua**,
-- which then looks up the bibligraphic data of the source with the citation
-- key "crenshaw1989DemarginalizingIntersectionRace" in Zotero before Pandoc
-- processes citations.
--
--      cat <<EOF >document.md
--      ---
--      zotero-bibliography: bibliography.json
--      ---
--      See @crenshaw1989DemarginalizingIntersectionRace for details.
--      EOF
--      pandoc -L pandoc-zotxt.lua -C document.md
--
-- This instructs **pandoc-zotxt.lua** to store bibliographic data in a file
-- named "bibliography.json" and to add that file to the metadata field
-- "bibliography", so that Pandoc picks it up. "bibliography.json" is placed in
-- the same directory as "document.md", since "document.md" is the first input
-- file given. The next time you process "document.md", **pandoc-zotxt.lua** will
-- *not* look up  "crenshaw1989DemarginalizingIntersectionRace" in Zotero, since
-- "bibliography.json" already contains data for that source.
--
--
-- KNOWN ISSUES
-- ------------
--
-- Zotero, from v5.0.71 onwards, does not allow browsers to access its
-- interface. It defines "browser" as any user agent that sets the "User
-- Agent" HTTP header to a string that starts with "Mozilla/". However,
-- Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user
-- agents that do not set the "User Agent" HTTP header. And **pandoc** does
-- not. As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
-- versions of Zotero, that is, unless you tell **pandoc** to set that header.
-- If you cannot upgrade to a more recent version of Zotero, you can make
-- **pandoc** set that header by passing, for instance, **--request-header**
-- *User-Agent:Pandoc/2*. If you must set the "User Agent" HTTP header to a
-- string that starts with "Mozilla/", you can still get **pandoc** to connect
-- to Zotero by setting the HTTP header "Zotero-Allowed-Request". You do so by
-- passing **--request-header** *Zotero-Allowed-Request:X*.
--
--
-- CAVEATS
-- -------
--
-- **pandoc-zotxt.lua**
--
-- * is Unicode-agnostic.
-- * cannot check whether you redefine a citation key if
--   you use additional bibliography files.
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
-- @release 1.0.0
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020 Odin Kroeger
-- @license MIT


-- INITIALISATION
-- ==============
--
-- luacheck: allow defined top

local M = {}

local assert = assert
local next = next
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


-- CONSTANTS
-- =========

-- About this script
-- -----------------

--- The name of this script.
NAME = 'pandoc-zotxt.lua'

--- The version of this script.
VERSION = '1.0.0'


-- Operating system
-- ----------------

--- The path seperator of the operating system.
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence of the operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end


-- zotxt
-- -----

--- The URL to lookup citation data.
--
-- See `get_source_csljson` and <https://github.com/egh/zotxt> for details.
ZOTXT_BASE_URL = 'http://localhost:23119/zotxt/items?'

--- Types of citation keys.
--
-- See `get_source_csljson` and <https://github.com/egh/zotxt> for details.
--
-- @table ZOTXT_KEYTYPES
ZOTXT_KEYTYPES = {
    'betterbibtexkey', -- Better BibTeX citation key
    'easykey',         -- zotxt easy citekey
    'key'              -- Zotero item ID
}


-- LIBRARIES
-- =========

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
    -- @string path The path to the file.
    -- @treturn string The file's path.
    -- @treturn string The file's name.
    --
    -- This function makes an educated guess given the string it's passed.
    -- It doesn't look at the filesystem. The guess is educated enough though.
    function split_path (path)
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


-- FUNCTIONS
-- =========

-- UI
-- --

--- Prints warnings to STDERR.
--
-- Prefixes messages with `NAME` and ": ".
-- Also appends `EOL`.
--
-- @string msg A message to write to STDERR.
-- @param ... Arguments (think `string.format`) for `msg`.
function warn (msg, ...)
    io.stderr:write(NAME, ': ', msg:format(...), EOL)
end


-- Paths
-- -----

--- Checks if a path is absolute.
--
-- @string path A path.
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


-- File handling
-- -------------

--- Reads a file.
--
-- @string fname Name of the file.
-- @treturn[1] string The content of thee file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int The error number.
function read_file (fname)
    local str, err, errno, f, ok
    f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    str, err, errno = f:read('a')
    if not str then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return str
end


--- Writes data to a file.
--
-- @param data Data.
-- @string fname Name of the file.
-- @treturn[1] bool `true` if `data` was written to the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--  Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
function write_file (str, fname)
    local err, errno, f, ok
    f, err, errno = io.open(fname, 'w')
    if not f then return nil, err, errno end
    ok, err, errno = f:write(str)
    if not ok then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return true
end


--- Reads a JSON file.
--
-- @string fname Name of the file.
-- @return[1] The parsed data.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--  Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
function read_json_file (fname)
    local str, err, errno = read_file(fname)
    if not str then return nil, err, errno end
    local ok, data = pcall(json.decode, str)
    if not ok then return nil, 'JSON decoding error', -1 end
    return conv_nums_to_strs(data)
end


--- Writes JSON data to a file.
--
-- Terminates files with `EOL`.
--
-- @param data Data.
-- @string fname Name of the file.
-- @treturn[1] bool `true` if `data` was written to the file.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--  Positive numbers are OS error numbers,
--  negative numbers indicate a JSON decoding error.
function write_json_file (data, fname)
    local ok, str = pcall(json.encode, data)
    if not ok then return nil, 'JSON encoding error', -1 end
    return write_file(str .. EOL, fname)
end


do
    local read = pandoc.read
    local header = '---\n%s\n...'

    --- Reads a CSL YAML file.
    --
    -- @string fname Name of the file.
    -- @return[1] The parsed data.
    -- @treturn[2] nil `nil` if the file could not be read.
    -- @treturn[2] string An error message.
    -- @treturn[2] int The OS error number.
    -- @raise An error if the file cannot be parsed.
    --  If you are running a version of Pandoc prior to v2.10,
    --  this error cannot be caught.
    function read_yaml_file (fname)
        local str, err, errno = read_file(fname)
        if not str then return nil, err, errno end
        local data = read(header:format(str), 'markdown')
        return data.meta.references
    end
end


-- Retrieving data
-- ---------------

do
    local pcall = pcall -- luacheck: ignore
    local fetch = pandoc.mediabag.fetch

    --- Retrieves data request from a URL via an HTTP GET request.
    --
    -- This is a function of its own only in order for the test scripts to
    -- be able to easily replace it with a function that redirects HTTP GET
    -- requests to canned responses.
    --
    -- @string url The URL.
    -- @treturn[1] string The data.
    -- @treturn[2] nil `nil` if no data could be retrieved. But only if you
    --  are using Pandoc v2.10 or later. Otherwise an error is raised.
    -- @treturn[2] string An error message.
    -- @treturn[2] userdata A pandoc error value.
    -- @raise An error if no data can be retrieved. But only if you are *not*
    --  using Pandoc v2.10 or later. This error cannot be caught.
    function read_url (url)
        local ok, err, data = pcall(fetch, url, '.')
        if not ok then return nil, url .. ': Could not retrieve.', err end
        return data
    end
end


-- Converters
-- ----------

do
    local pairs = pairs -- luacheck: ignore
    local tostring = tostring -- luacheck: ignore
    local type = type -- luacheck: ignore
    local floor = math.floor

    --- Converts all numbers in a multi-dimensional table to strings.
    --
    -- Also converts floating point numbers to integers. This is needed
    -- because all numbers are floating point numbers in JSON, but some
    -- versions of Pandoc expect integers.
    --
    -- @param data Data of any type.
    -- @return The given data, with all numbers converted into strings.
    function conv_nums_to_strs (data, depth)
        if not depth then depth = 1 end
        assert(depth < 512, 'Reached recursion limit.')
        local t = type(data)
        if t == 'table' then
            local s = {}
            for k, v in pairs(data) do
                s[k] = conv_nums_to_strs(v, depth + 1)
            end
            return s
        elseif t == 'number' then
            return tostring(floor(data))
        else
            return data
        end
    end
end


-- Retrieving bibliographic data
-- -----------------------------

do
    local pcall = pcall -- luacheck: ignore
    local concat = table.concat
    local insert = table.insert
    local remove = table.remove
    local base_url = ZOTXT_BASE_URL
    local keytypes = ZOTXT_KEYTYPES

    ---  Retrieves bibliographic data for a source (low-level).
    --
    -- Takes a citation key and a parsing function, queries zotxt for that
    -- citation key, passes whatever zotxt returns to the parsing function,
    -- and then returns whatever that parsing function returns. Tries again
    -- if the parsing function raises an exception, but assumes that the
    -- citation key is of a different type.
    --
    -- This is a low-level function and should not be called directly.
    -- Use `get_source` and `get_source_csl` instead.
    --
    -- @string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @func parse A function takes a CSL JSON string and
    --  returns bibliophic data.
    -- @treturn[1] string A CSL JSON string.
    -- @treturn[2] nil `nil` if an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] string The type of error that occurred, where
    --  `read_err` means that no data could be read from zotxt, and
    --  `no_match` that no meaningful data could be found for `citekey`.
    -- @raise An error if `citekey` is the empty string or
    --  if no data can be read from zotxt *and* you are *not*
    --  using Pandoc v2.10 or later. The latter error cannot be caught.
    function get_source_csljson (citekey, parse)
        assert(citekey ~= '', 'Citation key: Is the empty string ("").')
        for i = 1, #keytypes do
            local query_url, keytype
            keytype = keytypes[i]
            query_url = concat({base_url, keytype, '=', citekey})
            local response, err = read_url(query_url)
            if not response then return nil, err, 'read_err' end
            local ok, entry = pcall(parse, response)
            if ok then
                if i ~= 1 then
                    remove(keytypes, i)
                    insert(keytypes, 1, keytype)
                end
                return entry
            end
        end
        return nil, citekey .. ': Not found.', 'no_match'
    end
end


do
    local pcall = pcall -- luacheck: ignore
    local decode = json.decode

    --- Converts a CSL JSON string to a Lua data structure.
    --
    -- @string csljson A CSL JSON string.
    -- @return A Lua data structure.
    local function parse (csljson)
        return conv_nums_to_strs(decode(csljson)[1])
    end

    ---  Retrieves bibliographic data for a source (for JSON files).
    --
    -- Returns bibliographic data as Lua data structure, *not* as a Pandoc
    -- data structure. That is, the return value of this function can be
    -- passed to `write_json_file`, but should *not* be stored in the
    -- `references` metadata field. (Unless you are using a version of
    -- Pandoc prior to v2.11.)
    --
    -- @string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table A CSL item.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] string The type of that error. See `get_source_csljson`.
    -- @raise See `get_source_csljson`.
    function get_source_csl (citekey)
        local ref, err, errtype = get_source_csljson(citekey, parse)
        if not ref then return nil, err, errtype end
        ref.id = citekey
        return ref
    end
end


do
    local pcall = pcall -- luacheck: ignore
    local read = pandoc.read
    local MetaInlines = pandoc.MetaInlines
    local Str = pandoc.Str

    --- Converts a CSL JSON string to Pandoc metadata data structure.
    --
    -- @string csljson A CSL JSON string.
    -- @return A Pandoc metadata data structure.
    local function parse (csljson)
        return read(csljson, 'csljson').meta.references[1]
    end

    ---  Retrieves bibliographic data for a source (for Citeproc).
    --
    -- Returns data as a Pandoc data structure, which can be used in the
    -- `references` metadata field. (Regardless of what version of Pandoc
    -- you use.)
    --
    -- @string citekey The citation key of the source,
    --  e.g., 'name:2019word', 'name2019TwoWords'.
    -- @treturn[1] table Bibliographic data for that item.
    -- @treturn[2] nil `nil` if the source wasn't found or an error occurred.
    -- @treturn[2] string An error message.
    -- @treturn[2] string The type of that error. See `get_source_csljson`.
    -- @raise See `get_source_csljson`.
    function get_source (citekey)
        local ref, err, errtype = get_source_csljson(citekey, parse)
        if not ref then return nil, err, errtype end
        ref.id = MetaInlines{Str(citekey)}
        return ref
    end

    -- (a) The CSL JSON reader is only available in Pandoc v2.11 or later.
    -- (b) pandoc-citeproc had a (rather useful) bug and parses CSL tags
    --     in metadata fields, so there is no need to treat metadata
    --     fields and bibliography files differently.
    -- See <https://github.com/jgm/pandoc/issues/6722> for details.
    if not pandoc.types or PANDOC_VERSION < {2, 11} then
        get_source = get_source_csl
    end
end


-- Document handling
-- -----------------

--- Collects the citation keys occurring in a document.
--
-- @tparam pandoc.Doc doc A document.
-- @treturn table A set of citation keys.
function get_used_citekeys (doc)
    local ret = {}
    local filter = {
        Cite = function (cite)
            local citations = cite.citations
            for i = 1, #citations do
                local id = citations[i].id
                ret[id] = true
            end
        end
    }
    for i = 1, #doc.blocks do
        pandoc.walk_block(doc.blocks[i], filter)
    end
    return ret
end


--- Returns the citation keys of sources in the `references` metadata field.
--
-- @tparam pandoc.Doc doc A document.
-- @treturn table A set of citation keys.
function get_refs_citekeys (doc)
    assert(doc.blocks, 'Not a Pandoc document.')
    local ret = {}
    if doc.meta then
        local stringify = pandoc.utils.stringify
        local references = doc.meta.references
        if references then
            for i = 1, #references do
                local ref = references[i]
                local id = stringify(ref.id)
                ret[id] = true
            end
        end
    end
    return ret
end


function get_biblio_citekeys (doc)
    assert(doc.blocks, 'Not a Pandoc document.')
    local ret = {}
    if doc.meta then
        local stringify = pandoc.utils.stringify
        local biblio = doc.meta.bibliography
        if biblio then
            local fnames
            if biblio.tag == 'MetaInlines' then
                fnames = {stringify(biblio)}
            elseif biblio.tag == 'MetaList' then
                fnames = biblio:map(stringify)
            else
                warn 'Cannot parse metadata field "bibliography".'
            end
            for i = 1, #fnames do
                local fname = fnames[i]
                if fname:match '.[Jj][Ss][Oo][Nn]$' then
                    local sources = read_json_file(fname)
                    for j = 1, #sources do
                        local source = sources[j]
                        ret[source.id] = true
                    end
                elseif fname:match '.[Yy][Aa][Mm][Ll]$' then
                    local ok, sources = pcall(read_yaml_file, fname)
                    if ok then
                        for j = 1, #sources do
                            local source = sources[j]
                            ret[stringify(source.id)] = true
                        end
                    else
                        warn('%s: Could not parse.', fname)
                    end
                else
                    warn('%s: Unknown bibliography format.', fname)
                end
            end
        end
    end
    return ret
end


do
    local get_def_citekeys_funcs = {get_refs_citekeys, get_biblio_citekeys}

    function get_undef_citekeys (doc)
        local ret = get_used_citekeys(doc)
        for i = 1, #get_def_citekeys_funcs do
            local get_def_citekeys = get_def_citekeys_funcs[i]
            local def_citekeys = get_def_citekeys(doc)
            for citekey in pairs(def_citekeys) do
                ret[citekey] = nil
            end
        end
        return ret
    end
end



--- Adds sources to a bibliography file.
--
-- If a source is already in the bibliography file, the data of that source
-- will *not* be updated in the file.
--
-- Prints an error message to STDERR for every source that cannot be found.
--
-- @tab citekeys Set of citation keys that should be added, e.g.,
--  `{['name:2019word']=true, ['name2019WordWordWord']=true}`.
-- @string fname The name of the bibliography file.
-- @treturn[1] bool `true` if the bibliography file was updated
--  or no update was needed.
-- @treturn[2] nil `nil` if an error occurrs.
-- @treturn[2] string An error message, if applicable.
-- @treturn[2] int An error number, if applicable.
--  Positive numbers are OS error numbers,
--  a negative number indicates that no data could be retrieved.
-- @raise See `get_source_csljson`.
function update_bibliography (citekeys, fname)
    if next(citekeys) == nil then return true end
    local refs, err, errno = read_json_file(fname)
    if not refs then
        if err and errno ~= 2 then return nil, err, errno end
        refs = {}
    end
    local ids = {}
    for i = 1, #refs do
        local ref = refs[i]
        ids[ref.id] = true
    end
    local c = #refs
    local n = c
    for citekey in pairs(citekeys) do
        if not ids[citekey] then
            -- luacheck: ignore err
            local ref, err, errtype = get_source_csl(citekey)
            if ref then
                n = n + 1
                refs[n] = ref
            elseif errtype == 'read_err' then
                return nil, 'Could not retrieve data from Zotero.', -1
            else
                warn(err)
            end
        end
    end
    if (n == c) then return true end
    return write_json_file(refs, fname)
end


--- Adds sources to a bibliography file and that file to the metadata.
--
-- Behaves in the same way as `update_bibliography`, but also adds the
-- the given bibliography file to the metadata field `bibliography`.
--
-- @tab citekeys Set of citation keys that should be added, e.g.,
--  `{['name:2019word']=true, ['name2019WordWordWord']=true}`.
-- @tparam pandoc.Meta meta A metadata block, with the field
--  `zotero-bibliography` set to the filename of the bibliography file.
-- @treturn[1] pandoc.Meta An updated metadata block, with the field
--  `bibliography` added if needed.
-- @treturn[2] nil `nil` if no sources were found,
--  `zotero-bibliography` is not set, or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `get_source_csljson`.
function add_bibliography (citekeys, meta)
    if not meta['zotero-bibliography'] or next(citekeys) == nil then
        return
    end
    local stringify = pandoc.utils.stringify
    local fname = stringify(meta['zotero-bibliography'])
    if fname == '' then
        return nil, 'Name of bibliography file: Is the empty string ("").'
    elseif not fname:match '%.json$' then
        return nil, fname .. ': Does not end with ".json".'
    end
    if not is_path_absolute(fname) then
        fname = get_input_directory() .. PATH_SEP .. fname
    end
    local ok, err = update_bibliography(citekeys, fname)
    if not ok then return nil, err end
    if not meta.bibliography then
        meta.bibliography = fname
    elseif meta.bibliography.tag == 'MetaInlines' then
        meta.bibliography = {stringify(meta.bibliography), fname}
    elseif meta.bibliography.tag == 'MetaList' then
        table.insert(meta.bibliography, fname)
    end
    return meta
end


--- Adds sources to the `references` metadata field.
--
-- Prints an error message to STDERR for
--
--  - every source that cannot be found.
--  - every citation key that is defined more than once.
--
-- @tab citekeys Set of citation keys that should be added, e.g.,
--  `{['name:2019word']=true, ['name2019WordWordWord']=true}`.
-- @tparam pandoc.Meta meta A metadata block.
-- @treturn[1] pandoc.Meta An updated metadata block,
--  with the field `references` added if needed.
-- @treturn[2] nil `nil` if no sources were found or an error occurred.
-- @treturn[2] string An error message, if applicable.
-- @raise See `get_source_csljson`.
function add_references (citekeys, meta)
    if next(citekeys) == nil then return end
    if not meta.references then meta.references = pandoc.MetaList({}) end
    for citekey in pairs(citekeys) do
        local ref, err, errtype = get_source(citekey)
        if ref then
            table.insert(meta.references, ref)
        elseif errtype == 'read_err' then
            return nil, 'Could not retrieve data from Zotero.'
        else
            warn(err)
        end
    end
    local stringify = pandoc.utils.stringify
    local cnt = {}
    for i = 1, #meta.references do
        local id = meta.references[i].id
        if type(id) == 'table' then id = stringify(id) end
        if not cnt[id] then
            cnt[id] = 1
        else
            cnt[id] = cnt[id] + 1
        end
    end
    for citekey, c in pairs(cnt) do
        if c > 1 then
            warn('Citation key "%s": Defined %d times!', citekey, c)
        end
    end
    return meta
end


-- MAIN
-- ====

--- Collects sources and adds bibliographic data to a document.
--
-- Prints messages to STDERR if errors occur.
--
-- See the manual for detais.
--
-- @tparam pandoc.Pandoc doc A document.
-- @treturn[1] pandoc.Pandoc `doc`, but with bibliographic data added.
-- @treturn[2] nil `nil` if nothing was done or an error occurred.
-- @raise See `get_source_csljson`.
function main (doc)
    local citekeys = get_undef_citekeys(doc)
    if next(citekeys) == nil then return end
    for i = 1, 2 do
        local add_sources
        if i == 1 then
            add_sources = add_bibliography
        elseif i == 2 then
            add_sources = add_references
        end
        local ret, err = add_sources(citekeys, doc.meta)
        if ret then
            doc.meta = ret
            return doc
        elseif err then
            warn(err)
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
