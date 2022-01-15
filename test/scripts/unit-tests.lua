--- unit-tests.lua - A fake Pandoc filter that runs unit tests.
--
-- SYNOPSIS
-- ========
--
-- **pandoc** **-L** *unit-tests.lua* -o /dev/null FILE
--
--
-- DESCRIPTION
-- ===========
--
-- A fake Pandoc filter that runs unit tests for for pandoc-zotxt.lua.
-- Which tests are run is depeonds on the `test` metadata field, which is
-- passed as is to `lu.LuaUnit.run`. If it is not set, all tests are run.
--
--
-- SEE ALSO
-- ========
--
-- <https://luaunit.readthedocs.io/>
--
--
-- @script unit-tests.lua
-- @author Odin Kroeger
-- @copyright 2018, 2019, 2020, 2021, 2022 Odin Kroeger
-- @license MIT

-- luacheck: allow defined top, no global

--- Initialisation
-- @section

local concat = table.concat
local pack = table.pack
local unpack = table.unpack

-- luacheck: push ignore
if not pandoc.utils then pandoc.utils = require 'pandoc.utils' end
local stringify = pandoc.utils.stringify
-- luacheck: pop

local MetaInlines = pandoc.MetaInlines
local Null = pandoc.Null
local Para = pandoc.Para
local Space = pandoc.Space
local Str = pandoc.Str


-- Libraries

--- The path segment separator used by the operating system.
PATH_SEP = package.config:sub(1, 1)

--- The end of line sequence used on the given operating system.
EOL = '\n'
if PATH_SEP == '\\' then EOL = '\r\n' end

--- Join multiple path segments.
--
-- @string ... Path segments.
-- @treturn string A path.
--
-- @function path_join
function path_join (...)
    return path_normalise(concat({...}, PATH_SEP))
end

do
    -- Patterns that normalise directory paths.
    -- The order of these patterns is significant.
    local patterns = {
        -- Replace '/./' with '/'.
        {PATH_SEP .. '%.' .. PATH_SEP, PATH_SEP},
        -- Replace a sequence of '/'s with a single '/'.
        {PATH_SEP .. '+', PATH_SEP},
        -- Remove trailing '/'s, but not for the root node.
        {'(.)' .. PATH_SEP .. '$', '%1'},
        -- Remove './' at the beginning of a path.
        {'^%.' .. PATH_SEP, ''}
    }

    --- Normalise a path.
    --
    -- @string path A path.
    -- @treturn string A normalised path.
    --
    -- @function path_normalise
    function path_normalise (path)
        assert(path ~= '', 'path is the empty string.')
        for i = 1, #patterns do path = path:gsub(unpack(patterns[i])) end
        return path
    end
end

do
    -- Pattern to split a path into a directory and a filename part.
    local pattern = '(.-' .. PATH_SEP .. '?)([^' .. PATH_SEP .. ']-)$'

    --- Split a path into a directory and a filename.
    --
    -- @string path A path.
    -- @treturn string The directory the file is in.
    -- @treturn string The file's name.
    --
    -- @function path_split
    function path_split (path)
        assert(path ~= '', 'path is the empty string.')
        local dir, fname = path:match(pattern)
        if     dir == ''   then dir = '.'
        elseif fname == '' then fname = '.'
        end
        return path_normalise(dir), fname
    end
end

-- luacheck: globals PANDOC_SCRIPT_FILE
--- The directory of this script.
local SCPT_DIR = path_split(PANDOC_SCRIPT_FILE)

--- The directory of the test suite.
local TEST_DIR = path_join(SCPT_DIR, '..')

--- The test suite's data directory.
local DATA_DIR = path_join(TEST_DIR, 'data')

--- The test suite's tempory directory.
local TMP_DIR = path_join(TEST_DIR, 'tmp')

--- The repository directory.
local REPO_DIR = path_join(TEST_DIR, '..')

do
    package.path = concat({package.path,
        path_join(SCPT_DIR, '?.lua'),
        path_join(REPO_DIR, 'share', 'lua', '5.4', '?.lua')
    }, ';')
end


local lu = require 'luaunit'
local json = require 'lunajson'
local yaml = require 'tinyyaml'

local M = require 'test-wrapper'

-- Shorthands.
local assert_equals = lu.assert_equals
local assert_error_msg_matches = lu.assert_error_msg_matches
local assert_false = lu.assert_false
local assert_items_equals = lu.assert_items_equals
local assert_nil = lu.assert_nil
local assert_str_matches = lu.assert_str_matches
local assert_true = lu.assert_true


--- Constants
-- @section

--- Bibliographic data as JSON string.
ZOTXT_JSON = M.file_read(M.path_join(DATA_DIR, 'bibliography.json'))

--- Bibliographic data in CSL to compare data retrieved via zotxt to.
-- luacheck: globals ZOTXT_CSL
ZOTXT_CSL = M.csl_json_to_items(ZOTXT_JSON)

--- Bibliographic data as returned from a CSL YAML bibliography file.
ZOTXT_YAML = {
    {
        author={{family="Crenshaw", given="Kimberlé"}},
        id="crenshaw1989DemarginalizingIntersectionRace",
        issued={["date-parts"]={{'1989'}}},
        title="Demarginalizing the intersection of race and sex",
        type="article-journal"
    }
}

--- Bibliographic data as stored in the metadata block.
if pandoc.types and PANDOC_VERSION <= {2, 14} then
    ZOTXT_META = {
        {
            author={{text="Kimberlé"}, {}, {text="Crenshaw"}},
            id={{text="crenshaw1989DemarginalizingIntersectionRace"}},
            issued={["date-parts"]={{{{text="1989"}}}}},
            title={{text="Demarginalizing"}, {}, {text="the"}, {},
                {text="intersection"}, {}, {text="of"}, {}, {text="race"},
                {}, {text="and"}, {}, {text="sex"}
            },
            type={{text="article-journal"}}
        }
    }
else
    ZOTXT_META = {
        {
            author={Str "Kimberlé", Space(), Str "Crenshaw"},
            id={Str "crenshaw1989DemarginalizingIntersectionRace"},
            issued={["date-parts"]={{{Str "1989"}}}},
            title={Str "Demarginalizing", Space(), Str "the", Space(),
                Str "intersection", Space(), Str "of", Space(), Str "race",
                Space(), Str "and", Space(), Str "sex"
            },
            type={Str "article-journal"}
        }
    }
