vim.api.nvim_create_user_command("GolfThis", function(opts)
  require("golf_this").run(opts)
end, {
  desc = "Ask an LLM for a vimgolf-style edit solution",
  range = true,
})
