local M = {}
local core = require('audit.core')

-- Namespace for UI elements
M.ns_id = vim.api.nvim_create_namespace('audit_notes')
M.review_ns_id = vim.api.nvim_create_namespace('audit_reviewed')
M.note_marks = {}

-- Set up highlighting
function M.setup_highlights()
  vim.cmd([[
    highlight default link AuditNote Todo
    highlight default link AuditNoteHighlight CursorLine
    highlight default link AuditReviewed DiffAdd
  ]])
end

-- Add visual marks to lines with notes
function M.mark_notes(bufnr)
  -- Clear existing marks
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  
  local file_path = core.get_buffer_path()
  -- Skip if file path is nil or notes for this file don't exist
  if not file_path or not core.notes[file_path] then return end
  
  for i, note in ipairs(core.notes[file_path]) do
    for line = note.start_line, note.end_line do
      -- Determine the icon based on note type
      local icon = "📝"
      if note.type == "question" then
        icon = "🤨"
      elseif note.type == "finding" then
        icon = "🚨"
      end
      
      -- Add virtual text
      vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, line, 0, {
        virt_text = {{icon .. " " .. i, "AuditNote"}},
        virt_text_pos = "eol",
      })
      
      -- Highlight the line
      vim.api.nvim_buf_add_highlight(bufnr, M.ns_id, "AuditNoteHighlight", line, 0, -1)
    end
  end
end

-- Mark reviewed code sections
function M.mark_reviewed(bufnr)
  -- Clear existing review marks
  vim.api.nvim_buf_clear_namespace(bufnr, M.review_ns_id, 0, -1)
  
  local file_path = core.get_buffer_path()
  -- Skip if file path is nil or reviewed sections for this file don't exist
  if not file_path or not core.reviewed[file_path] then return end
  
  for _, section in ipairs(core.reviewed[file_path]) do
    for line = section.start_line, section.end_line do
      -- Add highlight for reviewed line
      vim.api.nvim_buf_add_highlight(bufnr, M.review_ns_id, "AuditReviewed", line, 0, -1)
    end
  end
end

return M 