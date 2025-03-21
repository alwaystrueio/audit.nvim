local M = {}
local core = require('audit.core')
local ui = require('audit.ui')

-- Panel state
M.panel_bufnr = nil
M.panel_winid = nil
M.panel_file_path = nil
M.panel_line = nil
M.auto_panel_enabled = true
M.auto_panel_augroup = nil

-- Show notes panel for the current line
function M.show_notes_panel()
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local file_path = core.get_buffer_path()
  
  -- Skip if file path is nil or notes for this file don't exist
  if not file_path or not core.notes[file_path] then 
    -- Close panel if open when there are no notes
    if M.panel_bufnr and vim.api.nvim_buf_is_valid(M.panel_bufnr) then
      vim.api.nvim_buf_delete(M.panel_bufnr, { force = true })
      M.panel_bufnr = nil
      M.panel_winid = nil
    end
    return 
  end
  
  -- Find notes for the current line
  local relevant_notes = {}
  for i, note in ipairs(core.notes[file_path]) do
    if current_line >= note.start_line and current_line <= note.end_line then
      table.insert(relevant_notes, {
        id = i,
        content = note.content,
        code = note.code
      })
    end
  end
  
  if #relevant_notes == 0 then
    -- Close panel if open and no relevant notes
    if M.panel_bufnr and vim.api.nvim_buf_is_valid(M.panel_bufnr) then
      vim.api.nvim_buf_delete(M.panel_bufnr, { force = true })
      M.panel_bufnr = nil
      M.panel_winid = nil
    end
    return
  end
  
  -- Create or update the panel
  local lines = {"# Audit Notes Panel", ""}
  
  for _, note in ipairs(relevant_notes) do
    table.insert(lines, "## Note " .. note.id)
    table.insert(lines, "")
    -- Split content into lines
    for _, content_line in ipairs(vim.split(note.content, "\n")) do
      table.insert(lines, content_line)
    end
    table.insert(lines, "")
    table.insert(lines, "```")
    -- Split code into lines
    for _, code_line in ipairs(vim.split(note.code, "\n")) do
      table.insert(lines, code_line)
    end
    table.insert(lines, "```")
    table.insert(lines, "")
  end
  
  -- Create or update buffer
  if not M.panel_bufnr or not vim.api.nvim_buf_is_valid(M.panel_bufnr) then
    M.panel_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.panel_bufnr, 'filetype', 'markdown')
    
    -- Make buffer modifiable but not file-backed
    vim.api.nvim_buf_set_option(M.panel_bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_option(M.panel_bufnr, 'buftype', 'nofile')
    
    -- Store the current file_path and line for the panel
    M.panel_file_path = file_path
    M.panel_line = current_line
  else
    -- Update stored file path and line
    M.panel_file_path = file_path
    M.panel_line = current_line
  end
  
  vim.api.nvim_buf_set_lines(M.panel_bufnr, 0, -1, false, lines)
  
  -- Create or update window
  if not M.panel_winid or not vim.api.nvim_win_is_valid(M.panel_winid) then
    local current_winid = vim.api.nvim_get_current_win()
    local width = vim.api.nvim_win_get_width(current_winid)
    local height = vim.api.nvim_win_get_height(current_winid)
    
    -- Open panel on the right
    vim.cmd('botright vsplit')
    M.panel_winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.panel_winid, M.panel_bufnr)
    vim.api.nvim_win_set_width(M.panel_winid, math.floor(width * 0.3))
    
    -- Set window options
    vim.api.nvim_win_set_option(M.panel_winid, 'number', false)
    vim.api.nvim_win_set_option(M.panel_winid, 'relativenumber', false)
    vim.api.nvim_win_set_option(M.panel_winid, 'cursorline', true)
    vim.api.nvim_win_set_option(M.panel_winid, 'signcolumn', 'no')
    
    -- Add some helpful instructions at the top
    local lines = vim.api.nvim_buf_get_lines(M.panel_bufnr, 0, 2, false)
    if lines[1] == "# Audit Notes Panel" then
      vim.api.nvim_buf_set_lines(M.panel_bufnr, 1, 2, false, {"Edit notes directly in this panel. Changes will be synced when you run :AuditSyncNotes or leave the panel.", ""})
    end
    
    -- Go back to original window
    vim.api.nvim_set_current_win(current_winid)
  end
end