end

--- API key for the Zotero Web API.
ZOTWEB_API_KEY = 'MO2GHxbkLnWgCqPtpoewgwIl'

--- Bibliographic data as returned by the Zotero Web API.
ZOTWEB_CSL = {
    isbn = '978-0-19-989262-4',
    author = {{family = 'Haslanger', given = 'Sally'}},
    ['event-place'] = 'Oxford',
    id = 'haslanger2012ResistingRealitySocial',
    issued = {['date-parts'] = {{'2012'}}},
    note = 'citation key: haslanger2012ResistingRealitySocial',
    publisher = 'Oxford University Press',
    ['publisher-place'] = 'Oxford',
    shorttitle = 'Resisting Reality',
    title = 'Resisting Reality: Social Construction and Social Critique',
    type = 'book'
}


--- Functions
-- @section

--- Return the given arguments.
--
-- @param ... Arguments.
-- @return The same arguments.
function id (...) return ... end

--- Return `nil`.
--
-- @treturn nil `nil`.
function nilify () return end

--- Read a Markdown file.
--
-- @tparam string fname A filename.
-- @treturn[1] pandoc.Pandoc A Pandoc AST.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] number An error number.
-- @raise An error if the file is not valid Markdown.
--  This error can only be caught since Pandoc v2.11.
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
-- @string fname A filename.
-- @return[1] The data.
-- @treturn[2] nil `nil` if an error occurred.
-- @treturn[2] string An error message.
-- @treturn[2] int An error number.
--  Positive numbers are OS error numbers,
--  negative numbers indicate a YAML decoding error.
function read_json_file (fname)
    local str, err, errno = M.file_read(fname)
    if not str then return nil, err, errno end
    local ok, data = pcall(json.decode, str)
    if not ok then
        return nil, fname .. ': JSON decoding error: ' .. data, -1
    end
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
    -- @tab data Data.
    -- @return The data with numbers converted to strings.
    -- @raise An error if the data is nested too deeply.
    function rconv_nums_to_strs (data)
        return M.walk(data, conv)
    end
end


--- Generate the list of all partial lists of a list.
--
-- @tab list A list.
-- @treturn M.Value The list of all partial lists of the list.
function powerset (list)
    local power = M.Values:new(M.Values:new())
    for i = 1, #list do
        for j = 1, power.n do
            power:add(power[j]:new(list[i]))
        end
    end
    return power
end


--- Tests
-- @section

do
    local err_pattern = '.-%f[%a]expected [%a%s]+, got %a+%.$'
    local values = {
        ['nil'] = {nil},
        ['boolean'] = {true, false},
        ['number'] = {math.huge * -1, 0, 1, math.huge},
        ['string'] = {''},
        ['table'] = {{}},
        ['function'] = {function () end},
        ['thread'] = {coroutine.create(function () end)}
    }
    local type_lists = powerset(M.keys(values))

    function make_type_match_test (func)
        return function ()
            local cycle = {}
            cycle[1] = cycle

            for args, pattern in pairs{
                [{true, true}] =
                    '.-%f[%a]expected string or table, got boolean.',
                [{true, ''}] =
                    '.-%f[%a]malformed type declaration%.$',
                [{true, '-nil'}] =
                    '.-%f[%a]malformed type declaration%.$',
                [{cycle, cycle}] =
                    '.-%f[%a]cycle in data tree.',
            } do
                local val, td = unpack(args)
                assert_error_msg_matches(pattern, func, val, td, true)
            end

            local ok, err
            for i = 1, type_lists.n do
                local type_list = type_lists[i]
                local type_spec = concat(type_list, '|')
                for t, vs in pairs(values) do
                    for j = 1, #vs do
                        local v = vs[j]
                        local opt_type_spec = '?' .. type_spec
                        local star_spec = '*|' .. type_spec
                        if type_spec:match(t) then
                            for _, ts in pairs{
                                type_spec,
                                opt_type_spec,
                                star_spec
                            } do
                                for _, argv in pairs{
                                    {v, ts},
                                    {{foo = v}, {foo = ts}}
                                } do
                                    ok, err = func(unpack(argv))
                                    assert_nil(err)
                                    assert_true(ok)
                                end
                            end
                        elseif type_spec ~= '' then
                            for _, argv in pairs{
                                {v, type_spec},
                                {{foo = v}, {foo = type_spec}}
                            } do
                                ok, err = func(unpack(argv))
                                assert_true(ok == nil or ok == false)
                                assert_str_matches(err, err_pattern)
                                if v == nil then
                                    ok, err = func(unpack(argv))
                                    assert_nil(err)
                                    assert_true(ok)
                                else
                                    ok, err = func(unpack(argv))
                                    assert_true(ok == nil or ok == false)
                                    assert_str_matches(err, err_pattern)
                                end
                            end

                        end
                    end
                end

                local args = {}
                local opt_type_list = {}
                local star_list = {}
                for j = 1, #type_list do
                    args[j] = values[type_list[j]][1]
                    opt_type_list[j] = '?' .. type_list[j]
                    star_list[j] = '*|' .. type_list[j]
                end
                for _, tl in pairs{type_list, opt_type_list, star_list} do
                    ok, err = func(args, tl)
                    assert_nil(err)
                    assert_true(ok)
                end
            end

            for _, vs in pairs(values) do
                for i = 1, #vs do
                    local v = vs[i]
                    for _, argv in pairs{
                        {v, '*'},
                        {{foo = v}, {foo = '*'}}
                    } do
                        if v == nil then
                            ok, err = func(unpack(argv))
                            assert_true(ok == nil or ok == false)
                            assert_str_matches(err, err_pattern)
                        else
                            ok, err = func(unpack(argv))
                            assert_nil(err)
                            assert_true(ok)
                        end
                    end
                    for _, argv in pairs{
                        {v, '?*'},
                        {{foo = v}, {foo = '?*'}}
                    } do
                        ok, err = func(unpack(argv))
                        assert_nil(err)
                        assert_true(ok)
                    end
                end
            end

            for argv, pattern in pairs{
                [{{1, '2'}, {'number', 'number'}}] =
                    '.-%f[%a]index 2: expected number, got string%.$',
                [{{foo = 'bar'}, {foo = '?table'}}] =
                    '.-%f[%a]index foo: expected table or nil, got string%.$',
                [{'foo', {foo = '?table'}}] =
                    '.-%f[%a]expected table or userdata, got string%.$'
            } do
                ok, err = func(unpack(argv))
                assert_true(ok == nil or ok == false)
                assert_str_matches(err, pattern)
            end
        end
    end

    test_type_match = make_type_match_test(function(val, td)
        return M.type_match(val, td)
    end)

    function test_typed_args ()
        local typed_args = M.typed_args

        make_type_match_test(function (val, td, unprotected)
            local func = typed_args(td)(nilify)
            if unprotected then return func(val) end
            return pcall(func, val)
        end)()

        for t, vs in pairs(values) do
            local func = M.typed_args(t, '...')(nilify)
            local ok, err
            for i = 1, #vs do
                local v = vs[i]
                for _, args in ipairs{
                    {v, v},
                    {v, v, nil},
                    {v, v, v}
                } do
                    ok, err = pcall(func, unpack(args))
                    assert_nil(err)
                    assert_true(ok)
                end
                for at, avs in pairs(values) do
                    if at ~= t then
                        for j = 1, #avs do
                            local av = avs[j]
                            if av ~= nil then
                                for _, args in ipairs{
                                    {v, nil, v},
                                    {v, av},
                                    {v, av, v},
                                    {v, v, av},
                                    {v, av, av},
                                    {v, v, v, av}
                                } do
                                    ok, err = pcall(func, unpack(args))
                                    assert_false(ok)
                                    assert_str_matches(err, err_pattern)
                                end
                            end
                        end
                    end
                end
            end
        end
        return true
    end
