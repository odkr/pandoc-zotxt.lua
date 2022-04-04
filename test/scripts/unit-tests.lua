--- unit-tests.lua - A fake Pandoc filter that runs unit tests.
--
-- SYNOPSIS
-- ========
--
-- **pandoc** **-L** *unit-tests.lua* -o /dev/null /dev/null
--
--
-- DESCRIPTION
-- ===========
--
-- A fake Pandoc filter that runs unit tests for pandoc-zotxt.lua. Which tests
-- are run depends on the `test` metadata field, which is passed as is to
-- `lu.LuaUnit.run`. If it is not set, all tests are run.
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


--- Initialisation
-- @section

-- luacheck: allow defined top
-- luacheck: globals PANDOC_SCRIPT_FILE PANDOC_VERSION pandoc
-- luacheck: ignore DEBUG

--- Enable debugging mode.
DEBUG = true

-- Libraries.

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
local DATA_DIR = path_join(TEST_DIR, 'data')

--- The test suite's tempory directory.
local TMP_DIR = os.getenv 'TMPDIR' or path_join(TEST_DIR, 'tmp')

do
    package.path = table.concat({package.path,
        path_join(SCPT_DIR, '?.lua'),
        path_join(REPO_DIR, '?.lua'),
        path_join(REPO_DIR, 'share', 'lua', '5.4', '?.lua')
    }, ';')
end

local lu = require 'luaunit'
local json = require 'lunajson'
local yaml = require 'tinyyaml'
local pancake = require 'pancake'

