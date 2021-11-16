--- unit-tests.lua - A fake Pandoc filter that runs units for pandoc-zotxt.lua.
--
-- SYNOPSIS
-- --------
--
-- **pandoc** **-L** *unit-tests.lua* -o /dev/null FILE
--
--
-- DESCRIPTION
-- -----------
--
-- A fake Pandoc filter that runs units for for pandoc-zotxt.lua.
-- Which tests are run is goverend by the `tests` metadata field in FILE.
-- This field is passed to lu.LuaUnit.run. If `tests` is not set,
-- runs all tests.
--
--
-- SEE ALSO
-- --------
--
-- <https://luaunit.readthedocs.io/>
--
-- AUTHOR
-- ------
--
-- Copyright 2019, 2020 Odin Kroeger
--
--
-- LICENSE
-- -------
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
--
-- @script unit-tests.lua
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020 Odin Kroeger
-- @license MIT

-- luacheck: allow defined top, no global

-- LIBRARIES
-- =========

-- luacheck: push ignore
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
local stringify = pandoc.utils.stringify
-- luacheck: pop


local MetaInlines = pandoc.MetaInlines
local Null = pandoc.Null
local Para = pandoc.Para
local Space = pandoc.Space
local Str = pandoc.Str


-- LIBRARIES
-- =========

--- The path seperator of the operating system.
PATH_SEP = package.config:sub(1, 1)

do
    -- Expression to split a path into a directory and a filename part.
    local split_e = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
    -- Expressions that sanitise directory paths.
    local san_es = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove './' at the beginning of paths.
        {'^%.' .. PATH_SEP, ''},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'}
    }

    --- Split a file's path into a directory and a filename part.
    --
    -- @string path The file's path.
    -- @treturn[1] string The directory the file is in.
    -- @treturn[1] string The file's name.
    -- @treturn[2] nil `nil` if `path` is the empty string ('').
    -- @treturn[2] string An error message.
    -- @raise An error if `path` is not a `string`.
    function path_split (path)
        assert(type(path) == 'string', 'Path is not a string.')
        if path == '' then return nil, 'Path is the empty string ("").' end
        local dir, fname = path:match(split_e)
        for i = 1, #san_es do dir = dir:gsub(table.unpack(san_es[i])) end
        if     dir == ''   then dir = '.'
        elseif fname == '' then fname = '.' end
        assert(dir ~= '')
        assert(fname ~= '')
        return dir, fname
    end
end


-- luacheck: globals PANDOC_SCRIPT_FILE
--- The directory of this script.
local SCPT_DIR = path_split(PANDOC_SCRIPT_FILE)

--- The directory of the test suite.
local TEST_DIR = SCPT_DIR .. PATH_SEP .. '..'

--- The test suite's data directory.
local DATA_DIR = TEST_DIR .. PATH_SEP .. 'data'

--- The test suite's tempory directory.
local TMP_DIR = TEST_DIR .. PATH_SEP .. 'tmp'

--- The repository directory.
local REPO_DIR = TEST_DIR .. PATH_SEP .. '..'

do
    package.path = package.path ..
            ';' .. SCPT_DIR .. PATH_SEP .. '?.lua'
    local concat = table.concat
    local versions = {'5.4', '5.3'}
    for i = 1, #versions do
        local vers = versions[i]
        package.path = package.path ..
            ';' .. concat({REPO_DIR, 'share', 'lua', vers, '?.lua'}, PATH_SEP)
    end
end

local lu = require 'luaunit'
local json = require 'lunajson'
local yaml = require 'tinyyaml'

local M = require 'debug-wrapper'


-- CONSTANTS
-- =========

--- Bibliographic data in CSL to compare data retrieved via zotxt to.
-- luacheck: globals ZOTXT_CSL
ZOTXT_CSL = {
    id = 'haslanger2012ResistingRealitySocial',
    type = 'book',
    author = {{family = 'Haslanger', given = 'Sally'}},
    title = 'Resisting Reality: Social Construction and Social Critique',
    ['title-short'] = 'Resisting Reality',
    publisher = 'Oxford University Press', ['publisher-place'] = 'Oxford',
    issued = {['date-parts'] = {{'2012'}}},
    isbn = '978-0-19-989262-4'
}

--- Bibliographic data as returned from a CSL YAML bibliography file.
ZOTXT_YAML = {
    {
        author={{family="Crenshaw", given="Kimberlé"}},
        id="crenshaw1989DemarginalizingIntersectionRace",
        issued={["date-parts"]={{'1989'}}},
        title="Demarginalizing the intersection of race and sex",
        type="paper"
    }
}

--- Bibliographic data as stored in the metadata block.
if pandoc.types and PANDOC_VERSION <= {2, 14} then
    ZOTXT_META = {
        {
            author={{text="Kimberlé"}, {}, {text="Crenshaw"}},
            id={{text="crenshaw1989DemarginalizingIntersectionRace"}},
            issued={["date-parts"]={{{{text="1989"}}}}},
            title={
                {text="Demarginalizing"},
                {},
                {text="the"},
                {},
                {text="intersection"},
                {},
                {text="of"},
                {},
                {text="race"},
                {},
                {text="and"},
                {},
                {text="sex"}
            },
            type={{text="paper"}}
        }
    }
else
    ZOTXT_META = {
        {
            author={Str "Kimberlé", Space(), Str "Crenshaw"},
            id={Str "crenshaw1989DemarginalizingIntersectionRace"},
            issued={["date-parts"]={{{Str "1989"}}}},
            title={
                Str "Demarginalizing",
                Space(),
                Str "the",
                Space(),
                Str "intersection",
                Space(),
                Str "of",
                Space(),
                Str "race",
                Space(),
                Str "and",
                Space(),
                Str "sex"
            },
            type={Str "paper"}
        }
    }
end

--- Bibliographic data as JSON string.
ZOTXT_JSON = '[\n  ' ..
    '{"id":"haslanger2012ResistingRealitySocial",' ..
    '"author":[{"family":"Haslanger","given":"Sally"}],' ..
    '"isbn":"978-0-19-989262-4",' ..
    '"issued":{"date-parts":[[2012]]},' ..
    '"publisher":"Oxford University Press",' ..
    '"publisher-place":"Oxford",' ..
    '"title":"Resisting Reality: Social Construction and Social Critique",' ..
    '"title-short":"Resisting Reality",' ..
    '"type":"book"}' ..
    '\n]\n'

