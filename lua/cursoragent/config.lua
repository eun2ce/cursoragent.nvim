local M = {}

---@class CursorAgentWindowConfig
---@field position string Window position: "float", "botright", "topleft", "vertical", "vsplit"
---@field split_ratio number Ratio for split windows (0-1)
---@field enter_insert boolean Enter insert mode when opening
---@field start_in_normal_mode boolean Whether to start in normal mode instead of insert mode
---@field hide_numbers boolean Hide line numbers
---@field hide_signcolumn boolean Hide sign column
---@field float CursorAgentFloatConfig|nil Floating window config (when position = "float")

---@class CursorAgentFloatConfig
---@field width number|string Width (number or percentage like "80%")
---@field height number|string Height (number or percentage like "80%")
---@field row number|string|nil Row position (number, "center", or percentage)
---@field col number|string|nil Column position (number, "center", or percentage)
---@field relative string Relative positioning: "editor" or "cursor"
---@field border string Border style: "none", "single", "double", "rounded", "solid", "shadow"

---@class CursorAgentRefreshConfig
---@field enable boolean Enable file change detection
---@field updatetime number updatetime when active (milliseconds)
---@field timer_interval number File check interval (milliseconds)
---@field show_notifications boolean Show notification when files reloaded

---@class CursorAgentGitConfig
---@field use_git_root boolean Set CWD to git root when opening
---@field multi_instance boolean Use multiple instances (one per git root)

---@class CursorAgentShellConfig
---@field separator string Command separator (e.g., '&&', ';')
---@field pushd_cmd string Command to push directory (e.g., 'pushd')
---@field popd_cmd string Command to pop directory (e.g., 'popd')

---@class CursorAgentKeymapsToggle
---@field normal string|boolean Normal mode keymap, false to disable
---@field terminal string|boolean Terminal mode keymap, false to disable
---@field variants table<string, string|boolean>|nil Variant keymaps

---@class CursorAgentKeymapsConfig
---@field toggle CursorAgentKeymapsToggle Toggle keymaps
---@field window_navigation boolean Enable window navigation keymaps
---@field scrolling boolean Enable scrolling keymaps

---@class CursorAgentConfig
---@field command string Command used to launch Cursor Agent
---@field window CursorAgentWindowConfig Window settings
---@field refresh CursorAgentRefreshConfig File refresh settings
---@field git CursorAgentGitConfig Git integration settings
---@field shell CursorAgentShellConfig Shell-specific settings
---@field command_variants table<string, string|boolean> Command variants (e.g., { resume = "--resume" })
---@field keymaps CursorAgentKeymapsConfig Keymaps configuration

local default_config = {
  window = {
    position = "float",
    split_ratio = 0.3,
    enter_insert = true,
    start_in_normal_mode = false,
    hide_numbers = true,
    hide_signcolumn = true,
    float = {
      width = "80%",
      height = "80%",
      row = "center",
      col = "center",
      relative = "editor",
      border = "rounded",
    },
  },
  
  refresh = {
    enable = true,
    updatetime = 100,
    timer_interval = 1000,
    show_notifications = true,
  },
  
  git = {
    use_git_root = true,
    multi_instance = true,
  },
  
  shell = {
    separator = '&&',
    pushd_cmd = 'pushd',
    popd_cmd = 'popd',
  },
  
  command = "cursor-agent",
  command_variants = {
    ask = "ask",
    plan = "plan",
    resume = "--resume",
  },
  
  keymaps = {
    toggle = {
      normal = "<leader>ca",
      terminal = "<leader>ca",
      variants = {
        ask = "<leader>cA",
        plan = "<leader>cP",
        resume = "<leader>cR",
      },
    },
    window_navigation = true,
    scrolling = true,
  },
}

local active_config = vim.deepcopy(default_config)