end


--- Variables
-- @section

function test_vars_get ()
    local function bar ()
        assert_equals(M.vars_get(3).foo, 'foo')
    end
    local function foo ()
        -- luacheck: ignore foo
        local foo = 'foo'
        bar()
    end
    foo()

    local function bar_rw ()
        local foo = M.vars_get(3).foo
        assert_equals(foo.bar, 'bar')
        foo.bar = 'bam!'
    end
    local function foo_rw ()
        local foo = {bar = 'bar'}
        bar_rw()
        assert_equals(foo.bar, 'bar')
    end
    foo_rw()
end


--- Tables
-- @section

function test_ignore_case ()
    local tab = setmetatable({}, M.ignore_case)

    local str = 'mIxEd'
    for i, new_index in ipairs{
        str,
        str:lower(),
        str:upper()
    } do
        tab[new_index] = i
        for _, index in ipairs{
            new_index,
            new_index:lower(),
            new_index:upper()
        } do
            assert_equals(tab[index], i)
        end
    end

    for i, non_str in ipairs{
        true, false,
        -math.huge, -1, 0, 1, math.huge,
        {}, {{}},
        function () end,
        coroutine.create(function () end)
    } do
        tab[non_str] = i
        assert_equals(tab[non_str], i)
    end
end

function test_copy ()
    -- Test a shallow copy.
    local mt = {}
    local tab = setmetatable({foo = 'bar', bar = {baz = true}}, mt)
    local cp = M.copy(tab, false)
    assert_items_equals(tab, cp)
    assert_equals(getmetatable(cp), getmetatable(tab))

    cp.bar.baz = false
    assert_items_equals(tab, cp)
    assert_false(tab.bar.baz)

    -- Test simple copies.
    for _, val in ipairs{
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
    } do
        cp = M.copy(val)
        assert_items_equals(cp, val)
    end

    -- Test a nested table.
    tab = {1, 2, 3, {1, 2, 3, {4, 5, 6}}}
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a self-referential table.
    tab = {1, 2, 3}
    tab.tab = tab
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a table that has another table as key.
    tab = {1, 2, 3}
    local other_tab = {1, 2, 3, {4, 5, 6}}
    other_tab[tab] = 7
    cp = M.copy(other_tab)
    assert_items_equals(cp, other_tab)

    -- Test a table that overrides `__pairs`.
    local single = {__pairs = function ()
        return function () end
    end}
    tab = setmetatable({1, 2, 3}, single)
    cp = M.copy(tab)
    assert_items_equals(cp, tab)

    -- Test a table that does all of this.
    tab = setmetatable({1, 2, 3, {4, 5}}, single)
    other_tab = {1, 2, 3, {4, 5, 6}}
    tab[other_tab] = {1, 2, 3, {4, 5}}
    tab.tab = tab
    cp = M.copy(tab)
    assert_items_equals(cp, tab)
end

function test_keys ()
    for input, output in pairs{
        [{}] =        {keys = {},        n = 0},
        [{1, 2, 3}] = {keys = {1, 2, 3}, n = 3},
        [{a = 1, b = 2, c = 3}] = {
            keys = {'a', 'b', 'c'},
            n = 3
        },
        [{a = 1, [{}] = 2}] = {
            keys = {'a', {}},
            n = 2
        },
        [{[{}]='a'}] = {keys = {{}},     n = 1},
        [{[{}]='a', [false]='b'}] = {
            keys = {{}, false},
            n = 2
        }
    } do
        local keys, n = M.keys(input)
        assert_items_equals(keys, output.keys)
        assert_equals(n, output.n)
    end
end

function test_order ()
    for input, output in pairs{
        [{order = {3},    data = {1, 2, 3}}] = {3, 1, 2},
        [{order = {},     data = {3, 2, 1}}] = {1, 2, 3},
        [{order = {3, 2}, data = {1, 2, 3}}] = {3, 2, 1},
        [{order = {3, 2}, data = {}}] = {},
        [{order = {},     data = {}}] = {}
    } do
        local func = M.order(input.order)
        table.sort(input.data, func)
        assert_equals(input.data, output)
    end
end

function test_sorted ()
    local unsorted = {c=3, F=9, another=1}
    local sorted = {'F', 'another', 'c'}
    local i = 0
    for k, v in M.sorted(unsorted) do
        i = i + 1
        assert_equals(k, sorted[i])
        assert_equals(v, unsorted[k])
    end

    local function rev (a, b) return b < a end
    unsorted = {c=3, F=9, another=1}
    sorted = {'c', 'another', 'F'}
    i = 0
    for k, v in M.sorted(unsorted, rev) do
        i = i + 1
        assert_equals(k, sorted[i])
        assert_equals(v, unsorted[k])
    end