--- API key for the Zotero Web API.
ZOTWEB_API_KEY = 'MO2GHxbkLnWgCqPtpoewgwIl'

--- Bibliographic data as returned by the Zotero Web API.
ZOTWEB_CSL = {
    ISBN = '978-0-19-989262-4',
    author = {{family = 'Haslanger', given = 'Sally'}},
    ['event-place'] = 'Oxford',
    id = 'haslanger2012ResistingRealitySocial',
    issued = {['date-parts'] = {{'2012'}}},
    note = 'citation key: haslanger2012ResistingRealitySocial',
    publisher = 'Oxford University Press',
    ['publisher-place'] = 'Oxford',
    shortTitle = 'Resisting Reality',
    title = 'Resisting Reality: Social Construction and Social Critique',
    type = 'book'
}

-- FUNCTIONS
-- =========

--- Copy a data tree.
--
-- Handles metatables, recursive structures, tables as keys, and
-- avoids the `__pairs` and `__newindex` metamethods.
-- Copies are deep.
--
-- @param data Arbitrary data.
-- @return A deep copy of `data`.
--
-- @usage
--      > x = {1, 2, 3}
--      > y = {x, 4}
--      > c = copy(y)
--      > table.insert(x, 4)
--      > table.unpack(c[1])
--      1       2       3
function copy (data, s)
    -- Borrows from:
    -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
    -- * <http://lua-users.org/wiki/CopyTable>
    if type(data) ~= 'table' then return data end
    if s and s[data] then return s[data] end
    local copy = copy
    local ret = setmetatable({}, getmetatable(data))
    s = s or {}
    s[data] = ret
    for k, v in next, data, nil do
        rawset(ret, copy(k, s), copy(v, s))
    end
    return ret
end


--- Read a Markdown file.
--
-- @tparam string fname Name of the file.
-- @return The parsed data, `nil` if an error occurred.
-- @treturn string An error message, if applicable.
-- @treturn number An error number. Positive numbers are OS error numbers.
--
-- May raise an uncatchable error.
function read_md_file (fname)
    assert(fname, 'no filename given')
    assert(fname ~= '', 'given filename is the empty string')
    local f, md, ok, err, errno
    f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    md, err, errno = f:read('a')
    if not md then return nil, err, errno end
    ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return pandoc.read(md, 'markdown')
end


--- Read a JSON file.
--
-- @string fname The name of the file.
-- @return[1] The parsed data.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--  Positive numbers are OS error numbers,
--  negative numbers indicate a YAML decoding error.
function read_json_file (fname)
    local str, err, errno = M.file_read(fname)
    if not str then return nil, err, errno end
    local ok, data = pcall(json.decode, str)
    if not ok then return nil, fname .. ': JSON decoding error: ' .. data, -1 end
    return data
end


do
    function conv (data)
        if type(data) ~= 'number' then return data end
        return tostring(math.floor(data))
    end

    --- Recursively convert numbers to strings.
    --
    -- Also converts floating point numbers to integers. This is needed
    -- because all numbers are floating point numbers in JSON, but some
    -- versions of Pandoc expect integers.
    --
    -- @tab data The data.
    -- @return A copy of `data` with numbers converted to strings.
    -- @raise An error if the data is nested too deeply.
    function rconv_nums_to_strs (data)
        return M.rmap(conv, data)
    end
end


-- TESTS
-- =====

-- File I/O
-- --------

function test_path_sanitise ()
    local invalid = {nil, false, '', 0, {}, function () end}

    for _, v in ipairs(invalid) do
        lu.assert_error(M.path_sanitise, v)
    end

    local ok, err = M.path_split('')
    lu.assert_nil(ok)
    lu.assert_not_nil(err)

    local tests = {
        ['.']                   = '.',
        ['..']                  = '..',
        ['/']                   = '/',
        ['//']                  = '/',
        ['/////////']           = '/',
        ['/.//////']            = '/',
        ['/.////.//']           = '/',
        ['/.//..//.//']         = '/..',
        ['/.//..//.//../']      = '/../..',
        ['a']                   = 'a',
        ['./a']                 = 'a',
        ['../a']                = '../a',
        ['/a']                  = '/a',
        ['//a']                 = '/a',
        ['//////////a']         = '/a',
        ['/.//////a']           = '/a',
        ['/.////.//a']          = '/a',
        ['/.//..//.//a']        = '/../a',
        ['/.//..//.//../a']     = '/../../a',
        ['a/b']                 = 'a/b',
        ['./a/b']               = 'a/b',
        ['../a/b']              = '../a/b',
        ['/a/b']                = '/a/b',
        ['//a/b']               = '/a/b',
        ['///////a/b']          = '/a/b',
        ['/.//////a/b']         = '/a/b',
        ['/.////.//a/b']        = '/a/b',
        ['/.//..//.//a/b']      = '/../a/b',
        ['/.//..//.//../a/b']   = '/../../a/b',
        ['/a/b/c/d']            = '/a/b/c/d',
        ['a/b/c/d']             = 'a/b/c/d',
        ['a/../.././c/d']       = 'a/../../c/d'
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.path_prettify(k), v)
    end
end

