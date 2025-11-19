---@mod cursoragent.keymaps Keymap management for cursoragent.nvim
---@brief [[
--- This module provides keymap registration and handling for cursoragent.nvim.
--- It handles normal mode, terminal mode, and window navigation keymaps.
---@brief ]]

local M = {}

---Register keymaps for cursoragent.nvim
---@param cursor_agent table The main plugin module
---@param config table The plugin configuration
function M.register_keymaps(cursor_agent, config)
  local map_opts = { noremap = true, silent = true }

  if config.keymaps.toggle.normal then
    vim.api.nvim_set_keymap(
      'n',
      config.keymaps.toggle.normal,
      [[<cmd>CursorAgent<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Cursor Agent: Toggle' })
    )
  end

  if config.keymaps.toggle.terminal then
    vim.api.nvim_set_keymap(
      't',
      config.keymaps.toggle.terminal,
      [[<C-\><C-n>:CursorAgent<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Cursor Agent: Toggle' })
    )
  end

  if config.keymaps.toggle.variants then
    for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
      if keymap then
        local capitalized_name = variant_name:gsub('^%l', string.upper)
        local cmd_name = 'CursorAgent' .. capitalized_name

        vim.api.nvim_set_keymap(
          'n',
          keymap,
          string.format([[<cmd>%s<CR>]], cmd_name),
          vim.tbl_extend('force', map_opts, { desc = 'Cursor Agent: ' .. capitalized_name })
        )
      end
    end
  end

  vim.defer_fn(function()
    local status_ok, which_key = pcall(require, 'which-key')
    if status_ok then
      if config.keymaps.toggle.normal then
        which_key.add {
          mode = 'n',
          { config.keymaps.toggle.normal, desc = 'Cursor Agent: Toggle', icon = '🤖' },
        }
      end
      if config.keymaps.toggle.terminal then
        which_key.add {
          mode = 't',
          { config.keymaps.toggle.terminal, desc = 'Cursor Agent: Toggle', icon = '🤖' },
        }
      end

      if config.keymaps.toggle.variants then
        for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
          if keymap then
            local capitalized_name = variant_name:gsub('^%l', string.upper)
            which_key.add {
              mode = 'n',
              { keymap, desc = 'Cursor Agent: ' .. capitalized_name, icon = '🤖' },
            }
          end
        end
      end
    end
  end, 100)
end

---Set up terminal-specific keymaps for window navigation
---@param cursor_agent table The main plugin module
---@param config table The plugin configuration
function M.setup_terminal_navigation(cursor_agent, config)
  local current_instance = cursor_agent.terminal.current_instance
  local buf = current_instance and cursor_agent.terminal.instances[current_instance]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local augroup = vim.api.nvim_create_augroup('CursorAgentTerminalFocus_' .. buf, { clear = true })

    vim.api.nvim_create_autocmd(
      { 'WinEnter', 'BufEnter', 'WinLeave', 'FocusGained', 'CmdLineLeave' },
      {
        group = augroup,
        callback = function()
          vim.schedule(cursor_agent.force_insert_mode)
        end,
        desc = 'Auto-enter insert mode when focusing Cursor Agent terminal',
      }
    )

    if config.keymaps.window_navigation then
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-h>',
        [[<C-\><C-n><C-w>h:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move left' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-j>',
        [[<C-\><C-n><C-w>j:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-k>',
        [[<C-\><C-n><C-w>k:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move up' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-l>',
        [[<C-\><C-n><C-w>l:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move right' }
      )

      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-h>',
        [[<C-w>h:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move left' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-j>',
        [[<C-w>j:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-k>',
        [[<C-w>k:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move up' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-l>',
        [[<C-w>l:lua require("cursoragent").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move right' }
      )
    end

    if config.keymaps.scrolling then
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-f>',
        [[<C-\><C-n><C-f>i]],
        { noremap = true, silent = true, desc = 'Scroll full page down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-b>',
        [[<C-\><C-n><C-b>i]],
        { noremap = true, silent = true, desc = 'Scroll full page up' }
      )
    end
  end
end

return M

