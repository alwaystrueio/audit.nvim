local M = {}
local core = require('audit.core')

-- Namespace for UI elements
M.ns_id = vim.api.nvim_create_namespace('audit_notes')
M.note_marks = {}

-- Set up highlighting
function M.setup_highlights()
  vim.cmd([[
    highlight default link AuditNote Todo
    highlight default link AuditNoteHighlight CursorLine
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
      -- Add virtual text
      vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, line, 0, {
        virt_text = {{"📝 Note " .. i, "AuditNote"}},
        virt_text_pos = "eol",
      })
      
      -- Highlight the line
      vim.api.nvim_buf_add_highlight(bufnr, M.ns_id, "AuditNoteHighlight", line, 0, -1)
    end
  end
end

return M 