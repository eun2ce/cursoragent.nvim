---@meta
---@brief [[
--- Centralized type definitions for CursorAgent.nvim public API.
--- This module contains all user-facing types and configuration structures.
---@brief ]]
---@module 'cursoragent.types'

-- Version information type
---@class CursorAgentVersion
---@field major integer
---@field minor integer
---@field patch integer
---@field prerelease? string
---@field string fun(self: CursorAgentVersion): string

-- Diff behavior configuration
---@class CursorAgentDiffOptions
---@field layout CursorAgentDiffLayout
---@field open_in_new_tab boolean Open diff in a new tab (false = use current tab)
---@field keep_terminal_focus boolean Keep focus in terminal after opening diff
---@field hide_terminal_in_new_tab boolean Hide Cursor Agent terminal in newly created diff tab
---@field on_new_file_reject CursorAgentNewFileRejectBehavior Behavior when rejecting a new-file diff

-- Model selection option
---@class CursorAgentModelOption
---@field name string
---@field value string

-- Log level type alias
---@alias CursorAgentLogLevel "trace"|"debug"|"info"|"warn"|"error"

-- Diff layout type alias
---@alias CursorAgentDiffLayout "vertical"|"horizontal"

-- Behavior when rejecting new-file diffs
---@alias CursorAgentNewFileRejectBehavior "keep_empty"|"close_window"

-- Terminal split side positioning
---@alias CursorAgentSplitSide "left"|"right"

-- In-tree terminal provider names
---@alias CursorAgentTerminalProviderName "auto"|"snacks"|"native"|"external"|"none"

-- Terminal provider-specific options
---@class CursorAgentTerminalProviderOptions
---@field external_terminal_cmd string|(fun(cmd: string, env: table): string)|table|nil Command for external terminal (string template with %s or function)

-- Working directory resolution context and provider
---@class CursorAgentCwdContext
---@field file string|nil   -- absolute path of current buffer file (if any)
---@field file_dir string|nil -- directory of current buffer file (if any)
---@field cwd string        -- current Neovim working directory

---@alias CursorAgentCwdProvider fun(ctx: CursorAgentCwdContext): string|nil

-- @ mention queued for Cursor Agent
---@class CursorAgentMention
---@field file_path string The absolute file path to mention
---@field start_line number? Optional start line (0-indexed for Cursor Agent compatibility)
---@field end_line number? Optional end line (0-indexed for Cursor Agent compatibility)
---@field timestamp number Creation timestamp from vim.loop.now() for expiry tracking

-- Terminal provider interface
---@class CursorAgentTerminalProvider
---@field setup fun(config: CursorAgentTerminalConfig)
---@field open fun(cmd_string: string, env_table: table, config: CursorAgentTerminalConfig, focus: boolean?)
---@field close fun()
---@field toggle fun(cmd_string: string, env_table: table, effective_config: CursorAgentTerminalConfig)
---@field simple_toggle fun(cmd_string: string, env_table: table, effective_config: CursorAgentTerminalConfig)
---@field focus_toggle fun(cmd_string: string, env_table: table, effective_config: CursorAgentTerminalConfig)
---@field get_active_bufnr fun(): number?
---@field is_available fun(): boolean
---@field ensure_visible? function
---@field _get_terminal_for_test fun(): table?

-- Terminal configuration
---@class CursorAgentTerminalConfig
---@field split_side CursorAgentSplitSide
---@field split_width_percentage number
---@field provider CursorAgentTerminalProviderName|CursorAgentTerminalProvider
---@field show_native_term_exit_tip boolean
---@field terminal_cmd string?
---@field provider_opts CursorAgentTerminalProviderOptions?
---@field auto_close boolean
---@field env table<string, string>
---@field snacks_win_opts snacks.win.Config
---@field cwd string|nil                 -- static working directory for Cursor Agent terminal
---@field git_repo_cwd boolean|nil      -- use git root of current file/cwd as working directory
---@field cwd_provider? CursorAgentCwdProvider -- custom function to compute working directory

-- Port range configuration
---@class CursorAgentPortRange
---@field min integer
---@field max integer

-- Server status information
---@class CursorAgentServerStatus
---@field running boolean
---@field port integer?
---@field client_count integer
---@field clients? table<string, any>

-- Main configuration structure
---@class CursorAgentConfig
---@field port_range CursorAgentPortRange
---@field auto_start boolean
---@field terminal_cmd string|nil
---@field env table<string, string>
---@field log_level CursorAgentLogLevel
---@field track_selection boolean
---@field focus_after_send boolean
---@field visual_demotion_delay_ms number
---@field connection_wait_delay number
---@field connection_timeout number
---@field queue_timeout number
---@field diff_opts CursorAgentDiffOptions
---@field models CursorAgentModelOption[]
---@field disable_broadcast_debouncing? boolean
---@field enable_broadcast_debouncing_in_tests? boolean
---@field terminal CursorAgentTerminalConfig?

---@class (partial) PartialCursorAgentConfig: CursorAgentConfig

-- Server interface for main module
---@class CursorAgentServerFacade
---@field start fun(config: CursorAgentConfig, auth_token: string|nil): (success: boolean, port_or_error: number|string)
---@field stop fun(): (success: boolean, error_message: string?)
---@field broadcast fun(method: string, params: table?): boolean
---@field get_status fun(): CursorAgentServerStatus

-- Main module state
---@class CursorAgentState
---@field config CursorAgentConfig
---@field server CursorAgentServerFacade|nil
---@field port integer|nil
---@field auth_token string|nil
---@field initialized boolean
---@field mention_queue CursorAgentMention[]
---@field mention_timer uv.uv_timer_t?  -- (compatible with vim.loop timer)
---@field connection_timer uv.uv_timer_t?  -- (compatible with vim.loop timer)

-- This module only defines types, no runtime functionality
return {}

