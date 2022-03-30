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

--- The repository directory.
local REPO_DIR = path_join(TEST_DIR, '..')

--- The test suite's data directory.
local DATA_DIR = path_join(TEST_DIR, 'data')

--- The test suite's tempory directory.
local TMP_DIR = os.getenv 'TMPDIR' or path_join(TEST_DIR, 'tmp')


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
local assert_not_equals = lu.assert_not_equals
local assert_error = lu.assert_error
local assert_error_msg_matches = lu.assert_error_msg_matches
local assert_false = lu.assert_false
local assert_items_equals = lu.assert_items_equals
local assert_nil = lu.assert_nil
local assert_not_nil = lu.assert_not_nil
local assert_str_matches = lu.assert_str_matches
local assert_true = lu.assert_true

local map = pandoc.List.map

--- Constants
-- @section

--- Bibliographic data as JSON string.
ZOTXT_JSON = M.file_read(M.path_join(DATA_DIR, 'bibliography.json'))

--- Bibliographic data in CSL to compare data retrieved via zotxt to.
-- luacheck: globals ZOTXT_CSL
-- @fixme
-- if not pandoc.types and PANDOC_VERSION < {2, 17}
--     then ZOTXT_CSL = M.csl_json_parse(ZOTXT_JSON)
--     else ZOTXT_CSL = pandoc.read(ZOTXT_JSON, 'csljson').meta.references
-- end
ZOTXT_CSL = M.BIBLIO_DECODERS.json(ZOTXT_JSON)

--- Bibliographic data as returned from a CSL YAML bibliography file.
ZOTXT_YAML = {
    {
        author = {{family = "Crenshaw", given = "Kimberlé"}},
        id = "crenshaw1989DemarginalizingIntersectionRace",
        issued = {["date-parts"] = {{'1989'}}},
        title = "Demarginalizing the intersection of race and sex",
        type = "article-journal"
    }
}

--- Bibliographic data as stored in the metadata block.
if not pandoc.types or PANDOC_VERSION < {2, 15} then
    ZOTXT_META = {
        {
            author = {{text = "Kimberlé"}, {}, {text = "Crenshaw"}},
            id = {{text = "crenshaw1989DemarginalizingIntersectionRace"}},
            issued = {["date-parts"] = {{{{text = "1989"}}}}},
            title = {{text = "Demarginalizing"}, {}, {text = "the"}, {},
                {text = "intersection"}, {}, {text = "of"}, {},
                {text = "race"}, {}, {text = "and"}, {}, {text = "sex"}
            },
            type = {{text = "article-journal"}}
        }
    }
elseif PANDOC_VERSION < {2, 17} then
    ZOTXT_META = {
        {
            author = {Str "Kimberlé", Space(), Str "Crenshaw"},
            id = {Str "crenshaw1989DemarginalizingIntersectionRace"},
            issued = {["date-parts"] = {{{Str "1989"}}}},
            title = {Str "Demarginalizing", Space(), Str "the", Space(),
                Str "intersection", Space(), Str "of", Space(), Str "race",
                Space(), Str "and", Space(), Str "sex"
            },
            type = {Str "article-journal"}
        }
    }
else
    ZOTXT_META = {
        {
            author = {{literal = "Kimberlé Crenshaw"}},
            id = "crenshaw1989DemarginalizingIntersectionRace",
            issued = {["date-parts"] = {{1989}}},
            title = {Str "Demarginalizing", Space(), Str "the", Space(),
                Str "intersection", Space(), Str "of", Space(), Str "race",
                Space(), Str "and", Space(), Str "sex"
            },
            type = "article-journal"
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
-- @treturn tab The list of all partial lists of the list.
function powerset (list)
    local power = {{}}
    for i = 1, #list do
        local n = #power
        for j = 1, n do
            local o = power[j]
            local c = {}
            local m = #o
            for k = 1, m do c[k] = o[k] end
            c[m + 1] = list[i]
            n = n + 1
            power[n] = c
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
                [{cycle, cycle}] =
                    '.-%f[%a]cycle in data tree.',
            } do
                local val, td = unpack(args)
                assert_error_msg_matches(pattern, func, val, td, true)
            end

            local ok, err
            for i = 1, #type_lists do
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

    function test_type_check ()
        local type_check = M.type_check

        make_type_match_test(function (val, td, unprotected)
            local func = type_check(td)(nilify)
            if unprotected then return func(val) end
            return pcall(func, val)
        end)()

        for t, vs in pairs(values) do
            local func = M.type_check(t, '...')(nilify)
            local ok, err
            for i = 1, #vs do
                local v = vs[i]
                for _, args in ipairs{
                    {v, nil, v},
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
    for level, message in pairs{
        [-1] = '.-%f[%a]level is not a positive number%.',
        [1048576] = '.-%f[%a]stack is not that high%.$',
    } do
        assert_error_msg_matches(message, M.vars_get, level)
    end

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


--- Strings
-- @section

function test_split ()
    for input, message in pairs{
        [{'string', '%f[%a]'}] = '.-%f[%a]split does not support %%f%.$',
        [{'string', 'ri', nil, ''}] = '.-%f[%a]expecting "l" or "r"%.$'
    } do
        assert_error_msg_matches(message, M.split, unpack(input))
    end

    for input, output in pairs{
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
    } do
        assert_items_equals(pack(M.tabulate(M.split(unpack(input)))), output)
    end
end

function test_trim ()
    local ws = powerset{'\t', '\n', ' ', '\r'}
    for _, cs in pairs(ws) do
        local sp = concat(cs)
        for i = 1, 3 do
            local str
            if     i == 1 then str = sp .. 'string'
            elseif i == 2 then str = 'string' .. sp
            elseif i == 3 then str = sp .. 'string' .. sp
            end
            assert_items_equals(pack(M.trim(str)), {'string', n = 2})
        end
    end
end

function test_vars_sub ()
    for input, message in pairs{
        [{'${a}', {a = '${b}', b = '${a}'}}] =
            '.-%f[%$]${a}: ${b}: ${a}: cycle in lookup%.',
        [{'${}', {}}] =
            '.-%f[%$]${}: name is the empty string%.',
        [{'${x|}', {x = 'yo'}}] =
            '.-%f[%$]${x|}: name is the empty string%.',
        [{'${test}', {}}] =
            '.-%f[%$]${test}: test is undefined%.',
        [{'${foo|bar}', {foo = ''}}] =
            '.-%f[%$]${foo|bar}: bar is undefined%.',
        [{'${foo.bar}', {}}] =
            '.-%f[%$]${foo.bar}: index foo: expected table, got nil%.',
        [{'${foo.bar}', {foo = 'string'}}] =
            '.-%f[%$]${foo.bar}: index foo: expected table, got string%.',
        [{'${foo|bar}', {foo = 'bar', bar = 'bar'}}] =
            '${foo|bar}: bar: not a function.',
        [{'${foo|bar.baz}', {foo = 'bar'}}] =
            '${foo|bar.baz}: index bar: expected table, got nil%.'
    } do
        local ok, err = M.vars_sub(unpack(input))
        assert_nil(ok)
        assert_str_matches(err, message)
    end

    for input, output in pairs{
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
        }}] = '{v2|f2}',
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
        }}] = '{v2|f2}',
        [{'${2}', {['2'] = 'ok'}}] = 'ok'
    } do
        assert_equals(M.vars_sub(unpack(input)), output)
    end
