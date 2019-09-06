--- test.lua - A fake Pandoc filter that runs units for for pandoc-zotxt.lua.
--
-- # SYNOPSIS
-- 
--      pandoc --lua-filter test.lua -o /dev/null FILE
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
-- Copyright 2019 Odin Kroeger
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
-- @copyright 2018, 2019 Odin Kroeger
-- @license MIT


-- # SHORTHANDS

local open = io.open
local popen = io.popen
local time = os.time
local execute = os.execute
local exit = os.exit
local concat = table.concat
local unpack = table.unpack
local format = string.format

local stringify = pandoc.utils.stringify


-- # LIBRARIES

local text = require 'text'
local sub = text.sub

--- The path seperator of the operating system
local PATH_SEP = sub(package.config, 1, 1)

do
    -- `string.match` expression that splits a path.
    local split_expr = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'
    -- `string.gsub` expressions and substitutions strings that sanitise paths.
    local san_exprs = {
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP}, -- '/./' -> '/'
        {PATH_SEP .. '+', PATH_SEP},              -- '//'  -> '/'
        {'^%.' .. PATH_SEP, ''}                   -- './'  -> ''
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
        for _, v in ipairs(san_exprs) do path = path:gsub(unpack(v)) end
        local dir, fname = path:match(split_expr)
        if #dir > 1 then dir = dir:gsub(PATH_SEP .. '$', '') end
        if fname == '' then fname = '.' end
        return dir, fname
    end
end

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
ZOTXT_SOURCE = {
    id = 'haslanger:2012resisting', type = 'book',
    author = {{family = 'Haslanger', given = 'Sally'}},
    title = 'Resisting Reality: Social Construction and Social Critique',
    publisher = 'Oxford University Press', ['publisher-place'] = 'Oxford',
    issued = {['date-parts'] = {{'2012'}}},
    ['title-short'] = 'Resisting Reality',
    ISBN = '978-0-19-989262-4'
}


--- Configuration options.
--
-- `run` overrides these defaults.
--
-- @table
CONFIG = M.DEFAULTS


-- # FUNCTIONS

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
    local f, err, errno = open(fname, 'r')
    if not f then return nil, err, errno end
    local md, err, errno = f:read('a')
    if not md then return nil, err, errno end
    local ok, err, errno = f:close()
    if not ok then return nil, err, errno end
    return pandoc.read(md, 'markdown')
end


-- # TESTS

test_core = {}

function test_core:test_split_path ()
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

function test_core:test_map ()
    local function base (x) return x end
    local function successor (x) return x + 1 end
  
    local invalid_inputs = {nil, false, 0, '', {}}
    for _, a in ipairs(invalid_inputs) do
        for _, b in ipairs({nil, false, 0, '', base}) do
            lu.assert_error(M.map, a, b)
        end
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

-- function test_core:test_filter ()
--     local function flt (x) return x == 1 end
-- 
--     local invalid_inputs = {nil, false, 0, '', {}}
--     for _, a in ipairs(invalid_inputs) do
--         for _, b in ipairs({nil, false, 0, '', base}) do
--             lu.assert_error(M.filter, a, b)
--         end
--     end
-- 
--     local tests = {
--         [{}]        = {},
--         [{1}]       = {},
--         [{0, 1, 2}] = {0, 2},
--         [{1, 1, 1}] = {1, 1, 1},
--         [{0, 0, 0}] = {}
--     }
-- 
--     for k, v in ipairs(tests) do
--         lu.assert_equals(M.filter(flt, k), v)
--     end
-- end

function test_core:test_get_position ()
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