end

function test_tabulate ()
    local function make_stateful_iterator (n)
        local i = n
        return function ()
            if i > 3 then return end
            i = i + 1
            return i
        end
    end

    local tests = {
        [make_stateful_iterator(0)] = {},
        [make_stateful_iterator(1)] = {1},
        [make_stateful_iterator(3)] = {1, 2, 3},
        [M.split('a/b/c', '/')] = {'a', 'b', 'c'},
        [M.split('a/b/c', 'x')] = {'a/b/c'},
        [function () end] = {}
    }

    for k, v in ipairs(tests) do
        assert_items_equal(table.pack(k), v)
    end
end

function test_update ()
    local tab = {foo = 'bar'}
    local other_tab = {bar = 'baz', baz = {}}
    M.update(tab, other_tab)
    assert_items_equals(tab, {foo = 'bar', bar = 'baz', baz = {}})
    assert_nil(other_tab.foo)
    table.insert(tab.baz, 'bam!')
    assert_equals(other_tab.baz[1], 'bam!')
end

function test_walk ()
    local cycle = {}
    cycle.cycle = cycle

    for _, tab in ipairs{
        {{}}, 1, ZOTXT_CSL, ZOTXT_JSON, ZOTXT_YAML, ZOTXT_META,
        false, {['false']=1}, {{{[false]=true}, 0}}, 'string',
        cycle
    } do
        assert_equals(M.walk(tab, id), tab)
        assert_equals(M.walk(tab, nilify), tab)
    end

    local function inc (v)
        if type(v) ~= 'number' then return v end
        return v + 1
    end

    for input, output in pairs{
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
    } do
        assert_equals(M.walk(input, inc), output)
    end
end



-- File I/O
-- --------


function test_path_normalise ()
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
        assert_equals(M.path_prettify(k), v)
    end
end

function test_path_split ()
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
        assert_equals(dir, v[1])
        assert_equals(fname, v[2])
    end
end


function test_path_join ()
    assert_equals(M.path_join('a', 'b'), 'a' .. M.PATH_SEP .. 'b')
    assert_equals(M.path_join('a', M.PATH_SEP .. 'b'),
                     'a' .. M.PATH_SEP .. 'b')
    assert_equals(M.path_join('a' .. M.PATH_SEP, 'b'),
                     'a' .. M.PATH_SEP .. 'b')
end

function test_path_is_abs ()
    local tests = {
        [M.PATH_SEP]                  = true,
        [M.PATH_SEP .. 'test']        = true,
        ['test']                      = false,
        [M.path_join('test', 'test')] = false,
    }

    for k, v in pairs(tests) do
        assert_equals(M.path_is_abs(k), v)
    end
end

function test_path_prettify ()
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
    end

    for k, v in pairs(tests) do
        assert_equals(M.path_prettify(k), v)
    end
end

function test_wd ()
    assert_equals(M.wd(), '/dev')
end

function test_file_exists ()
    lu.assert_true(M.file_exists(PANDOC_SCRIPT_FILE))
    local ok, _, errno = M.file_exists('<does not exist>')
    lu.assert_nil(ok)
    assert_equals(errno, 2)
end