end


--- Prototypes
-- @section

function test_object_clone ()
    local tab = {foo = 'yo'}
    local obj_mt = {foo = true, bar = {baz = true}}
    local Foo = M.Object:clone(tab, obj_mt)
    mt = getmetatable(Foo)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, true)
    obj_mt.baz = true
    assert_nil(mt.baz)
    obj_mt.bar.baz = false
    assert_equals(mt.bar.baz, false)
    assert_equals(tab.foo, 'yo')
    assert_equals(Foo, tab)

    local Bar = Foo:clone()
    mt = getmetatable(Bar)
    assert_equals(mt.__index, Foo)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)

    local baz = Bar:clone({}, {__index = M.Object})
    mt = getmetatable(baz)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)

    local obj_mt2 = {baz = true}
    local Baz = M.Object:clone({}, obj_mt, obj_mt2)
    mt = getmetatable(Baz)
    assert_equals(mt.__index, M.Object)
    assert_equals(mt.foo, true)
    assert_equals(mt.bar.baz, false)
    assert_equals(mt.baz, true)

    Foo = M.Object:clone({}, {__tostring = function (t) return t.bar end})
    Foo.bar = 'bar'
    assert_equals(tostring(Foo), 'bar')
    bar = Foo:clone()
    assert_equals(tostring(bar), 'bar')
    bar.bar = 'baz'
    assert_equals(tostring(bar), 'baz')
end

function test_object_new ()
    local args = {{foo = true}, {bar = false}}
    local a = M.Object:new(unpack(args))
    local b = M.update(M.Object:clone(), unpack(args))
    assert_items_equals(a, b)
    assert_items_equals(getmetatable(a), getmetatable(b))
end

function test_getterify ()
    local tab = {}
    local mt = {getters = {bar = function () return true end}}
    setmetatable(tab, mt)
    assert_nil(tab.bar)
    local tab2 = M.getterify(tab)
    assert_equals(tab, tab2)
    assert_true(tab.bar)
    assert_true(tab2.bar)
    tab.bar = false
    assert_false(tab.bar)
    assert_false(tab2.bar)

    local Foo = M.getterify(M.Object:clone())
    Foo.foo = 'bar'
    mt = getmetatable(Foo)
    mt.getters = {}
    function mt.getters.bar (obj) return obj.foo end
    assert_equals(Foo.bar, 'bar')
    local baz = Foo()
    baz.foo = 'bam!'
    assert_equals(baz.bar, 'bar')
    Foo.clone = function (...) return M.getterify(M.Object.clone(...)) end
    baz = Foo()
    baz.foo = 'bam!'
    assert_equals(baz.bar, 'bam!')
end


--- File I/O
-- @section

function test_path_normalise ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_normalise, '')

    for input, output in pairs{
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
    } do
        assert_equals(M.path_prettify(input), output)
    end
end

function test_path_split ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_split, '')

    for input, output in pairs{
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
    } do
        local dir, fname = M.path_split(input)
        assert_equals(dir, output[1])
        assert_equals(fname, output[2])
    end
end

