local client = require("jira.api.client")
local issues = require("jira.api.issues")

local M = {}

local AGILE = "/rest/agile/1.0"
local PAGE = 50
local MAX_ISSUES = 500

M.kanban_jql = "statusCategory != Done OR resolutiondate >= -14d"

local function get(path, query, cb)
  client.request("GET", AGILE .. path, { query = query }, function(result, err)
    if not result then
      return cb(nil, err)
    end
    cb(result.body or {}, nil)
  end)
end

function M.get(board_id, cb)
  get(("/board/%s"):format(client.uri_encode(board_id)), nil, function(body, err)
    if not body then
      return cb(nil, err)
    end
    local loc = type(body.location) == "table" and body.location or {}
    cb({ id = body.id, name = body.name, type = body.type, project = loc.projectKey }, nil)
  end)
end

function M.list(project, cb)
  local query = { maxResults = PAGE }
  if project and project ~= "" then
    query.projectKeyOrId = project
  end
  get("/board", query, function(body, err)
    if not body then
      return cb(nil, err)
    end
    local out = {}
    for _, b in ipairs(body.values or {}) do
      local loc = type(b.location) == "table" and b.location or {}
      table.insert(out, { id = b.id, name = b.name, type = b.type, project = loc.projectKey })
    end
    cb(out, nil)
  end)
end

function M.active_sprints(board_id, cb)
  get(("/board/%s/sprint"):format(client.uri_encode(board_id)), { state = "active" }, function(body, err)
    if not body then
      return cb(nil, err)
    end
    local out = {}
    for _, s in ipairs(body.values or {}) do
      table.insert(out, { id = s.id, name = s.name, goal = s.goal, end_date = s.endDate })
    end
    cb(out, nil)
  end)
end

function M.issues(board_id, jql, cb)
  local out = {}
  local function page(start_at)
    local query = { startAt = start_at, maxResults = PAGE, fields = issues.LIST_FIELDS }
    if jql and jql ~= "" then
      query.jql = jql
    end
    get(("/board/%s/issue"):format(client.uri_encode(board_id)), query, function(body, err)
      if not body then
        return cb(nil, err)
      end
      local batch = body.issues or {}
      for _, raw in ipairs(batch) do
        table.insert(out, issues.from_response(raw))
      end
      local total = tonumber(body.total) or 0
      local next_at = start_at + #batch
      if #batch > 0 and next_at < total and next_at < MAX_ISSUES then
        page(next_at)
      else
        cb(out, nil)
      end
    end)
  end
  page(0)
end

function M.board_view(board_id, cb)
  M.get(board_id, function(board, err)
    if not board then
      return cb(nil, err)
    end
    if board.type ~= "scrum" then
      return M.issues(board_id, M.kanban_jql, function(list, ierr)
        cb(list, ierr, ("%s (board %s)"):format(board.name, board_id))
      end)
    end
    M.active_sprints(board_id, function(sprints, serr)
      if not sprints then
        return cb(nil, serr)
      end
      local names = {}
      for _, s in ipairs(sprints) do
        local ends = s.end_date and (" — ends " .. s.end_date:sub(1, 10)) or ""
        table.insert(names, s.name .. ends)
      end
      local title = ("%s: %s"):format(board.name, #names > 0 and table.concat(names, ", ") or "no active sprint")
      if #sprints == 0 then
        return cb({}, nil, title)
      end
      local ids = {}
      for _, s in ipairs(sprints) do
        table.insert(ids, tostring(s.id))
      end
      M.issues(board_id, ("sprint in (%s)"):format(table.concat(ids, ",")), function(list, ierr)
        cb(list, ierr, title)
      end)
    end)
  end)
end

return M
