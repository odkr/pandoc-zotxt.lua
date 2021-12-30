--- A simple Lua writer for Pandoc that writes LDoc Markdown.
--
-- Only supports the subset of Markdown needed to represent the manual.
--
-- @script ldoc-md.lua
-- @author Odin Kroeger
-- @copyright 2021 Odin Kroeger
-- @license MIT

-- luacheck: allow defined top
-- luacheck: ignore pandoc

if not pandoc.text then pandoc.text = require 'text' end

local len = pandoc.text.len
local rep = string.rep
local format = string.format

local stringify = pandoc.utils.stringify

--- At what column to wrap lines.
local WRAP = 76

--- Functions
-- @section

--- Print an error message to STDERR.
--
-- The message is prefixed with `PANDOC_SCRIPT_FILE .. ': '` and
-- terminated with `\n`. Non-string values are coerced to strings.
--
-- @param ... Messages
local function warn (...)
    -- luacheck: ignore PANDOC_SCRIPT_FILE
    local function write (...) return io.stderr:write(...) end
    local msgs = table.pack(...)
    if msgs.n < 1 then return end
    write(PANDOC_SCRIPT_FILE, ': ')
    for i = 1, msgs.n do write(tostring(msgs[i])) end
    write('\n')
end


--- Indent every line of a string.
--
-- @string str A string.
-- @int n How many columns to indent lines.
-- @treturn A string with indented lines.
local function indent (str, n)
    local ind = {}
    local sp = string.rep(' ', n)
    local i = 0
    for line in str:gmatch '[^\n]*' do
        i = i + 1
        ind[i] = sp .. line .. '\n'
    end
    return table.concat(ind)
end

--- Reflow lines of a string.
--
-- @string str A string.
-- @int n At what column to wrap lines.
-- @treturn string A wrapped string.
local function wrap (str, n)
    local lines = {}
    local i = 0
    local function add (ln)
        i = i + 1
        lines[i] = ln
    end
    for line in str:gmatch '[^\n]*' do
        -- luacheck: ignore wrap
        local ind, pos, rem = line:match '^(%s*)()(.*)'
        local wrap = n - (pos or 1) + 1
        while len(rem) > wrap do
            local ln = rem:sub(1, wrap)
            local eol, sol = ln:match '()%s+()%S*$'
            if not eol then
                add(ind .. ln)
                rem = rem:sub(wrap + 1)
            else
                add(ind .. rem:sub(1, eol - 1))
                rem = rem:sub(sol)
            end
        end
        if not rem:match '^%s*$'
            then add(ind .. rem)
            else add('')
        end
    end
    return table.concat(lines, '\n'):gsub('\n*(\n\n)', '%1')
end


--- Error handling
-- @section

-- Report if a format is unsupported.
setmetatable(_G, {__index = function (_, key)
    warn(key, ': unsupported format.')
    return function () return '' end
end})


--- Elements
-- @section

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
    return indent(s, 4)
end

-- luacheck: ignore DefinitionList
function DefinitionList (t)
    local s = ''
    for _, ds in ipairs(t) do
        for k, vs in pairs(ds) do
            s = s .. format('* `%s`', k)
            local i = 1
            for _, v in pairs(vs) do
                if v ~= '' then
                    v = indent(v, 2)
                    if i == 1 then s = s .. ': ' .. v:gsub('^%s+', '')
                              else s = s .. v
                    end
                    s = s .. '\n'
                    i = i + 1
                end
            end
        end
        s = s .. '\n'
    end
    return s
end

-- luacheck: ignore Doc
function Doc (s, _, _)
    return wrap(s, WRAP)
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
        warn 'LDoc only supports Setext-style headers.'
        return '\n' .. s
    end
end

-- luacheck: ignore Para
function Para (s)
    return s
end

-- luacheck: ignore Plain
Plain = stringify

-- luacheck: ignore SoftBreak
function SoftBreak ()
    return ' '
end

-- luacheck: ignore Span
function Span (s)
    return s
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