function test_path_split ()
    local invalid = {nil, false, 0, {}, function () end}

    for _, v in ipairs(invalid) do
        lu.assert_error(M.path_split, v)
    end

    local ok, err = M.path_split('')
    lu.assert_nil(ok)
    lu.assert_not_nil(err)

    local tests = {
        ['.']                   = {'.',         '.' },
        ['..']                  = {'.',         '..'},
        ['/']                   = {'/',         '.' },
        ['//']                  = {'/',         '.' },
        ['/////////']           = {'/',         '.' },
        ['/.//////']            = {'/',         '.' },
        ['/.////.//']           = {'/',         '.' },
        ['/.//..//.//']         = {'/..',       '.' },
        ['/.//..//.//../']      = {'/../..',    '.' },
        ['a']                   = {'.',         'a' },
        ['./a']                 = {'.',         'a' },
        ['../a']                = {'..',        'a' },
        ['/a']                  = {'/',         'a' },
        ['//a']                 = {'/',         'a' },
        ['//////////a']         = {'/',         'a' },
        ['/.//////a']           = {'/',         'a' },
        ['/.////.//a']          = {'/',         'a' },
        ['/.//..//.//a']        = {'/..',       'a' },
        ['/.//..//.//../a']     = {'/../..',    'a' },
        ['a/b']                 = {'a',         'b' },
        ['./a/b']               = {'a',         'b' },
        ['../a/b']              = {'../a',      'b' },
        ['/a/b']                = {'/a',        'b' },
        ['//a/b']               = {'/a',        'b' },
        ['///////a/b']          = {'/a',        'b' },
        ['/.//////a/b']         = {'/a',        'b' },
        ['/.////.//a/b']        = {'/a',        'b' },
        ['/.//..//.//a/b']      = {'/../a',     'b' },
        ['/.//..//.//../a/b']   = {'/../../a',  'b' },
        ['/a/b/c/d']            = {'/a/b/c',    'd' },
        ['a/b/c/d']             = {'a/b/c',     'd' },
        ['a/../.././c/d']       = {'a/../../c', 'd' }
}

    for k, v in pairs(tests) do
        local dir, fname = M.path_split(k)
        lu.assert_equals(dir, v[1])
        lu.assert_equals(fname, v[2])
    end
end


function test_path_join ()
    local invalid = {nil, false, 0, '', {}, function () end}

    for _, v in ipairs(invalid) do
        lu.assert_error(M.path_join, v)
    end

    lu.assert_error(M.path_join)
    lu.assert_error(M.path_join, 'a', '', 'b')

    lu.assert_equals(M.path_join('a', 'b'), 'a' .. M.PATH_SEP .. 'b')
    lu.assert_equals(M.path_join('a', M.PATH_SEP .. 'b'),
                     'a' .. M.PATH_SEP .. 'b')
    lu.assert_equals(M.path_join('a' .. M.PATH_SEP, 'b'),
                     'a' .. M.PATH_SEP .. 'b')
end

function test_path_is_abs ()
    local original_path_sep = M.PATH_SEP
    lu.assert_error(M.path_is_abs)

    local invalid = {nil, false, 0, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.path_is_abs, {v})
    end

    M.PATH_SEP = '\\'
    local tests = {
        ['\\']          = true,
        ['C:\\']        = true,
        ['[:\\']        = true,
        ['\\test']      = true,
        ['test']        = false,
        ['test\\test']  = false,
        ['/']           = false,
        ['/test']       = false,
        ['test/test']   = false
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.path_is_abs(k), v)
    end

    M.PATH_SEP = '/'
    tests = {
        ['\\']          = false,
        ['C:\\']        = false,
        ['[:\\']        = false,
        ['\\test']      = false,
        ['test']        = false,
        ['test\\test']  = false,
        ['/']           = true,
        ['/test']       = true,
        ['test/test']   = false
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.path_is_abs(k), v)
    end

    M.PATH_SEP = original_path_sep
end

function test_path_prettify ()
    lu.assert_error(M.path_prettify)

    local invalid = {nil, false, 0, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.path_prettify, v)
    end

    if M.PATH_SEP ~= '/' then return end
    local home = os.getenv('HOME')

    local tests = {
        [home .. 'x'] = home .. 'x',
        [M.path_join(home, 'test')] = '~/test'
    }

    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        local wd = pandoc.system.get_working_directory()
        local home_wd = M.path_prettify(wd)
        lu.assert_not_nil(home_wd)
        lu.assert_not_equals(home_wd, '')
        tests[M.path_join(wd, 'test')] = 'test'
        tests[M.path_join(wd .. 'test')] = home_wd .. 'test'
    end

    for k, v in pairs(tests) do
        lu.assert_equals(M.path_prettify(k), v)
    end
end

function test_wd ()
    lu.assert_equals(M.wd(), '.')
end

