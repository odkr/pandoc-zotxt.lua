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


-- LIBRARIES
-- =========

--- The path seperator of the operating system.
PATH_SEP = package.config:sub(1, 1)

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
local TEST_DIR = SCRIPT_DIR .. PATH_SEP .. '..'

--- The test suite's data directory.
local DATA_DIR = TEST_DIR .. PATH_SEP .. 'data'

--- The test suite's tempory directory.
local TMP_DIR = TEST_DIR .. PATH_SEP .. 'tmp'

--- The repository directory.
local REPO_DIR = TEST_DIR .. PATH_SEP .. '..'

package.path = package.path ..
    ';' .. SCRIPT_DIR .. PATH_SEP .. '?.lua' ..
    ';' .. table.concat({REPO_DIR, 'share', 'lua', '5.3', '?.lua'}, PATH_SEP)


local lu = require 'luaunit'
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
    ISBN = '978-0-19-989262-4'
}

--- Bibliographic data as returned from a YAML file.
ZOTXT_YAML = {
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

--- Bibliographic data as JSON string.
ZOTXT_JSON = '[\n  ' ..
    '{"id":"haslanger2012ResistingRealitySocial","author":[{"family":"Haslanger","given":"Sally"}],"ISBN":"978-0-19-989262-4","issued":{"date-parts":[[2012]]},"publisher":"Oxford University Press","publisher-place":"Oxford","title":"Resisting Reality: Social Construction and Social Critique","title-short":"Resisting Reality","type":"book"}' ..
    '\n]\n'



-- FUNCTIONS
-- =========

-- luacheck: globals copy
--- Copies tables recursively.
--
-- Handles metatables, recursive structures, tables as keys, and
-- avoids the `__pairs` and `__newindex` metamethods.
-- Copies are deep.
--
-- @param orig The original.
--
-- @return A copy.
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
    local res = setmetatable({}, getmetatable(data))
    s = s or {}
    s[data] = res
    for k, v in next, data, nil do
        rawset(res, copy(k, s), copy(v, s))
    end
    return res
end


--- Reads a Markdown file.
--
-- @tparam string fname Name of the file.
-- @return The parsed data, `nil` if an error occurred.
-- @treturn string An error message, if applicable.
-- @treturn number An error number. Positive numbers are OS error numbers.
--
-- May raise an uncatchable error.
function read_md_file (fname)
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


-- TESTS
-- =====

-- Paths
-- -----

function test_split_path ()
    local invalid_inputs = {nil, false, 0, '', {}, function () end}

    for _, v in ipairs(invalid_inputs) do
        lu.assert_error(M.split_path, v)
    end

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
        local dir, fname = M.split_path(k)
        lu.assert_equals(dir, v[1])
        lu.assert_equals(fname, v[2])
    end
end


function test_is_path_absolute ()
    local original_path_sep = M.PATH_SEP
    lu.assert_error(M.is_path_absolute)

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
        lu.assert_equals(M.is_path_absolute(k), v)
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
        lu.assert_equals(M.is_path_absolute(k), v)
    end

    M.PATH_SEP = original_path_sep
end


function test_get_input_directory ()
    lu.assert_equals(M.get_input_directory(), '.')
end


-- JSON files
-- ----------

function test_read_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_json_file, invalid)
    end

    local str, ok, err, errno
    ok, err, errno = M.read_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = DATA_DIR .. PATH_SEP .. 'bibliography.json'
    str, err, errno = M.read_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(str)
    lu.assert_nil(errno)
    lu.assert_equals(str, ZOTXT_JSON)
end

function test_write_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_file, nil, invalid)
    end

    local data, ok, err, errno
    ok, err, errno = M.read_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = TMP_DIR .. PATH_SEP .. 'file'
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    ok, err, errno = M.write_file(ZOTXT_JSON, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    lu.assert_nil(errno)

    data, err, errno = M.read_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)

    lu.assert_equals(data, ZOTXT_JSON)
end

function test_read_json_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_json_file, invalid)
    end

    local data, ok, err, errno
    ok, err, errno = M.read_json_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = DATA_DIR .. PATH_SEP .. 'bibliography.json'
    data, err, errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)
    lu.assert_equals(data, {ZOTXT_CSL})
end

function test_read_yaml_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_yaml_file, invalid)
    end

    local data, ok, err, errno
    ok, err, errno = M.read_yaml_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = DATA_DIR .. PATH_SEP .. 'bibliography.yaml'
    data, err, errno = M.read_yaml_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)
    lu.assert_equals(data, {ZOTXT_YAML})
end