function test_path_join ()
    for input, output in pairs{
        [{'a', 'b'}] = 'a' .. M.PATH_SEP .. 'b',
        [{'a', 'b', 'c'}] = 'a' .. M.PATH_SEP .. 'b' .. M.PATH_SEP .. 'c',
        [{'a', M.PATH_SEP .. 'b'}]  = 'a' .. M.PATH_SEP .. 'b',
        [{'a' .. M.PATH_SEP, 'b'}]  = 'a' .. M.PATH_SEP .. 'b'
    } do
        assert_equals(M.path_join(unpack(input)), output)
    end
end

function test_path_is_abs ()
    for input, output in pairs{
        [M.PATH_SEP]                  = true,
        [M.PATH_SEP .. 'test']        = true,
        ['test']                      = false,
        [M.path_join('test', 'test')] = false,
    } do
        assert_equals(M.path_is_abs(input), output)
    end

    if pandoc.types and PANDOC_VERSION >= {2, 12} then
        assert_equals(M.path_is_abs(M.path_make_abs('foo')), true)
    end
end

if pandoc.types and PANDOC_VERSION >= {2, 12} then
    function test_path_make_abs ()
        assert_error_msg_matches('.-%f[%a]path is the empty string.',
            M.path_make_abs, '')

        for input, output in ipairs{
            foo = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. 'foo'] = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. M.PATH_SEP .. 'foo'] = M.PATH_SEP .. 'foo',
            [M.PATH_SEP .. 'foo' .. M.PATH_SEP] = M.PATH_SEP .. 'foo',
        } do
            assert_equals(M.path_make_abs(input), output)
        end
    end
end

function test_path_prettify ()
    assert_error_msg_matches('.-%f[%a]path is the empty string.',
        M.path_prettify, '')

    local tests = {}
    local home = os.getenv('HOME')

    if M.PATH_SEP == '/' then
        tests[home] = home
        tests[home .. 'foo'] = home .. 'foo'
        tests[M.path_join(home, 'foo')] = '~/foo'
    end

    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        local cwd = pandoc.system.get_working_directory()
        local rwd
        if M.PATH_SEP == '/'
            then rwd = cwd:gsub('^' .. home .. M.PATH_SEP, '~' .. M.PATH_SEP)
            else rwd = cwd
        end
        tests[cwd] = rwd
        tests[cwd .. 'foo'] = rwd .. 'foo'
        tests[M.path_join(cwd, 'foo')] = 'foo'
    end

    for input, output in pairs(tests) do
        assert_equals(M.path_prettify(input), output)
    end
end

function test_project_dir ()
    assert_equals(M.project_dir(), '/dev')
end

function test_file_exists ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_exists, '')
    assert_true(M.file_exists(PANDOC_SCRIPT_FILE))
    local ok, _, errno = M.file_exists('<no such file>')
    assert_equals(errno, 2)
    assert_nil(ok)
end

function test_file_locate ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_locate, '')

    local ok, err = M.file_locate('<no such file>')
    assert_nil(ok)
    assert_equals(err, '<no such file>: not found in resource path.')

    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        -- luacheck: ignore err
        local cwd = pandoc.system.get_working_directory()
        local path = PANDOC_SCRIPT_FILE:gsub('^' .. cwd .. M.PATH_SEP, '')
        local fname, err = M.file_locate(path)
        assert_nil(err)
        assert_equals(fname, PANDOC_SCRIPT_FILE)
    end
end

function test_file_read ()
    assert_error_msg_matches('.-%f[%a]filename is the empty string.',
        M.file_read, '')

    local str, err, errno = M.file_read('<no such file>')
    assert_nil(str)
    assert_equals(err, '<no such file>: No such file or directory')
    assert_equals(errno,  2)

    local fname = M.path_join(DATA_DIR, 'bibliography.json')
    str, err, errno = M.file_read(fname)
    assert_nil(err)
    assert_nil(errno)
    assert_not_nil(str)
    assert_equals(str, ZOTXT_JSON)
end

function test_file_write ()
    local funcs = {[M.file_write_legacy] = true, [M.file_write] = true}
    if pandoc.types and PANDOC_VERSION >= {2, 8} then
        funcs[M.file_write_modern] = true
    end

    math.randomseed(os.time())
    local max = 2 ^ 32

    for func in pairs(funcs) do
        assert_error_msg_matches('.-%f[%a]filename is the empty string.',
            M.file_write, '')

        -- pandoc.system.with_temporary_directory raises an uncatchable
        -- error if it cannot create the temporary directory.
        if func == M.file_write_legacy then
            local ok, err, errno = func('<no such directory>/file', 'foo')
            assert_nil(ok)
            assert_str_matches(err, '.-No such file or directory.-')
            if errno ~= nil then assert_equals(errno, 2) end
        end

        local remove = os.remove
        local tmp_fname
        local _ = setmetatable({}, {__gc = function () remove(tmp_fname) end})

        tmp_fname = M.tmp_fname(TMP_DIR)
        local ok, err, errno = remove(tmp_fname)
        assert(ok or errno == 2, err)

        local wdata = string.pack('d', math.random(1, max))
        ok, err, errno = func(tmp_fname, wdata)
        assert_nil(err)
        assert_nil(errno)
        assert_true(ok)

        local rdata
        rdata, err, errno = M.file_read(tmp_fname)
        assert_nil(err)
        assert_nil(errno)
        assert_equals(rdata, wdata)
    end
