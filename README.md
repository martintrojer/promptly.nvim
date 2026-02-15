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

```lua
require("promptly").setup({
  profile = "code_assist",

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
        max_context_lines = 400,
        include_current_line = true,
        include_selection = true,
      },
      apply = {
        default = "first_suggestion",
        handlers = {
          keys = "feedkeys",
          replace_selection = "replace_selection",
          replace_buffer = "replace_buffer",
          ex_command = "nvim_cmd",
        },
      },
      ui = {
        prompt_title = " Promptly Prompt ",
        result_title = " Promptly Suggestions ",
      },
    },
  },
})
```

## Configuration example (golf_this profile)

Use a dedicated profile named `golf_this` and make it active:

```lua
require("promptly").setup({
  profile = "golf_this",

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
        max_context_lines = 250,
        include_current_line = true,
        include_selection = true,
      },
      ui = {
        prompt_title = " Golf Prompt ",
        result_title = " Golf Suggestions ",
      },
      apply = {
        default = "first_suggestion",
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
