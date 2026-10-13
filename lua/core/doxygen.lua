--- A blink.cmp source that completes Doxygen commands inside C and C++
--- comments: type `@` (or a backslash) and the commands appear.
---
--- It only answers when the cursor is in a comment and the word under it
--- starts with `@` or a backslash, so it never shows up in ordinary code.

local source = {}

local filetypes = { c = true, cpp = true, objc = true, objcpp = true, cuda = true }

-- label, snippet body and a one line description. `$0`, `${1:...}` are
-- snippet tab stops. The marker of a comment line (`///`, `//!` or `*`) is
-- added in front of every line after the first, see expand().
local commands = {
  { "brief",      "brief ${1:description}",             "A one line summary" },
  { "param",      "param ${1:name} ${2:description}",   "Document a parameter" },
  { "tparam",     "tparam ${1:T} ${2:description}",     "Document a template parameter" },
  { "return",     "return ${1:description}",            "Document the return value" },
  { "retval",     "retval ${1:value} ${2:description}", "Document one return value" },
  { "details",    "details ${1:text}",                  "A longer description" },
  { "note",       "note ${1:text}",                     "A note" },
  { "warning",    "warning ${1:text}",                  "A warning" },
  { "see",        "see ${1:name}",                      "A reference to something else" },
  { "copydoc",    "copydoc ${1:name}",                  "Copy the documentation of something else" },
  { "code",       "code\n$0\n@endcode",                 "Start a code block" },
  { "endcode",    "endcode",                            "End a code block" },
  { "file",       "file ${1:path}",                     "Document the file itself" },
  { "name",       "name ${1:group}\n$0",                "A named member group; close it with @}" },
  { "deprecated", "deprecated ${1:use X instead}",      "Mark as deprecated" },
  { "todo",       "todo ${1:text}",                     "Something left to do" },
  { "p",          "p ${1:name}",                        "Refer to a parameter, in typewriter font" },
  { "a",          "a ${1:name}",                        "Refer to an argument, in italics" },
  { "ref",        "ref ${1:name}",                      "A link to a named item" },
  { "ingroup",    "ingroup ${1:group}",                 "Add to a group" },
  { "defgroup",   "defgroup ${1:group} ${2:title}",     "Define a group" },
}

--- Tells whether the cursor is inside a comment, as the syntax tree sees it.
local function in_comment()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- Look at the character just before the cursor: at the end of a line the
  -- cursor itself is already past the comment.
  local ok, node = pcall(vim.treesitter.get_node, {
    pos = { row - 1, math.max(col - 1, 0) },
    ignore_injections = true,
  })
  if not ok then return false end
  while node do
    if node:type() == "comment" then return true end
    node = node:parent()
  end
  return false
end

--- The text that starts a comment line: `///`, `//!` or `*`.
local function comment_marker()
  local line = vim.api.nvim_get_current_line()
  return line:match("^%s*(//[/!])") or (line:match("^%s*%*") and "*") or "///"
end

--- Puts the comment marker in front of every line of a snippet but the first.
local function expand(body, marker)
  local lines = vim.split(body, "\n", { plain = true })
  for i = 2, #lines do
    lines[i] = lines[i]:match("^@") and (marker .. " " .. lines[i])
        or (marker .. "  " .. lines[i])
  end
  return table.concat(lines, "\n")
end

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return filetypes[vim.bo.filetype] == true and in_comment()
end

function source:get_trigger_characters()
  return { "@", "\\" }
end

function source:get_completions(ctx, callback)
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  -- Only right after a command character, never on ordinary words.
  if not before:match("[@\\]%a*$") then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local kinds = require("blink.cmp.types").CompletionItemKind
  local marker = comment_marker()
  local items = {}
  for _, command in ipairs(commands) do
    local label, body, description = command[1], command[2], command[3]
    items[#items + 1] = {
      label = label,
      kind = kinds.Keyword,
      insertText = expand(body, marker),
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      documentation = { kind = "markdown", value = "**@" .. label .. "**: " .. description },
    }
  end
  callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
end

return source