function test_write_json_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_json_file, nil, invalid)
    end

    local data, ok, err, errno
    ok, err, errno = M.read_json_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)

    local fname = TMP_DIR .. PATH_SEP .. 'bibliography.json'
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    ok, err, errno = M.write_json_file(ZOTXT_CSL, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    lu.assert_nil(errno)

    data, err, errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)

    lu.assert_equals(data, ZOTXT_CSL)
end


-- Converters
-- ----------

function test_conv_nums_to_strs ()
    local a = {}
    a.a = a
    lu.assert_error(M.conv_nums_to_strs, a)
    lu.assert_nil(M.conv_nums_to_strs())

    local tests = {
        [true] = true, [1] = '1', [1.1] = '1', ['a'] = 'a', [{}] = {},
        [{nil, true, 1, 1.12, 'a', {}}] = {nil, true, '1', '1', 'a', {}},
        [{a = nil, b = true, c = 1, d = 1.12, e = 'a', f = {}}] =
            {a = nil, b = true, c = '1', d = '1', e = 'a', f = {}},
        [{a = nil, b = true, c = 1, d = 1.12, e = 'a',
            f = {nil, true, 1, 1.12, 'a', {}}}] =
                {a = nil, b = true, c = '1', d = '1', e = 'a',
                    f = {nil, true, '1', '1', 'a', {}}}
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.conv_nums_to_strs(k), v)
    end
end


-- Retrieving bibliographic data
-- -----------------------------

function test_get_source_csljson ()
    local function id (...)
        return ...
    end

    local invalid = {nil, false, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.get_source_csljson, v, id)
    end

    local ret = M.get_source_csljson('haslanger2012ResistingRealitySocial', id)
    lu.assert_equals(ret, ZOTXT_JSON)
end

function test_get_source_csl ()
    local invalid = {nil, false, '', {}, function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.get_source_csl, v)
    end

    local ret = M.get_source_csl('haslanger2012ResistingRealitySocial')
    lu.assert_equals(ret, ZOTXT_CSL)
end


-- Updating the document
-- ---------------------

function test_get_used_citekeys ()
    local invalid = {nil, false, 0, '', {}}
    for _, v in pairs(invalid) do
        lu.assert_error(M.get_used_citekeys, v)
    end

    -- luacheck: globals DOC
    local empty_fname = DATA_DIR .. PATH_SEP .. 'test-empty.md'
    local empty = read_md_file(empty_fname)
    lu.assert_equals(M.get_used_citekeys(empty), {})

    local test_fname = DATA_DIR .. PATH_SEP .. 'test-easy-citekey.md'
    local test_file = read_md_file(test_fname)
    lu.assert_items_equals(M.get_used_citekeys(test_file), {
        ['dotson:2016word']=true,
        ['díaz-león:2013what']=true,
        ['díaz-león:2015defence']=true,
        ['díaz-león:2016woman']=true,
        ['haslanger:2012resisting']=true,
        ['nobody:0000nothing']=true
    })
end


function test_update_bibliography ()
    local invalid_citekeys = {nil, false, 0, function () end}

    -- local fname = DATA_DIR .. PATH_SEP .. 'test-update_bibliography.json'
    local fname = TMP_DIR .. PATH_SEP .. 'update-bibliography.json'

    for i = 1, #invalid_citekeys do
        lu.assert_error(M.update_bibliography, invalid_citekeys[i], fname)
    end

    -- Remove file, just in case.
    local data, ok, err, errno
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end

    -- Checks whether we do nothing if there's nothing to be done.
    ok, err = M.update_bibliography({}, fname)
    if not ok then error(err) end
    ok, err, errno = os.remove(fname)
    if ok or errno ~= 2 then error(err) end

    -- Checks adding citations from zero.
    ok, err = M.update_bibliography({['haslanger:2012resisting']=true}, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    local csl = copy(ZOTXT_CSL)
    csl.id = 'haslanger:2012resisting'
    lu.assert_equals(data, {csl})

    -- Checks adding a new citation.
    local new
    citekeys = {['haslanger:2012resisting']=true, ['dotson:2016word']=true}
    ok, err = M.update_bibliography(citekeys, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_equals(#data, 2)

    ok, err = M.update_bibliography(citekeys, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    new, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(new)
    lu.assert_equals(new, data)

    -- This should not change the file.
    local post
    ok, err = M.update_bibliography(citekeys, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    post, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(post)
    lu.assert_equals(new, post)
end


-- BOILERPLATE
-- ===========

-- luacheck: globals run
--- Runs the tests
--
-- Looks up the `tests` metadata field in the current Pandoc document
-- and passes it to `lu.LuaUnit.run`, as is. Also configures tests.
--
-- @tparam pandoc.Doc doc A Pandoc document.
function run (doc)
    -- luacheck: globals DOC
    DOC = doc
    os.exit(lu.LuaUnit.run())
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}