---Validate window configuration
---@param window table
---@return boolean valid
---@return string? error_message
local function validate_window_config(window)
  if type(window) ~= 'table' then
    return false, 'window config must be a table'
  end
  
  if type(window.split_ratio) ~= 'number' or window.split_ratio <= 0 or window.split_ratio > 1 then
    return false, 'window.split_ratio must be a number between 0 and 1'
  end
  
  if type(window.position) ~= 'string' then
    return false, 'window.position must be a string'
  end
  
  if type(window.enter_insert) ~= 'boolean' then
    return false, 'window.enter_insert must be a boolean'
  end
  
  if type(window.start_in_normal_mode) ~= 'boolean' then
    return false, 'window.start_in_normal_mode must be a boolean'
  end
  
  if type(window.hide_numbers) ~= 'boolean' then
    return false, 'window.hide_numbers must be a boolean'
  end
  
  if type(window.hide_signcolumn) ~= 'boolean' then
    return false, 'window.hide_signcolumn must be a boolean'
  end
  
  return true, nil
end

---Validate float configuration
---@param float table
---@return boolean valid
---@return string? error_message
local function validate_float_config(float)
  if type(float) ~= 'table' then
    return false, 'window.float must be a table when position is "float"'
  end
  
  -- Validate width
  if type(float.width) == 'string' then
    if not float.width:match('^%d+%%$') then
      return false, 'window.float.width must be a number or percentage (e.g., "80%")'
    end
  elseif type(float.width) ~= 'number' or float.width <= 0 then
    return false, 'window.float.width must be a positive number or percentage string'
  end
  
  -- Validate height
  if type(float.height) == 'string' then
    if not float.height:match('^%d+%%$') then
      return false, 'window.float.height must be a number or percentage (e.g., "80%")'
    end
  elseif type(float.height) ~= 'number' or float.height <= 0 then
    return false, 'window.float.height must be a positive number or percentage string'
  end
  
  -- Validate relative
  if float.relative ~= 'editor' and float.relative ~= 'cursor' then
    return false, 'window.float.relative must be "editor" or "cursor"'
  end
  
  -- Validate border
  local valid_borders = { 'none', 'single', 'double', 'rounded', 'solid', 'shadow' }
  local is_valid_border = false
  for _, border in ipairs(valid_borders) do
    if float.border == border then
      is_valid_border = true
      break
    end
  end
  if not is_valid_border and type(float.border) ~= 'table' then
    return false, 'window.float.border must be one of: none, single, double, rounded, solid, shadow, or an array'
  end
  
  return true, nil
end

---Validate refresh configuration
---@param refresh table
---@return boolean valid
---@return string? error_message
local function validate_refresh_config(refresh)
  if type(refresh) ~= 'table' then
    return false, 'refresh config must be a table'
  end
  
  if type(refresh.enable) ~= 'boolean' then
    return false, 'refresh.enable must be a boolean'
  end
  
  if type(refresh.updatetime) ~= 'number' or refresh.updatetime <= 0 then
    return false, 'refresh.updatetime must be a positive number'
  end
  
  if type(refresh.timer_interval) ~= 'number' or refresh.timer_interval <= 0 then
    return false, 'refresh.timer_interval must be a positive number'
  end
  
  if type(refresh.show_notifications) ~= 'boolean' then
    return false, 'refresh.show_notifications must be a boolean'
  end
  
  return true, nil
end

---Validate git configuration
---@param git table
---@return boolean valid
---@return string? error_message
local function validate_git_config(git)
  if type(git) ~= 'table' then
    return false, 'git config must be a table'
  end
  
  if type(git.use_git_root) ~= 'boolean' then
    return false, 'git.use_git_root must be a boolean'
  end
  
  if type(git.multi_instance) ~= 'boolean' then
    return false, 'git.multi_instance must be a boolean'
  end
  
  return true, nil
end

---Validate shell configuration
---@param shell table
---@return boolean valid
---@return string? error_message
local function validate_shell_config(shell)
  if type(shell) ~= 'table' then
    return false, 'shell config must be a table'
  end
  
  if type(shell.separator) ~= 'string' then
    return false, 'shell.separator must be a string'
  end
  
  if type(shell.pushd_cmd) ~= 'string' then
    return false, 'shell.pushd_cmd must be a string'
  end
  
  if type(shell.popd_cmd) ~= 'string' then
    return false, 'shell.popd_cmd must be a string'
  end
  
  return true, nil
end

