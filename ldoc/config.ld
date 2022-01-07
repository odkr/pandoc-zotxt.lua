project = 'pandoc-zotxt.lua'
description = 'Pandoc filter that looks up bibliographic data in Zotero.'
full_description = [[pandoc-zotxt.lua looks up bibliographic data for
citations in Zotero and adds it either to a document's references metadata
field or to a bibliography file.

It requires zotxt and Better BibTeX for Zotero.

See <https://github.com/odkr/pandoc-zotxt.lua> for details.]]

file = '../pandoc-zotxt.lua'
readme = '../README.md'
format = 'discount'
dir = '../docs'
style = '.'

backtick_references = false

new_type('object', 'Prototypes', false, 'Uninitialised properties')

custom_tags = {
    {'caveats', title = 'Caveats'},
    {'proto', title = 'Prototype'},
    {'require', title = 'Requires'},
    {'side', title = 'Side-effects'},
    {'tip', title = 'Tip'}
}
