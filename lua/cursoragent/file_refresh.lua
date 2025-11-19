---@mod cursoragent.file_refresh File refresh functionality for cursoragent.nvim
---@brief [[
--- This module provides file refresh functionality to detect and reload files
--- that have been modified by cursoragent or other external processes.
---@brief ]]

local M = {}

---Timer for checking file changes
---@type userdata|nil
local refresh_timer = nil

---Setup autocommands for file change detection
---@param cursor_agent table The main plugin module
---@param config table The plugin configuration
function M.setup(cursor_agent, config)
  if not config.refresh.enable then
    return
  end

  local augroup = vim.api.nvim_create_augroup('CursorAgentFileRefresh', { clear = true })

  -- Create an autocommand that checks for file changes more frequently
  vim.api.nvim_create_autocmd({
    'CursorHold',
    'CursorHoldI',
    'FocusGained',
    'BufEnter',
    'InsertLeave',
    'TextChanged',
    'TermLeave',
    'TermEnter',
    'BufWinEnter',
  }, {
    group = augroup,
    pattern = '*',
    callback = function()
      if vim.fn.filereadable(vim.fn.expand '%') == 1 then
        vim.cmd 'checktime'
      end
    end,
    desc = 'Check for file changes on disk',
  })

  -- Clean up any existing timer
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end

  -- Create a timer to check for file changes periodically
  refresh_timer = vim.loop.new_timer()
  if refresh_timer then
    refresh_timer:start(
      0,
      config.refresh.timer_interval,
      vim.schedule_wrap(function()
        -- Only check time if there's an active cursoragent terminal
        local current_instance = cursor_agent.terminal.current_instance
        local bufnr = current_instance and cursor_agent.terminal.instances[current_instance]
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) and #vim.fn.win_findbuf(bufnr) > 0 then
          vim.cmd 'silent! checktime'
        end
      end)
    )
  end

  -- Create an autocommand that notifies when a file has been changed externally
  if config.refresh.show_notifications then
    vim.api.nvim_create_autocmd('FileChangedShellPost', {
      group = augroup,
      pattern = '*',
      callback = function()
        vim.notify('File changed on disk. Buffer reloaded.', vim.log.levels.INFO)
      end,
      desc = 'Notify when a file is changed externally',
    })
  end

  -- Set a shorter updatetime while cursoragent is open
  cursor_agent.terminal.saved_updatetime = vim.o.updatetime

  -- When cursoragent opens, set a shorter updatetime
  vim.api.nvim_create_autocmd('TermOpen', {
    group = augroup,
    pattern = '*',
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match('cursoragent') then
        cursor_agent.terminal.saved_updatetime = vim.o.updatetime
        vim.o.updatetime = config.refresh.updatetime
      end
    end,
    desc = 'Set shorter updatetime when cursoragent is open',
  })

  -- When cursoragent closes, restore normal updatetime
  vim.api.nvim_create_autocmd('TermClose', {
    group = augroup,
    pattern = '*',
    callback = function()
      local buf_name = vim.api.nvim_buf_get_name(0)
      if buf_name:match('cursoragent') then
        if cursor_agent.terminal.saved_updatetime then
          vim.o.updatetime = cursor_agent.terminal.saved_updatetime
        end
      end
    end,
    desc = 'Restore normal updatetime when cursoragent is closed',
  })
end

---Clean up the file refresh functionality (stop the timer)
function M.cleanup()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

return M

