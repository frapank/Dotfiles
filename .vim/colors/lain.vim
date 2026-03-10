vim9script

# Base 
set termguicolors
syntax on
set background=dark
hi Normal       guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0
hi CursorLine   guibg=#000000 ctermbg=0
hi LineNr       guifg=#ffffff ctermfg=15
hi StatusLine   guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0
hi VertSplit    guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0

# All gropus
const groups = [
      \ "Constant", "String", "Character", "Number", "Boolean", "Float",
      \ "Identifier", "Function",
      \ "Statement", "Conditional", "Repeat", "Label", "Operator", "Keyword", "Exception",
      \ "PreProc", "Include", "Define", "Macro", "PreCondit",
      \ "Type", "StorageClass", "Structure", "Typedef",
      \ "Special", "SpecialChar", "Tag", "Delimiter", "SpecialComment", "Debug",
      \ "Underlined", "Ignore", "Error", "Todo"
      \ ]

for g in groups
    exec $"hi {g} guifg=#ffffff ctermfg=15"
endfor

hi Comment      guifg=#7d7d7d ctermfg=8
hi String       guifg=#8a8a8a ctermfg=8
hi StatusLine   guifg=#cccccc ctermfg=8
hi StatusLineNC guifg=#cccccc ctermfg=8
hi EndOfBuffer  guifg=#000000 ctermfg=15
hi NonText      guifg=#555555 ctermfg=15

hi Pmenu        guifg=#ffffff guibg=#0f0f0f ctermfg=15 ctermbg=0
hi PmenuSel     guifg=#000000 guibg=#cccccc ctermfg=0 ctermbg=8
hi PmenuSbar    guifg=#ffffff guibg=#555555 ctermfg=15 ctermbg=8
hi PmenuThumb   guifg=#ffffff guibg=#aaaaaa ctermfg=15 ctermbg=7
hi WildMenu     guifg=#ffffff guibg=#0f0f0f ctermfg=0  ctermbg=8

hi VertSplit    guifg=#000000 guibg=#ffffff ctermfg=15 ctermbg=0
hi WinSeparator guifg=#000000 guibg=#ffffff ctermfg=7 ctermbg=0
