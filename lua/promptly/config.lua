local M = {}
M.validation_error = nil

local defaults = {
	include_default_profile = true,
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
			title = "promptly.nvim",
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
	profiles = {
		code_assistant = {
			provider = "openai",
			system_message = "You are a Neovim coding assistant. Prefer safe, minimal edits and explain tradeoffs briefly.",
			context = {
				max_context_lines = 400,
				include_current_line = true,
				include_selection = true,
			},
			apply = {
				default = "first_suggestion",
			},
			ui = {
				prompt_title = " Code Assistant Prompt ",
				result_title = " Code Assistant Suggestions ",
			},
		},
	},
}

M.values = vim.deepcopy(defaults)

local function detect_family(provider_name, provider)
	local name = tostring(provider_name or ""):lower()
	local url = type(provider.url) == "string" and provider.url:lower() or ""
	local kind = type(provider.kind) == "string" and provider.kind:lower() or ""

	if name:find("openrouter", 1, true) or url:find("openrouter%.ai") then
		return "openrouter"
	end
	if name:find("anthropic", 1, true) or url:find("anthropic%.com") or kind == "anthropic" then
		return "anthropic"
	end
	if name:find("ollama", 1, true) or url:find("localhost:11434", 1, true) or url:find("127%.0%.0%.1:11434") then
		return "ollama"
	end
	if name:find("openai", 1, true) or url:find("api%.openai%.com") then
		return "openai"
	end

	return nil
end

local function apply_inferred_defaults(provider_name, provider)
	local family = detect_family(provider_name, provider)
	if not family then
		return
	end

	if family == "openrouter" then
		provider.kind = provider.kind or "openai_compatible"
		provider.url = provider.url or "https://openrouter.ai/api/v1/chat/completions"
		provider.model = provider.model or "anthropic/claude-3.5-sonnet"
		provider.title = provider.title or "promptly.nvim"
		if not provider.api_key and not provider.api_key_env then
			provider.api_key_env = "OPENROUTER_API_KEY"
		end
		return
	end

	if family == "anthropic" then
		provider.kind = provider.kind or "anthropic"
		provider.url = provider.url or "https://api.anthropic.com/v1/messages"
		provider.model = provider.model or "claude-3-5-sonnet-latest"
		provider.anthropic_version = provider.anthropic_version or "2023-06-01"
		provider.max_tokens = provider.max_tokens or 600
		if not provider.api_key and not provider.api_key_env then
			provider.api_key_env = "ANTHROPIC_API_KEY"
		end
		return
	end

	if family == "ollama" then
		provider.kind = provider.kind or "openai_compatible"
		provider.url = provider.url or "http://localhost:11434/v1/chat/completions"
		provider.model = provider.model or "qwen2.5-coder:7b"
		return
	end

	if family == "openai" then
		provider.kind = provider.kind or "openai_compatible"
		provider.url = provider.url or "https://api.openai.com/v1/chat/completions"
		provider.model = provider.model or "gpt-4.1-mini"
		if not provider.api_key and not provider.api_key_env then
			provider.api_key_env = "OPENAI_API_KEY"
		end
	end
end

function M.setup(opts)
	M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	M.validation_error = nil

	if M.values.include_default_profile == false and M.values.profiles then
		M.values.profiles.code_assistant = nil
	end

	local names = M.profile_names()
	if #names == 0 then
		M.validation_error = "no profiles configured in setup().profiles"
		return
	end

	for profile_name, profile in pairs(M.values.profiles or {}) do
		if type(profile.system_message) ~= "string" or vim.trim(profile.system_message) == "" then
			M.validation_error = string.format(
				"profiles.%s.system_message is required and must be a non-empty string",
				tostring(profile_name)
			)
			break
		end
	end
end

function M.current_provider()
	local profile_name = M.current_profile_name()
	return M.provider_for_profile(profile_name)
end

function M.provider_for_profile(profile_name)
	local profile = M.profile_by_name(profile_name)
	if not profile then
		return nil
	end

	local provider_name = profile.provider
	local provider = M.values.providers[provider_name]
	if not provider then
		return nil
	end

	local resolved = vim.deepcopy(provider)
	apply_inferred_defaults(provider_name, resolved)
	return resolved
end

function M.current_profile()
	return M.profile_by_name(M.current_profile_name())
end

function M.profile_by_name(profile_name)
	if M.validation_error then
		return nil
	end

	local profile = M.values.profiles and M.values.profiles[profile_name] or nil
	if not profile then
		return nil
	end

	if type(profile.system_message) ~= "string" or vim.trim(profile.system_message) == "" then
		return nil
	end

	return vim.deepcopy(profile)
end

function M.current_profile_name()
	local names = M.profile_names()
	return names[1]
end

function M.current_profile_error()
	return M.profile_error(M.current_profile_name())
end

function M.profile_error(profile_name)
	if M.validation_error then
		return M.validation_error
	end

	local profile = M.values.profiles and M.values.profiles[profile_name] or nil
	if not profile then
		return string.format("profile '%s' not found in setup().profiles", tostring(profile_name))
	end
	if type(profile.system_message) ~= "string" or vim.trim(profile.system_message) == "" then
		return string.format(
			"profiles.%s.system_message is required and must be a non-empty string",
			tostring(profile_name)
		)
	end
	return nil
end

function M.profile_names()
	local names = {}
	for name, _ in pairs(M.values.profiles or {}) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return M
