---@mod cursoragent.terminal Terminal management for cursoragent.nvim
---@brief [[
--- This module provides terminal buffer management for cursoragent.nvim.
--- It handles creating, toggling, and managing terminal windows with multi-instance support.
---@brief ]]

local M = {}

---Terminal buffer and window management
---@table CursorAgentTerminal
---@field instances table<string, number> Key-value store of instance ID to buffer number
---@field saved_updatetime number|nil Original updatetime before cursoragent was opened
---@field current_instance string|nil Current instance identifier
M.terminal = {
  instances = {},
  saved_updatetime = nil,
  current_instance = nil,
}

---Get instance identifier (git root or cwd)
---@param git table The git module
---@param config table Plugin configuration
---@return string identifier Instance identifier
local function get_instance_identifier(git, config)
  if config.git.multi_instance then
    if config.git.use_git_root then
      local git_root = git.get_git_root()
      if git_root then
        return git_root
      end
    end
    return vim.fn.getcwd()
  else
    return 'global'
  end
end

---Calculate floating window dimensions from percentage strings
---@param value number|string Dimension value (number or percentage string)
---@param max_value number Maximum value (columns or lines)
---@return number Calculated dimension
local function calculate_float_dimension(value, max_value)
  if value == nil then
    return math.floor(max_value * 0.8)
  elseif type(value) == 'string' and value:match('^%d+%%$') then
    local percentage = tonumber(value:match('^(%d+)%%$'))
    return math.floor(max_value * percentage / 100)
  end
  return value
end

---Calculate floating window position
---@param value number|string Position value (number, "center", or percentage)
---@param window_size number Size of the window
---@param max_value number Maximum value (columns or lines)
---@return number Calculated position
local function calculate_float_position(value, window_size, max_value)
  local pos
  if value == 'center' then
    pos = math.floor((max_value - window_size) / 2)
  elseif type(value) == 'string' and value:match('^%d+%%$') then
    local percentage = tonumber(value:match('^(%d+)%%$'))
    pos = math.floor(max_value * percentage / 100)
  else
    pos = value or 0
  end
  return math.max(0, math.min(pos, max_value - window_size))
end

---Create a floating window
---@param config table Plugin configuration
---@param existing_bufnr number|nil Existing buffer number
---@return number win_id Window ID
local function create_float(config, existing_bufnr)
  local float_config = config.window.float or {}
  
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight - 1
  
  local width = calculate_float_dimension(float_config.width, editor_width)
  local height = calculate_float_dimension(float_config.height, editor_height)
  
  local row = calculate_float_position(float_config.row, height, editor_height)
  local col = calculate_float_position(float_config.col, width, editor_width)
  
  local win_config = {
    relative = float_config.relative or 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = float_config.border or 'rounded',
    style = 'minimal',
  }
  
  local bufnr = existing_bufnr
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
  else
    if not vim.api.nvim_buf_is_valid(bufnr) then
      bufnr = vim.api.nvim_create_buf(false, true)
    else
      local buftype = vim.api.nvim_get_option_value('buftype', {buf = bufnr})
      if buftype ~= 'terminal' then
        bufnr = vim.api.nvim_create_buf(false, true)
      end
    end
  end
  
  return vim.api.nvim_open_win(bufnr, true, win_config)
end

---Build command with git root directory if configured
---@param config table Plugin configuration
---@param git table Git module
---@param base_cmd string Base command to run
---@return string Command with git root directory change if applicable
local function build_command_with_git_root(config, git, base_cmd)
  if config.git and config.git.use_git_root then
    local git_root = git.get_git_root()
    if git_root then
      local quoted_root = vim.fn.shellescape(git_root)
      local separator = config.shell.separator
      local pushd_cmd = config.shell.pushd_cmd
      local popd_cmd = config.shell.popd_cmd
      return pushd_cmd
        .. ' '
        .. quoted_root
        .. ' '
        .. separator
        .. ' '
        .. base_cmd
        .. ' '
        .. separator
        .. ' '
        .. popd_cmd
    end
  end
  return base_cmd
end

---Configure window options
---@param win_id number Window ID
---@param config table Plugin configuration
local function configure_window_options(win_id, config)
  if config.window.hide_numbers then
    vim.api.nvim_set_option_value('number', false, {win = win_id})
    vim.api.nvim_set_option_value('relativenumber', false, {win = win_id})
  end
  
  if config.window.hide_signcolumn then
    vim.api.nvim_set_option_value('signcolumn', 'no', {win = win_id})
  end
end

---Generate buffer name for instance
---@param instance_id string Instance identifier
---@param config table Plugin configuration
---@return string Buffer name
local function generate_buffer_name(instance_id, config)
  if config.git.multi_instance then
    return 'cursoragent-' .. instance_id:gsub('[^%w%-_]', '-')
  else
    return 'cursoragent'
  end
end