-- function test_core:test_get_element ()
--     local invalid_inputs = {nil, true, 1, 'a'}
--     for _, v in ipairs(invalid_inputs) do
--         lu.assert_error(M.get_element(v))
--     end
-- 
--     local input = {
--         [1] = {[2] = {3, 4}, [5] = 6},
--         a = {b = {'c', 'd'}, e = 'f'},
--         ['_'] = {b = {3, 'd'}, [5] = 'f'}
--     }
-- 
--     local tests = {
--      [{}] = nil,
--      [{1}] = {[2] = {3, 4}, [5] = 6},
--      [{1, 2}] = {3, 4},
--      [{1, 5}] = 6,
--      [{'a'}] = {['b'] = {'c', 'd'}, e = 'f'},
--      [{'a', 'b'}] = {'c', 'd'},
--      [{'a', 'e'}] = 'f',
--      [{'_'}] = {b = {3, 'd'}, [5] = 'f'},
--      [{'_', 'b'}] = {3, 'd'},
--      [{'_', 5}] = 'f'
--     }
-- 
--     for k, v in pairs(tests) do
--         lu.assert_equals(M.get_element(input, unpack(k)), v)
--     end
-- end

function test_core:test_delegates_to ()
    local c = {}
    local b = setmetatable({}, {__index = c})
    local a = setmetatable({}, {__index = b})
    
    local invalid = {nil, false, 0, 'a', function () end}
    for _, v in ipairs(invalid) do
        lu.assert_error(M.delegates_to, a, invalid)
        lu.assert_error(M.delegates_to, invalid, a)
    end

    lu.assert_false(M.delegates_to(a, a))
    lu.assert_true(M.delegates_to(a, b))
    lu.assert_true(M.delegates_to(b, c))
    lu.assert_true(M.delegates_to(a, c))
    lu.assert_false(M.delegates_to(c, a))
    lu.assert_false(M.delegates_to(c, b))
end

function test_core:test_get_input_directory ()    
    lu.assert_equals(M.get_input_directory(), PATH_SEP .. 'dev')
end

function test_core:test_is_path_absolute ()
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
    local tests = {
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

function test_core:test_convert_numbers_to_strings ()
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

function test_core:test_convert_meta_to_table ()
    M.convert_meta_to_table(DOC.meta)
end

function test_core:test_read_json_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_json_file, invalid)
    end

    local ok, err, errno = M.read_json_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)
    
    local fname = concat({DATA_DIR, 'test-read_json_file.json'}, PATH_SEP)
    local data, err, errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)
    lu.assert_equals(data, ZOTXT_SOURCE)
end

