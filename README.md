# golf-this.nvim

`golf-this.nvim` is a Neovim plugin prototype for vimgolf-style editing prompts.

## What it does

- `:GolfThis` opens an inline prompt input over your current buffer.
- Uses async model requests (no editor freeze on Neovim 0.10+).
- Sends your prompt with context:
  - current cursor line (always)
  - selected range text (when using range/Visual)
  - buffer excerpt
- Shows inline response with:
  - short explanation
  - step-by-step approach
  - optional executable key sequence
- `<Esc>` closes the popup.
- `<CR>` runs "Do It" (feeds the returned key sequence into Neovim) and closes.

## Libraries

- Inline UI: [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- Model transport: async HTTP via `vim.system` (Neovim 0.10+) with optional fallback to [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Model API shape:
  - Remote: OpenAI-compatible APIs (`openai`, `openrouter`) and native `anthropic`
  - Local: Ollama OpenAI-compatible endpoint

## Install (lazy.nvim)

```lua
{
  "martintrojer/golf-this",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim", -- fallback HTTP path for older Neovim
  },
  config = function()
    require("golf_this").setup({
      provider = "openai", -- openai | openrouter | anthropic | ollama
      providers = {
        openai = {
          kind = "openai_compatible",
          url = "https://api.openai.com/v1/chat/completions",
          model = "gpt-4.1-mini",
          api_key_env = "OPENAI_API_KEY",
        },
        openrouter = {
          kind = "openai_compatible",
          url = "https://openrouter.ai/api/v1/chat/completions",
          model = "anthropic/claude-3.5-sonnet",
          api_key_env = "OPENROUTER_API_KEY",
          referer = "https://your-site.example", -- optional, recommended by OpenRouter
          title = "golf-this.nvim", -- optional
        },
        anthropic = {
          kind = "anthropic",
          url = "https://api.anthropic.com/v1/messages",
          model = "claude-3-5-sonnet-latest",
          api_key_env = "ANTHROPIC_API_KEY",
          anthropic_version = "2023-06-01",
          max_tokens = 600,
        },
        ollama = {
          kind = "openai_compatible",
          url = "http://localhost:11434/v1/chat/completions",
          model = "qwen2.5-coder:7b",
          api_key_env = nil,
        },
      },
    })
  end,
}
```

## Usage

- Current line context (default): `:GolfThis`
- Visual/range context:
  1. Select lines in Visual mode.
  2. Run `:'<,'>GolfThis`

In the response popup:
- Press `<Esc>` or `q` to close.
- Press `<CR>` to run returned keys.

## Vim docs

- Help file: `doc/golf-this.txt`
- After install, run `:helptags ALL` (or your plugin manager’s helptags hook), then use `:help golf-this`.

## Model Output Contract

The plugin asks the model to return JSON:

```json
{
  "explanation": "short explanation",
  "steps": ["step 1", "step 2"],
  "keys": "normal-mode-key-sequence"
}
```

If `keys` is empty or missing, "Do It" is unavailable.
