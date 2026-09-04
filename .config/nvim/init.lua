-- init.lua. Neovim 0.12+. No plugins, no package manager.
--
--   colors/PaperColor.vim   vendored theme, the only third-party code
--   lua/local.lua           untracked, host-specific, loaded last if present
--
-- C-h opens the cheat sheet. Keys beyond the defaults:  ij (esc)  ,sf (files)
-- ,sg (grep)  ,e (diagnostic)  gd (definition)  ,t (clear tag stack)
-- LSP defaults worth knowing: grn rename, gra code action, grr references,
-- gri implementation, gO symbols, K hover, [d ]d diagnostics, C-n C-p C-y
-- to pick a completion.

vim.g.mapleader = ','

-- [[ options ]]
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'
vim.o.mouse = 'a'
vim.o.clipboard = 'unnamedplus'
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = false
vim.o.breakindent = true
vim.o.completeopt = 'menuone,noselect,popup,fuzzy'

-- status line: default layout plus the tag stack, the files you gd'd through
-- to get here (C-t pops back one). Empty when the stack is empty.
function _G.TagStack()
  local stack = vim.fn.gettagstack()
  local names = {}
  for i = 1, stack.curidx - 1 do
    names[#names + 1] = vim.fn.fnamemodify(vim.fn.bufname(stack.items[i].from[1]), ':t')
  end
  if #names == 0 then return '' end
  names[#names + 1] = vim.fn.expand('%:t')
  return table.concat(names, ' > ')
end
vim.o.statusline = ' %<%f %h%w%m%r %=%{v:lua.TagStack()}  %-14.(%l,%c%V%) %P '

-- indent guides without a plugin: one bar per level, for tabs (Go) and spaces
vim.o.list = true
vim.opt.listchars = { tab = '│ ', leadmultispace = '│ ' }

-- folds by indent, all open on load, "+ --> N lines" when closed
vim.o.foldmethod = 'indent'
vim.o.foldlevelstart = 99
vim.opt.fillchars:append({ fold = ' ' })
function _G.FoldText()
  return '+ --> ' .. (vim.v.foldend - vim.v.foldstart + 1) .. ' lines'
end
vim.o.foldtext = 'v:lua.FoldText()'

-- [[ colors ]] PaperColor for the UI; no syntax highlighting; comments only.
vim.o.termguicolors = true
vim.o.background = 'light'
vim.cmd.colorscheme('PaperColor')
vim.cmd.syntax('off')
vim.api.nvim_set_hl(0, 'Folded', { fg = '#ff0000' })

local paper = vim.api.nvim_create_augroup('paper', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = paper,
  pattern = 'go',
  callback = function()
    vim.api.nvim_set_hl(0, 'Comment', { fg = '#ababab' })
    vim.cmd([[match Comment /\/\/.*/]])
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  group = paper,
  pattern = 'sql',
  callback = function() vim.cmd([[match Comment /\-\-.*/]]) end,
})

-- [[ picker ]] fzf full screen in its own tab: list left, preview right.
-- Esc closes it. The pick, if any, is handed to on_pick after the tab is gone.
-- C-j C-k move the list (fzf default), C-d C-u scroll the preview.
local FZF = 'fzf --color=light --layout=reverse --info=inline'
  .. ' --preview-window=right,60%,border-left'
  .. ' --bind ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up'

local function fzf(cmd, on_pick)
  local out = vim.fn.tempname()
  local origin = vim.api.nvim_get_current_win()
  vim.cmd('tabnew')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = 'wipe'

  local function close()
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
  end

  vim.fn.jobstart(cmd .. ' > ' .. vim.fn.shellescape(out), {
    term = true,
    on_exit = vim.schedule_wrap(function()
      local pick = (vim.fn.filereadable(out) == 1 and vim.fn.readfile(out) or {})[1]
      vim.fn.delete(out)
      close()
      if pick and pick ~= '' then on_pick(pick) end
    end),
  })
  vim.keymap.set('t', '<Esc>', close, { buffer = buf })
  vim.cmd.startinsert()
end

local function find_files()
  fzf('rg --files --hidden --glob !.git | ' .. FZF .. " --preview 'cat -n {}'", vim.cmd.edit)
end

-- live grep: fzf only renders; rg re-runs on every keystroke.
-- Lines are file:line:text, so {1} is the file and {2} the line for the preview.
local function live_grep()
  local rg = 'rg --line-number --no-heading --color=never --smart-case -- {q} || true'
  fzf(FZF .. " --disabled --delimiter : --bind 'change:reload:" .. rg .. "'"
      .. " --preview 'cat -n {1}' --preview-window=right,60%,border-left,+{2}-/2", function(pick)
    local file, line = pick:match('^(.-):(%d+):')
    if not file then return end
    vim.cmd.edit(file)
    vim.api.nvim_win_set_cursor(0, { tonumber(line), 0 })
  end)
end

-- [[ cheat sheet ]] C-h opens a tab listing every described mapping, global and
-- buffer-local, plus the keys that live inside fzf and the completion popup.
local function cheat_sheet()
  local buf = vim.api.nvim_get_current_buf()
  local lines = { 'keys.  q closes.', '' }
  for _, mode in ipairs({ { 'n', 'normal' }, { 'x', 'visual' }, { 'i', 'insert' }, { 't', 'terminal' } }) do
    local rows = {}
    for _, m in ipairs(vim.list_extend(vim.api.nvim_get_keymap(mode[1]), vim.api.nvim_buf_get_keymap(buf, mode[1]))) do
      if m.desc and m.desc ~= '' then rows[#rows + 1] = ('  %-16s %s'):format(m.lhs, m.desc) end
    end
    if #rows > 0 then
      table.sort(rows)
      lines[#lines + 1] = mode[2] .. ':'
      vim.list_extend(lines, rows)
      lines[#lines + 1] = ''
    end
  end
  vim.list_extend(lines, {
    'picker (,sf ,sg):',
    '  C-j C-k          move through results',
    '  C-d C-u          scroll the preview',
    '  enter            open',
    '  esc              close',
    '',
    'completion popup:',
    '  C-n C-p          next, previous',
    '  C-y              accept',
    '  C-e              dismiss',
    '',
    'tag stack:',
    '  gd  C-]          push and jump',
    '  C-t              pop',
    '  ,t               clear',
  })
  vim.cmd('tabnew')
  local sheet = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(sheet, 0, -1, false, lines)
  vim.bo[sheet].buftype = 'nofile'
  vim.bo[sheet].bufhidden = 'wipe'
  vim.bo[sheet].modifiable = false
  vim.keymap.set('n', 'q', '<Cmd>tabclose<CR>', { buffer = sheet })
end

-- [[ keys ]]
vim.keymap.set('i', 'ij', '<Esc>', { desc = 'escape' })
vim.keymap.set('n', '<C-h>', cheat_sheet, { desc = 'cheat sheet' })
vim.keymap.set('n', '<leader>sf', find_files, { desc = 'find files' })
vim.keymap.set('n', '<leader>sg', live_grep, { desc = 'live grep' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'diagnostic under cursor' })
vim.keymap.set('n', '<leader>t', function()
  vim.fn.settagstack(vim.fn.win_getid(), { items = {} }, 'r')
end, { desc = 'clear tag stack' })

-- [[ lsp ]] gopls from PATH (~/go/bin, built from tip).
-- Per-project settings such as build tags go in lua/local.lua:
--   vim.lsp.config('gopls', { settings = { gopls = { buildFlags = { '-tags=x' } } } })
vim.lsp.config('gopls', {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.work', 'go.mod', '.git' },
  settings = { gopls = { gofumpt = true, staticcheck = true } },
})
vim.lsp.enable('gopls')

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    vim.lsp.completion.enable(true, ev.data.client_id, ev.buf, { autotrigger = true })
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf, desc = 'definition' })
  end,
})

-- organize imports, then format, on every Go save
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.go',
  callback = function(ev)
    local client = vim.lsp.get_clients({ bufnr = ev.buf, name = 'gopls' })[1]
    if not client then return end
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { 'source.organizeImports' } }
    local res = vim.lsp.buf_request_sync(ev.buf, 'textDocument/codeAction', params, 1000)
    for _, r in pairs(res or {}) do
      for _, action in pairs(r.result or {}) do
        if action.edit then vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding) end
      end
    end
    vim.lsp.buf.format({ bufnr = ev.buf })
  end,
})

if vim.uv.fs_stat(vim.fn.stdpath('config') .. '/lua/local.lua') then
  require('local')
end
