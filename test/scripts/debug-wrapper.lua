--- debug-wrapper.lua - A fake Pandoc filter that runs pandoc-zotxt.lua.
--
-- # SYNOPSIS
--
--      pandoc -L debug-wrapper.lua
--
--
-- # DESCRIPTION
--
-- Runs pandoc-zotxt.lua, but money-patches it so that URL requests are
-- redirected to canned responses in the filesystem.
--
-- # AUTHOR
--
-- Odin Kroeger
--
-- @script debug-wrapper.lua
-- @author Odin Kroeger

-- luacheck: allow defined top

-- # LIBRARIES

-- luacheck: push ignore
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
-- luacheck: pop

local text = require 'text'


--- The path seperator of the operating system.
PATH_SEP = text.sub(package.config, 1, 1)

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

-- luacheck: globals PANDOC_SCRIPT_FILE
--- The directory of this script.
local SCRIPT_DIR = split_path(PANDOC_SCRIPT_FILE)

--- The directory of the test suite.
local TEST_DIR = table.concat({SCRIPT_DIR, '..'}, PATH_SEP)

--- The location of canned resposes.
local CAN_DIR = table.concat({TEST_DIR, 'can'}, PATH_SEP)

--- The repository directory.
local REPO_DIR = table.concat({TEST_DIR, '..'}, PATH_SEP)

package.path = package.path .. ';' ..
    table.concat({REPO_DIR, 'share', 'lua', '5.3', '?.lua'}, PATH_SEP)

local M = require 'pandoc-zotxt'

--- Returns canned responses for URL requests.
--
-- Takes a URL, hashes it using SHA-1, truncates the hash to eight characters,
-- and then returns the content of the file of that name in `CAN_DIR`.
--
-- Also prints the requested URL and the file it serves to STDERR.
--
-- @tparam string url The URL.
-- @treturn[1] string The data.
-- @treturn[2] string An error message (not `nil`) if an error occurred.
function M.read_url (url)
    -- luacheck: ignore pandoc
    local hash = pandoc.utils.sha1(url):sub(1, 8)
    M.warn('%s -> %s', url, hash)
    local fname, f, data, ok, err
    fname = CAN_DIR .. PATH_SEP .. hash
    f, err = io.open(fname, 'r')
    if not f then return err end
    data, err = f:read('a')
    if not data then return err end
    ok, err = f:close()
    if not ok then return err end
    return data
end

return M