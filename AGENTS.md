# AGENTS.md

## Project

- Name: `promptly.nvim`
- Repository: `https://github.com/martintrojer/promptly.nvim`
- Purpose: prompt-driven Neovim editing assistant that returns structured suggestions and applies them to the current buffer.

## Current Naming (canonical)

- Lua module root: `promptly`
- User commands: `:Promptly`, `:PromptlyHealth`
- Help doc: `doc/promptly.txt` (`:help promptly`)

Do not introduce `golf-this`/`golf_this` naming in code, docs, or commands.

## Code Layout

- Runtime entrypoint: `lua/promptly/init.lua`
- Config: `lua/promptly/config.lua`
- Model parsing: `lua/promptly/model.lua`
- UI: `lua/promptly/ui.lua`
- Transport: `lua/promptly/transport.lua`
- Adapters: `lua/promptly/adapters/`
- Neovim command definitions: `plugin/promptly.lua`
- Health:
  - `lua/promptly/health.lua`
  - `health/promptly.lua`

## Config Shape

Use profile-based configuration:

- Top-level: `include_default_profile`, `providers`, `profiles`
- Active profile defines `system_message` (required, non-empty), prompt context, UI titles, and apply behavior.

## Suggestion Contract

Model responses are expected as JSON:

- `explanation` (string)
- `steps` (string[])
- `suggestions` (array of objects)

Each suggestion object:

- `label` (string)
- `kind` (`keys` | `replace_selection` | `replace_buffer` | `ex_command`)
- `payload` (string)

## Quality Gates

Before finalizing changes run:

```sh
luacheck .
stylua --check .
```

Both must pass with no warnings/errors.

## Docs

If commands/config/contract change, update both:

- `README.md`
- `doc/promptly.txt`

After editing help docs, regenerate helptags in Neovim:

```vim
:helptags /Users/martintrojer/hacking/golf-this/doc
```