---Validate keymaps configuration
---@param keymaps table
---@return boolean valid
---@return string? error_message
local function validate_keymaps_config(keymaps)
  if type(keymaps) ~= 'table' then
    return false, 'keymaps config must be a table'
  end
  
  if type(keymaps.toggle) ~= 'table' then
    return false, 'keymaps.toggle must be a table'
  end
  
  if not (keymaps.toggle.normal == false or type(keymaps.toggle.normal) == 'string') then
    return false, 'keymaps.toggle.normal must be a string or false'
  end
  
  if not (keymaps.toggle.terminal == false or type(keymaps.toggle.terminal) == 'string') then
    return false, 'keymaps.toggle.terminal must be a string or false'
  end
  
  if keymaps.toggle.variants then
    if type(keymaps.toggle.variants) ~= 'table' then
      return false, 'keymaps.toggle.variants must be a table'
    end
    
    for variant_name, keymap in pairs(keymaps.toggle.variants) do
      if not (keymap == false or type(keymap) == 'string') then
        return false, 'keymaps.toggle.variants.' .. variant_name .. ' must be a string or false'
      end
    end
  end
  
  if type(keymaps.window_navigation) ~= 'boolean' then
    return false, 'keymaps.window_navigation must be a boolean'
  end
  
  if type(keymaps.scrolling) ~= 'boolean' then
    return false, 'keymaps.scrolling must be a boolean'
  end
  
  return true, nil
end

---Validate command variants configuration
---@param command_variants table
---@return boolean valid
---@return string? error_message
local function validate_command_variants_config(command_variants)
  if type(command_variants) ~= 'table' then
    return false, 'command_variants config must be a table'
  end
  
  for variant_name, variant_args in pairs(command_variants) do
    if not (variant_args == false or type(variant_args) == 'string') then
      return false, 'command_variants.' .. variant_name .. ' must be a string or false'
    end
  end
  
  return true, nil
end

---Validate configuration
---@param config CursorAgentConfig
---@return boolean valid
---@return string? error_message
local function validate_config(config)
  -- Validate command
  if type(config.command) ~= 'string' or config.command == '' then
    return false, 'command must be a non-empty string'
  end
  
  -- Validate window settings
  local valid, err = validate_window_config(config.window)
  if not valid then
    return false, err
  end
  
  -- Validate float configuration if position is "float"
  if config.window.position == 'float' then
    valid, err = validate_float_config(config.window.float)
    if not valid then
      return false, err
    end
  end
  
  -- Validate refresh settings
  valid, err = validate_refresh_config(config.refresh)
  if not valid then
    return false, err
  end
  
  -- Validate git settings
  valid, err = validate_git_config(config.git)
  if not valid then
    return false, err
  end
  
  -- Validate shell settings
  valid, err = validate_shell_config(config.shell)
  if not valid then
    return false, err
  end
  
  -- Validate command variants
  valid, err = validate_command_variants_config(config.command_variants)
  if not valid then
    return false, err
  end
  
  -- Validate keymaps
  valid, err = validate_keymaps_config(config.keymaps)
  if not valid then
    return false, err
  end
  
  -- Cross-validate keymaps with command variants
  if config.keymaps.toggle.variants then
    for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
      if keymap ~= false and not config.command_variants[variant_name] then
        return false, 'keymaps.toggle.variants.' .. variant_name .. ' has no corresponding command variant'
      end
    end
  end
  
  return true, nil
end

---Setup configuration
---@param user_config? table
---@param silent? boolean Suppress error notifications (for tests)
function M.setup(user_config, silent)
  -- Deep merge user config with defaults
  local config = vim.tbl_deep_extend('force', {}, default_config, user_config or {})
  
  -- If position is float and no float config provided, use default
  if config.window.position == 'float' and not (user_config and user_config.window and user_config.window.float) then
    config.window.float = vim.deepcopy(default_config.window.float)
  end
  
  local valid, err = validate_config(config)
  if not valid then
    if not silent then
      vim.notify('cursoragent: ' .. err, vim.log.levels.ERROR)
    end
    -- Fall back to default config
    active_config = vim.deepcopy(default_config)
    return
  end
  
  active_config = config
end

---Get current configuration
---@return CursorAgentConfig
function M.get()
  return active_config
end

---Reset to defaults
function M.reset_to_defaults()
  active_config = vim.deepcopy(default_config)
end

return M

