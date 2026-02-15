local Input = require("nui.input")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

function M.prompt(opts, on_submit)
	local profile_names = opts.profile_names or {}
	local selected_index = 1
	local selected_profile_name = opts.initial_profile
	local input

	if #profile_names > 0 then
		for i, name in ipairs(profile_names) do
			if name == selected_profile_name then
				selected_index = i
				break
			end
		end
		selected_profile_name = profile_names[selected_index]
	end

	local function title()
		local name = selected_profile_name or "unknown"
		return string.format(" Promptly [%s] ", name)
	end

	local function cycle_profile(step)
		if #profile_names <= 1 then
			return
		end
		selected_index = ((selected_index - 1 + step) % #profile_names) + 1
		selected_profile_name = profile_names[selected_index]
		if input and input.border and input.border.set_text then
			input.border:set_text("top", title())
		end
	end

	input = Input({
		relative = "cursor",
		position = {
			row = 1,
			col = 0,
		},
		size = {
			width = 70,
		},
		border = {
			style = "rounded",
			text = {
				top = title(),
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
		},
	}, {
		prompt = "> ",
		default_value = "",
		on_submit = function(value)
			input:unmount()
			on_submit(value, selected_profile_name)
		end,
	})

	input:mount()
	input:on(event.BufLeave, function()
		input:unmount()
	end)

	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		input:unmount()
	end, { buffer = input.bufnr, nowait = true })

	vim.keymap.set({ "n", "i" }, "<Tab>", function()
		cycle_profile(1)
	end, { buffer = input.bufnr, nowait = true })

	vim.keymap.set({ "n", "i" }, "<S-Tab>", function()
		cycle_profile(-1)
	end, { buffer = input.bufnr, nowait = true })

	vim.keymap.set({ "n", "i" }, "<C-n>", function()
		cycle_profile(1)
	end, { buffer = input.bufnr, nowait = true })

	vim.keymap.set({ "n", "i" }, "<C-p>", function()
		cycle_profile(-1)
	end, { buffer = input.bufnr, nowait = true })
end

function M.result(answer, profile, on_apply)
	local result_title = ((profile or {}).ui or {}).result_title or " Promptly Suggestions "
	local lines = {
		"Promptly",
		"",
		"Explanation:",
		answer.explanation ~= "" and answer.explanation or "(none)",
		"",
		"Steps:",
	}

	if #answer.steps == 0 then
		table.insert(lines, "- (none)")
	else
		for i, step in ipairs(answer.steps) do
			table.insert(lines, string.format("%d. %s", i, step))
		end
	end

	table.insert(lines, "")
	table.insert(lines, "Suggestions:")

	if #answer.suggestions == 0 then
		table.insert(lines, "- (none)")
		table.insert(lines, "")
		table.insert(lines, "<Esc>/q: Close")
	else
		for i, suggestion in ipairs(answer.suggestions) do
			local label = suggestion.label or "Apply"
			table.insert(lines, string.format("%d. %s [%s]", i, label, suggestion.kind))
		end
		table.insert(lines, "")
		table.insert(lines, "<CR>: Apply #1   1-9: Apply choice   <Esc>/q: Close")
	end

	local popup = Popup({
		enter = true,
		focusable = true,
		relative = "editor",
		position = "50%",
		size = {
			width = math.min(vim.o.columns - 6, 90),
			height = math.min(vim.o.lines - 6, math.max(12, #lines + 2)),
		},
		border = {
			style = "rounded",
			text = {
				top = result_title,
			},
		},
		win_options = {
			wrap = true,
			linebreak = true,
		},
	})

	popup:mount()
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

	local function close()
		popup:unmount()
	end

	vim.keymap.set("n", "<Esc>", close, { buffer = popup.bufnr, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = popup.bufnr, nowait = true })

	if #answer.suggestions > 0 then
		vim.keymap.set("n", "<CR>", function()
			close()
			on_apply(answer.suggestions[1])
		end, { buffer = popup.bufnr, nowait = true })

		for i = 1, math.min(9, #answer.suggestions) do
			vim.keymap.set("n", tostring(i), function()
				close()
				on_apply(answer.suggestions[i])
			end, { buffer = popup.bufnr, nowait = true })
		end
	end
end

return M