---Create a split window
---@param position string Window position
---@param config table Plugin configuration
---@param existing_bufnr number|nil Existing buffer number
local function create_split(position, config, existing_bufnr)
  -- Handle floating window
  if position == 'float' then
    return create_float(config, existing_bufnr)
  end

  local is_vertical = position:match('vsplit') or position:match('vertical')

  if position:match('split') then
    vim.cmd(position)
  else
    local split_cmd = is_vertical and 'vsplit' or 'split'
    vim.cmd(position .. ' ' .. split_cmd)
  end

  if existing_bufnr then
    vim.cmd('buffer ' .. existing_bufnr)
  end
  if is_vertical then
    vim.cmd('vertical resize ' .. math.floor(vim.o.columns * config.window.split_ratio))
  else
    vim.cmd('resize ' .. math.floor(vim.o.lines * config.window.split_ratio))
  end
end

---Check if buffer is a valid terminal
---@param bufnr number Buffer number
---@return boolean is_valid
local function is_valid_terminal_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  
  local buftype = nil
  pcall(function()
    buftype = vim.api.nvim_get_option_value('buftype', {buf = bufnr})
  end)
  
  local terminal_job_id = nil
  pcall(function()
    terminal_job_id = vim.b[bufnr].terminal_job_id
  end)
  
  return buftype == 'terminal'
    and terminal_job_id
    and vim.fn.jobwait({ terminal_job_id }, 0)[1] == -1
end

---Handle existing instance (toggle visibility)
---@param bufnr number Buffer number
---@param config table Plugin configuration
local function handle_existing_instance(bufnr, config)
  local win_ids = vim.fn.win_findbuf(bufnr)
  if #win_ids > 0 then
    for _, win_id in ipairs(win_ids) do
      vim.api.nvim_win_close(win_id, true)
    end
  else
    if config.window.position == 'float' then
      create_float(config, bufnr)
    else
      create_split(config.window.position, config, bufnr)
    end
    if not config.window.start_in_normal_mode then
      vim.schedule(function()
        vim.cmd 'startinsert'
      end)
    end
  end
end

---Create new cursoragent instance
---@param cursor_agent table The main plugin module
---@param config table Plugin configuration
---@param git table Git module
---@param instance_id string Instance identifier
local function create_new_instance(cursor_agent, config, git, instance_id)
  if config.window.position == 'float' then
    local new_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'hide', {buf = new_bufnr})

    local win_id = create_float(config, new_bufnr)
    vim.api.nvim_win_set_buf(win_id, new_bufnr)

    local cmd = build_command_with_git_root(config, git, config.command)
    vim.fn.termopen(cmd)

    local buffer_name = generate_buffer_name(instance_id, config)
    vim.api.nvim_buf_set_name(new_bufnr, buffer_name)

    configure_window_options(win_id, config)
    cursor_agent.terminal.instances[instance_id] = new_bufnr

    if config.window.enter_insert and not config.window.start_in_normal_mode then
      vim.cmd 'startinsert'
    end
  else
    create_split(config.window.position, config)

    local base_cmd = build_command_with_git_root(config, git, config.command)
    local cmd = 'terminal ' .. base_cmd

    vim.cmd(cmd)
    vim.cmd 'setlocal bufhidden=hide'

    local buffer_name = generate_buffer_name(instance_id, config)
    vim.cmd('file ' .. buffer_name)

    local current_win = vim.api.nvim_get_current_win()
    configure_window_options(current_win, config)

    cursor_agent.terminal.instances[instance_id] = vim.fn.bufnr('%')

    if config.window.enter_insert and not config.window.start_in_normal_mode then
      vim.cmd 'startinsert'
    end
  end
end

---Toggle cursoragent terminal window
---@param cursor_agent table The main plugin module
---@param config table Plugin configuration
---@param git table Git module
function M.toggle(cursor_agent, config, git)
  local instance_id = get_instance_identifier(git, config)
  cursor_agent.terminal.current_instance = instance_id
  
  local bufnr = cursor_agent.terminal.instances[instance_id]
  
  if bufnr and not is_valid_terminal_buffer(bufnr) then
    cursor_agent.terminal.instances[instance_id] = nil
    bufnr = nil
  end
  
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    handle_existing_instance(bufnr, config)
  else
    if bufnr and not vim.api.nvim_buf_is_valid(bufnr) then
      cursor_agent.terminal.instances[instance_id] = nil
    end
    create_new_instance(cursor_agent, config, git, instance_id)
  end
end

---Force insert mode when entering cursoragent window
---@param cursor_agent table The main plugin module
---@param config table Plugin configuration
function M.force_insert_mode(cursor_agent, config)
  local current_bufnr = vim.fn.bufnr('%')
  
  local is_cursor_instance = false
  for _, bufnr in pairs(cursor_agent.terminal.instances) do
    if bufnr and bufnr == current_bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      is_cursor_instance = true
      break
    end
  end
  
  if is_cursor_instance then
    local mode = vim.api.nvim_get_mode().mode
    if vim.bo.buftype == 'terminal' and mode ~= 't' and mode ~= 'i' then
      vim.cmd 'silent! stopinsert'
      vim.schedule(function()
        vim.cmd 'silent! startinsert'
      end)
    end
  end
end

return M

