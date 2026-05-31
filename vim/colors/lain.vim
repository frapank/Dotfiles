vim9script

hi clear
if exists("syntax_on")
  syntax reset
endif
g:colors_name = "lain"

# Palette
const BG       = '#000000'
const FG       = '#ffffff'
const GOLD     = '#ffd700'
const MUTED    = '#8a8a8a'
const DIM      = '#7d7d7d'
const SPLIT    = '#1a1a1a'
const PMENU_BG = '#0f0f0f'
const PMENU_FG = '#e6e6e6'
const PMENU_SE = '#cccccc'
const WILD_BG  = '#303030'
const SBAR_BG  = '#555555'
const THUMB_BG = '#aaaaaa'
const STATUSNC = '#bfbfbf'

# Helper
def Hi(group: string, fg: string, bg: string, attr: string = 'NONE')
    execute $"hi {group} guifg={fg} guibg={bg} gui={attr} cterm={attr}"
enddef

# Base groups 
const groups = [
      \ 'Constant', 'String', 'Character', 'Number', 'Boolean', 'Float',
      \ 'Identifier', 'Function',
      \ 'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
      \ 'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
      \ 'Type', 'StorageClass', 'Structure', 'Typedef',
      \ 'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
      \ 'Underlined', 'Ignore',
      \ ]
for g in groups
    Hi(g, FG, BG)
endfor

# Custom groups
Hi('Normal',         FG,       BG)
Hi('LineNr',         DIM,      BG)
Hi('VertSplit',      SPLIT,    BG)
Hi('WinSeparator',   SPLIT,    BG)
Hi('StatusLine',     BG,       FG,      'bold')
Hi('StatusLineNC',   BG,       MUTED,   'bold')
Hi('CursorLine',     FG,       BG)
Hi('CursorLineNr',   GOLD,     BG)
Hi('EndOfBuffer',    BG,       BG)
Hi('NonText',        FG,       BG)
Hi('Visual',         BG,       GOLD)
Hi('Search',         BG,       GOLD)
Hi('IncSearch',      BG,       GOLD)
Hi('MatchParen',     GOLD,     BG)
Hi('Pmenu',          PMENU_FG, PMENU_BG)
Hi('PmenuSel',       BG,       PMENU_SE)
Hi('PmenuSbar',      PMENU_FG, SBAR_BG)
Hi('PmenuThumb',     PMENU_FG, THUMB_BG)
Hi('WildMenu',       PMENU_FG, WILD_BG)
Hi('String',         MUTED,    BG)
Hi('Comment',        MUTED,    BG,      'italic')
Hi('Todo',           GOLD,     BG,      'bold')
Hi('SpecialComment', GOLD,     BG)
Hi('Error',          GOLD,     BG)