function test_core:test_write_json_file ()
    local invalid_inputs = {nil, false, '', {}}
    for _, invalid in ipairs(invalid_inputs) do
        lu.assert_error(M.read_json_file, nil, invalid)
    end

    local ok, err, errno = M.read_json_file('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    lu.assert_equals(errno, 2)
    
    local fname = concat({TMP_DIR, 'test-write_json_file.json'}, PATH_SEP)
    local ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end    
    local ok, err, errno = M.write_json_file(ZOTXT_SOURCE, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    lu.assert_nil(errno)

    local data, err,errno = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_nil(errno)
    
    lu.assert_equals(data, ZOTXT_SOURCE) 
end

function test_core:test_get_citekeys ()
    local invalid = {nil, false, 0, '', {}}
    for _, v in pairs(invalid) do
        lu.assert_error(M.get_citekeys, v)
    end
    
    local data_dir = stringify(DOC.meta['test-data-dir'])
    local empty_fname = data_dir .. PATH_SEP .. 'test-empty.md'
    local empty = read_md_file(empty_fname)
    lu.assert_equals(M.get_citekeys(empty), {})

    local test_fname = data_dir .. PATH_SEP .. 'test-keytype-easy-citekey.md'
    local test_file = read_md_file(test_fname)
    lu.assert_equals(M.get_citekeys(test_file), {
        'haslanger:2012resisting','díaz-león:2013what',
        'díaz-león:2015defence','díaz-león:2016woman',
        'dotson:2016word','nobody:0000nothing'
    })
end

-- function test_core:test_getterise ()
--     Prototype = {_getters = {}}
--     function Prototype._getters.one () return 1 end
--     function Prototype:new ()
--         self = self or Prototype
--         return setmetatable({}, {__index = M.getterise(self)})
--     end
--     local obj = Prototype:new()
--     lu.assert_equals(obj.one, 1)
--     lu.assert_nil(obj.two)
-- 
--     function Prototype._getters.two () 
--         if not self._two then self._two = 2 
--                          else self._two = self._two + 1 end
--         return self._two
--     end
--     lu.assert_equals(obj.two, 2)
--     lu.assert_equals(obj.two, 2)
-- end
-- 
-- 
-- test_citekey = {}
-- 
-- function test_citekey:test_citekey_parse ()
--     local invalid = {nil, true, 1, {}, '', '1999', 'doe-1999'}
--     for _, v in ipairs(invalid) do
--         lu.assert_error(M.Citekey:parse(v))
--     end
-- 
--     local tests = {
--         doe2000 = {author = 'doe', year = 2000},
--         doe = {author = 'doe'},
--         ['doe:2000'] = {author = 'doe', year = 2000},
--         ['doe:'] = {author = 'doe'},
--         doe2000Word  = {author = 'doe', year = 2000, title = 'word'},
--         ['doe:2000WORD'] = {author = 'doe', year = 2000, title = 'word'},
--         ['díaz-león:2012'] = {author = 'díaz-león', year = 2012},
--         ['doe:title'] = {author = 'doe', title = 'title'}
--     }
-- 
--     for k, v in pairs(tests) do
--         local obj, err = M.Citekey:parse(k)
--         lu.assert_nil(err)
--         lu.assert_not_nil(obj)
--         lu.assert_equals(obj, v)
--     end
-- end
-- 
-- function test_citekey:test_citekey_matches ()
--     function make_item (author, year, title)
--         local ret = {title = title or ''}
--         if year then ret['issued'] = {['date-parts'] = {{year}}} end
--         ret['author'] = {{family = author}}
--         return ret
--     end
-- 
--     local citation = M.Citekey:parse('doe')
--     local invalid = {nil, true, 1, 'a', {}}
--     for _, v in ipairs(invalid) do
--         lu.assert_error(citation:matches(v))
--     end
-- 
--     local tests = {
--         doe = {
--             [{'doe'}] = true,
--             [{'no'}] = false,
--             [{'doe', 2000}] = false,
--             [{'doe', nil, ''}] = true,
--             [{'doe', nil, 'no'}] = true
--         },
--         doe2000 = {
--             [{'doe'}] = false,
--             [{'no'}] = false,
--             [{'doe', 2000}] = true,
--             [{'doe', 3000}] = false,
--             [{'doe', nil, ''}] = false,
--             [{'doe', nil, 'no'}] = false,
--             [{'doe', 2000, 'no'}] = true,
--             [{'doe', 2000, ''}] = true
--         },
--         doe2000word = {
--             [{'doe'}] = false,
--             [{'no'}] = false,
--             [{'doe', 2000}] = false,
--             [{'doe', 3000}] = false,
--             [{'doe', nil, ''}] = false,
--             [{'doe', nil, 'no'}] = false,
--             [{'doe', 2000, 'no'}] = false,
--             [{'doe', 2000, ''}] = false,
--             [{'doe', 2000, 'word'}] = true,
--             [{'doe', 2000, 'birdword'}] = true,
--             [{'doe', 2000, 'birdwordbird'}] = true,
--             [{'doe', 2000, 'wo'}] = false,
--             [{'doe', 2000, 'nope'}] = false
--         },
--         ['doe:title'] = {
--             [{'doe'}] = false,
--             [{'no'}] = false,
--             [{'doe', 2000}] = false,
--             [{'doe', 3000}] = false,
--             [{'doe', nil, ''}] = false,
--             [{'doe', nil, 'no'}] = false,
--             [{'doe', 2000, 'no'}] = false,
--             [{'doe', 2000, ''}] = false,
--             [{'doe', 2000, 'word'}] = false,
--             [{'doe', 2000, 'title'}] = false,
--             [{'doe', nil, 'title'}] = true,
--             [{'doe', nil, 'xxxtitlexxx'}] = true
--         }
--     }
-- 
--     for citekey, test in pairs(tests) do
--         obj = M.Citekey:parse(citekey)
--         for desc, res in pairs(test) do
--             local item = make_item(unpack(desc))
--             lu.assert_equals(obj:matches(item), res)
--         end
--     end
-- end
-- 
-- test_ordered_table = {}
-- 
-- function test_ordered_table:setup ()
--     self.tab = M.OrderedTable:new{a = 1, c = 3, b = 2}
-- end
-- 
-- function test_ordered_table:test_ordered_table_new ()
--     lu.assert_not_nil(self.tab)
--     lu.assert_equals(self.tab, {a = 1, b = 2, c = 3})
-- end
-- 
-- function test_ordered_table:test_ordered_table_ipairs ()
--     local keys = {}
--     for k in pairs(self.tab) do keys[#keys + 1] = k end
--     lu.assert_not_nil(keys)
--     lu.assert_equals(keys, {'a', 'b', 'c'})
-- end


test_zotxt = {}

function test_zotxt:setup ()
    self.db = CONFIG.db_connector:new(CONFIG, DOC.meta)
end

function test_zotxt:test_get_source ()
    lu.assert_error(self.db.get_source, nil, '<none>')
    local invalid_input = {nil, false, 0, '', {}}
    for _, invalid in pairs(invalid_input) do
        lu.assert_error(self.db.get_source, self.db, invalid)
    end

    lu.assert_nil(select(2, pcall(self.db.get_source, self.db, '<none>')))

    local better_bibtex = copy(ZOTXT_SOURCE)
    better_bibtex.id = 'haslanger2012ResistingRealitySocial'
    local zotero_id = copy(ZOTXT_SOURCE)
    zotero_id.id = 'TPN8FXZV'
    
    local tests = {
        [ZOTXT_SOURCE.id]   = ZOTXT_SOURCE,
        [better_bibtex.id]  = better_bibtex,
        [zotero_id.id]      = zotero_id
    }
    
    for k, v in pairs(tests) do
        lu.assert_equals(self.db:get_source(k), v)
    end
end

function test_zotxt:test_update_bibliography ()
    local invalid_fnames = {nil, false, '', {}}
    local invalid_keys = {nil, false, 0, '', base}
    for _, fname in ipairs(invalid_fnames) do
        for _, keys in ipairs(invalid_keys) do
            lu.assert_error(self.db.update_bibliography, self.db, fname, keys)
        end
    end


    local fname = concat({TMP_DIR, 'test-update_bibliography.json'}, PATH_SEP)
    local ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    local ok, err = M.update_bibliography(self.db, {'haslanger:2012resisting'},
        fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    local data, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_equals(data, {ZOTXT_SOURCE})

    local citekeys = {'haslanger:2012resisting', 'dotson:2016word'}
    local ok, err = M.update_bibliography(self.db, citekeys, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    local data, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    lu.assert_equals(#data, 2)

    local ok, err = M.update_bibliography(self.db, citekeys, fname)
    lu.assert_nil(err)
    lu.assert_true(ok)
    local new, err = M.read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(new)
    lu.assert_equals(new, data)
end


-- # BOILERPLATE

--- Runs the tests
--
-- Looks up the `tests` metadata field in the current Pandoc document
-- and passes it to `lu.LuaUnit.run`, as is. Also configures tests.
--
-- @tparam pandoc.Doc doc A Pandoc document.
function run (doc)
    local meta = doc.meta
    local tests, err
    if meta.tests then tests = stringify(meta.tests) end
    CONFIG, err = M.get_db_configuration(doc.meta)
    if not CONFIG then M.warn(err) return nil end
    DOC = doc
    exit(lu.LuaUnit.run(tests))
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}


