local M = {}

local function present(v)
  return v ~= nil and v ~= ""
end

function M.headers(cfg)
  if not present(cfg.api_token) then
    error("jira.nvim: no API token configured (set JIRA_API_TOKEN or api_token)")
  end

  if present(cfg.email) then
    return { Authorization = "Basic " .. vim.base64.encode(cfg.email .. ":" .. cfg.api_token) }
  end

  return { Authorization = "Bearer " .. cfg.api_token }
end

return M