local M = require 'test-wrapper'



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
ZOTXT_JSON = pancake.file_read(pancake.path_join(DATA_DIR, 'bibliography.json'))

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
    local str, err, errno = pancake.file_read(fname)
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
        return pancake.walk(data, conv)
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
    }, {__pairs = pancake.sorted})

    local list = setmetatable({1, 2}, {__pairs = pancake.sorted})
    table.insert(list, pancake.copy(list))

    local dict = setmetatable({foo = 1, bar = 2}, {__pairs = pancake.sorted})
    dict.baz = pancake.copy(dict)

    local tests = {
        [{true}] = 'true',
        [{false}] = 'false',
        [{0}] = '0',
        [{1}] = '1',
        [{'1'}] = '"1"',
        [{''}] = '""',
        [{'foo'}] = '"foo"',
        [{'foo bar'}] = '"foo bar"',
        [{'foo\nbar'}] = '"foo' .. pancake.EOL .. 'bar"',
        [{'foo\r\nbar'}] = '"foo' .. pancake.EOL .. 'bar"',
        [{{}}] = '',
        [{{'foo'}}] = '- "foo"',
        [{{'foo', 'bar'}}] = '- "foo"' .. pancake.EOL .. '- "bar"',
        [{{['foo'] = 'foo'}}] = 'foo: "foo"',
        [{tab}] = 'bar: "bar"' .. pancake.EOL .. 'foo: "foo"',
        [{true, 1}] = 'true',
        [{false, 1}] = 'false',
        [{0, 1}] = '0',
        [{1, 1}] = '1',
        [{'1', 1}] = '"1"',
        [{'', 1}] = '""',
        [{'foo', 1}] = '"foo"',
        [{'foo bar', 1}] = '"foo bar"',
        [{'foo\nbar', 1}] = '"foo' .. pancake.EOL .. 'bar"',
        [{'foo\r\nbar', 1}] = '"foo' .. pancake.EOL .. 'bar"',
        [{{}, 1}] = '',
        [{{'foo'}, 1}] = '- "foo"',
        [{{'foo', 'bar'}, 1}] = '- "foo"' .. pancake.EOL .. '- "bar"',
        [{{['foo'] = 'foo'}, 1}] = 'foo: "foo"',
        [{tab, 1}] = 'bar: "bar"' .. pancake.EOL .. 'foo: "foo"',
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
    assert_items_equals(M.csl_item_add_extras(pancake.copy(input)), output)

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
    assert_items_equals(M.csl_item_add_extras(pancake.copy(input)), output)
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
    assert_items_equals(pack(pancake.tabulate(iter)), {
        'https://api.zotero.org/users/5763466/items/',
        'https://api.zotero.org/groups/4513095/items/',
        n = 2
    })

    iter, err = zoteroweb:endpoints 'FAKE0123'
    lu.assert_not_nil(iter)
    lu.assert_nil(err)
    assert_items_equals(pack(pancake.tabulate(iter)), {
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

    fname = pancake.path_join(DATA_DIR, 'bibliography.json')
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, ZOTXT_CSL)

    fname = pancake.path_join(DATA_DIR, 'bibliography.yaml')
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

    fname = pancake.path_join(TMP_DIR, 'bibliography.json')
    ok, err, errno = os.remove(fname)
    if not ok and errno ~= 2 then error(err) end
    fmt, err = M.biblio_write(fname, {ZOTXT_CSL})
    lu.assert_nil(err)
    assert_equals(fmt, true)
    data, err = M.biblio_read(fname)
    lu.assert_not_nil(data)
    lu.assert_nil(err)
    assert_items_equals(data, {ZOTXT_CSL})

    fname = pancake.path_join(TMP_DIR, 'bibliography.yaml')
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
    local fname = pancake.path_join(DATA_DIR, 'bibliography.bib')
    local str, err = pancake.file_read(fname)
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
    local fname = pancake.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = pancake.file_read(fname)
    if not str then error(err) end
    assert_items_equals(decode(str), ZOTXT_YAML)
end

function test_biblio_types_yaml_encode ()
    -- luacheck: ignore yaml
    local encode = M.BIBLIO_ENCODERS.yaml
    local fname = pancake.path_join(DATA_DIR, 'bibliography.yaml')
    local str, err = pancake.file_read(fname)
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

    local fname = pancake.path_join(TMP_DIR, 'update-biblio.json')

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
    local csl = pancake.copy(ZOTXT_CSL)
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


function test_doc_srcs ()
    -- luacheck: ignore err

    local empty_fname = pancake.path_join(DATA_DIR, 'empty.md')
    local empty, err = read_md_file(empty_fname)
    assert(empty, err)
    assert_equals(M.doc_srcs(empty), {})

    local test_fname = pancake.path_join(DATA_DIR, 'dup.md')
    local test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    assert_items_equals(M.doc_srcs(test_file), ZOTXT_META)

    -- @fixme Needs a separate test for Pandoc >= v2.17.
    -- test_fname = M.path_join(DATA_DIR, 'dup-biblio-yaml.md')
    -- test_file, err = read_md_file(test_fname)
    -- assert(test_file, err)
    -- assert_items_equals(M.doc_srcs(test_file), ZOTXT_YAML)

    test_fname = pancake.path_join(DATA_DIR, 'dup-biblio-bib.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    local ids = M.csl_items_ids(M.doc_srcs(test_file))
    assert_items_equals(ids, {
        ["crenshaw1989DemarginalizingIntersectionRace"] = true,
        ["díaz-león2015WhatSocialConstruction"] = true
    })
end

function test_doc_ckeys ()

    local empty_fname = pancake.path_join(DATA_DIR, 'empty.md')
    local empty = read_md_file(empty_fname)
    assert_equals(M.doc_ckeys(empty), {})

    local test_fname = pancake.path_join(DATA_DIR, 'easykey.md')
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

    test_fname = pancake.path_join(DATA_DIR, 'dup.md')
    test_file, err = read_md_file(test_fname)
    assert(test_file, err)
    ckeys, n = M.doc_ckeys(test_file)
    assert_items_equals(ckeys,
        {'crenshaw1989DemarginalizingIntersectionRace'})
    assert_equals(n, 1)
    ckeys, n = M.doc_ckeys(test_file, true)
    assert_items_equals(ckeys, {})
    assert_equals(n, 0)

    test_fname = pancake.path_join(DATA_DIR, 'issue-7.md')
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
