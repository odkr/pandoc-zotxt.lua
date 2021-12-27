project = 'pandoc-zotxt.lua'
description = 'Pandoc filter that looks up sources of citations in Zotero.'
full_description = [[pandoc-zotxt.lua looks up sources of citations in Zotero
and adds them either to a document's references metadata field or to a
bibliography file, where Pandoc can pick them up.

It requires zotxt and Better BibTeX for Zotero.

See <https://github.com/odkr/pandoc-zotxt.lua> for details.]]

file = '../pandoc-zotxt.lua'
readme = '../README.md'
format = 'discount'
dir = '../docs'
style = '.'

backtick_references = false

new_type('object', 'Prototypes', false, 'Uninitialised properties')
new_type('const', 'Constructors', false, 'Named parameters')

custom_tags = {
    {'caveats', title = 'Caveats'},
    {'side', title = 'Side-effects'},
    {'require', title = 'Requires'},
    {'proto', title = 'Prototype'}
}
