vim9script

hi clear
if exists("syntax_on")
  syntax reset
endif
set background=dark
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
    execute $"hi {group} guifg={fg} guibg={bg} gui={attr} cterm={attr} ctermfg=NONE ctermbg=NONE"
enddef

# Base groups
const groups = [
      \ 'Constant', 'Character', 'Number', 'Boolean', 'Float',
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
Hi('EndOfBuffer',    BG,       BG)
Hi('NonText',        FG,       BG)
Hi('SpecialKey',     DIM,      BG)
Hi('VertSplit',      SPLIT,    BG)
Hi('WinSeparator',   SPLIT,    BG)

Hi('StatusLine',     BG,       FG,      'bold')
Hi('StatusLineNC',   BG,       MUTED,   'bold')

Hi('CursorLine',     FG,       BG)
Hi('CursorLineNr',   GOLD,     BG)
Hi('MatchParen',     GOLD,     BG)

Hi('Visual',         BG,       GOLD)
Hi('Search',         BG,       GOLD)
Hi('CurSearch',      BG,       FG,      'bold')
Hi('IncSearch',      BG,       GOLD)

Hi('Pmenu',          PMENU_FG, PMENU_BG)
Hi('PmenuSel',       BG,       PMENU_SE)
Hi('PmenuSbar',      PMENU_FG, SBAR_BG)
Hi('PmenuThumb',     PMENU_FG, THUMB_BG)
Hi('WildMenu',       PMENU_FG, WILD_BG)

Hi('TabLine',        MUTED,    SPLIT)
Hi('TabLineFill',    MUTED,     SPLIT)
Hi('TabLineSel',     BG,       FG,       'bold')

Hi('DiffAdd',        BG,       MUTED)
Hi('DiffChange',     BG,       DIM)
Hi('DiffDelete',     BG,       SPLIT)
Hi('DiffText',       BG,       GOLD,     'bold')

Hi('Directory',      FG,       BG,       'bold')
Hi('Title',          GOLD,     BG,       'bold')
Hi('ModeMsg',        FG,       BG,       'bold')
Hi('MoreMsg',        DIM,      BG)
Hi('Question',       GOLD,     BG)
Hi('WarningMsg',     GOLD,     BG)

Hi('String',         MUTED,    BG)
Hi('Comment',        MUTED,    BG,      'italic')
Hi('Todo',           GOLD,     BG,      'bold')
Hi('SpecialComment', GOLD,     BG)

Hi('Error',          GOLD,     BG,       'reverse')
Hi('ErrorMsg',       GOLD,     BG,       'reverse')

# Terminal colors
const T_RED     = '#cc6666'
const T_GREEN   = '#8c9a8c'
const T_BLUE    = '#708a99'
const T_MAGENTA = '#a6829c'
const T_CYAN    = '#70a09f'
const T_YELLOW  = '#ffe066'

const T_B_RED   = '#d97e7e'
const T_B_GREEN = '#afd7af'
const T_B_BLUE  = '#8ab0c6'
const T_B_MAG   = '#c59dc8'
const T_B_CYAN  = '#8cc8c7'

g:terminal_ansi_colors = [
      BG,
      T_RED,
      T_GREEN,
      GOLD,
      T_BLUE,
      T_MAGENTA,
      T_CYAN,
      MUTED,
      SBAR_BG,
      T_B_RED,
      T_B_GREEN,
      T_YELLOW,
      T_B_BLUE,
      T_B_MAG,
      T_B_CYAN,
      FG
]

#FZF
$FZF_DEFAULT_OPTS =
  '--color=' ..
  'fg:#ffffff,' ..
  'bg:#000000,' ..
  'hl:#b0b0b0,' ..
  'fg+:#000000,' ..
  'bg+:#ffffff,' ..
  'hl+:#000000,' ..
  'border:#ffffff,' ..
  'header:#ffffff,' ..
  'gutter:#000000,' ..
  'spinner:#ffffff,' ..
  'info:#b0b0b0,' ..
  'pointer:#ffffff,' ..
  'marker:#ffffff,' ..
  'prompt:#ffffff,' ..
  'query:#ffffff,' ..
  'disabled:#666666,' ..
  'preview-fg:#ffffff,' ..
  'preview-bg:#000000'
