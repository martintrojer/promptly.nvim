local Input = require("nui.input")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

function M.prompt(on_submit)
  local input = Input({
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
        top = " Golf This Prompt ",
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
      on_submit(value)
    end,
  })

  input:mount()
  input:on(event.BufLeave, function()
    input:unmount()
  end)

  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    input:unmount()
  end, { buffer = input.bufnr, nowait = true })
end

function M.result(answer, on_do_it)
  local lines = {
    "Golf This",
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
  if answer.keys ~= "" then
    table.insert(lines, "<CR>: Do It    <Esc>/q: Close")
  else
    table.insert(lines, "<Esc>/q: Close")
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
        top = " Golf This Answer ",
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

  if answer.keys ~= "" then
    vim.keymap.set("n", "<CR>", function()
      close()
      on_do_it(answer.keys)
    end, { buffer = popup.bufnr, nowait = true })
  end
end

return M