end

function test_tmp_fname ()
    for input, msg in pairs {
        [{'', nil}] =
            '.-%f[%a]directory is the empty string.',
        [{'', 'tmp'}] =
            '.-%f[%a]directory is the empty string.',
    } do
        assert_error_msg_matches(msg, M.tmp_fname, unpack(input))
    end

    for input, output in pairs{
        [{nil, nil}] = '^pdz%-%w%w%w%w%w%w$',
        [{nil, 'test_XXXXXXXXX'}] = '^test_%w%w%w%w%w%w%w%w%w$',
        [{'/tmp', nil}] = '^/tmp' .. M.PATH_SEP .. 'pdz%-%w%w%w%w%w%w$',
        [{'/tmp', 'XXXXXXX'}] = '^/tmp' .. M.PATH_SEP .. '%w%w%w%w%w%w%w$'
    } do
        local fname = assert(M.tmp_fname(unpack(input)))
        assert_str_matches(fname, output)
    end

    local fnames = {}
    for i = 1, 4 do
        fnames[i] = assert(M.tmp_fname())
        for j = 2, i do
            if i ~= j then assert_not_equals(fnames[i], fnames[j]) end
        end
    end
end

function test_with_tmp_file ()
    local remove = os.remove
    local tmp_fname
    local _ = setmetatable({}, {__gc = function () remove(tmp_fname) end})

    for input, msg in pairs {
        [{'', nil}] =
            '.-%f[%a]directory is the empty string.',
        [{'', 'tmp'}] =
            '.-%f[%a]directory is the empty string.',
    } do
        assert_error_msg_matches(msg, M.with_tmp_file, nilify, unpack(input))
    end

    local function wrap (func)
        return function (fname)
            tmp_fname = fname
            local file, ok, err, errno
            ok, err, errno = remove(tmp_fname)
            assert(ok or errno == 2, err)
            file = assert(io.open(fname, 'w'))
            assert(file:write('foo'))
            assert(file:flush())
            assert(file:close())
            assert(M.file_exists(fname))
            return func()
        end
    end

    for i, func in ipairs(map({
        function () return true end,
        function () return end,
        function () error() end
    }, wrap)) do
        tmp_fname = nil
        local res = M.with_tmp_file(func)
        assert_not_nil(tmp_fname)
        assert_not_equals(tmp_fname, '')
        if i == 1 then
            assert_equals(res, true)
            assert_true(remove(tmp_fname))
        else
            assert_nil(res)
            assert_nil(M.file_exists(tmp_fname))
        end
    end
end


--- Markup converters
-- @section

function test_escape_markdown ()
    for input, output in pairs{
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
    } do
        local str = M.escape_markdown(input)
        assert_equals(str, output)
        local doc = pandoc.read(str, 'markdown-smart')
        assert_not_nil(doc)
        if  doc.blocks and #doc.blocks > 0 and
            not input:match '^%s'          and
            not input:match '%s$'          and
            not input:match '^%s*%*'       and
            not input:match '\\'
        then assert_equals(input, stringify(doc.blocks[1].content)) end
    end
end

function test_markdownify ()
    local funcs = {[M.markdownify_legacy] = true, [M.markdownify] = true}
    if pandoc.types and PANDOC_VERSION >= {2, 17} then
        funcs[M.markdownify_modern] = true
    end

    for func in pairs(funcs) do
        assert_error(func, {function () end})
        for _, md in ipairs{
            '' ,
            'test',
            '*test*',
            '**test**',
            '***test***',
            '^test^',
            '~test~',
            '[test]{.test}',
            '[*test*^2^]{.nocase}',
            '***test***^[ABC]{.class}^'
        } do
            local conv = func(pandoc.read(md))
            assert_equals(conv, md)
        end
    end
end

