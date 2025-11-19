---@mod cursoragent Cursor Agent Neovim Plugin
---@brief [[
--- A Neovim plugin for seamless integration with Cursor Agent CLI.
--- Provides terminal-based interface with multi-instance support, file refresh,
--- and various window configurations.
---@brief ]]

local config = require('cursoragent.config')
local context = require('cursoragent.context')
local util = require('cursoragent.util')
local terminal = require('cursoragent.terminal')
local file_refresh = require('cursoragent.file_refresh')
local git = require('cursoragent.git')
local commands = require('cursoragent.commands')
local keymaps = require('cursoragent.keymaps')
local termui = require('cursoragent.ui.term')

local M = {}

M.commands = commands
M.config = {}
M.terminal = terminal.terminal

function M.force_insert_mode()
  terminal.force_insert_mode(M, M.config)
end

local function get_current_buffer_number()
  local current_instance = M.terminal.current_instance
  if current_instance and type(M.terminal.instances) == 'table' then
    return M.terminal.instances[current_instance]
  end
  return nil
end

function M.toggle()
  terminal.toggle(M, M.config, git)

  local bufnr = get_current_buffer_number()
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    keymaps.setup_terminal_navigation(M, M.config)
  end
end

---Toggle the cursoragent terminal window with a specific command variant
---@param variant_name string The name of the command variant to use
function M.toggle_with_variant(variant_name)
  if not variant_name or not M.config.command_variants[variant_name] then
    -- If variant doesn't exist, fall back to regular toggle
    return M.toggle()
  end

  local original_command = M.config.command
  local variant_args = M.config.command_variants[variant_name]
  if not variant_args or variant_args == false then
    return M.toggle()
  end

  local is_subcommand = not variant_args:match("^%-%-")
  
  if is_subcommand then
    local base_cmd = original_command:match("^%S+")
    local rest = original_command:match("^%S+%s+(.*)$")
    if rest then
      M.config.command = base_cmd .. ' ' .. variant_args .. ' ' .. rest
    else
      M.config.command = base_cmd .. ' ' .. variant_args
    end
  else
    M.config.command = original_command .. ' ' .. variant_args
  end

  terminal.toggle(M, M.config, git)

  local bufnr = get_current_buffer_number()
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    keymaps.setup_terminal_navigation(M, M.config)
  end

  M.config.command = original_command
end

---Ask cursoragent with a prompt or file
---@param opts table Options table
---@field file string|nil File path to send
---@field prompt string|nil Prompt text to send
---@field title string|nil Window title
function M.ask(opts)
  opts = opts or {}
  local title = opts.title or 'Cursor Agent'
  local cfg = config.get()

  local argv = vim.split(cfg.command, '%s+', { trimempty = true })
  if not argv or #argv == 0 then
    util.err('Invalid command configured')
    return
  end

  if opts.file and opts.file ~= '' then
    table.insert(argv, opts.file)
  elseif opts.prompt and opts.prompt ~= '' then
    table.insert(argv, opts.prompt)
  end

  local root = util.get_project_root()
  termui.open_float_term({
    argv = argv,
    title = title,
    border = 'rounded',
    width = 0.6,
    height = 0.6,
    cwd = root,
    on_exit = function(code)
      if code ~= 0 then
        util.notify(('cursoragent exited with code %d'):format(code), vim.log.levels.WARN)
      end
    end,
  })
end

function M.toggle_terminal()
  M.toggle()
end

---Setup function for the plugin
---@param user_config? table User configuration table (optional)
function M.setup(user_config)
  config.setup(user_config, false)
  M.config = config.get()

  vim.o.autoread = true
  file_refresh.setup(M, M.config)
  commands.register_commands(M)
  keymaps.register_keymaps(M, M.config)
end

return M

