" Base 
set termguicolors
syntax on
set background=dark
hi Normal       guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0
hi CursorLine   guibg=#000000 ctermbg=0
hi LineNr       guifg=#ffffff ctermfg=15
hi StatusLine   guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0
hi VertSplit    guifg=#ffffff guibg=#000000 ctermfg=15 ctermbg=0

" All gropus
for group in [
      \ 'Constant','String','Character','Number','Boolean','Float',
      \ 'Identifier','Function',
      \ 'Statement','Conditional','Repeat','Label','Operator','Keyword','Exception',
      \ 'PreProc','Include','Define','Macro','PreCondit',
      \ 'Type','StorageClass','Structure','Typedef',
      \ 'Special','SpecialChar','Tag','Delimiter','SpecialComment','Debug',
      \ 'Underlined','Ignore','Error','Todo'
      \ ]
  exec 'hi ' . group . ' guifg=#ffffff ctermfg=15'
endfor

hi Comment guifg=#7d7d7d ctermfg=8
hi String guifg=#8a8a8a ctermfg=8
hi StatusLine guifg=#cccccc ctermfg=8
hi StatusLineNC guifg=#cccccc ctermfg=8
hi EndOfBuffer guifg=#555555 ctermfg=15
hi NonText guifg=#555555 ctermfg=15
