# cursoragent.nvim

A Neovim plugin for seamless integration with Cursor Agent CLI. Provides terminal-based interface with multi-instance support, automatic file refresh, and support for multiple Cursor Agent modes.

## Demo

![Demo](./assets/demo.gif)

> **Note**: This plugin is inspired by [xTacobaco/cursor-agent.nvim](https://github.com/xTacobaco/cursor-agent.nvim) and [greggh/claude-code.nvim](https://github.com/greggh/claude-code.nvim). While the original cursor-agent.nvim provides a minimal floating terminal interface, this plugin adds multi-instance support, file refresh, window management, and support for Cursor Agent's different modes, drawing inspiration from claude-code.nvim's comprehensive feature set.

## Requirements

- Neovim 0.9.0 or higher
- Cursor Agent CLI: `cursor-agent` available on your `$PATH`

## Installation

### lazy.nvim

```lua
{
  "eun2ce/cursoragent.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("cursoragent").setup({})
  end,
}
```

### packer.nvim

```lua
use({
  "eun2ce/cursoragent.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("cursoragent").setup({})
  end,
})
```

## Quickstart

- Run `:CursorAgent` to toggle an interactive terminal (defaults to agent mode)
- Use `:CursorAgentAsk` or `:CursorAgentPlan` for specific modes
- Use `:CursorAgentResume` to resume the most recent conversation
- Visually select code and use `:CursorAgentSelection` to send it
- Use `:CursorAgentBuffer` to send the entire current buffer

## Commands

- `:CursorAgent` - Toggle the interactive Cursor Agent terminal (agent mode by default)
- `:CursorAgentAsk` - Launch in ask mode
- `:CursorAgentPlan` - Launch in plan mode
- `:CursorAgentResume` - Resume the most recent conversation
- `:CursorAgentSelection` - Send the current visual selection
- `:CursorAgentBuffer` - Send the full current buffer

## Configuration

```lua
require("cursoragent").setup({
  -- Command settings (include CLI options here)
  command = "cursor-agent --model auto", -- Use --model auto to avoid usage limits
  
  -- Window position: "float", "botright", "topleft", etc.
  window = {
    position = "botright vsplit", -- Opens on the right side (use "botright vsplit" or "vertical")
    split_ratio = 0.3,
  },
  
  command_variants = {
    ask = "ask",
    plan = "plan",
    resume = "--resume",
  },
  
  keymaps = {
    toggle = {
      normal = "<leader>ca",
      variants = {
        ask = "<leader>cA",
        plan = "<leader>cP",
        resume = "<leader>cR",
      },
    },
  },
})
```

See `lua/cursoragent/config.lua` for all available options.

## How It Works

- Terminal windows are created using Neovim's terminal API
- The terminal starts in the detected project root (git root if available)
- For selection/buffer commands, text is written to a temporary file and passed to the CLI
- File changes are automatically detected and buffers are reloaded when Cursor Agent modifies files
- Multiple instances are supported per git repository when `multi_instance` is enabled

## Troubleshooting

- CLI not found: Ensure `cursor-agent` is on your `$PATH`
- No output appears: Verify your CLI installation by running it in a normal terminal
- Wrong directory: The terminal starts in your project root (git root if available)

## Acknowledgements

- [xTacobaco/cursor-agent.nvim](https://github.com/xTacobaco/cursor-agent.nvim) - Original minimal implementation
- [greggh/claude-code.nvim](https://github.com/greggh/claude-code.nvim) - Inspiration for multi-instance support, file refresh, and window management features
- Cursor Agent CLI by Cursor

