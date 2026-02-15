local M = {}

local function decode_json(text)
  local ok, decoded = pcall(vim.json.decode, text)
  if ok and decoded then
    return decoded
  end

  local json_block = text:match("```json%s*(.-)%s*```")
  if json_block then
    local ok_block, parsed_block = pcall(vim.json.decode, json_block)
    if ok_block and parsed_block then
      return parsed_block
    end
  end

  local object = text:match("(%b{})")
  if object then
    local ok_object, parsed_object = pcall(vim.json.decode, object)
    if ok_object and parsed_object then
      return parsed_object
    end
  end

  return nil
end

local function get_api_key(cfg)
  local env_name = cfg.api_key_env or cfg.api_key
  if not env_name then
    return nil
  end
  return vim.env[env_name]
end

local function build_user_message(prompt, request)
  local lines = {
    "Task:",
    prompt,
    "",
    string.format("Current cursor line (%d):", request.current_row),
    request.current_line,
    "",
  }

  if request.selection then
    table.insert(lines, string.format("Selected lines (%d-%d):", request.selection.start_line, request.selection.end_line))
    table.insert(lines, request.selection.text)
    table.insert(lines, "")
  end

  table.insert(lines, "Current buffer excerpt:")
  table.insert(lines, request.buffer_excerpt)

  return table.concat(lines, "\n")
end

local function system_prompt()
  return table.concat({
    "You are a Vim golf assistant.",
    "Return ONLY valid JSON with keys: explanation (string), steps (array of strings), keys (string).",
    "explanation must be short (<= 2 sentences).",
    "steps must be concise and actionable.",
    "keys must be a single normal-mode keystroke sequence for nvim_feedkeys.",
    "Prefer robust motions/text-objects over line numbers when possible.",
    "If unsafe or unknown, return empty keys and explain.",
  }, " ")
end

local function build_openai_payload(cfg, prompt, request)
  return {
    model = cfg.model,
    temperature = 0,
    messages = {
      { role = "system", content = system_prompt() },
      { role = "user", content = build_user_message(prompt, request) },
    },
  }
end

local function build_anthropic_payload(cfg, prompt, request)
  return {
    model = cfg.model,
    max_tokens = cfg.max_tokens or 600,
    system = system_prompt(),
    messages = {
      {
        role = "user",
        content = build_user_message(prompt, request),
      },
    },
  }
end

local function extract_openai_content(parsed)
  local content = (((parsed or {}).choices or {})[1] or {}).message
  content = content and content.content or nil

  if type(content) == "string" then
    return content
  end

  if type(content) == "table" then
    local chunks = {}
    for _, block in ipairs(content) do
      if type(block) == "table" and block.type == "text" and type(block.text) == "string" then
        table.insert(chunks, block.text)
      end
    end
    if #chunks > 0 then
      return table.concat(chunks, "\n")
    end
  end

  return nil
end

local function extract_anthropic_content(parsed)
  if type(parsed) ~= "table" or type(parsed.content) ~= "table" then
    return nil
  end

  local chunks = {}
  for _, block in ipairs(parsed.content) do
    if type(block) == "table" and block.type == "text" and type(block.text) == "string" then
      table.insert(chunks, block.text)
    end
  end

  if #chunks == 0 then
    return nil
  end

  return table.concat(chunks, "\n")
end

local function parse_solution_text(text)
  local result = decode_json(text)
  if not result then
    return nil, "model did not return valid JSON contract"
  end

  return {
    explanation = result.explanation or "",
    steps = vim.tbl_islist(result.steps) and result.steps or {},
    keys = result.keys or "",
  }, nil
end

local function http_post_async(url, headers, body, cb)
  local done = vim.schedule_wrap(cb)

  if vim.system then
    local cmd = { "curl", "-sS", "-X", "POST", url }

    for key, value in pairs(headers) do
      table.insert(cmd, "-H")
      table.insert(cmd, string.format("%s: %s", key, value))
    end

    table.insert(cmd, "--data-binary")
    table.insert(cmd, body)
    table.insert(cmd, "-w")
    table.insert(cmd, "\n__HTTP_STATUS__:%{http_code}")

    vim.system(cmd, { text = true }, function(obj)
      if obj.code ~= 0 then
        local stderr = obj.stderr and obj.stderr ~= "" and obj.stderr or tostring(obj.code)
        done(nil, "request failed: " .. stderr)
        return
      end

      local stdout = obj.stdout or ""
      local response_body, status = stdout:match("^(.*)\n__HTTP_STATUS__:(%d%d%d)%s*$")
      if not status then
        done(nil, "request failed: missing HTTP status")
        return
      end

      done({
        status = tonumber(status),
        body = response_body,
      }, nil)
    end)
    return
  end

  local ok, curl = pcall(require, "plenary.curl")
  if not ok then
    done(nil, "Neovim 0.10+ required for async requests (or install plenary fallback)")
    return
  end

  local response = curl.post(url, {
    headers = headers,
    body = body,
    timeout = 30000,
  })

  done({ status = response.status, body = response.body }, nil)
end

function M.solve_async(cfg, prompt, request, cb)
  local provider_kind = cfg.kind or "openai_compatible"
  local api_key = get_api_key(cfg)

  local headers = {
    ["Content-Type"] = "application/json",
  }

  local payload

  if provider_kind == "anthropic" then
    if api_key and api_key ~= "" then
      headers["x-api-key"] = api_key
    end
    headers["anthropic-version"] = cfg.anthropic_version or "2023-06-01"
    payload = build_anthropic_payload(cfg, prompt, request)
  else
    if api_key and api_key ~= "" then
      headers.Authorization = "Bearer " .. api_key
    end

    if cfg.referer and cfg.referer ~= "" then
      headers["HTTP-Referer"] = cfg.referer
    end

    if cfg.title and cfg.title ~= "" then
      headers["X-Title"] = cfg.title
    end

    payload = build_openai_payload(cfg, prompt, request)
  end

  http_post_async(cfg.url, headers, vim.json.encode(payload), function(response, request_err)
    if request_err then
      cb(nil, request_err)
      return
    end

    if response.status < 200 or response.status >= 300 then
      cb(nil, string.format("model request failed (%s): %s", response.status, response.body))
      return
    end

    local ok, parsed = pcall(vim.json.decode, response.body)
    if not ok or not parsed then
      cb(nil, "failed to parse model response")
      return
    end

    local content
    if provider_kind == "anthropic" then
      content = extract_anthropic_content(parsed)
    else
      content = extract_openai_content(parsed)
    end

    if type(content) ~= "string" then
      cb(nil, "missing response content")
      return
    end

    local solved, parse_err = parse_solution_text(content)
    if parse_err then
      cb(nil, parse_err)
      return
    end

    cb(solved, nil)
  end)
end

return M
