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

local stringify = pandoc.utils.stringify


-- Report an error if a format is unsupported.
setmetatable(_G, {__index = function (_, key)
    io.stderr:write(format('%s: unsupported format.\n', key))
    return function () return '' end
end})

Str = stringify
Plain = stringify

function Blocksep ()
    return '\n\n'
end

function BulletList (items)
    local ret = ''
    for i = 1, #items do
        ret = ret .. '* ' .. items[i] .. '\n'
    end
    return ret
end

function Code (s, _)
  return '`' .. s .. '`'
end

function CodeBlock (s, _)
    local ret = ''
    for ln in s:gmatch '([^\n]+)' do
        ret = ret .. '    ' .. ln .. '\n'
    end

    return ret
end

function Doc (s, _, _)
    return s
end

function DoubleQuoted (s)
    return '"' .. s .. '"'
end

function Emph (s)
    return '*' .. s .. '*'
end

function LineBreak ()
    return '\n'
end

function Link(s, href, title, _)
    if title and title ~= '' then
        return format('[%s](%s "%s")', s, href, title)
    else
        return format('[%s](%s)', s, href)
    end
end

function Header (level, s, attr)
    if level < 3 then
        local c
        if level == 1 then c = '='
                      else c = '-'
        end
        return '\n' .. s .. '\n' .. rep(c, len(s))
    else
        return '\n' .. rep('#', level) .. ' ' .. s
    end
end

function Para (s)
    return s
end

function SoftBreak ()
    return '\n'
end

function Space ()
    return ' '
end

function Strong (s)
    return '**' .. s .. '**'
end

function Table (_, aligns, _, headers, rows)
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
                local len = len(row[j])
                if not widths[j] or widths[j] < len then widths[j] = len end
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
