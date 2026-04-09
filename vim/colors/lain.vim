vim9script

set termguicolors
syntax on
set background=dark
highlight clear

hi Normal           guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0
hi CursorLine       guibg=#0a0a0a ctermbg=0
hi CursorLineNr     guifg=#ffd700 guibg=#0a0a0a ctermfg=3 ctermbg=0
hi LineNr           guifg=#7d7d7d ctermfg=8
hi StatusLine       guifg=#ffffff guibg=#1a1a1a ctermfg=15 ctermbg=0
hi StatusLineNC     guifg=#bfbfbf guibg=#1a1a1a ctermfg=8 ctermbg=0
hi VertSplit        guifg=#1a1a1a guibg=#000000 ctermfg=8 ctermbg=0
hi WinSeparator     guifg=#1a1a1a guibg=#000000 ctermfg=8 ctermbg=0

const groups = [
      \ 'Constant', 'String', 'Character', 'Number', 'Boolean', 'Float',
      \ 'Identifier', 'Function',
      \ 'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
      \ 'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
      \ 'Type', 'StorageClass', 'Structure', 'Typedef',
      \ 'Special', 'SpecialChar', 'Tag', 'Delimiter', 'SpecialComment', 'Debug',
      \ 'Underlined', 'Ignore', 'Error', 'Todo'
      \ ]

for g in groups
    execute $"highlight {g} guifg=#e6e6e6 ctermfg=15"
endfor

hi Comment          guifg=#7d7d7d ctermfg=8 gui=italic
hi String           guifg=#8a8a8a ctermfg=8
hi EndOfBuffer      guifg=#000000 ctermfg=0
hi NonText          guifg=#555555 ctermfg=8

hi Visual           guibg=#111111
hi Search           guifg=#000000 guibg=#ffd700
hi IncSearch        guifg=#000000 guibg=#ffb86b
hi MatchParen       guibg=#0f0f0f guifg=#ffd700

hi Pmenu            guifg=#e6e6e6 guibg=#0f0f0f
hi PmenuSel         guifg=#000000 guibg=#cccccc
hi PmenuSbar        guifg=#e6e6e6 guibg=#555555
hi PmenuThumb       guifg=#e6e6e6 guibg=#aaaaaa
hi WildMenu         guifg=#e6e6e6 guibg=#303030

hi Todo             guifg=#ffd700 gui=bold guibg=NONE
hi SpecialComment   guifg=#ffd700 guibg=NONE

hi EndOfBuffer      guifg=#000000
hi NonText          guifg=#555555 