function test_yamlify ()
    local cycle = {}
    cycle.cycle = cycle
    local thread = coroutine.create(nilify)

    for input, pattern in pairs{
        [{cycle}] = '.+%f[%a]cycle in data tree%.',
        [{nilify}] = '.+%f[%a]function: cannot be expressed in YAML%.',
        [{thread}] = '.+%f[%a]thread: cannot be expressed in YAML%.',
        [{'foo', 0}] = '.+%f[%a]number of spaces must be greater than 0.'
    } do
        assert_error_msg_matches(pattern, M.yamlify, unpack(input))
    end

    local tab = setmetatable({
        foo = 'foo',
        bar = 'bar'
    }, M.sort_pairs)

    local list = setmetatable({1, 2}, M.sort_pairs)
    table.insert(list, M.copy(list))

    local dict = setmetatable({foo = 1, bar = 2}, M.sort_pairs)
    dict.baz = M.copy(dict)

    local tests = {
        [{true}] = 'true',
        [{false}] = 'false',
        [{0}] = '0',
        [{1}] = '1',
        [{'1'}] = '"1"',
        [{''}] = '""',
        [{'foo'}] = '"foo"',
        [{'foo bar'}] = '"foo bar"',
        [{'foo\nbar'}] = '"foo' .. M.EOL .. 'bar"',
        [{'foo\r\nbar'}] = '"foo' .. M.EOL .. 'bar"',
        [{{}}] = '',
        [{{'foo'}}] = '- "foo"',
        [{{'foo', 'bar'}}] = '- "foo"' .. M.EOL .. '- "bar"',
        [{{['foo'] = 'foo'}}] = 'foo: "foo"',
        [{tab}] = 'bar: "bar"' .. M.EOL .. 'foo: "foo"',
        [{true, 1}] = 'true',
        [{false, 1}] = 'false',
        [{0, 1}] = '0',
        [{1, 1}] = '1',
        [{'1', 1}] = '"1"',
        [{'', 1}] = '""',
        [{'foo', 1}] = '"foo"',
        [{'foo bar', 1}] = '"foo bar"',
        [{'foo\nbar', 1}] = '"foo' .. M.EOL .. 'bar"',
        [{'foo\r\nbar', 1}] = '"foo' .. M.EOL .. 'bar"',
        [{{}, 1}] = '',
        [{{'foo'}, 1}] = '- "foo"',
        [{{'foo', 'bar'}, 1}] = '- "foo"' .. M.EOL .. '- "bar"',
        [{{['foo'] = 'foo'}, 1}] = 'foo: "foo"',
        [{tab, 1}] = 'bar: "bar"' .. M.EOL .. 'foo: "foo"',
        [{list, 1}] =
[[- 1
- 2
- - 1
  - 2]],
        [{dict}] =
[[bar: 2
baz:
    bar: 2
    foo: 1
foo: 1]],
        [{dict, 1}] =
[[bar: 2
baz:
 bar: 2
 foo: 1
foo: 1]],
        [{dict, 2}] =
[[bar: 2
baz:
  bar: 2
  foo: 1
foo: 1]],
        [{dict, 3}] =
[[bar: 2
baz:
   bar: 2
   foo: 1
foo: 1]],
        [{dict, 4}] =
[[bar: 2
baz:
    bar: 2
    foo: 1
foo: 1]]
}

    for _, code in ipairs{0x22, 0x5c} do
        local char = utf8.char(code)
        local esc = '\\' .. char
        tests[{char}] = '"' .. esc .. '"'
        tests[{'foo' .. char}] = '"foo' .. esc .. '"'
        tests[{char .. 'bar'}] = '"' .. esc .. 'bar"'
        tests[{'foo' .. char .. 'bar'}] = '"foo' .. esc .. 'bar"'
    end

    for _, range in ipairs{
        {0x0000, 0x001f}, -- C0 control block
        {0x007f, 0x007f}, -- DEL
        {0x0080, 0x009f}, -- C1 control block
        {0xd800, 0xdfff}, -- Surrogate block
        {0xfffe, 0xffff},
    } do
        local start, stop = unpack(range)
        local format
        if stop <= 0x7f then format = '\\x%02x'
                        else format = '\\u%04x'
        end
        for code = start, stop do
            if not pandoc.List.includes({0x09, 0x0a, 0x0d, 0x85}, code) then
                local char = utf8.char(code)
                local esc = string.format(format, code)
                tests[{char}] = '"' .. esc .. '"'
                tests[{'foo' .. char}] = '"foo' .. esc .. '"'
                tests[{char .. 'bar'}] = '"' .. esc .. 'bar"'
                tests[{'foo' .. char .. 'bar'}] = '"foo' .. esc .. 'bar"'
            end
        end
    end

    for input, output in pairs(tests) do
        assert_equals(M.yamlify(unpack(input)), output)
    end

    local str = M.yamlify(ZOTXT_CSL)
    local csl = rconv_nums_to_strs(yaml.parse(str))
    assert_equals(csl, ZOTXT_CSL)
end

function test_zotero_to_html ()
    for input, pattern in pairs{
        ['<sc>'] = 'encountered 1 <sc> but 0 </sc> tags.',
        ['<sc>foo'] = 'encountered 1 <sc> but 0 </sc> tags.',
        ['<sc>foo</sc><sc>'] = 'encountered 2 <sc> but 1 </sc> tags.',
        ['<sc>foo</sc>bar<sc>'] = 'encountered 2 <sc> but 1 </sc> tags.',
        ['</sc>'] = 'encountered 0 <sc> but 1 </sc> tags.',
        ['foo</sc>'] = 'encountered 0 <sc> but 1 </sc> tags.',
        ['<sc>foo</sc></sc>'] = 'encountered 1 <sc> but 2 </sc> tags.',
        ['<sc>foo</sc>bar</sc>'] = 'encountered 1 <sc> but 2 </sc> tags.',
    } do
        local ok, err = M.zotero_to_html(input)
        assert_nil(ok)
        assert_equals(err, pattern)
    end

    for input, output in pairs{
        [''] = '',
        ['foo'] = 'foo',
        ['<sc>foo</sc>'] = '<span class="smallcaps">foo</span>',
        ['<sc><b>foo</b></sc>'] = '<span class="smallcaps"><b>foo</b></span>',
    } do
        assert_equals(M.zotero_to_html(input), output)
    end
end

