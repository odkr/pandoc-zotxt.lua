--- test.lua - A fake Pandoc filter that runs units for pandoc-zotxt.lua.
--
-- # SYNOPSIS
--
--      pandoc -L test.lua -o /dev/null FILE
--
--
-- # DESCRIPTION
--
-- A fake Pandoc filter that runs units for for pandoc-zotxt.lua.
-- Which tests are run is goverend by the `tests` metadata field in FILE.
-- This field is passed to lu.LuaUnit.run. If `tests` is not set,
-- runs all tests.
--
--
-- # SEE ALSO
--
-- <https://luaunit.readthedocs.io/>
--
-- # AUTHOR
--
-- Copyright 2019, 2020 Odin Kroeger
--
--
-- # LICENSE
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
-- @script test.lua
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020 Odin Kroeger
-- @license MIT
-- luacheck: allow defined top, no global


-- # SHORTHANDS

local concat = table.concat
local unpack = table.unpack


-- # LIBRARIES

-- luacheck: push ignore
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
local stringify = pandoc.utils.stringify
-- luacheck: pop

local text = require 'text'
local sub = text.sub


-- # LIBRARIES

--- The path seperator of the operating system.
PATH_SEP = sub(package.config, 1, 1)

do
    local split = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
    local sanitisers = {{PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        {PATH_SEP .. '+', PATH_SEP}, {'^%.' .. PATH_SEP, ''}}

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
        for _, s in ipairs(sanitisers) do
            path = path:gsub(table.unpack(s))
        end
        local dir, fname = path:match(split)
        dir = dir:gsub('(.)' .. PATH_SEP .. '$', '%1')
        if dir   == '' then dir   = '.' end
        if fname == '' then fname = '.' end
        return dir, fname
    end
end

-- luacheck: globals PANDOC_SCRIPT_FILE
--- The directory of the script.
local SCRIPT_DIR = split_path(PANDOC_SCRIPT_FILE)

--- The directory of the test suite.
local TEST_DIR = concat({SCRIPT_DIR, '..'}, PATH_SEP)

--- The test suite's data directory.
local DATA_DIR = concat({TEST_DIR, 'data'}, PATH_SEP)

--- The test suite's temporary directory.
local TMP_DIR = concat({TEST_DIR, 'tmp'}, PATH_SEP)

--- The repository directory.
local REPO_DIR = concat({TEST_DIR, '..'}, PATH_SEP)

package.path = package.path .. ';' ..
    concat({REPO_DIR, 'share', 'lua', '5.3', '?.lua'}, PATH_SEP)

local lu = require 'luaunit'
local M = require 'pandoc-zotxt'


-- # CONSTANTS

--- Bibliographic data in CSL to compare data retrieved via zotxt to.
-- luacheck: globals ZOTXT_SOURCE
ZOTXT_SOURCE = {
    id = 'haslanger:2012resisting', type = 'book',
    author = {{family = 'Haslanger', given = 'Sally'}},
    title = 'Resisting Reality: Social Construction and Social Critique',
    publisher = 'Oxford University Press', ['publisher-place'] = 'Oxford',
    issued = {['date-parts'] = {{'2012'}}},
    ['title-short'] = 'Resisting Reality',
    ISBN = '978-0-19-989262-4'
}


-- # FUNCTIONS

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


-- # TESTS

-- ## List handling

function test_get_position ()
    local invalid_inputs = {nil, false, 0, 'x', function () end}
    for _, v in ipairs(invalid_inputs) do
        lu.assert_error(M.get_position, nil, v)
    end

    local tests = {
        [{nil, {}}]         = nil,
        [{nil, {1, 2, 3}}]  = nil,
        [{2, {1}}]          = nil,
        [{1, {1}}]          = 1,
        [{1, {1, 2, 3}}]    = 1,
        [{2, {1, 2, 3}}]    = 2,
        [{3, {1, 2, 3}}]    = 3
    }

    for k, v in pairs(tests) do
        lu.assert_equals(M.get_position(unpack(k)), v)
    end
end

function test_map ()
    -- luacheck: no redefined
    local function base (x) return x end
    local function successor (x) return x + 1 end

    local func = function (...) return ... end
    for _, v in ipairs({nil, false, 0, '', {}}) do
        lu.assert_error(M.map, func, v)
    end
    for _, v in ipairs({nil, false, 0, '', base}) do
        lu.assert_error(M.map, v, {1, 2, 3})
    end

    local tests = {
        [base]      = {[{}] = {}, [{1}] = {1}, [{1, 2, 3}] = {1, 2, 3}},
        [successor] = {[{}] = {}, [{1}] = {2}, [{1, 2, 3}] = {2, 3, 4}},
    }

    for func, values in ipairs(tests) do
        for k, v in pairs(values) do
            lu.assert_equals(M.map(func, k), v)
        end
    end
end


-- ## Path Handling

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


-- ## JSON files


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

    local fname = concat({DATA_DIR, 'bibliography.json'}, PATH_SEP)
    data, err, errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)
    lu.assert_equals(data, ZOTXT_SOURCE)
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

    local fname = concat({TMP_DIR, 'test-write_json_file.json'}, PATH_SEP)
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    ok, err, errno = M.write_json_file(ZOTXT_SOURCE, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    lu.assert_nil(errno)

    data, err, errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)

    lu.assert_equals(data, ZOTXT_SOURCE)