function test_file_exists ()
    lu.assert_error(M.file_exists)

    local invalid = {nil, false, 0, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.file_exists, v)
    end

    lu.assert_true(M.file_exists(PANDOC_SCRIPT_FILE))
    local ok, _, errno = M.file_exists('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_equals(errno, 2)
end

function test_file_read ()
    local invalid = {nil, false, {}}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.file_read, v)
    end

    local str, ok, err, errno
    ok, err, errno = M.file_read('')
    lu.assert_nil(ok)
    lu.assert_not_nil(err)
    lu.assert_equals(errno, 2)

    ok, err, errno = M.file_read('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = M.path_join(DATA_DIR, 'bibliography.json')
    str, err, errno = M.file_read(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(str)
    lu.assert_nil(errno)
    lu.assert_equals(str, ZOTXT_JSON)
end

function test_file_write ()
    local invalid = {nil, false, 0, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.file_read, nil, v)
    end

    local data, ok, err, errno

    ok, err, errno = M.file_read('')
    lu.assert_nil(ok)
    lu.assert_not_nil(err)
    lu.assert_equals(errno, 2)

    ok, err, errno = M.file_read('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = M.path_join(TMP_DIR, 'file')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    ok, err, errno = M.file_write(fname, ZOTXT_JSON)
    lu.assert_nil(err)
    lu.assert_true(ok)
    lu.assert_nil(errno)

    data, err, errno = M.file_read(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)

    lu.assert_equals(data, ZOTXT_JSON)

    ok, err = M.file_write(fname, 'a', 'b', 'c')
    if not ok then error(err) end
    data, err = M.file_read(fname)
    if not data then error(err) end
    lu.assert_equals(data, 'abc')
end

function test_tmp_fname ()
    local invalid = {false, 0, {}, '', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.tmp_fname, nil, v)
        lu.assert_error(M.tmp_fname, v, nil)
    end

    local tests = {
        [{nil, nil}] = '^pdz%-%w%w%w%w%w%w$',
        [{nil, 'test_XXXXXXXXX'}] = '^test_%w%w%w%w%w%w%w%w%w$',
        [{'/tmp', nil}] = '^/tmp' .. M.PATH_SEP .. 'pdz%-%w%w%w%w%w%w$',
        [{'/tmp', 'XXXXXXX'}] = '^/tmp' .. M.PATH_SEP .. '%w%w%w%w%w%w%w$'
    }

    for k, v in pairs(tests) do
        local fname, err = M.tmp_fname(table.unpack(k))
        if not fname then error(err) end
        lu.assert_str_matches(fname, v)
    end

    local f1 = M.tmp_fname()
    local f2 = M.tmp_fname()
    lu.assert_not_equals(f1, f2)
end

function test_with_tmp_file ()
    local invalid = {false, 0, {}, '', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.with_tmp_file, nil, v)
        lu.assert_error(M.with_tmp_file, v, nil)
    end

    local tmp_file_copy
    M.with_tmp_file(nil, nil, function (tmp_file)
        tmp_file_copy = tmp_file
        return os.remove(tmp_file)
    end)

    lu.assert_not_nil(tmp_file_copy)
    lu.assert_nil(M.file_exists(tmp_file_copy))

    tmp_file_copy = nil
    pcall(M.with_tmp_file, nil, nil, function (tmp_file)
        tmp_file_copy = tmp_file
        error 'test'
    end)

    lu.assert_not_nil(tmp_file_copy)
    lu.assert_nil(M.file_exists(tmp_file_copy))
end


-- Warnings
-- --------

function test_printf ()
    lu.assert_error(M.printf, 99)
end


-- Higher-order functions
-- ----------------------

function test_do_after ()
    local invalid = {nil, false, 0, {}, ''}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.do_after, function () end, v)
        lu.assert_error(M.do_after, v, function () end)
    end

    local vs
    local function cleanup (...)
        vs = table.pack(...)
    end

    vs = nil
    M.do_after(cleanup, function ()
        return 1, 2, 3
    end)
    lu.assert_equals(vs, {true, 1, 2, 3, n = 4})

    vs = nil
    pcall(M.do_after, cleanup, function ()
        error 'err'
    end)
    lu.assert_equals(vs[1], false)
    lu.assert_str_contains(tostring(vs[2]), 'err')
    lu.assert_equals(vs.n, 2)
end


-- Table manipulation
-- ------------------

function test_keys ()
    local invalid = {nil, 0, 'string', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.keys, v)
    end

    local tests = {
        [{}] = {{}, 0},
        [{1, 2, 3}] = {{1, 2, 3}, 3},
        [{a=1, b=2, c=3}] = {{'a', 'b', 'c'}, 3},
        [{a=1, [{}]=2}] = {{'a', {}}, 2},
        [{[{}]='a'}] = {{{}}, 1},
        [{[{}]='a', [false]='b'}] = {{{}, false}, 2}
    }

    for k, v in pairs(tests) do
        local ks, n = M.keys(k)
        lu.assert_items_equals(ks, v[1])
        lu.assert_equals(n, v[2])
    end
end

function test_copy ()
    -- Test simple copies.
    local simple = {
        nil, false, true, 0, 1, '', 'test', {},
        {1, 2, 3},
        {5, 2, 3, 9},
        {1, 2, 3, 'b', true, false},
        {1, 2, 'x', false, 3, true},
        (function ()
            local t = {}
            for i = 1, 1000 do t[i] = i end
            return t
            end)(),
        {true},
        {false},
        {true, false, true},
        {'a', 'b', 'c'},
        (function ()
            local t = {}
            for i = 33, 126 do t[i-32] = string.char(i) end
            return t
            end)(),
    }

    for _, v in ipairs(simple) do
        local t = M.copy(v)
        lu.assert_items_equals(t, v)
    end

    -- Test a nested table.
    local t = {1, 2, 3, {1, 2, 3, {4, 5, 6}}}
    local c = copy(t)
    lu.assert_items_equals(c, t)

    -- Test a self-referential table.
    t = {1, 2, 3}
    t.t = t
    c = copy(t)
    lu.assert_items_equals(c, t)

    -- Test a table that has another table as key.
    t = {1, 2, 3}
    local u = {1, 2, 3, {4, 5, 6}}
    u[t] = 7
    c = copy(u)
    lu.assert_items_equals(c, u)

    -- Test a table that overrides `__pairs`.
    local single = {__pairs = function ()
        return function () end
    end}
    t = setmetatable({1, 2, 3}, single)
    c = copy(t)
    lu.assert_items_equals(c, t)

    -- Test a table that does all of this.
    t = setmetatable({1, 2, 3, {4, 5}}, single)
    u = {1, 2, 3, {4, 5, 6}}
    t[u] = {1, 2, 3, {4, 5}}
    t.t = t
    c = copy(t)
    lu.assert_items_equals(c, t)
end

function test_rmap ()
    local invalid = {nil, true, 0, 'string', {}}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.rmap, v, 0)
    end

    local function id (...) return ... end
    local function nilify () return nil end

    local tests = {
        {{}}, 1, ZOTXT_CSL, ZOTXT_JSON, ZOTXT_YAML, ZOTXT_META,
        false, {['false']=1}, {{{[false]=true}, 0}}, 'string'
    }

    for _, v in ipairs(tests) do
        lu.assert_equals(M.rmap(id, v), v)
        lu.assert_equals(M.rmap(nilify, v), v)
    end

    local function inc (v)
        if type(v) ~= 'number' then return v end
        return v + 1
    end

    tests = {
        [{{}}] = {{}},
        [1] = 2,
        [false] = false,
        [{['false'] = 1}] = {['false'] = 2},
        [{{{[false] = true}, 0}}] = {{{[false] = true}, 1}},
        ['string'] = 'string',
        [{1}] = {2},
        [{2}] = {3},
        [{1, {2}}] = {2, {3}},
        [{dont = 3, 3}] = {dont = 4, 4}
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.rmap(inc, k), v)
    end
end

function test_lower_keys ()
    local invalid = {nil, 0, 'string', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.lower_keys, v)
    end

    local tests = {
        [{}] = {},
        [{1, 2, 3}] = {1, 2, 3},
        [{A=1, b=2, C=3}] = {a=1, b=2, c=3},
        [{nil}] = {nil},
        [{A=1, B={C=2, D=3}}] = {a=1, b={c=2, d=3}},
        [{A=1, B={C=2, [false]=3}}] = {a=1, b={c=2, [false]=3}}
    }

    for k, v in pairs(tests) do
        lu.assert_items_equals(M.lower_keys(k), v)
    end
end

function test_sorted_pairs ()
    local invalid = {nil, 0, 'string', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.sorted_pairs, v)
    end

    local unsorted = {c=3, F=9, another=1}
    local sorted = {'F', 'another', 'c'}
    local i = 0
    for k, v in M.sorted_pairs(unsorted) do
        i = i + 1
        lu.assert_equals(k, sorted[i])
        lu.assert_equals(v, unsorted[k])
    end

    local function rev (a, b) return b < a end
    unsorted = {c=3, F=9, another=1}
    sorted = {'c', 'another', 'F'}
    i = 0
    for k, v in M.sorted_pairs(unsorted, rev) do
        i = i + 1
        lu.assert_equals(k, sorted[i])
        lu.assert_equals(v, unsorted[k])
    end
end


-- Converters
-- ----------

function test_esc_md ()
    local invalid = {nil, 0, false, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.esc_md, v)
    end

    local tests = {
        [''] = '',
        ['\\'] = '\\\\',
        ['\\\\'] = '\\\\\\',
        ['*'] = '*',
        [' *'] = ' *',
        ['* '] = '* ',
        [' * '] = ' * ',
        ['**'] = '**',
        ['*text'] = '\\*text',
        ['**text'] = '\\*\\*text',
        ['***text'] = '\\*\\*\\*text',
        ['****text'] = '\\*\\*\\*\\*text',
        ['* text'] = '* text',
        ['** text'] = '** text',
        ['*** text'] = '*** text',
        ['**** text'] = '**** text',
        ['*text*'] = '\\*text*',
        ['**text**'] = '\\*\\*text**',
        ['***text***'] = '\\*\\*\\*text***',
        ['****text****'] = '\\*\\*\\*\\*text****',
        ['*text *'] = '\\*text *',
        ['**text **'] = '\\*\\*text **',
        ['***text ***'] = '\\*\\*\\*text ***',
        ['****text ****'] = '\\*\\*\\*\\*text ****',
        ['**text*'] = '\\*\\*text*',
        ['*text**'] = '\\*text**',
        ['**text *'] = '\\*\\*text *',
        ['*text **'] = '\\*text **',
        ['a*b*c'] = 'a\\*b\\*c',
        ['***a*****b**'] = '\\*\\*\\*a\\*\\*\\*\\*\\*b**',
        ['*a**b*'] = '\\*a\\*\\*b*',
        ['***my**text*'] = '\\*\\*\\*my\\*\\*text*',
        ['***my*text**'] = '\\*\\*\\*my\\*text**',
        ['*my**text***'] = '\\*my\\*\\*text***',
        ['**my*text***'] = '\\*\\*my\\*text***',
        ['_'] = '_',
        [' _'] = ' _',
        ['_ '] = '_ ',
        [' _ '] = ' _ ',
        ['__'] = '__',
        ['_text'] = '\\_text',
        ['__text'] = '\\_\\_text',
        ['___text'] = '\\_\\_\\_text',
        ['____text'] = '\\_\\_\\_\\_text',
        ['_ text'] = '_ text',
        ['__ text'] = '__ text',
        ['___ text'] = '___ text',
        ['____ text'] = '____ text',
        ['_text_'] = '\\_text_',
        ['__text__'] = '\\_\\_text__',
        ['___text___'] = '\\_\\_\\_text___',
        ['____text____'] = '\\_\\_\\_\\_text____',
        ['_text _'] = '\\_text _',
        ['__text __'] = '\\_\\_text __',
        ['___text ___'] = '\\_\\_\\_text ___',
        ['____text ____'] = '\\_\\_\\_\\_text ____',
        ['__text_'] = '\\_\\_text_',
        ['_text__'] = '\\_text__',
        ['__text _'] = '\\_\\_text _',
        ['_text __'] = '\\_text __',
        ['___my__text_'] = '\\_\\_\\_my\\_\\_text_',
        ['___my_text__'] = '\\_\\_\\_my\\_text__',
        ['_my__text___'] = '\\_my\\_\\_text___',
        ['__my_text___'] = '\\_\\_my\\_text___',
        ['a_b_c'] = 'a\\_b\\_c',
        ['___a_____b__'] = '\\_\\_\\_a\\_\\_\\_\\_\\_b__',
        ['_a__b_'] = '\\_a\\_\\_b_',
        ['^'] = '^',
        ['^^'] = '\\^\\^',
        ['^^^'] = '\\^\\^\\^',
        ['^x'] = '^x',
        ['x^'] = 'x^',
        ['^x^'] = '\\^x\\^',
        ['^x#x^'] = '\\^x#x\\^',
        ['^^x^'] = '\\^\\^x\\^',
        ['^^^x^'] = '\\^\\^\\^x\\^',
        ['^x^^^'] = '\\^x\\^\\^\\^',
        ['^x x^'] = '^x x^',
        ['~'] = '~',
        ['~~'] = '~~',
        ['~~~'] = '~~~',
        ['~x'] = '~x',
        ['x~'] = 'x~',
        ['~x~'] = '\\~x\\~',
        ['~x#x~'] = '\\~x#x\\~',
        ['~~x~'] = '\\~\\~x\\~',
        ['~~~x~'] = '\\~\\~\\~x\\~',
        ['~x~~~'] = '\\~x\\~\\~\\~',
        ['~x x~'] = '~x x~',
        ['['] = '[',
        ['[['] = '[[',
        ['[[['] = '[[[',
        [']'] = ']',
        [']]'] = ']]',
        [']]]'] = ']]]',
        ['[]'] = '[]',
        ['[text]'] = '[text]',
        ['[text]-'] = '[text]-',
        ['[]()'] = '\\[\\]()',
        ['[]{}'] = '\\[\\]{}',
        ['[text](link)'] = '\\[text\\](link)',
        ['[text]{.class}'] = '\\[text\\]{.class}',
        ['[**E**[*x*~*i*~]]{.class}'] = '\\[\\*\\*E\\*\\*[\\*x\\*\\~\\*i\\*\\~]\\]{.class}',
        ['[***My*Name**]{style="small-caps"}'] = '\\[\\*\\*\\*My\\*Name\\*\\*\\]{style="small-caps"}',
        ['*my*~i~ is [more]{.complex}^'] = '\\*my\\*\\~i\\~ is \\[more\\]{.complex}^',
        ['yet **another**~*test*~^a^ [b]{.c}'] = 'yet \\*\\*another\\*\\*\\~\\*test\\*\\~\\^a\\^ \\[b\\]{.c}'
    }

    for i, o in pairs(tests) do
        local ret = M.esc_md(i)
        lu.assert_equals(ret, o)
        -- luacheck: ignore ret
        local doc = pandoc.read(ret, 'markdown-smart')
        lu.assert_not_nil(doc)
        if  doc.blocks[1]        and
            not i:match '^%s'    and
            not i:match '%s$'    and
            not i:match '^%s*%*' and
            not i:match '\\'
        then
            lu.assert_equals(i, stringify(doc.blocks[1].content))
        end
    end
end

function test_html_to_md ()
    local pt = {nil, 0, false, {}, function () end}
    for _, v in ipairs(pt) do
        lu.assert_equals(M.html_to_md(v), v)
    end

    local tests = {
        [''] = '',
        ['test'] = 'test',
        ['<i>test</i>'] = '*test*',
        ['<b>test</b>'] = '**test**',
        ['<b><i>test</i></b>'] = '***test***',
        ['<i><b>test</b></i>'] = '***test***',
        ['<sc>test</sc>'] = '[test]{style="font-variant: small-caps"}',
        ['<span style="font-variant: small-caps">test</span>'] =
            '[test]{style="font-variant: small-caps"}',
        ['<sub>x</sub>'] = '~x~',
        ['<sup>x</sup>'] = '^x^',
        ['<span>test</span>'] = 'test',
        ['<span id="test">test</span>'] = '[test]{#test}',
        ['<span class="nocase">test</span>'] = '[test]{.nocase}',
        ['<span class="test">test</span>'] = '[test]{.test}',
        ['<span class="a b c">test</span>'] = '[test]{.a .b .c}',
        ['<span style="test">test</span>'] = '[test]{style="test"}',
        ['<span style="test" data-test="test">test</span>'] =
            '[test]{style="test" test="test"}',
        ['<i><sc>test</sc></i>'] = '*[test]{style="font-variant: small-caps"}*',
        ['<b><sc>test</sc><sub>2</sub></b>'] =
            '**[test]{style="font-variant: small-caps"}~2~**',
        ['<sc><b>[**E**[*x*~*i*~]]{.class}</b><sup>x</sup></sc>'] =
            '[**\\[\\*\\*E\\*\\*[\\*x\\*\\~\\*i\\*\\~]\\]{.class}**^x^]{style="font-variant: small-caps"}',
        ['<i>**test**</i>'] = '*\\*\\*test***',
        ['<b>**test**</b>'] = '**\\*\\*test****',
        ['<span class="test">*test*~2~</span>'] = '[\\*test\\*\\~2\\~]{.test}',
        ['<span style="font-variant: small-caps">test~x~*!*</span>'] =
            '[test\\~x\\~\\*!*]{style="font-variant: small-caps"}',
        ['<span class="nocase"><i>*test*</i><sc>**X**</sc></span>'] =
            '[*\\*test**[\\*\\*X**]{style="font-variant: small-caps"}]{.nocase}',
    }

    for i, o in pairs(tests) do
        lu.assert_equals(M.html_to_md(i), o)
    end
end

function test_markdownify ()
    local invalid = {nil, true, 1, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.markdownify, v)
    end

    local tests = {
        '' ,'test',
        '*test*', '**test**', '***test***',
        '^test^', '~test~',
        '[test]{.test}',
        '[*test*^2^]{.nocase}',
        '***test***^[ABC]{.class}^'
    }

    for i = 1, #tests do
        local md = tests[i]
        local conv = M.markdownify(pandoc.read(md))
        lu.assert_true(conv == md or conv == '\\' .. md)
    end
end

function test_yamlify ()
    local invalid = {nil, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.yamlify, v)
    end

    invalid = {nil, 3.3, 'x', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.yamlify, 'test', v)
    end

    invalid = {nil, 3, 'x', {},
        {[{}] = 0}, [function () end] = 0, {test = function () end}}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.yamlify, 'test', nil, v)
    end

    lu.assert_equals(M.yamlify(3), '3')
    lu.assert_equals(M.yamlify('test'), 'test')
    lu.assert_equals(M.yamlify({'test'}), '- test')
    lu.assert_equals(M.yamlify('test test'), '"test test"')
    lu.assert_equals(M.yamlify({['test test'] = 0}), '"test test": 0')
    lu.assert_equals(M.yamlify('test\ntest'), '"test' .. M.EOL .. 'test"')
    lu.assert_equals(M.yamlify('test\r\ntest'), '"test' .. M.EOL .. 'test"')
    lu.assert_equals(M.yamlify('test' .. utf8.char(0x7f) .. 'test'),
        '"test\\x7ftest"')
    lu.assert_equals(M.yamlify('test' .. utf8.char(0xda99) .. 'test'),
        '"test\\uda99test"')
    local str = M.yamlify(ZOTXT_CSL)
    local csl = rconv_nums_to_strs(yaml.parse(str))
    lu.assert_equals(csl, ZOTXT_CSL)