function test_zotero_to_markdown ()
    for input, pattern in pairs{
        ['<sc>'] = 'encountered 1 <sc> but 0 </sc> tags.',
        ['<sc>foo'] = 'encountered 1 <sc> but 0 </sc> tags.',
        ['<sc>foo</sc><sc>'] = 'encountered 2 <sc> but 1 </sc> tags.',
        ['<sc>foo</sc>bar<sc>'] = 'encountered 2 <sc> but 1 </sc> tags.',
        ['</sc>'] = 'encountered 0 <sc> but 1 </sc> tags.',
        ['foo</sc>'] = 'encountered 0 <sc> but 1 </sc> tags.',
        ['<sc>foo</sc></sc>'] = 'encountered 1 <sc> but 2 </sc> tags.',
        ['<sc>foo</sc>bar</sc>'] = 'encountered 1 <sc> but 2 </sc> tags.'
    } do
        local ok, err = M.zotero_to_markdown(input)
        assert_nil(ok)
        assert_equals(err, pattern)
    end

    for input, output in pairs{
        [''] = '',
        ['foo'] = 'foo',
        ['<i>foo</i>'] = '*foo*',
        ['<b>foo</b>'] = '**foo**',
        ['<b><i>foo</i></b>'] = '***foo***',
        ['<i><b>foo</b></i>'] = '***foo***',
        ['<em>foo</em>'] = '*foo*',
        ['<strong>foo</strong>'] = '**foo**',
        ['<strong><em>foo</em></strong>'] = '***foo***',
        ['<em><strong>foo</strong></em>'] = '***foo***',
        ['<sc>foo</sc>'] = '[foo]{.smallcaps}',
        ['<span style="font-variant:small-caps;">foo</span>'] = '[foo]{.smallcaps}',
        ['<i><sc>foo</sc></i>'] = '*[foo]{.smallcaps}*',
        ['<b><sc>foo</sc><sub>bar</sub></b>'] = '**[foo]{.smallcaps}~bar~**',
        ['<sub>foo</sub>'] = '~foo~',
        ['<sup>foo</sup>'] = '^foo^',
        ['<span class="nocase">foo</span>'] = '[foo]{.nocase}'
    } do
        assert_equals(M.zotero_to_markdown(input), output)
    end
end


--- CSL items
-- @section

function test_csl_item_extras ()
    for _, input in ipairs{
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
    } do
        local res = {}
        for k, v in M.csl_item_extras(input) do
            res[k] = v
        end

        assert_items_equals(res, {
            ['original-date'] = '1970',
            ['original-author'] = 'Doe || Jane'
        })
    end
end

function test_csl_item_add_extras ()
    for date, msg in pairs{
        [''] =
            'unknown item: original-date: is empty.',
        ['/'] =
            'unknown item: original-date: missing from date.',
        ['foo'] =
            'unknown item: original-date: from date: year is not a number.',
        ['1970-foo'] =
            'unknown item: original-date: from date: month is not a number.',
        ['1970-01-foo'] =
            'unknown item: original-date: from date: day is not a number.',
        ['1970-01-01-01'] =
            'unknown item: original-date: from date: too many date parts.',
        ['1970-01-01/'] =
            'unknown item: original-date: missing to date.',
        ['1970-01-01/foo'] =
            'unknown item: original-date: to date: year is not a number.',
        ['1970-01-01/1970-foo'] =
            'unknown item: original-date: to date: month is not a number.',
        ['1970-01-01/1970-01-foo'] =
            'unknown item: original-date: to date: day is not a number.',
        ['1970-01-01/1970-01-01-01'] =
            'unknown item: original-date: to date: too many date parts.',
        ['1970-01-01/1970-01-01/'] =
            'unknown item: original-date: too many dates.',
    } do
        local ok, err = M.csl_item_add_extras{note = 'original-date: ' .. date}
        assert_nil(ok)
        assert_equals(err, msg)
    end

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

function test_csl_item_normalise ()
    local cycle = {}
    cycle.cycle = cycle
    assert_items_equals(M.csl_item_normalise(cycle), cycle)

    local test = {
        ISBN = '978-0-19-989262-4',
        Author = {{Family = 'Haslanger', Given = 'Sally'}},
        ['Event place'] = 'Oxford',
        ID = 'haslanger2012ResistingRealitySocial',
        Issued = {['Date parts'] = {{'2012'}}},
        Note = 'citation key: haslanger2012ResistingRealitySocial',
        Publisher = 'Oxford University Press',
        ['Publisher place'] = 'Oxford',
        ShortTitle = 'Resisting Reality',
        Title = 'Resisting Reality: Social Construction and Social Critique',
        Type = 'book'
    }
    assert_equals(M.csl_item_normalise(test), ZOTWEB_CSL)
end

----------------
-- test_csl_item_to_meta @fixme
----------------

function test_csl_items_filter_by_ckey ()
    local foo = {note = 'citekey: foo'}
    local bar = {note = 'citation-key: bar'}
    local baz = {note = 'Citation key: baz'}
    local items = {foo, bar, baz}

    assert_items_equals(M.csl_items_filter_by_ckey({}, 'foo'), {})
    assert_items_equals(M.csl_items_filter_by_ckey(items, 'foo'), {foo})
    assert_items_equals(M.csl_items_filter_by_ckey(items, 'bar'), {bar})
    assert_items_equals(M.csl_items_filter_by_ckey(items, 'baz'), {baz})

end

function test_csl_items_ids ()
    for input, output in pairs{
        [{}] = {},
        [ZOTXT_CSL] = {haslanger2012ResistingRealitySocial = true},
        [ZOTXT_YAML] = {crenshaw1989DemarginalizingIntersectionRace = true}
    } do
        assert_equals(M.csl_items_ids(input), output)
    end
