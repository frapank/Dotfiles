vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
end
vim.opt.background = "dark"
vim.g.colors_name = "dot"

-- Palette
local bg              = '#0a0a0a'
local fg              = '#ffffff'
local accent          = '#ffee8f'
local text_muted      = '#a8a8a8'
local text_noise      = '#737373'
local text_dim        = '#7d7d7d'
local border          = '#1a1a1a'
local popup_bg        = '#0f0f0f'
local popup_fg        = '#e6e6e6'
local popup_sel       = '#cccccc'
local menu_bg         = '#303030'
local scrollbar_bg    = '#555555'
local scrollbar_thumb = '#aaaaaa'
local cursor_bg       = '#141414'
local diff_add_bg     = '#1a231a'
local diff_chg_bg     = '#1a1a23'
local diff_del_bg     = '#231a1a'

-- Helper function
local function Hi(group, fg, bg, attr)
    local opts = {}
    if fg and fg ~= 'NONE' then opts.fg = fg end
    if bg and bg ~= 'NONE' then opts.bg = bg end
    if attr and attr ~= 'NONE' then
        opts[attr] = true
    end
    vim.api.nvim_set_hl(0, group, opts)
end

-- Base groups
local base_groups = {
    'Constant', 'Character', 'Number', 'Boolean', 'Float',
    'Identifier', 'Function',
    'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
    'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
    'Type', 'StorageClass', 'Structure', 'Typedef',
    'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
    'Underlined', 'Ignore',
}

for _, g in ipairs(base_groups) do
    Hi(g, fg, bg)
end

-- Custom groups
Hi('Normal',         fg,            bg                        )

Hi('LineNr',         text_dim,      bg                        )
Hi('EndOfBuffer',    bg,            bg                        )
Hi('NonText',        text_noise,    bg                        )
Hi('SpecialKey',     text_dim,      bg                        )
Hi('VertSplit',      border,        bg                        )
Hi('WinSeparator',   border,        bg                        )

Hi('SignColumn',     text_dim,      bg                        )
Hi('Folded',         text_noise,    border,        'italic'   )
Hi('FoldColumn',     text_dim,      bg                        )
Hi('ColorColumn',    nil,           border                    )
Hi('Conceal',        text_noise,    bg                        )
Hi('QuickFixLine',   bg,            accent                    )
Hi('Substitute',     bg,            accent                    )

Hi('Whitespace',     border,        bg                        )

Hi('PmenuKind',      accent,        popup_bg                  )
Hi('PmenuKindSel',   bg,            popup_sel                 )
Hi('PmenuExtra',     text_noise,    popup_bg                  )
Hi('PmenuExtraSel',  text_noise,    popup_sel                 )

Hi('NormalFloat',    popup_fg,      popup_bg                  )
Hi('FloatBorder',    text_noise,    popup_bg                  )
Hi('FloatTitle',     accent,        popup_bg,      'bold'     )

Hi('LineNrAbove',    text_noise,    bg                        )
Hi('LineNrBelow',    text_noise,    bg                        )

Hi('StatusLine',     fg,            border,        'bold'     )
Hi('StatusLineNC',   bg,            text_muted,    'bold'     )

Hi('CursorLine',     nil,           cursor_bg                 )
Hi('CursorLineNr',   accent,        bg                        )
Hi('MatchParen',     accent,        bg                        )

Hi('Visual',         bg,            accent                    )
Hi('Search',         bg,            accent                    )
Hi('CurSearch',      bg,            fg,            'bold'     )
Hi('IncSearch',      bg,            accent                    )

Hi('Pmenu',          popup_fg,      popup_bg                  )
Hi('PmenuSel',       bg,            popup_sel                 )
Hi('PmenuSbar',      popup_fg,      scrollbar_bg              )
Hi('PmenuThumb',     popup_fg,      scrollbar_thumb           )
Hi('WildMenu',       popup_fg,      menu_bg                   )

Hi('TabLine',        text_muted,    border                    )
Hi('TabLineFill',    text_muted,    border                    )
Hi('TabLineSel',     bg,            fg,            'bold'     )

Hi('DiffAdd',        nil,           diff_add_bg               )
Hi('DiffChange',     nil,           diff_chg_bg               )
Hi('DiffDelete',     nil,           diff_del_bg               )
Hi('DiffText',       bg,            accent,        'bold'     )

Hi('Directory',      fg,            bg,            'bold'     )
Hi('Title',          accent,        bg,            'bold'     )
Hi('ModeMsg',        fg,            bg,            'bold'     )
Hi('MoreMsg',        text_dim,      bg                        )
Hi('Question',       accent,        bg                        )
Hi('WarningMsg',     accent,        bg                        )

Hi('String',         text_muted,    bg                        )
Hi('Comment',        text_noise,    bg,            'italic'   )
Hi('Todo',           accent,        bg,            'bold'     )
Hi('SpecialComment', accent,        bg                        )

Hi('Error',          accent,        bg,            'reverse'  )
Hi('ErrorMsg',       accent,        bg,            'reverse'  )

-- Terminal colors
local term_red          = '#cc6666'
local term_green        = '#8c9a8c'
local term_blue         = '#708a99'
local term_magenta      = '#a6829c'
local term_cyan         = '#70a09f'
local term_yellow       = '#ffe066'

local term_bright_red   = '#d97e7e'
local term_bright_green = '#afd7af'
local term_bright_blue  = '#8ab0c6'
local term_bright_mag   = '#c59dc8'
local term_bright_cyan  = '#8cc8c7'

local term_colors = {
    bg,           term_red,         term_green,       accent,
    term_blue,    term_magenta,     term_cyan,        text_muted,
    scrollbar_bg, term_bright_red,  term_bright_green, term_yellow,
    term_bright_blue, term_bright_mag, term_bright_cyan, fg
}
for i, color in ipairs(term_colors) do
    vim.g["terminal_color_" .. (i - 1)] = color
end

-- FZF Default Options
vim.env.FZF_DEFAULT_OPTS =
    '--color=' ..
    'fg:#ffffff,'      ..
    'bg:#0a0a0a,'      ..
    'hl:#ffee8f,'      ..
    'fg+:#0a0a0a,'     ..
    'bg+:#cccccc,'     ..
    'hl+:#ffee8f,'     ..
    'border:#1a1a1a,'  ..
    'header:#8a8a8a,'  ..
    'gutter:#0a0a0a,'  ..
    'spinner:#ffee8f,' ..
    'info:#8a8a8a,'    ..
    'pointer:#ffee8f,' ..
    'marker:#ffee8f,'  ..
    'prompt:#ffee8f,'  ..
    'query:#ffffff,'   ..
    'separator:#1a1a1a,' ..
    'scrollbar:#555555,' ..
    'label:#8a8a8a,'   ..
    'disabled:#7d7d7d,' ..
    'preview-fg:#ffffff,' ..
    'preview-bg:#0f0f0f'