-- Sync changes from panel to notes data structure
function M.sync_panel_changes()
  if not M.panel_bufnr or not vim.api.nvim_buf_is_valid(M.panel_bufnr) then
    return
  end
  
  -- Get the buffer content
  local lines = vim.api.nvim_buf_get_lines(M.panel_bufnr, 0, -1, false)
  
  -- Parse the buffer content
  local current_note_id = nil
  local in_content_section = false
  local in_code_block = false
  local content_lines = {}
  local code_lines = {}
  local updated_notes = {}
  
  for i, line in ipairs(lines) do
    -- Skip the header
    if i <= 2 then
      -- Skip first two lines (header)
      goto continue
    end
    
    if line:match("^## Note (%d+)") then
      -- Found a note section
      current_note_id = tonumber(line:match("^## Note (%d+)"))
      in_content_section = true
      content_lines = {}
      code_lines = {}
      
    elseif line == "```" then
      if in_code_block then
        -- End of code block
        in_code_block = false
        
        -- Save the note
        if current_note_id then
          updated_notes[current_note_id] = {
            content = table.concat(content_lines, "\n"),
            code = table.concat(code_lines, "\n")
          }
        end
      else
        -- Start of code block
        in_content_section = false
        in_code_block = true
      end
      
    elseif current_note_id then
      if in_content_section and line ~= "" then
        -- Add to content (skip first empty line after the note header)
        if #content_lines > 0 or line ~= "" then
          table.insert(content_lines, line)
        end
      elseif in_code_block then
        -- Add to code
        table.insert(code_lines, line)
      end
    end
    
    ::continue::
  end
  
  -- Update the notes data structure
  if M.panel_file_path and core.notes[M.panel_file_path] then
    local updated = false
    
    for note_id, note_data in pairs(updated_notes) do
      if core.notes[M.panel_file_path][note_id] then
        core.notes[M.panel_file_path][note_id].content = note_data.content
        -- We don't update the code as it should remain the original selection
        updated = true
      end
    end
    
    if updated then
      -- Save to file
      core.save_notes()
      vim.notify("Audit Notes: Notes updated successfully")
      
      -- Update marks
      ui.mark_notes(0)
    end
  end
end

-- Close notes panel
function M.close_notes_panel()
  -- Sync changes before closing
  M.sync_panel_changes()
  
  if M.panel_winid and vim.api.nvim_win_is_valid(M.panel_winid) then
    vim.api.nvim_win_close(M.panel_winid, true)
    M.panel_winid = nil
  end
  
  if M.panel_bufnr and vim.api.nvim_buf_is_valid(M.panel_bufnr) then
    vim.api.nvim_buf_delete(M.panel_bufnr, { force = true })
    M.panel_bufnr = nil
  end
end

-- Toggle notes panel
function M.toggle_notes_panel()
  -- Check if panel is currently visible
  if M.panel_winid and vim.api.nvim_win_is_valid(M.panel_winid) then
    -- Close the panel regardless of where the cursor is
    M.close_notes_panel()
    
    -- Disable auto-showing panel on cursor move
    if M.auto_panel_enabled then
      -- Remove the autocmd
      if M.auto_panel_augroup then
        vim.api.nvim_clear_autocmds({ group = M.auto_panel_augroup })
      end
      
      M.auto_panel_enabled = false
      vim.notify("Audit Notes: Notes panel auto-display disabled")
    end
  else
    -- Force show panel for current line
    M.show_notes_panel()
    
    -- Re-enable auto-showing panel on cursor move if not already enabled
    if not M.auto_panel_enabled then
      if not M.auto_panel_augroup or not vim.api.nvim_get_autocmds({group = M.auto_panel_augroup})[1] then
        -- Create or clear the augroup
        M.auto_panel_augroup = vim.api.nvim_create_augroup('AuditNotesPanel', { clear = true })
        
        -- Create the autocmd
        vim.api.nvim_create_autocmd('CursorMoved', {
          group = M.auto_panel_augroup,
          pattern = '*',
          callback = function()
            -- Skip if we're inside the panel buffer
            if M.panel_bufnr and vim.api.nvim_get_current_buf() == M.panel_bufnr then
              return
            end
            
            if M.auto_panel_enabled then
              M.show_notes_panel()
            end
          end
        })
      end
      
      M.auto_panel_enabled = true
      vim.notify("Audit Notes: Notes panel auto-display enabled")
    end
  end
end

-- Set up auto commands for the panel
function M.setup_autocmds()
  -- Store auto panel augroup ID and create the autocmd
  M.auto_panel_augroup = vim.api.nvim_create_augroup('AuditNotesPanel', { clear = true })
  
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = M.auto_panel_augroup,
    pattern = '*',
    callback = function()
      -- Skip if we're inside the panel buffer
      if M.panel_bufnr and vim.api.nvim_get_current_buf() == M.panel_bufnr then
        return
      end
      
      if M.auto_panel_enabled then
        M.show_notes_panel()
      end
    end
  })
  
  -- Auto-sync changes when leaving the panel buffer
  vim.api.nvim_create_autocmd('BufLeave', {
    group = M.auto_panel_augroup,
    callback = function(event)
      if M.panel_bufnr and event.buf == M.panel_bufnr then
        M.sync_panel_changes()
      end
    end
  })
  
  -- Handle :w in the panel buffer
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = M.auto_panel_augroup,
    callback = function(event)
      if M.panel_bufnr and event.buf == M.panel_bufnr then
        M.sync_panel_changes()
        vim.notify("Audit Notes: Notes saved")
        -- Mark the buffer as not modified to clear the 'modified' flag
        vim.api.nvim_buf_set_option(M.panel_bufnr, 'modified', false)
        return true -- Prevent the actual file write
      end
    end
  })
end

return M 