function test_file_read ()
    local ok, err, errno = M.file_read('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    assert_equals(errno, 2)

    local fname = M.path_join(DATA_DIR, 'bibliography.json')
    local str, err, errno = M.file_read(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(str)
    lu.assert_nil(errno)
    assert_equals(str, ZOTXT_JSON)
end

function test_file_write ()

    local ok, err, errno = M.file_read('<does not exist>')
    lu.assert_nil(ok)
    lu.assert_not_equals(err, '')
    assert_equals(errno, 2)

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

    assert_equals(data, ZOTXT_JSON)

    ok, err = M.file_write(fname, 'a', 'b', 'c')
    if not ok then error(err) end
    data, err = M.file_read(fname)
    if not data then error(err) end
    assert_equals(data, 'abc')
end

function test_tmp_fname ()

    local tests = {
        [{nil, nil}] = '^pdz%-%w%w%w%w%w%w$',
        [{nil, 'test_XXXXXXXXX'}] = '^test_%w%w%w%w%w%w%w%w%w$',
        [{'/tmp', nil}] = '^/tmp' .. M.PATH_SEP .. 'pdz%-%w%w%w%w%w%w$',
        [{'/tmp', 'XXXXXXX'}] = '^/tmp' .. M.PATH_SEP .. '%w%w%w%w%w%w%w$'
    }

    for k, v in pairs(tests) do
        local fname, err = M.tmp_fname(unpack(k))
        if not fname then error(err) end
        lu.assert_str_matches(fname, v)
    end

    local f1 = M.tmp_fname()
    local f2 = M.tmp_fname()
    lu.assert_not_equals(f1, f2)
end

function test_with_tmp_file ()

    local tmp_file_copy
    M.with_tmp_file(function (tmp_file)
        tmp_file_copy = tmp_file
        return true
    end)

    lu.assert_not_nil(tmp_file_copy)
    lu.assert_nil(M.file_exists(tmp_file_copy))

    tmp_file_copy = nil
    pcall(M.with_tmp_file, function (tmp_file)
        tmp_file_copy = tmp_file
        error 'test'
    end)

    lu.assert_not_nil(tmp_file_copy)
    lu.assert_nil(M.file_exists(tmp_file_copy))
end


-- Values prototype
-- ------------------

function test_values_add ()
    local t = M.Values()
    for i = 1, 4 do
        for j = 1, 4 do
            t:add(i, j)
        end
    end
    assert_equals(t.n, 32)
    assert_equals(t.n, #t)
end


-- String manipulation
-- -------------------

function test_split ()
    local tests = {
        [{'string', '%s*:%s*'}] = {'string', n = 1},
        [{'key: value:', '%s*:%s*'}] = {'key', 'value', '', n = 3},
        [{'val, val, val', ',%s*'}] = {'val', 'val', 'val', n = 3},
        [{', val , val', '%s*,%s*'}] = {'', 'val', 'val', n = 3},
        [{'key: value', ': '}] = {'key', 'value', n = 2},
        [{'key: value:x', '%s*:%s*', 2}] = {'key', 'value:x', n = 2},
        [{'val, val, val', ',%s*', 2}] = {'val', 'val, val', n = 2},
        [{'CamelCaseTest', '%u', nil, 'l'}] =
            {'', 'Camel', 'Case', 'Test', n = 4},
        [{'CamelCaseTest', '%u', nil, 'r'}] =
            {'C', 'amelC', 'aseT', 'est', n = 4},
        [{'CamelCaseTest', '%u', 2, 'l'}] =
            {'', 'CamelCaseTest', n = 2},
        [{'CamelCaseTest', '%u', 2, 'r'}] =
            {'C', 'amelCaseTest', n = 2}
        }

    for k, v in pairs(tests) do
        assert_items_equals(pack(M.tabulate(M.split(unpack(k)))), v)
    end
end

function test_vars_sub ()
    lu.assert_error_msg_matches('.+: cycle in variable lookup%.',
                                M.vars_sub, '${a}', {a = '${b}', b = '${a}'})

    local tests = {
        [{'${test}', {}}] = 'nil',
        [{'${test}', {}}] = 'nil',
        [{'$${test}$', {test = 'nok'}}] = '${test}',
        [{'${test}$', {test = 'ok'}}] = 'ok',
        [{'$${test|func}', {
            test = 'nok',
            func = function ()
                return 'NOK'
            end }}] = '${test|func}',
        [{'${test|func}', {
            test = 'nok',
            func = function (s)
                return s:gsub('nok', 'ok')
            end }}] = 'ok',
        [{'${test.test}', {
            test = { test = 'ok' }
        }}] = 'ok',
        [{'${test.test.test.test}', {
            test = { test = { test = { test ='ok' } } }
        }}] = 'ok',
        [{'${test|func}', {
            test = 'nok',
            func = function (s)
                return s:gsub('nok', '${v2|f2}')
            end,
            v2 = 'nok2',
            f2 = function (s)
                return s:gsub('nok2', 'ok')
            end
        }}] = 'ok',
        [{'${2}', {['2'] = 'ok'}}] = 'ok',
        [{'${test.test.test|test.func}', {
            test = {
                test = {test = 'nok'},
                func = function (s)
                    return s:gsub('nok', '${v2|f2}')
                end
            },
            v2 = 'nok2',
            f2 = function (s)
                return s:gsub('nok2', 'ok')
            end
        }}] = 'ok',
        [{'${2}', {['2'] = 'ok'}}] = 'ok'
    }

    for k, v in pairs(tests) do
        assert_equals(M.vars_sub(unpack(k)), v)
    end
end


-- Table manipulation
-- ------------------






-- Converters
-- ----------

function test_escape_markdown ()

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
        local ret = M.escape_markdown(i)
        assert_equals(ret, o)
        -- luacheck: ignore ret
        local doc = pandoc.read(ret, 'markdown-smart')
        lu.assert_not_nil(doc)
        if  doc.blocks[1]        and
            not i:match '^%s'    and
            not i:match '%s$'    and
            not i:match '^%s*%*' and
            not i:match '\\'
        then
            assert_equals(i, stringify(doc.blocks[1].content))
        end
    end
end

function test_zotero_to_markdown ()
    local pt = {nil, 0, false, {}, function () end}
    for _, v in ipairs(pt) do
        assert_equals(M.zotero_to_markdown(v), v)
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
        assert_equals(M.zotero_to_markdown(i), o)
    end
end

function test_markdownify ()
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
    local cycle = {}
    cycle.cycle = cycle
    lu.assert_error_msg_matches('.+: cycle in data tree%.', M.yamlify, cycle)

    local tests = {
        [3] = "3",
        ['3'] = '"3"',
        ['test'] = '"test"',
        [{'test'}] = '- "test"',
        ['test test'] = '"test test"',
        [{['test test'] = 0}] = 'test test: 0',
        ['test\ntest'] = '"test' .. M.EOL .. 'test"',
        ['test\r\ntest'] = '"test' .. M.EOL .. 'test"',
        ['test' .. utf8.char(0x7f) .. 'test'] = '"test\\x7ftest"',
        ['test' .. utf8.char(0xda99) .. 'test'] = '"test\\uda99test"'
    }
    for k, v in pairs(tests) do
        assert_equals(M.yamlify(k) ,v)
    end

    local str = M.yamlify(ZOTXT_CSL)
    local csl = rconv_nums_to_strs(yaml.parse(str))
    assert_equals(csl, ZOTXT_CSL)
end

function test_options_add ()
    local options = M.Options()
    local add = options.add

    local errors = {
        {'argument 2: expected table or userdata, got nil%.', add, options},
        {'argument 2: expected table or userdata, got nil%.', add, options, nil},
        {'argument 2: expected table or userdata, got boolean%.', add, options, true},
        {'argument 2: index name: expected string, got nil%.', add, options, {}},
        {'argument 2: index parse: expected function or nil, got boolean%.', add, options, {name = 'n', parse = true}}
    }

    for _, v in ipairs(errors) do
        lu.assert_error_msg_matches(unpack(v))
    end

    lu.assert_true(pcall(add, options, {name = 'test'}))
end

function test_options_parse ()
    local meta = pandoc.MetaMap{
        ['zotero-test'] = pandoc.MetaInlines{pandoc.Str 'test'},
        ['zotero-unstr'] = pandoc.MetaMap{},
        ['zotero-list'] = pandoc.MetaInlines{pandoc.Str 'test'},
        ['zotero-num-list'] = 3,
        ['zotero-higher-ord'] = pandoc.MetaInlines{pandoc.Str 'test'},
        ['zotero-nil'] = 'not yet nil'
    }

    local erroneous = {
        [{prefix = 'zotero', name = 'unstr'}] = 'zotero-unstr: not a string or empty.',
    }

    for k, v in pairs(erroneous) do
        local parser = M.Options()
        parser:add(k)
        lu.assert_error_msg_equals(
            v,
            parser.parse,
            parser,
            meta
        )
    end

    local missing = {
        [{name = 'test', check = nilify}] = nil,
    }
    for k, v in pairs(missing) do
        local parser = M.Options()
        parser:add(M.Setting:new(k))
        local ok, msg = parser:parse(meta)
        lu.assert_nil(ok)
        assert_equals(msg, v)
    end

    local conf_parser = M.Options()
    conf_parser:add({prefix = 'zotero', name = 'test'})
    conf_parser:add({prefix = 'zotero', name = 'list', type = 'list'})
    conf_parser:add({prefix = 'zotero', name = 'num_list', type = 'list', parse = id})
    conf_parser:add({prefix = 'zotero', name = 'higher_ord', type = 'list<list>'})

    local conf = conf_parser:parse(meta)

    assert_equals(conf.test, 'test')
    assert_items_equals(conf.list, {'test'})
    assert_items_equals(conf.num_list, {'3'})
    assert_items_equals(conf.higher_ord, {{'test'}})
end


-- zotxt
-- -----

function test_zotero_fetch ()
    local ret, err = M.connectors.Zotxt:fetch('haslanger2012ResistingRealitySocial')
    lu.assert_nil(err)
    assert_equals(ret, rconv_nums_to_strs(ZOTXT_CSL[1]))
end

-- Zotero Web API
-- --------------

-- function test_zoteroweb_get_user_id ()
--     local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}
--     local ret, err = zoteroweb:get_user_id()
--     lu.assert_not_nil(ret)
--     lu.assert_nil(err)
--     assert_equals(ret, 5763466)
-- end

-- function test_zoteroweb_get_groups ()
--     local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}
--     local ret, err = zoteroweb:get_groups()
--     lu.assert_not_nil(ret)
--     lu.assert_nil(err)
--     assert_items_equals(ret, {4513095})
-- end

function test_zoteroweb_endpoints ()
    local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}
    local iter, err = zoteroweb:endpoints()
    lu.assert_not_nil(iter)
    lu.assert_nil(err)
    assert_items_equals(pack(M.tabulate(iter)), {
        'https://api.zotero.org/users/5763466/items/',
        'https://api.zotero.org/groups/4513095/items/',
        n = 2
    })

    iter, err = zoteroweb:endpoints 'FAKE0123'
    lu.assert_not_nil(iter)
    lu.assert_nil(err)
    assert_items_equals(pack(M.tabulate(iter)), {
        'https://api.zotero.org/users/5763466/items/FAKE0123',
        'https://api.zotero.org/groups/4513095/items/FAKE0123',
        n = 2
    })
