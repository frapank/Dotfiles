vim9script

hi clear
if exists("syntax_on")
  syntax reset
endif
set background=dark

g:colors_name = "dog"

# Palette
const BG          = '#0a0a0a'
const FG          = '#ffffff'
const GOLD        = '#ffee8f'
const MUTED       = '#a8a8a8'
const NOISE       = '#737373'
const DIM         = '#7d7d7d'
const SPLIT       = '#1a1a1a'
const PMENU_BG    = '#0f0f0f'
const PMENU_FG    = '#e6e6e6'
const PMENU_SE    = '#cccccc'
const WILD_BG     = '#303030'
const SBAR_BG     = '#555555'
const THUMB_BG    = '#aaaaaa'
const CURSOR_BG   = '#141414'
const STATUS_BG   = '#1a1a1a'
const DIFF_ADD_BG = '#1a231a'
const DIFF_CHG_BG = '#1a1a23'
const DIFF_DEL_BG = '#231a1a'

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
Hi('NonText',        NOISE,    BG)
Hi('SpecialKey',     DIM,      BG)
Hi('VertSplit',      SPLIT,    BG)
Hi('WinSeparator',   SPLIT,    BG)

Hi('SignColumn',     DIM,      BG)
Hi('Folded',         NOISE,    SPLIT,   'italic')
Hi('FoldColumn',     DIM,      BG)
Hi('ColorColumn',    'NONE',   SPLIT)
Hi('Conceal',        NOISE,    BG)
Hi('QuickFixLine',   BG,       GOLD)
Hi('Substitute',     BG,       GOLD)

Hi('Whitespace',     SPLIT,    BG)

Hi('PmenuKind',      GOLD,     PMENU_BG)
Hi('PmenuKindSel',   BG,       PMENU_SE)
Hi('PmenuExtra',     NOISE,    PMENU_BG)
Hi('PmenuExtraSel',  NOISE,    PMENU_SE)

Hi('NormalFloat',    PMENU_FG, PMENU_BG)
Hi('FloatBorder',    NOISE,    PMENU_BG)
Hi('FloatTitle',     GOLD,     PMENU_BG, 'bold')

Hi('LineNrAbove',    NOISE,    BG)
Hi('LineNrBelow',    NOISE,    BG)

Hi('StatusLine',     FG,       STATUS_BG, 'bold')
Hi('StatusLineNC',   BG,       MUTED,   'bold')

Hi('CursorLine',     'NONE',   CURSOR_BG)
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
Hi('TabLineFill',    MUTED,    SPLIT)
Hi('TabLineSel',     BG,       FG,       'bold')

Hi('DiffAdd',        'NONE',   DIFF_ADD_BG)
Hi('DiffChange',     'NONE',   DIFF_CHG_BG)
Hi('DiffDelete',     'NONE',   DIFF_DEL_BG)
Hi('DiffText',       BG,       GOLD,        'bold')

Hi('Directory',      FG,       BG,       'bold')
Hi('Title',          GOLD,     BG,       'bold')
Hi('ModeMsg',        FG,       BG,       'bold')
Hi('MoreMsg',        DIM,      BG)
Hi('Question',       GOLD,     BG)
Hi('WarningMsg',     GOLD,     BG)

Hi('String',         MUTED,    BG)
Hi('Comment',        NOISE,    BG,      'italic')
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

# FZF
$FZF_DEFAULT_OPTS =
  '--color=' ..
  'fg:#ffffff,' ..
  'bg:#0a0a0a,' ..
  'hl:#ffee8f,' ..
  'fg+:#0a0a0a,' ..
  'bg+:#cccccc,' ..
  'hl+:#ffee8f,' ..
  'border:#1a1a1a,' ..
  'header:#8a8a8a,' ..
  'gutter:#0a0a0a,' ..
  'spinner:#ffee8f,' ..
  'info:#8a8a8a,' ..
  'pointer:#ffee8f,' ..
  'marker:#ffee8f,' ..
  'prompt:#ffee8f,' ..
  'query:#ffffff,' ..
  'separator:#1a1a1a,' ..
  'scrollbar:#555555,' ..
  'label:#8a8a8a,' ..
  'disabled:#7d7d7d,' ..
  'preview-fg:#ffffff,' ..
  'preview-bg:#0f0f0f'
