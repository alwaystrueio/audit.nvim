local core = require('audit.core')
local ui = require('audit.ui')
local panel = require('audit.panel')

local M = {}

-- Export the API functions
M.add_note = core.add_note
M.get_buffer_path = core.get_buffer_path
M.load_notes = core.load_notes
M.save_notes = core.save_notes
M.delete_note = core.delete_note
M.mark_notes = ui.mark_notes
M.mark_reviewed = core.mark_reviewed
M.toggle_reviewed = core.toggle_reviewed
M.show_notes_panel = panel.show_notes_panel
M.sync_panel_changes = panel.sync_panel_changes
M.close_notes_panel = panel.close_notes_panel
M.toggle_notes_panel = panel.toggle_notes_panel

-- Setup function
function M.setup(opts)
  opts = opts or {}
  
  -- Set up highlighting
  ui.setup_highlights()
  
  -- Load existing notes - wrapped in pcall for safety
  local success, err = pcall(core.load_notes)
  if not success then
    vim.notify("Error loading notes: " .. tostring(err), vim.log.levels.WARN)
    -- Ensure core.notes is initialized even if load_notes fails
    core.notes = {}
  end
  
  -- Set up commands
  vim.api.nvim_create_user_command('AuditAddNote', core.add_note, { range = true })
  vim.api.nvim_create_user_command('AuditToggleReviewed', core.toggle_reviewed, { range = true })
  vim.api.nvim_create_user_command('AuditDeleteNote', function(opts)
    if not opts.args or opts.args == "" then
      -- No parameter provided - check notes at current cursor line
      local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- Convert to 0-indexed
      local notes_at_line = core.get_notes_at_line(current_line)
      
      if #notes_at_line == 0 then
        vim.notify("No notes found at current line", vim.log.levels.WARN)
        return
      elseif #notes_at_line == 1 then
        -- Only one note at this line, delete it
        core.delete_note(notes_at_line[1].id)
      else
        -- Multiple notes, prompt user to select one
        local options = {}
        for _, note_info in ipairs(notes_at_line) do
          local preview = note_info.note.content:sub(1, 30)
          if #note_info.note.content > 30 then
            preview = preview .. "..."
          end
          table.insert(options, string.format("Note %d: %s", note_info.id, preview))
        end
        
        vim.ui.select(options, {
          prompt = "Select note to delete:",
        }, function(choice, idx)
          if not choice then return end
          core.delete_note(notes_at_line[idx].id)
        end)
      end
    else
      local note_id = tonumber(opts.args)
      if not note_id then
        vim.notify("Invalid note ID: " .. opts.args, vim.log.levels.ERROR)
        return
      end
      core.delete_note(note_id)
    end
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('AuditTogglePanel', panel.toggle_notes_panel, {})
  vim.api.nvim_create_user_command('AuditSyncNotes', panel.sync_panel_changes, {})
  
  -- Flag to track if auto panel display is enabled
  panel.auto_panel_enabled = true
  
  -- Set up auto-commands
  local augroup = vim.api.nvim_create_augroup('AuditNotes', { clear = true })
  
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    pattern = '*',
    callback = function()
      ui.mark_reviewed(0)
      ui.mark_notes(0)
    end
  })
  
  -- Set up panel auto-commands
  panel.setup_autocmds()
  
  return M
end

return M