end

function test_csl_items_sort ()
    for input, output in pairs{
        [{{id = 1}, {id = 2}}] = true,
        [{{id = 1}, {id = 1}}] = false,
        [{{id = 2}, {id = 1}}] = false,
        [{{id = 'a'}, {id = 'b'}}] = true,
        [{{id = 'a'}, {id = 'a'}}] = false,
        [{{id = 'b'}, {id = 'a'}}] = false,
        [{{id = 'Z'}, {id = 'a'}}] = true,
        [{{id = 'Z'}, {id = 'Z'}}] = false,
        [{{id = 'a'}, {id = 'Z'}}] = false
    } do
        assert_equals(M.csl_items_sort(unpack(input)), output)
    end
end

function test_csl_varname_normalise ()
    for input, pattern in pairs{
        [''] = '^variable name is the empty string%.',
        ['!'] = '.+: not a CSL variable%.',
        ['foo.bar'] = '.+: not a CSL variable%.'
    } do
        local ok, err = M.csl_varname_normalise(input)
        lu.assert_nil(ok)
        lu.assert_str_matches(err, pattern)
    end

    for input, output in pairs{
        ['Citation Key'] = 'citation-key',
        ['ORIGINAL DATE'] = 'original-date',
        ['Author'] = 'author',
        ['BLA-bla bLa'] = 'bla-bla-bla'
    } do
        assert_equals(M.csl_varname_normalise(input), output)
    end
end

function test_csl_vars_sort ()
    for input, output in pairs{
        [{'a', 'b'}] = true,
        [{'a', 'a'}] = false,
        [{'b', 'a'}] = false,
        [{'id', 'a'}] = true,
        [{'a', 'id'}] = false,
        [{'id', 'type'}] = true,
        [{'type', 'id'}] = false,
        [{'id', 'id'}] = false,
    } do
        assert_equals(M.csl_vars_sort(unpack(input)), output)
    end
end

--- Citation keys
-- @section

function test_citekey_terms ()
    local ts = {'betterbibtexkey', 'easykey'}

    for input, output in pairs {
        [''] = nil,
        ['doe'] = nil,
        ['doe:'] = nil,
        ['doe2020'] = {'doe', '2020'},
        ['doe:2020easy'] = {'doe', '2020', 'easy'},
        ['doeWord'] = {'doe', 'Word'},
        ['doeWord2020'] = {'doe', 'Word', '2020'},
        ['doe2020TwoWords'] = {'doe', '2020', 'Two', 'Words'},
        ['doe2020lowercaseWord'] = {'doe', '2020', 'lowercase', 'Word'}
    } do
        assert_items_equals(M.citekey_terms(input, ts), output)
    end
end

function test_citekey_types ()
    local ts = {'betterbibtexkey', 'easykey', 'key'}
    for input, output in pairs{
        [''] = {'betterbibtexkey', 'easykey'},
        ['doe'] = {'betterbibtexkey', 'easykey'},
        ['doe:'] = {'betterbibtexkey', 'easykey'},
        ['doe:2020easy'] = {'betterbibtexkey', 'easykey'},
        ['doeWord'] = {'betterbibtexkey', 'easykey'},
        ['doeWord2020'] = {'betterbibtexkey', 'easykey'},
        ['doeWord2020TwoWords'] = {'betterbibtexkey', 'easykey'},
        ['doeWord2020lowercaseWord'] = {'betterbibtexkey', 'easykey'},
        ['ABCD1234'] = {'betterbibtexkey', 'easykey', 'key'},
    } do
        assert_items_equals(M.citekey_types(input, ts), output)
    end
end

----------------------------------------------------------------




function test_options_add ()
    local options = M.Options:clone()
    local add = options.add

    local errors = {
        {'.-%f[%a]argument 2: expected table or userdata, got nil%.', add, options},
        {'.-%f[%a]argument 2: expected table or userdata, got nil%.', add, options, nil},
        {'.-%f[%a]argument 2: expected table or userdata, got boolean%.', add, options, true},
        {'.-%f[%a]argument 2: index name: expected string, got nil%.', add, options, {}},
        {'.-%f[%a]argument 2: index parse: expected function or nil, got boolean%.', add, options, {name = 'n', parse = true}}
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
        [{prefix = 'zotero', name = 'unstr'}] =
            '.-%f[%a]zotero%-unstr: not a string or empty%.',
    }

    for k, v in pairs(erroneous) do
        local parser = M.Options:clone()
        parser:add(k)
        local ok, err = parser:parse(meta)
        lu.assert_nil(ok)
        lu.assert_str_matches(err, v)
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

    local conf_parser = M.Options:clone()
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
    lu.assert_nil(err)
    lu.assert_not_nil(item)
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











function test_biblio_read ()
    local fname, data, err

    fname = M.path_join(DATA_DIR, 'bibliography.json')
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_CSL)

    fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_YAML)
end

-- function test_csl_json_parse ()
--     local output = {
--         author = {{family = 'Doe', given = 'John'}},
--         issued = {['date-parts'] = {{'2021'}}},
--         publisher = 'Unit test press',
--         ['publisher-place'] = 'Vienna',
--         title = 'Unit testing',
--         type = 'book'
--     }