end

function test_zoteroweb_search ()
    local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}

    local items, err = zoteroweb:search('haslanger', '2012', 'Resisting', 'Reality', 'Social')
    lu.assert_not_nil(items)
    lu.assert_nil(err)
    assert_equals(#items, 1)
    items[1].id = 'haslanger2012ResistingRealitySocial'
    assert_items_equals(items[1], ZOTWEB_CSL)
end

function test_zoteroweb_lookup ()
    local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}

    local item, err = zoteroweb:lookup 'D9HEKNWD'
    lu.assert_not_nil(item)
    lu.assert_nil(err)
    item.id = 'haslanger2012ResistingRealitySocial'
    assert_items_equals(item, ZOTWEB_CSL)
end

function test_zoteroweb_fetch ()
    local zoteroweb = M.connectors.ZoteroWeb:new{api_key = ZOTWEB_API_KEY}

    local ret, err = zoteroweb:fetch('haslanger2012ResistingRealitySocial')
    lu.assert_not_nil(ret)
    lu.assert_nil(err)
    assert_equals(ret, ZOTWEB_CSL)
end


-- Bibliography files
-- ------------------

function test_csl_varname_normalise ()
    local tests = {
        ['Citation Key'] = 'citation-key',
        ['ORIGINAL DATE'] = 'original-date',
        ['Author'] = 'author',
        ['BLA-bla bLa'] = 'bla-bla-bla'
    }
    for k, v in pairs(tests) do
        assert_equals(M.csl_varname_normalise(k), v)
    end

    local nok, err = M.csl_varname_normalise '!'
    lu.assert_nil(nok)
    lu.assert_str_matches(err, '.+: not a variable name%.')
end

function test_csl_item_normalise_vars ()
    local cycle = {}
    cycle.cycle = cycle
    assert_items_equals(M.csl_item_normalise_vars(cycle), cycle)

    local test = {
        ISBN = '978-0-19-989262-4',
        Author = {{Family = 'Haslanger', Given = 'Sally'}},
        ['Event place'] = 'Oxford',
        ID = 'haslanger2012ResistingRealitySocial',
        Issued = {['date-parts'] = {{'2012'}}},
        Note = 'citation key: haslanger2012ResistingRealitySocial',
        Publisher = 'Oxford University Press',
        ['Publisher place'] = 'Oxford',
        ShortTitle = 'Resisting Reality',
        Title = 'Resisting Reality: Social Construction and Social Critique',
        Type = 'book'
    }

    assert_equals(M.csl_item_normalise_vars(test), ZOTWEB_CSL)
end

function test_csl_item_extras ()

    local inputs = {
        {
            author = {{family = 'Doe', given = 'John'}},
            issued = {['date-parts'] = {{'2021'}}},
            note = [[
                Original date: 1970
                Original author: Doe || Jane
            ]],
            publisher = 'Unit test press',
            ['publisher-place'] = 'Vienna',
            title = 'Unit testing',
            type = 'book'
        },
        {
            author = {{family = 'Doe', given = 'John'}},
            issued = {['date-parts'] = {{'2021'}}},
            note = [[
                {:original-date: 1970}
                {:original-author: Doe || Jane}
            ]],
            publisher = 'Unit test press',
            ['publisher-place'] = 'Vienna',
            title = 'Unit testing',
            type = 'book'
        }
    }

    for _, i in ipairs(inputs) do
        local res = {}
        for k, v in M.csl_item_extras(i) do
            res[k] = v
        end

        assert_items_equals(res, {
            ['original-date'] = '1970',
            ['original-author'] = 'Doe || Jane'
        })
    end
end

