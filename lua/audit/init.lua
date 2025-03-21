local core = require('audit.core')
local ui = require('audit.ui')
local panel = require('audit.panel')

local M = {}

-- Export the API functions
M.add_note = core.add_note
M.get_buffer_path = core.get_buffer_path
M.load_notes = core.load_notes
M.save_notes = core.save_notes
M.mark_notes = ui.mark_notes
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
      ui.mark_notes(0)
    end
  })
  
  -- Set up panel auto-commands
  panel.setup_autocmds()
  
  return M
end

return M
