local config = require("promptly.config")
local model = require("promptly.model")
local ui = require("promptly.ui")

local M = {}
local request_lock = false

local function start_spinner(label, profile_name)
	local frames = { "-", "\\", "|", "/" }
	local i = 1
	local active = true
	local uv = vim.uv or vim.loop
	local timer = uv and uv.new_timer() or nil

	local function render()
		if not active then
			return
		end
		local text = string.format("%s promptly[%s]: %s", frames[i], profile_name or "unknown", label)
		vim.api.nvim_echo({ { text, "ModeMsg" } }, false, {})
		i = (i % #frames) + 1
	end

	render()

	if timer then
		timer:start(100, 100, vim.schedule_wrap(render))
	end

	return function(final_text, hl)
		if not active then
			return
		end
		active = false
		if timer then
			timer:stop()
			timer:close()
		end

		if final_text and final_text ~= "" then
			vim.api.nvim_echo({ { final_text, hl or "ModeMsg" } }, false, {})
		else
			vim.api.nvim_echo({ { "", "Normal" } }, false, {})
		end
	end
end

local function build_buffer_excerpt(max_lines)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if #lines > max_lines then
		lines = vim.list_slice(lines, 1, max_lines)
	end
	return table.concat(lines, "\n")
end

local function build_request(opts, profile)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_row = cursor[1]
	local current_line = vim.api.nvim_get_current_line()
	local selection = nil
	local context = profile.context or {}

	if context.include_selection ~= false and opts and opts.range and opts.range > 0 then
		local start_line = opts.line1
		local end_line = opts.line2
		local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

		selection = {
			start_line = start_line,
			end_line = end_line,
			text = table.concat(selected_lines, "\n"),
		}
	end

	return {
		buffer_excerpt = build_buffer_excerpt(context.max_context_lines or 400),
		current_row = current_row,
		current_line = current_line,
		selection = selection,
		include_current_line = context.include_current_line ~= false,
	}
end

local function feed_keys(keys)
	local replaced = vim.api.nvim_replace_termcodes(keys, true, false, true)
	vim.api.nvim_feedkeys(replaced, "n", false)
end

local function replace_buffer(text)
	local lines = vim.split(text, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function replace_selection(selection, text)
	if not selection then
		vim.notify("promptly: no selection available for this suggestion", vim.log.levels.WARN)
		return
	end
	local lines = vim.split(text, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(0, selection.start_line - 1, selection.end_line, false, lines)
end

local function run_ex_command(command_text)
	local ok, err = pcall(vim.cmd, command_text)
	if not ok then
		vim.notify("promptly: failed to run command: " .. tostring(err), vim.log.levels.ERROR)
	end
end

local function apply_suggestion(suggestion, request)
	local kind = suggestion.kind
	local payload = suggestion.payload or ""

	if kind == "keys" then
		feed_keys(payload)
		return
	end
	if kind == "replace_selection" then
		replace_selection(request.selection, payload)
		return
	end
	if kind == "replace_buffer" then
		replace_buffer(payload)
		return
	end
	if kind == "ex_command" then
		run_ex_command(payload)
		return
	end

	vim.notify("promptly: unsupported suggestion kind: " .. tostring(kind), vim.log.levels.WARN)
end

function M.run(opts)
	if request_lock then
		vim.notify("promptly: request already running", vim.log.levels.WARN)
		return
	end

	local profile_names = config.profile_names()
	if #profile_names == 0 then
		vim.notify("promptly: no profiles configured in setup().profiles", vim.log.levels.ERROR)
		return
	end

	local initial_profile = config.current_profile_name()

	ui.prompt({
		profile_names = profile_names,
		initial_profile = initial_profile,
	}, function(prompt, selected_profile_name)
		if not prompt or prompt:gsub("%s+", "") == "" then
			return
		end

		local profile_err = config.profile_error(selected_profile_name)
		if profile_err then
			vim.notify("promptly: " .. profile_err, vim.log.levels.ERROR)
			return
		end

		local profile = config.profile_by_name(selected_profile_name)
		local provider = config.provider_for_profile(selected_profile_name)
		if not profile or not provider then
			vim.notify("promptly: invalid provider configuration", vim.log.levels.ERROR)
			return
		end

		local request = build_request(opts, profile)
		request_lock = true
		local stop_spinner = start_spinner("thinking...", selected_profile_name)

		model.solve_async(provider, profile, prompt, request, function(answer, err)
			request_lock = false
			if err then
				stop_spinner("promptly: request failed", "ErrorMsg")
				vim.notify("promptly: " .. err, vim.log.levels.ERROR)
				return
			end

			stop_spinner("promptly: done", "MoreMsg")
			ui.result(answer, profile, function(suggestion)
				apply_suggestion(suggestion, request)
			end)
		end)
	end)
end

function M.setup(opts)
	config.setup(opts)
end

return M
