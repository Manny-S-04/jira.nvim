local M = {}

---@alias jira.StatusFilter "open"|"todo"|"inprogress"|"done"
---@alias jira.PersonFilter "me"|"unassigned"
---@alias jira.SprintFilter "open"|"none"

---@class jira.JqlSpec
---@field project string|nil        project key, e.g. "PROJ"
---@field assignee jira.PersonFilter|nil
---@field reporter_me boolean|nil
---@field status jira.StatusFilter|nil
---@field issue_type string|nil     e.g. "Bug"
---@field sprint jira.SprintFilter|nil
---@field text string|nil           free-text search across summary/description/comments
---@field updated_within string|nil relative duration, e.g. "7d"
---@field order_by string|nil       defaults to "updated DESC"

---@type table<jira.StatusFilter, string>
local STATUS_CLAUSE = {
  open = 'statusCategory != "Done"',
  todo = 'statusCategory = "To Do"',
  inprogress = 'statusCategory = "In Progress"',
  done = 'statusCategory = "Done"',
}

---@type table<jira.PersonFilter, string>
local ASSIGNEE_CLAUSE = {
  me = "assignee = currentUser()",
  unassigned = "assignee is EMPTY",
}

---@type table<jira.SprintFilter, string>
local SPRINT_CLAUSE = {
  open = "sprint in openSprints()",
  none = "sprint is EMPTY",
}

---@param value string
---@return string
function M.quote(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

---@param s string|nil
---@return boolean
local function present(s)
  return s ~= nil and s:match("%S") ~= nil
end

---@param spec jira.JqlSpec
---@return string
function M.build(spec)
  ---@type string[]
  local clauses = {}
  if present(spec.project) then
    table.insert(clauses, "project = " .. M.quote(vim.trim(spec.project)))
  end
  if spec.issue_type and present(spec.issue_type) then
    table.insert(clauses, "issuetype = " .. M.quote(spec.issue_type))
  end
  if spec.status then
    table.insert(clauses, STATUS_CLAUSE[spec.status])
  end
  if spec.assignee then
    table.insert(clauses, ASSIGNEE_CLAUSE[spec.assignee])
  end
  if spec.reporter_me then
    table.insert(clauses, "reporter = currentUser()")
  end
  if spec.sprint then
    table.insert(clauses, SPRINT_CLAUSE[spec.sprint])
  end
  if spec.text and present(spec.text) then
    table.insert(clauses, "text ~ " .. M.quote(vim.trim(spec.text)))
  end
  if spec.updated_within and present(spec.updated_within) then
    table.insert(clauses, "updated >= -" .. spec.updated_within)
  end

  local order = "ORDER BY " .. (spec.order_by or "updated DESC")
  if #clauses == 0 then
    return order
  end
  return table.concat(clauses, " AND ") .. " " .. order
end

---@param input string
---@return string
function M.from_freeform(input)
  local s = vim.trim(input)
  if s:match("^[A-Za-z][A-Za-z0-9_]*%-%d+$") then
    return "key = " .. s:upper()
  end
  if s:match("[=~<>!]") or s:lower():match("%f[%w]order%s+by%f[%W]") or s:lower():match("%f[%w]in%s*%(") then
    return s
  end
  return M.build({ text = s })
end

return M
