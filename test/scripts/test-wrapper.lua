--- debug-wrapper.lua - A fake Pandoc filter that runs pandoc-zotxt.lua.
--
-- SYNOPSIS
-- --------
--
-- **pandoc** **-L** *debug-wrapper.lua* ...
--
--
-- DESCRIPTION
-- -----------
--
-- Runs pandoc-zotxt.lua, but money-patches it so that URL requests are
-- redirected to canned responses in the filesystem.
--
-- AUTHOR
-- ------
--
-- Odin Kroeger
--
-- @script debug-wrapper.lua
-- @author Odin Kroeger

-- luacheck: allow defined top



--- The path segment separator used by the operating system.
PATH_SEP = package.config:sub(1, 1)

-- A shorthand for joining paths.
local function path_join(...) return table.concat({...}, PATH_SEP) end

--- The directory of this script.
local SCPT_DIR = PANDOC_SCRIPT_FILE:match('(.*)' .. PATH_SEP)

--- The directory of the test suite.
local TEST_DIR = path_join(SCPT_DIR, '..')

--- The repository directory.
local REPO_DIR = path_join(TEST_DIR, '..')

--- The test suite's data directory.
local CAN_DIR = path_join(TEST_DIR, 'cans')

do
    package.path = table.concat({package.path,
        path_join(REPO_DIR, '?.lua'),
        path_join(REPO_DIR, 'share', 'lua', '5.4', '?.lua')
    }, ';')
end

local pancake = require 'pancake'


-- luacheck: push ignore
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
-- luacheck: pop



--- Enable debugging mode.
_G.DEBUG = true

--- Load the module.
local M = require 'pandoc-zotxt'

--- Returns canned responses for URL requests.
--
-- Takes a URL, hashes it using SHA-1, truncates the hash to eight characters,
-- and then returns the content of the file of that name in `CAN_DIR`.
--
-- Also prints the requested URL and the file it serves to STDERR.
--
-- @tparam string url The URL.
-- @treturn[1] string The MIME type.
-- @treturn[1] string The data.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
function M.http_get (url)
    -- luacheck: ignore pandoc
    local hash = pandoc.utils.sha1(url):sub(1, 8)
    local path = pancake.path_join(CAN_DIR, hash)
    pancake.xwarn('@info', 'redirecting <${url}> to ${path}')
    local mt = 'text/plain; charset=utf-8'
    local data, err, errno = pancake.file_read(path)
    if not data then
        if errno == 2 then
            err = string.format('<%s> has not been canned.', url)
        end
        return mt, err
    end
    local hdr, con = pancake.tabulate(pancake.split(data, '\r?\n\r?\n', 2))
    if not hdr or not con then return mt, path .. ': not a can.' end
    for line in hdr:gmatch '[^\n]*' do
        local k, v = line:match '(.-)%s*:%s*(.*)'
        if k and k:lower() == 'content-type' and v then mt = v:lower() end
    end
    return mt, con
end

return M