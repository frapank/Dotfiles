vim9script

const groups = [
      \ 'Constant', 'String', 'Character', 'Number', 'Boolean', 'Float',
      \ 'Identifier', 'Function',
      \ 'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
      \ 'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
      \ 'Type', 'StorageClass', 'Structure', 'Typedef',
      \ 'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
      \ 'Underlined', 'Ignore', 'Error',
      \ ]
for g in groups
    execute $"highlight {g} guifg=#ffffff guibg=#000000"
endfor

hi Normal           guifg=#ffffff guibg=#000000
hi LineNr           guifg=#7d7d7d guibg=#000000
hi VertSplit        guifg=#1a1a1a guibg=#000000
hi WinSeparator     guifg=#1a1a1a guibg=#000000
hi StatusLine       guifg=#ffffff guibg=#000000
hi StatusLineNC     guifg=#bfbfbf guibg=#000000

hi CursorLine       guifg=#ffffff guibg=#000000
hi CursorLineNr     guifg=#ffd700 guibg=#000000

hi EndOfBuffer      guifg=#000000 guibg=#000000
hi NonText          guifg=#ffffff guibg=#000000

hi Visual           guifg=#000000 guibg=#ffd700
hi Search           guifg=#000000 guibg=#ffd700
hi IncSearch        guifg=#000000 guibg=#ffd700
hi MatchParen       guifg=#ffd700 guibg=#000000

hi Pmenu            guifg=#e6e6e6 guibg=#0f0f0f
hi PmenuSel         guifg=#000000 guibg=#cccccc
hi PmenuSbar        guifg=#e6e6e6 guibg=#555555
hi PmenuThumb       guifg=#e6e6e6 guibg=#aaaaaa
hi WildMenu         guifg=#e6e6e6 guibg=#303030

hi String           guifg=#8a8a8a guibg=#000000
hi Comment          guifg=#8a8a8a guibg=#000000
hi Todo             guifg=#ffd700 guibg=#000000
hi SpecialComment   guifg=#ffd700 guibg=#000000
