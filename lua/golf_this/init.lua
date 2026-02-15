local config = require("golf_this.config")
local model = require("golf_this.model")
local ui = require("golf_this.ui")

local M = {}

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

    vim.notify("golf-this: thinking...", vim.log.levels.INFO)

    model.solve_async(provider, prompt, request, function(answer, err)
      if err then
        vim.notify("golf-this: " .. err, vim.log.levels.ERROR)
        return
      end

      ui.result(answer, feed_keys)
    end)
  end)
end

function M.setup(opts)
  config.setup(opts)
end

return M
