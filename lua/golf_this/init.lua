local config = require("golf_this.config")
local model = require("golf_this.model")
local ui = require("golf_this.ui")

local M = {}
local request_lock = false

local function start_spinner(label)
  local frames = { "-", "\\", "|", "/" }
  local i = 1
  local active = true
  local uv = vim.uv or vim.loop
  local timer = uv and uv.new_timer() or nil

  local function render()
    if not active then
      return
    end
    local text = string.format("%s golf-this: %s", frames[i], label)
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

local function build_request(opts)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row = cursor[1]
  local current_line = vim.api.nvim_get_current_line()
  local selection = nil

  if opts and opts.range and opts.range > 0 then
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
    buffer_excerpt = build_buffer_excerpt(config.values.max_context_lines),
    current_row = current_row,
    current_line = current_line,
    selection = selection,
  }
end

local function feed_keys(keys)
  local replaced = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(replaced, "n", false)
end

function M.run(opts)
  if request_lock then
    vim.notify("golf-this: request already running", vim.log.levels.WARN)
    return
  end

  local provider = config.current_provider()
  if not provider then
    vim.notify("golf-this: invalid provider configuration", vim.log.levels.ERROR)
    return
  end

  local request = build_request(opts)

  ui.prompt(function(prompt)
    if not prompt or prompt:gsub("%s+", "") == "" then
      return
    end

    request_lock = true
    local stop_spinner = start_spinner("thinking...")

    model.solve_async(provider, prompt, request, function(answer, err)
      request_lock = false
      if err then
        stop_spinner("golf-this: request failed", "ErrorMsg")
        vim.notify("golf-this: " .. err, vim.log.levels.ERROR)
        return
      end

      stop_spinner("golf-this: done", "MoreMsg")
      ui.result(answer, feed_keys)
    end)
  end)
end

function M.setup(opts)
  config.setup(opts)
end

return M
