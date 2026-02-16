local M = {}

function M.get_api_key(cfg)
	-- If someone accidentally puts a raw key into api_key_env, accept it as a direct key.
	if type(cfg.api_key_env) == "string" and cfg.api_key_env:match("^sk%-") then
		return cfg.api_key_env, nil
	end

	if cfg.api_key_env and cfg.api_key_env ~= "" then
		local key = vim.env[cfg.api_key_env]
		return key, cfg.api_key_env
	end

	if cfg.api_key and cfg.api_key ~= "" then
		local from_env = vim.env[cfg.api_key]
		if from_env and from_env ~= "" then
			return from_env, cfg.api_key
		end
		return cfg.api_key, nil
	end

	return nil, nil
end

function M.system_prompt(profile)
	local parts = {
		"You are a Neovim editing assistant.",
		"Return ONLY valid JSON with keys: explanation (string), steps (array of strings), suggestions (array).",
		"explanation must be short (<= 2 sentences).",
		"steps must be concise and actionable.",
		"Each suggestions[] item must have: label (string), "
			.. "kind (keys|replace_selection|replace_buffer|ex_command), payload (string).",
		"Prefer robust motions/text-objects over line numbers when possible.",
		"If unsafe or unknown, return empty suggestions and explain.",
	}

	local apply = type(profile) == "table" and profile.apply or nil
	local enabled = type(apply) == "table" and apply.enabled
	local allowed = type(apply) == "table" and apply.allowed_kinds or nil
	if vim.tbl_islist(allowed) and #allowed > 0 then
		table.insert(parts, "Only use suggestion kinds: " .. table.concat(allowed, ", ") .. ".")
	end
	if enabled == false then
		table.insert(parts, "Suggestions are advisory only and will not be executed by the editor.")
	end

	local custom = type(profile) == "table" and profile.system_message or nil
	if type(custom) == "string" then
		custom = vim.trim(custom)
		if custom ~= "" then
			table.insert(parts, "Additional system instruction: " .. custom)
		end
	end

	return table.concat(parts, " ")
end

function M.build_user_message(prompt, request, _profile)
	local lines = {
		"Task:",
		prompt,
		"",
	}

	if request.include_current_line ~= false then
		table.insert(lines, string.format("Current cursor line (%d):", request.current_row))
		table.insert(lines, request.current_line)
		table.insert(lines, "")
	end

	if request.selection then
		table.insert(
			lines,
			string.format("Selected lines (%d-%d):", request.selection.start_line, request.selection.end_line)
		)
		table.insert(lines, request.selection.text)
		table.insert(lines, "")
	end

	table.insert(lines, "Current buffer excerpt:")
	table.insert(lines, request.buffer_excerpt)

	return table.concat(lines, "\n")
end

function M.decode_response_json(response_body)
	local ok, parsed = pcall(vim.json.decode, response_body)
	if not ok or not parsed then
		return nil, "failed to parse model response"
	end
	return parsed, nil
end

return M