function test_csl_item_add_extras ()

    local input = {
        author = {{family = 'Doe', given = 'John'}},
        issued = {['date-parts'] = {{'2021'}}},
        note = [[
            Original date: 1970
            Original author: Doe || Jane
        ]],
        publisher = 'Unit test press',
        ['publisher-place'] = 'Vienna',
        title = 'Unit testing',
        type = 'book'
    }
    local output = {
        author = {{family = 'Doe', given = 'John'}},
        ['original-author'] = {{family = 'Doe', given = 'Jane'}},
        issued = {['date-parts'] = {{'2021'}}},
        ['original-data'] = {['date-parts'] = {{'1970'}}},
        note = [[
            Original date: 1970
            Original author: Doe || Jane
        ]],
        publisher = 'Unit test press',
        ['publisher-place'] = 'Vienna',
        title = 'Unit testing',
        type = 'book'
    }
    assert_items_equals(M.csl_item_add_extras(M.copy(input)), output)

    input = {
        author = {{family = 'Doe', given = 'John'}},
        issued = {['date-parts'] = {{'2021'}}},
        note = [[
            {:original-date: 1970}
            {:original-author: Doe || Jane}
        ]],
        publisher = 'Unit test press',
        ['publisher-place'] = 'Vienna',
        title = 'Unit testing',
        type = 'book'
    }
    output = {
        author = {{family = 'Doe', given = 'John'}},
        ['original-author'] = {{family = 'Doe', given = 'Jane'}},
        issued = {['date-parts'] = {{'2021'}}},
        ['original-data'] = {['date-parts'] = {{'1970'}}},
        note = [[
            {:original-date: 1970}
            {:original-author: Doe || Jane}
        ]],
        publisher = 'Unit test press',
        ['publisher-place'] = 'Vienna',
        title = 'Unit testing',
        type = 'book'
    }

    assert_items_equals(M.csl_item_add_extras(M.copy(input)), output)
end

function test_csl_vars_sort ()
    lu.assert_true(M.csl_vars_sort('a', 'b'))
    lu.assert_false(M.csl_vars_sort('b', 'a'))
    lu.assert_true(M.csl_vars_sort('id', 'a'))
    lu.assert_false(M.csl_vars_sort('a', 'id'))
    lu.assert_true(M.csl_vars_sort('id', 'type'))
    lu.assert_false(M.csl_vars_sort('type', 'id'))
end

function test_csl_items_sort ()
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
        assert_equals(M.csl_items_sort(unpack(k)), v)
    end
end

function test_csl_items_ids ()
    assert_equals(M.csl_items_ids({}), {})
    assert_equals(M.csl_items_ids(ZOTXT_CSL),
        {haslanger2012ResistingRealitySocial=true})
    assert_equals(M.csl_items_ids(ZOTXT_YAML),
        {crenshaw1989DemarginalizingIntersectionRace=true})
end

function test_biblio_read ()
    local fname, data, err

    fname = M.path_join(DATA_DIR, 'bibliography.json')
    data, err = M.biblio:read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_CSL)

    fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    data, err = M.biblio:read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_YAML)
end

function test_csl_json_to_items ()
    local output = {
        author = {{family = 'Doe', given = 'John'}},
        issued = {['date-parts'] = {{'2021'}}},
        publisher = 'Unit test press',
        ['publisher-place'] = 'Vienna',
        title = 'Unit testing',
        type = 'book'
    }

    local tests = {
        [[
            {
                "author": [
                    {
                        "family": "Doe",
                        "given": "John"
                    }
                ],
                "issued": {
                    "date-parts": [
                        ["2021"]
                    ]
                },
                "publisher": "Unit test press",
                "publisher-place": "Vienna",
                "title": "Unit testing",
                "type": "book"
            }
        ]],
        [[
            {
                "Author": [
                    {
                        "family": "Doe",
                        "given": "John"
                    }
                ],
                "Issued": {
                    "Date parts": [
                        [2021]
                    ]
                },
                "Publisher": "Unit test press",
                "Publisher place": "Vienna",
                "Title": "Unit testing",
                "Type": "book"
            }
        ]]
    }

    for _, v in ipairs(tests) do
        assert_items_equals(M.csl_json_to_items(v), output)
    end
end

function test_citekey_to_terms ()
    local citekey_types = M.connectors.ZoteroWeb.citekey_types

    local tests = {
        [''] = nil,
        ['doe'] = {'doe'},
        ['doeWord'] = {'doe', 'Word'},
        ['doe:'] = nil,
        ['doe2020'] = {'doe', '2020'},
        ['doe:2020'] = {'doe', '2020'},
        ['doeWord2020'] = {'doe', 'Word', '2020'},
        ['doe:2020easy'] = {'doe', '2020', 'easy'},
        ['doe2020TwoWords'] = {'doe', '2020', 'Two', 'Words'}
    }

    for k, v in pairs(tests) do
        assert_items_equals(M.citekey:guess_terms(k, citekey_types), v)
    end
end

function test_biblio_write ()
    local fname, ok, fmt, data, err, errno

    fname = M.path_join(TMP_DIR, 'bibliography.json')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio:write(fname, {ZOTXT_CSL})
    assert_equals(fmt, 'json')
    lu.assert_nil(err)
    data, err = M.biblio:read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, {ZOTXT_CSL})

    fname = M.path_join(TMP_DIR, 'bibliography.yaml')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio:write(fname, ZOTXT_YAML)
    assert_equals(fmt, 'yaml')
    lu.assert_nil(err)
    data, err = M.biblio:read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_YAML)
end

-- @fixme
-- function test_biblio_types_mt___index ()
--     assert_equals(M.biblio.types.JSON, M.biblio.types.json);
--     assert_equals(M.biblio.types.JsOn, M.biblio.types.json);
-- end

function test_biblio_codecs_bib_decode ()
    local bib = M.biblio.types.bib
    local fname = M.path_join(DATA_DIR, 'bibliography.bib')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    local ids = M.csl_items_ids(bib.decode(str))
    assert_items_equals(ids, {
        ['crenshaw1989DemarginalizingIntersectionRace'] = true,
        ['díaz-león2015WhatSocialConstruction'] = true
    })
end


function test_biblio_codecs_yaml_decode ()
    -- luacheck: ignore yaml
    local yaml = M.biblio.types.yaml
    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    assert_items_equals(yaml.decode(str), ZOTXT_YAML)
end

function test_biblio_types_yaml_encode ()
    -- luacheck: ignore yaml
    local yaml = M.biblio.types.yaml
    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    assert_items_equals(yaml.decode(yaml.encode(ZOTXT_YAML)), ZOTXT_YAML)
end

