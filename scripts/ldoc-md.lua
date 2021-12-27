--- A simple Lua writer for Pandoc that writes LDoc Markdown.
--
-- It only supports the subset of Markdown that is used by the manual.
--
-- @script ldoc-md.lua
-- @author Odin Kroeger
-- @copyright 2021 Odin Kroeger
-- @license MIT

local len = string.len
local rep = string.rep
local format = string.format

-- luacheck: ignore pandoc
local stringify = pandoc.utils.stringify


-- FUNCTIONS
-- =========

--- Print an error message to STDERR.
--
-- Prefixes the message with `ldoc-md.lua` and ': ', and appends `\n`.
--
-- @param msg The message.
-- @param ... Arguments to that message (think `string.format`).
--  Only applied if `msg` is a `string`.
-- @within Warnings
local function errf (msg, ...)
    io.stderr:write('ldoc-md.lua: ', msg:format(...), '\n')
end

-- Report if a format is unsupported.
setmetatable(_G, {__index = function (_, key)
    errf('%s: unsupported format.', key)
    return function () return '' end
end})


-- ELEMENTS
-- ========

-- luacheck: ignore Blocksep
function Blocksep ()
    return '\n\n'
end

-- luacheck: ignore BulletList
function BulletList (items)
    local ret = ''
    for i = 1, #items do
        ret = ret .. '* ' .. items[i] .. '\n'
    end
    return ret
end

-- luacheck: ignore Code
function Code (s, _)
  return '`' .. s .. '`'
end

-- luacheck: ignore CodeBlock
function CodeBlock (s, _)
    local ret = ''
    for ln in s:gmatch '([^\n]+)' do
        ret = ret .. '    ' .. ln .. '\n'
    end

    return ret
end

-- luacheck: ignore DefinitionList
function DefinitionList (t)
    local s = ''
    for _, ds in ipairs(t) do
        for k, vs in pairs(ds) do
            s = s .. '<h3>' .. k .. '</h3>' .. Blocksep()
            for _, v in pairs(vs) do
                s = s .. v .. Blocksep()
            end
        end
    end
    return s
end

-- luacheck: ignore Doc
function Doc (s, _, _)
    return s
end

-- luacheck: ignore DoubleQuoted
function DoubleQuoted (s)
    return '"' .. s .. '"'
end

-- luacheck: ignore Emph
function Emph (s)
    return '*' .. s .. '*'
end

-- luacheck: ignore LineBreak
function LineBreak ()
    return '\n'
end

-- luacheck: ignore Link
function Link(s, href, title, _)
    if title and title ~= '' then
        return format('[%s](%s "%s")', s, href, title)
    else
        return format('[%s](%s)', s, href)
    end
end

-- luacheck: ignore Header
function Header (level, s, _)
    if level < 3 then
        local c
        if level == 1 then c = '='
                      else c = '-'
        end
        return '\n' .. s .. '\n' .. rep(c, len(s))
    else
        errf 'LDoc only supports Setext-style headers.'
        return '\n' .. s
    end
end

-- luacheck: ignore Para
function Para (s)
    return s
end

-- luacheck: ignore Plain
Plain = stringify

-- This is so that the output can be wrapped with `fold` or `fmt`.
-- luacheck: ignore SoftBreak
function SoftBreak ()
    return ' '
end

-- luacheck: ignore Space
function Space ()
    return ' '
end

-- luacheck: ignore Str
Str = stringify

-- luacheck: ignore Strong
function Strong (s)
    return '**' .. s .. '**'
end

-- luacheck: ignore Table
function Table (_, _, _, headers, rows)
    local ret = ''
    local widths = {}
    if headers then
        for i = 1, #headers do
            widths[i] = len(headers[i])
        end
    end
    if rows then
        for i = 1, #rows do
            local row = rows[i]
            for j = 1, #row do
                local n = len(row[j])
                if not widths[j] or widths[j] < n then widths[j] = n end
            end
        end
    end
    local n = #widths
    if n == 0 then return '' end
    local function add (row)
        for i = 1, n do
            if i == 1 then ret = ret .. '| ' end
            local c = row[i]
            ret =  ret .. c .. rep(' ', widths[i] - len(c))
            if i ~= n then ret = ret .. ' | '
                      else ret = ret .. ' |\n'
            end
        end
    end
    if headers then
        add(headers)
        local sep = {}
        for i = 1, n do
            sep[i] = rep('-', widths[i])
        end
        add(sep)
    end
    if rows then
        for i = 1, #rows do
            add(rows[i])
        end
    end
    return ret
end