end


-- zotxt
-- -----

function test_zotxt_get_csl_item ()
    local invalid = {nil, false, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.Zotxt.get_csl_item, M.Zotxt, v)
    end

    local ret, err = M.Zotxt:get_csl_item('haslanger2012ResistingRealitySocial')
    lu.assert_nil(err)
    lu.assert_equals(ret, ZOTXT_CSL)
end

-- Zotero Web API
-- --------------

function test_zotweb_get_csl_item ()
    local zotweb = M.ZotWeb{api_key = ZOTWEB_API_KEY}
    local invalid = {nil, false, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(zotweb.get_csl_item, zotweb, v)
    end

    local ret, err = zotweb:get_csl_item('haslanger2012ResistingRealitySocial')
    lu.assert_nil(err)
    lu.assert_equals(ret, ZOTWEB_CSL)
end


-- Bibliography files
-- --------------

function test_csl_keys_sort ()
    local invalid = {nil, false, 0, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.csl_keys_sort, v, 'string')
        lu.assert_error(M.csl_keys_sort, 'string', v)
    end

    lu.assert_true(M.csl_keys_sort('a', 'b'))
    lu.assert_false(M.csl_keys_sort('b', 'a'))
    lu.assert_true(M.csl_keys_sort('id', 'a'))
    lu.assert_false(M.csl_keys_sort('a', 'id'))
    lu.assert_true(M.csl_keys_sort('id', 'type'))
    lu.assert_false(M.csl_keys_sort('type', 'id'))
end

function test_csl_items_sort ()
    local invalid = {nil, false, 0, 'string', {}, {1}, {x=1}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.csl_items_sort, v, {id='x'})
        lu.assert_error(M.csl_items_sort, {id='x'}, v)
    end

    lu.assert_error(M.csl_items_sort)
    lu.assert_error(M.csl_items_sort, {id='x'})

    local tests = {
        [{{id = 1}, {id = 2}}] = true,
        [{{id = 1}, {id = 1}}] = false,
        [{{id = 2}, {id = 1}}] = false,
        [{{id = 'a'}, {id = 'b'}}] = true,
        [{{id = 'a'}, {id = 'a'}}] = false,
        [{{id = 'b'}, {id = 'a'}}] = false,
        [{{id = 'Z'}, {id = 'a'}}] = true,
        [{{id = 'Z'}, {id = 'Z'}}] = false,
        [{{id = 'a'}, {id = 'Z'}}] = false
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.csl_items_sort(table.unpack(k)), v)
    end
end

function test_csl_items_ids ()
    local invalid = {nil, 0, false, 'string', function () end,
        {'this'}, {0},
        {{id=0}}, {{id=false}}, {{id={}}}, {{id=function () end}}
    }
    for _, v in ipairs(invalid) do
        lu.assert_error(M.csl_items_ids, v)
    end

    lu.assert_equals(M.csl_items_ids({}), {})
    lu.assert_equals(M.csl_items_ids({ZOTXT_CSL}),
        {haslanger2012ResistingRealitySocial=true})
    lu.assert_equals(M.csl_items_ids(ZOTXT_YAML),
        {crenshaw1989DemarginalizingIntersectionRace=true})
end

function test_biblio_read ()
    local fname, data, err

    fname = M.path_join(DATA_DIR, 'bibliography.json')
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    lu.assert_items_equals(rconv_nums_to_strs(data), {ZOTXT_CSL})

    fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    lu.assert_items_equals(data, ZOTXT_YAML)
end

function test_biblio_write ()
    local fname, ok, fmt, data, err, errno

    fname = M.path_join(TMP_DIR, 'bibliography.json')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio_write(fname, {ZOTXT_CSL})
    lu.assert_equals(fmt, 'json')
    lu.assert_nil(err)
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    lu.assert_items_equals(rconv_nums_to_strs(data), {ZOTXT_CSL})

    fname = M.path_join(TMP_DIR, 'bibliography.yaml')
    ok, err = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio_write(fname, ZOTXT_YAML)
    lu.assert_equals(fmt, 'yaml')
    lu.assert_nil(err)
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    lu.assert_items_equals(data, ZOTXT_YAML)
end

function test_biblio_types_mt___index ()
    lu.assert_equals(M.BIBLIO_TYPES.JSON, M.BIBLIO_TYPES.json);
    lu.assert_equals(M.BIBLIO_TYPES.JsOn, M.BIBLIO_TYPES.json);
end

function test_biblio_codecs_bib_decode ()
    local bib = M.BIBLIO_TYPES.bib

    local invalid = {nil, false, 0, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(bib.decode, v)
    end

    local fname = M.path_join(DATA_DIR, 'bibliography.bib')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    local ids = M.csl_items_ids(bib.decode(str))
    lu.assert_items_equals(ids, {
        ['crenshaw1989DemarginalizingIntersectionRace'] = true,
        ['diaz-leon2015WhatSocialConstruction'] = true
    })
end


function test_biblio_codecs_yaml_decode ()
    -- luacheck: ignore yaml
    local yaml = M.BIBLIO_TYPES.yaml

    local invalid = {nil, false, 0, {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(yaml.decode, v)
    end

    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    lu.assert_items_equals(yaml.decode(str), ZOTXT_YAML)
end

function test_biblio_types_yaml_encode ()
    -- luacheck: ignore yaml
    local yaml = M.BIBLIO_TYPES.yaml

    local invalid = {nil, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(yaml.encode, v)
    end

    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    lu.assert_items_equals(yaml.decode(yaml.encode(ZOTXT_YAML)), ZOTXT_YAML)
end

function test_biblio_update ()
    local invalid = {nil, false, 0, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.biblio_update, M.Zotxt, v, {'<n/a>'})
    end

    local wrong = {'nosuffix', 'n.', 'n.wrongformat'}
    for _, v in ipairs(wrong) do
        local ok, err =  M.biblio_update(M.Zotxt, v, {'<n/a>'})
        lu.assert_nil(ok)
        lu.assert_not_nil(err)
    end

    local fname = M.path_join(TMP_DIR, 'update-biblio.json')
    invalid = {nil, false, 0, 'string', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.biblio_update, M.Zotxt, fname, v)
    end

    -- Remove file, just in case.
    local data, ok, err, errno
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end

    -- Checks whether we do nothing if there's nothing to be done.
    ok, err = M.biblio_update(M.Zotxt, fname, {})
    if not ok then error(err) end
    ok, err, errno = os.remove(fname)
    if ok or errno ~= 2 then error(err) end

    -- Checks adding citations from zero.
    ok, err = M.biblio_update(M.Zotxt, fname, {'haslanger:2012resisting'})
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    local csl = copy(ZOTXT_CSL)
    csl.id = 'haslanger:2012resisting'
    lu.assert_equals(data, {csl})

    -- Checks adding a new citation.
    local new
    ckeys = {'haslanger:2012resisting', 'dotson:2016word'}
    ok, err = M.biblio_update(M.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_equals(#data, 2)

    ok, err = M.biblio_update(M.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    new, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(new)
    lu.assert_equals(new, data)

    -- This should not change the file.
    local post
    ok, err = M.biblio_update(M.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    post, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(post)
    lu.assert_equals(new, post)
end


-- Pandoc
-- ------

function test_elem_type ()
    local non_pandoc = {nil, true, 1, 'string', {}, function () end}
    for _, v in ipairs(non_pandoc) do
        lu.assert_nil(M.elem_type(v))
    end

    local tests = {
        [Str 'test'] = {'Str', 'Inline', 'AstElement', n = 3},
        [Para{Str ''}] = {'Para', 'Block', 'AstElement', n = 3},
        [MetaInlines{Str ''}] =
            {'MetaInlines', 'MetaValue', 'AstElement', n = 3}
    }

    for k, v in pairs(tests) do
        lu.assert_equals(table.pack(M.elem_type(k)), v)
    end
end

function test_walk ()
    local id = {AstElement = function (...) return ... end}
    local nilify = {AstElement = function () return end}
    local nullify = {AstElement = function () return Null() end}
    local pt = {nil, false, 0, '', {}, function () end}

    for _, v in ipairs(pt) do
        lu.assert_equals(M.walk(v, del), v)
    end

    local fnames = {
        'better-bibtex.md', 'biblio-json.md', 'biblio-yaml.md',
        'dup-biblio-bib.md', 'dup-biblio-yaml.md', 'dup.md',
        'easy-citekey.md', 'empty.md', 'ex-biblio.md',
        'ex-simple.md', 'issue-4-2.md', 'issue-4.md',
        'merge.md', 'nocite.md', 'pre-existing-mixed.md',
        'zotero-id.md'
    }

    for _, v in ipairs(fnames) do
        local fname = M.path_join(DATA_DIR, v)
        local doc, err = read_md_file(fname)
        assert(doc, err)
        lu.assert_equals(doc, M.walk(doc, id))
        lu.assert_equals(doc, M.walk(doc, nilify))
        lu.assert_equals(M.walk(doc, nullify).tag, 'Null')
    end

    local yesify = {Str = function (s)
        if stringify(s) == 'no' then return Str 'yes' end
    end}
    local yes = M.walk(Str 'no', yesify)
    lu.assert_equals(stringify(yes), 'yes')
    local no = M.walk(Str 'no!', yesify)
    lu.assert_equals(stringify(no), 'no!')

    local elem = Para{Str 'no'}
    local walked = M.walk(elem, {
        Str = function () return Str 'yes' end,
        Para = function (p) if stringify(p) == 'no' then return Null() end end
    })
    lu.assert_equals(stringify(walked), 'yes')
    lu.assert_false(pandoc.utils.equals(elem, walked))
end

function test_meta_sources ()
    -- luacheck: ignore err
    local invalid = {nil, false, 0, 'string', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.meta_sources, v)
    end

    local empty_fname = M.path_join(DATA_DIR, 'empty.md')
    local empty, err = read_md_file(empty_fname)
    assert(empty, err)
    lu.assert_equals(M.meta_sources(empty.meta), {})

    local test_fname = M.path_join(DATA_DIR, 'dup.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    lu.assert_items_equals(M.meta_sources(test_file.meta), ZOTXT_META)

    test_fname = M.path_join(DATA_DIR, 'dup-biblio-yaml.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    lu.assert_items_equals(M.meta_sources(test_file.meta), ZOTXT_YAML)

    test_fname = M.path_join(DATA_DIR, 'dup-biblio-bib.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ids = M.csl_items_ids(M.meta_sources(test_file.meta))
    lu.assert_items_equals(ids, {
        ["crenshaw1989DemarginalizingIntersectionRace"] = true,
        ["diaz-leon2015WhatSocialConstruction"] = true
    })
end

function test_doc_ckeys ()
    local invalid = {nil, false, 0, '', {}, function () end}
    for _, v in pairs(invalid) do
        lu.assert_error(M.doc_ckeys, v)
    end

    local empty_fname = M.path_join(DATA_DIR, 'empty.md')
    local empty = read_md_file(empty_fname)
    lu.assert_equals(M.doc_ckeys(empty), {})

    local test_fname = M.path_join(DATA_DIR, 'easy-citekey.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ckeys, n = M.doc_ckeys(test_file)
    lu.assert_items_equals(ckeys, {
        'dotson:2016word',
        'díaz-león:2015what',
        'díaz-león:2015defence',
        'díaz-león:2016woman',
        'haslanger:2012resisting',
        'nobody:0000nothing'
    })
    lu.assert_equals(n, 6)

    test_fname = M.path_join(DATA_DIR, 'dup.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    ckeys, n = M.doc_ckeys(test_file)
    lu.assert_items_equals(ckeys,
        {'crenshaw1989DemarginalizingIntersectionRace'})
    lu.assert_equals(n, 1)
    ckeys, n = M.doc_ckeys(test_file, true)
    lu.assert_items_equals(ckeys, {})
    lu.assert_equals(n, 0)

    test_fname = M.path_join(DATA_DIR, 'nocite.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    lu.assert_items_equals(M.doc_ckeys(test_file),
        {'crenshaw1989DemarginalizingIntersectionRace'})
    lu.assert_items_equals(M.doc_ckeys(test_file, true),
    {'crenshaw1989DemarginalizingIntersectionRace'})
end


-- BOILERPLATE
-- ===========

-- luacheck: globals run
--- Runs the tests
--
-- Looks up the `tests` metadata field in the current Pandoc document
-- and passes it to `lu.LuaUnit.run`, as is. Also configures tests.
function run (doc)
    local tests = nil
    if doc.meta.tests then tests = stringify(doc.meta.tests) end
    os.exit(lu.LuaUnit.run(tests), true)
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}
