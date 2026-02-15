local M = {}

local defaults = {
  provider = "openai",
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
      referer = nil,
      title = "golf-this.nvim",
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
  max_context_lines = 400,
}

M.values = vim.deepcopy(defaults)

function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

function M.current_provider()
  return M.values.providers[M.values.provider]
end

return M