--     local tests = {
--         [[
--             {
--                 "author": [
--                     {
--                         "family": "Doe",
--                         "given": "John"
--                     }
--                 ],
--                 "issued": {
--                     "date-parts": [
--                         ["2021"]
--                     ]
--                 },
--                 "publisher": "Unit test press",
--                 "publisher-place": "Vienna",
--                 "title": "Unit testing",
--                 "type": "book"
--             }
--         ]],
--         [[
--             {
--                 "Author": [
--                     {
--                         "family": "Doe",
--                         "given": "John"
--                     }
--                 ],
--                 "Issued": {
--                     "Date parts": [
--                         [2021]
--                     ]
--                 },
--                 "Publisher": "Unit test press",
--                 "Publisher place": "Vienna",
--                 "Title": "Unit testing",
--                 "Type": "book"
--             }
--         ]]
--     }

--     for _, v in ipairs(tests) do
--         assert_items_equals(M.csl_json_parse(v), output)
--     end
-- end


function test_biblio_write ()
    local fname, ok, fmt, data, err, errno

    fname = M.path_join(TMP_DIR, 'bibliography.json')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio_write(fname, {ZOTXT_CSL})
    lu.assert_nil(err)
    assert_equals(fmt, true)
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, {ZOTXT_CSL})

    fname = M.path_join(TMP_DIR, 'bibliography.yaml')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio_write(fname, ZOTXT_YAML)
    assert_equals(fmt, true)
    lu.assert_nil(err)
    data, err = M.biblio_read(fname)
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
    local decode = M.BIBLIO_DECODERS.bib
    local fname = M.path_join(DATA_DIR, 'bibliography.bib')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    local ids = M.csl_items_ids(decode(str))
    assert_items_equals(ids, {
        ['crenshaw1989DemarginalizingIntersectionRace'] = true,
        ['díaz-león2015WhatSocialConstruction'] = true
    })
end


function test_biblio_codecs_yaml_decode ()
    -- luacheck: ignore yaml
    local decode = M.BIBLIO_DECODERS.yaml
    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    assert_items_equals(decode(str), ZOTXT_YAML)
end

function test_biblio_types_yaml_encode ()
    -- luacheck: ignore yaml
    local encode = M.BIBLIO_ENCODERS.yaml
    local fname = M.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = M.file_read(fname)
    if not str then error(err) end
    assert_items_equals(M.BIBLIO_DECODERS.yaml(encode(ZOTXT_YAML)), ZOTXT_YAML)
end

function test_biblio_update ()
    local wrong = {'nosuffix', 'n.', 'n.wrongformat'}
    for _, v in ipairs(wrong) do
        local ok, err =  M.biblio_update(M.connectors.Zotxt, v, {'<n/a>'})
        lu.assert_nil(ok)
        lu.assert_not_nil(err)
    end

    local fname = M.path_join(TMP_DIR, 'update-biblio.json')

    -- Remove file, just in case.
    local data, ok, err, errno
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end

    -- Checks whether we do nothing if there's nothing to be done.
    ok, err = M.biblio_update(M.connectors.Zotxt, fname, {})
    if not ok then error(err) end
    ok, err, errno = os.remove(fname)
    if ok or errno ~= 2 then error(err) end

    -- Checks adding citations from zero.
    ok, err = M.biblio_update(M.connectors.Zotxt, fname, {'haslanger:2012resisting'})
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
    ok, err = M.biblio_update(M.connectors.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    data, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(data)
    assert_equals(#data, 2)

    ok, err = M.biblio_update(M.connectors.Zotxt, fname, ckeys)
    lu.assert_nil(err)
    lu.assert_true(ok)
    new, err = read_json_file(fname)
    lu.assert_nil(err)
    lu.assert_not_nil(new)
    assert_equals(new, data)

    -- This should not change the file.
    local post
    ok, err = M.biblio_update(M.connectors.Zotxt, fname, ckeys)
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

function test_doc_srcs ()
    -- luacheck: ignore err

    local empty_fname = M.path_join(DATA_DIR, 'empty.md')
    local empty, err = read_md_file(empty_fname)
    assert(empty, err)
    assert_equals(M.doc_srcs(empty), {})

    local test_fname = M.path_join(DATA_DIR, 'dup.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    assert_items_equals(M.doc_srcs(test_file), ZOTXT_META)

    -- @fixme Needs a separate test for Pandoc >= v2.17.
    -- test_fname = M.path_join(DATA_DIR, 'dup-biblio-yaml.md')
    -- test_file, err = read_md_file(test_fname)
    -- assert(test_file, err)
    -- assert_items_equals(M.doc_srcs(test_file), ZOTXT_YAML)

    test_fname = M.path_join(DATA_DIR, 'dup-biblio-bib.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ids = M.csl_items_ids(M.doc_srcs(test_file))
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

-- New stuff




-- BOILERPLATE
-- ===========

-- luacheck: globals run
--- Runs the tests
--
-- Looks up the `tests` metadata field in the current Pandoc document
-- and passes it to `lu.LuaUnit.run`, as is. Also configures tests.
function run (doc)
    local test
    if doc.meta and doc.meta.test then
        test = stringify(doc.meta.test)
        if test == '' then test = nil end
    end
    os.exit(lu.LuaUnit.run(test), true)
end

-- 'Pandoc', rather than 'Meta', because there's always a Pandoc document.
return {{Pandoc = run}}
