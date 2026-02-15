# promptly.nvim

`promptly.nvim` is a Neovim plugin for prompt-driven editing suggestions.

## What it does

- `:Promptly` opens an inline prompt input over your current buffer.
- Sends prompt + editor context (current line, optional selection, buffer excerpt).
- Shows explanation, steps, and one or more suggestions.
- Applies suggestions directly to the current buffer.

Supported suggestion kinds:
- `keys`
- `replace_selection`
- `replace_buffer`
- `ex_command`

## Install

Repository: [https://github.com/martintrojer/promptly.nvim](https://github.com/martintrojer/promptly.nvim)

## API keys

Use environment variables for API keys.

```bash
export OPENAI_API_KEY="..."
export OPENROUTER_API_KEY="..."
export ANTHROPIC_API_KEY="..."
```

## Provider fields: required vs optional

Every profile must point to a provider name:

- `profiles.<name>.provider` is required.
- `profiles.<name>.system_message` is required and must be a non-empty string.
- Promptly starts on the first profile (sorted by name), and you can switch in the popup.
- Promptly ships with a built-in `code_assistant` profile.
- Set `include_default_profile = false` to exclude the built-in default from profile cycling.
- Built-in `code_assistant` uses provider `openai` by default.
- Override it by setting `profiles.code_assistant.provider` in your setup.

Inside `providers.<name>`:

- `kind`, `url`, `model`, `api_key_env` are optional for built-in families:
  - `openai`
  - `openrouter`
  - `anthropic`
  - `ollama`
- Promptly infers defaults for those families from provider name and/or URL.
- `api_key_env` is optional for local providers (for example Ollama).

If you use a custom provider name/URL that does not match a built-in family:

- `kind` is required (`openai_compatible` or `anthropic`)
- `url` is required
- `model` is required
- `api_key_env` (or `api_key`) is required for authenticated remote endpoints

Provider-specific optional fields:

- OpenRouter: `referer`, `title`
- Anthropic: `anthropic_version`, `max_tokens`

## Configuration example (general coding assistant)

To change which provider the built-in `code_assistant` profile uses, override
that profile by name:

```lua
require("promptly").setup({
  providers = {
    openrouter = {
      kind = "openai_compatible", -- optional (inferred for built-in provider names)
      url = "https://openrouter.ai/api/v1/chat/completions", -- optional (inferred)
      model = "anthropic/claude-3.5-sonnet", -- optional (inferred default exists)
      api_key_env = "OPENROUTER_API_KEY", -- optional (inferred to OPENROUTER_API_KEY)
    },
  },
  profiles = {
    code_assistant = {
      provider = "openrouter",
      system_message = "You are a Neovim coding assistant. Prefer safe, minimal edits.",
    },
  },
})
```

```lua
require("promptly").setup({
  -- optional: exclude built-in "code_assistant" profile
  include_default_profile = false,

  providers = {
    openrouter = {
      kind = "openai_compatible", -- optional (inferred for built-in provider names)
      url = "https://openrouter.ai/api/v1/chat/completions", -- optional (inferred)
      model = "openai/gpt-4.1-mini", -- optional (inferred default exists)
      api_key_env = "OPENROUTER_API_KEY", -- optional (inferred to OPENROUTER_API_KEY)
      referer = "https://your-site.example", -- optional (OpenRouter)
      title = "promptly.nvim", -- optional (OpenRouter)
    },
  },

  profiles = {
    code_assist = {
      provider = "openrouter",
      system_message = "You are a Neovim coding assistant. Prefer safe, minimal edits and explain tradeoffs briefly.", -- required
      context = {
        max_context_lines = 400, -- optional
        include_current_line = true, -- optional
        include_selection = true, -- optional
      },
      apply = {
        default = "first_suggestion", -- optional
        handlers = {
          keys = "feedkeys", -- optional
          replace_selection = "replace_selection", -- optional
          replace_buffer = "replace_buffer", -- optional
          ex_command = "nvim_cmd", -- optional
        },
      },
      ui = {
        prompt_title = " Promptly Prompt ", -- optional
        result_title = " Promptly Suggestions ", -- optional
      },
    },
  },
})
```

## Configuration example (golf_this profile)

Use a dedicated profile named `golf_this`:

```lua
require("promptly").setup({
  include_default_profile = false, -- optional: hide built-in "code_assistant"

  providers = {
    openrouter = {
      kind = "openai_compatible", -- optional (inferred)
      url = "https://openrouter.ai/api/v1/chat/completions", -- optional (inferred)
      model = "anthropic/claude-3.5-sonnet", -- optional (inferred default exists)
      api_key_env = "OPENROUTER_API_KEY", -- optional (inferred to OPENROUTER_API_KEY)
      referer = "https://your-site.example", -- optional
      title = "promptly.nvim", -- optional
    },
  },

  profiles = {
    golf_this = {
      provider = "openrouter",
      system_message = "You are a Vim golf specialist. Return shortest robust normal-mode sequences and avoid brittle absolute line-number jumps.", -- required
      context = {
        max_context_lines = 250, -- optional
        include_current_line = true, -- optional
        include_selection = true, -- optional
      },
      ui = {
        prompt_title = " Golf Prompt ", -- optional
        result_title = " Golf Suggestions ", -- optional
      },
      apply = {
        default = "first_suggestion", -- optional
      },
    },
  },
})
```

Then run:

- `:Promptly` for current line
- `:'<,'>Promptly` for a selected range

## Commands

- `:Promptly`
- `:PromptlyHealth`

## Usage

- `:Promptly` for current-line context.
- `:'<,'>Promptly` for range/Visual context.

In result popup:
- `<Esc>` or `q`: close
- `<CR>`: apply suggestion #1
- `1-9`: apply suggestion

In prompt popup (when multiple profiles are configured):
- `<Tab>` / `<S-Tab>`: next/previous profile
- `<C-n>` / `<C-p>`: next/previous profile