end


-- ## Converters

function test_convert_numbers_to_strings ()
    local a = {}
    a.a = a
    lu.assert_error(M.convert_numbers_to_strings, a)
    lu.assert_nil(M.convert_numbers_to_strings())

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
        lu.assert_equals(M.convert_numbers_to_strings(k), v)
    end
end


-- ## Handling bibliographic data

function test_get_citekeys ()
    local invalid = {nil, false, 0, '', {}}
    for _, v in pairs(invalid) do
        lu.assert_error(M.get_citekeys, v)
    end

    -- luacheck: globals DOC
    local empty_fname = DATA_DIR .. PATH_SEP .. 'test-empty.md'
    local empty = read_md_file(empty_fname)
    lu.assert_equals(M.get_citekeys(empty), {})

    local test_fname = DATA_DIR .. PATH_SEP .. 'test-easy-citekey.md'
    local test_file = read_md_file(test_fname)
    lu.assert_equals(M.get_citekeys(test_file), {
        'haslanger:2012resisting','díaz-león:2013what',
        'díaz-león:2015defence','díaz-león:2016woman',
        'dotson:2016word','nobody:0000nothing'
    })
end


-- function test_higher:setup ()
--     function self.get (citekey)
--         return M.get_source(M.fake_read_url, citekey)
--     end
-- end

-- function test_higher:test_get_source ()
--     lu.assert_error(self.get, nil, '<none>')
--     local invalid_input = {nil, false, 0, {}}
--     for _, invalid in pairs(invalid_input) do
--         lu.assert_error(self.db.get_source, self.db, invalid)
--     end

--     lu.assert_nil(select(2, pcall(self.db.get_source, self.db, '<none>')))

--     lu.assert_nil(self.db:get_source(''))

--     local better_bibtex = copy(ZOTXT_SOURCE)
--     better_bibtex.id = 'haslanger2012ResistingRealitySocial'
--     local zotero_id = copy(ZOTXT_SOURCE)
--     zotero_id.id = 'TPN8FXZV'

--     local tests = {
--         [ZOTXT_SOURCE.id]   = ZOTXT_SOURCE,
--         [better_bibtex.id]  = better_bibtex,
--         [zotero_id.id]      = zotero_id
--     }

--     for k, v in pairs(tests) do
--         lu.assert_equals(self.db:get_source(k), v)
--     end
-- end

-- function test_zotxt:test_update_bibliography ()
--     local invalid_db = {nil, false, 0, "false", {}, function () end}
--     local invalid_citekeys = {nil, false, 0, "false", function () end}
--     local invalid_fnames = {nil, false, 0, function () end, '', 'test'}

--     local db = self.db
--     local citekeys = {'haslanger:2012resisting'}
--     local fname = concat({TMP_DIR, 'test-update_bibliography.json'}, PATH_SEP)

--     for i = 1, #invalid_db do
--         lu.assert_error(M.update_bibliography, invalid_db[i], citekeys, fname)
--     end
--     for i = 1, #invalid_citekeys do
--         lu.assert_error(M.update_bibliography, db, invalid_citekeys[i], fname)
--     end
--     for i = 1, #invalid_fnames do
--         lu.assert_error(M.update_bibliography, db, citekeys, invalid_fnames[i])
--     end

--     -- Remove file, just in case.
--     local data, ok, err, errno
--     ok, err, errno = os.remove(fname)
--     if not ok and errno ~= 2 then error(err) end

--     -- Checks whether we do nothing if there's nothing to be done.
--     ok, err = M.update_bibliography(db, {}, fname)
--     if not ok then error(err) end
--     ok, err, errno = os.remove(fname)
--     if ok or errno ~= 2 then error(err) end

--     -- Checks adding citations from zero.
--     ok, err = M.update_bibliography(db, {'haslanger:2012resisting'}, fname)
--     lu.assert_nil(err)
--     lu.assert_true(ok)
--     data, err = M.read_json_file(fname)
--     lu.assert_nil(err)
--     lu.assert_not_nil(data)
--     lu.assert_equals(data, {ZOTXT_SOURCE})

--     -- Checks adding a new citation.
--     local new
--     citekeys = {'haslanger:2012resisting', 'dotson:2016word'}
--     ok, err = M.update_bibliography(db, citekeys, fname)
--     lu.assert_nil(err)
--     lu.assert_true(ok)
--     data, err = M.read_json_file(fname)
--     lu.assert_nil(err)
--     lu.assert_not_nil(data)
--     lu.assert_equals(#data, 2)

--     ok, err = M.update_bibliography(db, citekeys, fname)
--     lu.assert_nil(err)
--     lu.assert_true(ok)
--     new, err = M.read_json_file(fname)
--     lu.assert_nil(err)
--     lu.assert_not_nil(new)
--     lu.assert_equals(new, data)

--     -- This should not change the file.
--     local post
--     ok, err = M.update_bibliography(db, citekeys, fname)
--     lu.assert_nil(err)
--     lu.assert_true(ok)
--     post, err = M.read_json_file(fname)
--     lu.assert_nil(err)
--     lu.assert_not_nil(post)
--     lu.assert_equals(new, post)
-- end


-- # BOILERPLATE

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