function test_biblio_update ()
    local wrong = {'nosuffix', 'n.', 'n.wrongformat'}
    for _, v in ipairs(wrong) do
        local ok, err =  M.biblio:update(M.connectors.Zotxt, v, {'<n/a>'})
        lu.assert_nil(ok)
        lu.assert_not_nil(err)
    end

    local fname = M.path_join(TMP_DIR, 'update-biblio.json')

    -- Remove file, just in case.
    local data, ok, err, errno
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end

    -- Checks whether we do nothing if there's nothing to be done.
    ok, err = M.biblio:update(M.connectors.Zotxt, fname, {})
    if not ok then error(err) end
    ok, err, errno = os.remove(fname)
    if ok or errno ~= 2 then error(err) end

    -- Checks adding citations from zero.
    ok, err = M.biblio:update(M.connectors.Zotxt, fname, {'haslanger:2012resisting'})
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    local csl = M.copy(ZOTXT_CSL)
    csl[1].id = 'haslanger:2012resisting'
    assert_equals(data, rconv_nums_to_strs(csl))

    -- Checks adding a new citation.
    local new
    ckeys = {'haslanger:2012resisting', 'dotson:2016word'}
    ok, err = M.biblio:update(M.connectors.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    assert_equals(#data, 2)

    ok, err = M.biblio:update(M.connectors.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    new, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(new)
    assert_equals(new, data)

    -- This should not change the file.
    local post
    ok, err = M.biblio:update(M.connectors.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    post, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(post)
    assert_equals(new, post)
end


-- Pandoc
-- ------

function test_elem_type ()
    -- local non_pandoc = {nil, true, 1, 'string', {}, function () end}
    -- for _, v in ipairs(non_pandoc) do
    --     lu.assert_nil(M.elem_type(v))
    -- end

    local tests = {
        -- [Str 'test'] = {'Str', 'Inline', 'AstElement'},
        -- [{Str ''}] = {'Inlines'},
        -- [Para{Str ''}] = {'Para', 'Block', 'AstElement'},
        -- [{Para{Str ''}}] = {'Blocks'},
        -- [read_md_file(path_join(DATA_DIR, 'empty.md'))] = {'Pandoc'}
        -- @fixme Fails for the development version of Pandoc
        -- [MetaInlines{Str ''}] =
        --     {'MetaInlines', 'MetaValue', 'AstElement'}
    }

    for k, v in pairs(tests) do
        assert_equals(pack(M.elem_type(k)), v)
    end
end

function test_elem_walk ()
    local id = {AstElement = id}
    local nilify = {AstElement = nilify}

    for _, v in ipairs{nil, false, 0, '', {}, function () end} do
        assert_equals(M.elem_walk(v, del), v)
    end

    local fnames = {
        'betterbibtexkey.md', 'biblio-json.md', 'biblio-yaml.md',
        'dup-biblio-bib.md', 'dup-biblio-yaml.md', 'dup.md',
        'easykey.md', 'empty.md', 'ex-biblio.md',
        'ex-simple.md', 'issue-4-2.md', 'issue-4.md',
        'merge.md', 'pre-existing-mixed.md'
    }

    for _, v in ipairs(fnames) do
        local fname = M.path_join(DATA_DIR, v)
        local doc, err = read_md_file(fname)
        assert(doc, err)
        assert_equals(doc, M.elem_walk(doc, id))
        assert_equals(doc, M.elem_walk(doc, nilify))
    end

    local yesify = {Str = function (s)
        if stringify(s) == 'no' then return Str 'yes' end
    end}
    local yes = M.elem_walk(Str 'no', yesify)
    assert_equals(stringify(yes), 'yes')
    local no = M.elem_walk(Str 'no!', yesify)
    assert_equals(stringify(no), 'no!')

    local elem = Para{Str 'no'}
    local walked = M.elem_walk(elem, {
        Str = function () return Str 'yes' end,
        Para = function (p) if stringify(p) == 'no' then return Null() end end
    })
    assert_equals(stringify(walked), 'yes')
    lu.assert_false(pandoc.utils.equals(elem, walked))
end

function test_meta_sources ()
    -- luacheck: ignore err

    local empty_fname = M.path_join(DATA_DIR, 'empty.md')
    local empty, err = read_md_file(empty_fname)
    assert(empty, err)
    assert_equals(M.meta_sources(empty.meta), {})

    local test_fname = M.path_join(DATA_DIR, 'dup.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    assert_items_equals(M.meta_sources(test_file.meta), ZOTXT_META)

    test_fname = M.path_join(DATA_DIR, 'dup-biblio-yaml.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    assert_items_equals(M.meta_sources(test_file.meta), ZOTXT_YAML)

    test_fname = M.path_join(DATA_DIR, 'dup-biblio-bib.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ids = M.csl_items_ids(M.meta_sources(test_file.meta))
    assert_items_equals(ids, {
        ["crenshaw1989DemarginalizingIntersectionRace"] = true,
        ["díaz-león2015WhatSocialConstruction"] = true
    })
end

function test_doc_ckeys ()

    local empty_fname = M.path_join(DATA_DIR, 'empty.md')
    local empty = read_md_file(empty_fname)
    assert_equals(M.doc_ckeys(empty), {})

    local test_fname = M.path_join(DATA_DIR, 'easykey.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ckeys, n = M.doc_ckeys(test_file)
    assert_items_equals(ckeys, {
        'dotson:2016word',
        'díaz-león:2015what',
        'díaz-león:2015defence',
        'díaz-león:2016woman',
        'haslanger:2012resisting',
        'nobody:0000nothing'
    })
    assert_equals(n, 6)

    test_fname = M.path_join(DATA_DIR, 'dup.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    ckeys, n = M.doc_ckeys(test_file)
    assert_items_equals(ckeys,
        {'crenshaw1989DemarginalizingIntersectionRace'})
    assert_equals(n, 1)
    ckeys, n = M.doc_ckeys(test_file, true)
    assert_items_equals(ckeys, {})
    assert_equals(n, 0)

    test_fname = M.path_join(DATA_DIR, 'issue-7.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    assert_items_equals(M.doc_ckeys(test_file),
        {'crenshaw1989DemarginalizingIntersectionRace'})
    assert_items_equals(M.doc_ckeys(test_file, true),
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
    local test
    if doc.meta and doc.meta.test then test = stringify(doc.meta.test) end
    os.exit(lu.LuaUnit.run(test), true)
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}
