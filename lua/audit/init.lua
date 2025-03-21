local M = {}

-- Storage for notes
M.notes = {}
M.note_marks = {}
M.ns_id = vim.api.nvim_create_namespace('audit_notes')

-- Utility function to get current buffer's relative path
function M.get_buffer_path()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local cwd = vim.fn.getcwd()
  return string.sub(buf_name, string.len(cwd) + 2)
end

-- Add a note for the selected text
function M.add_note()
  local start_line, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  local end_line, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
  
  -- Adjustments for proper indexing
  start_line = start_line - 1
  end_line = end_line - 1
  end_col = end_col + 1
  
  -- Get the content of the selected text
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
  if #lines == 0 then return end
  
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col + 1, end_col)
  else
    lines[1] = string.sub(lines[1], start_col + 1)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end
  
  local selected_text = table.concat(lines, '\n')
  
  -- Prompt for note text
  vim.ui.input({
    prompt = "Enter note: ",
  }, function(input)
    if not input or input == "" then
      return
    end
    
    -- Add note to our data structure
    local file_path = M.get_buffer_path()
    
    if not M.notes[file_path] then
      M.notes[file_path] = {}
    end
    
    table.insert(M.notes[file_path], {
      start_line = start_line,
      end_line = end_line,
      content = input,
      code = selected_text
    })
    
    -- Save notes to file
    M.save_notes()
    
    -- Add visual indicators
    M.mark_notes(0)
    
    vim.notify("Note added")
  end)
end

-- Save notes to notes.md file
function M.save_notes()
  local lines = {"# Audit Notes", ""}
  
  for file, file_notes in pairs(M.notes) do
    table.insert(lines, "## " .. file)
    table.insert(lines, "")
    
    for i, note in ipairs(file_notes) do
      local line_ref = (note.start_line + 1) .. "-" .. (note.end_line + 1)
      table.insert(lines, "### Note " .. i .. " (Lines " .. line_ref .. ")")
      table.insert(lines, "")
      table.insert(lines, note.content)
      table.insert(lines, "")
      table.insert(lines, "```")
      table.insert(lines, note.code)
      table.insert(lines, "```")
      table.insert(lines, "")
    end
  end
  
  vim.fn.writefile(lines, "notes.md")
end

-- Add visual marks to lines with notes
function M.mark_notes(bufnr)
  -- Clear existing marks
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  
  local file_path = M.get_buffer_path()
  if not M.notes[file_path] then return end
  
  for i, note in ipairs(M.notes[file_path]) do
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

-- Show notes panel for the current line
function M.show_notes_panel()
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local file_path = M.get_buffer_path()
  
  if not M.notes[file_path] then return end
  
  -- Find notes for the current line
  local relevant_notes = {}
  for i, note in ipairs(M.notes[file_path]) do
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
  local lines = {"# Notes for current line", ""}
  
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
    
    -- Go back to original window
    vim.api.nvim_set_current_win(current_winid)
  end
end

-- Close notes panel
function M.close_notes_panel()
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
    -- Close the panel
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
            M.show_notes_panel()
          end
        })
      end
      
      M.auto_panel_enabled = true
      vim.notify("Audit Notes: Notes panel auto-display enabled")
    end
  end
end

-- Load notes from file
function M.load_notes()
  local filename = "notes.md"
  if not vim.fn.filereadable(filename) then
    return
  end
  
  local content = vim.fn.readfile(filename)
  if #content == 0 then
    return
  end
  
  local current_file = nil
  local current_note = nil
  local current_section = nil
  local code_block = false
  local code_content = {}
  
  M.notes = {}
  
  for _, line in ipairs(content) do
    if line:match("^## (.+)$") then
      current_file = line:match("^## (.+)$")
      M.notes[current_file] = {}
      current_note = nil
      
    elseif line:match("^### Note (%d+) %(Lines (%d+)%-(%d+)%)") then
      local note_id, start_line, end_line = line:match("^### Note (%d+) %(Lines (%d+)%-(%d+)%)")
      current_note = {
        start_line = tonumber(start_line) - 1, -- Convert to 0-indexed
        end_line = tonumber(end_line) - 1,     -- Convert to 0-indexed
        content = "",
        code = ""
      }
      current_section = "note"
      
    elseif line == "```" then
      if code_block then
        -- End of code block
        if current_note then
          current_note.code = table.concat(code_content, "\n")
          table.insert(M.notes[current_file], current_note)
        end
        code_block = false
        current_section = nil
      else
        -- Start of code block
        code_block = true
        code_content = {}
      end
      
    elseif code_block then
      table.insert(code_content, line)
      
    elseif current_note and current_section == "note" and line ~= "" then
      current_note.content = line
      current_section = "after_note"
    end
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  
  -- Create highlight groups
  vim.cmd([[
    highlight default link AuditNote Todo
    highlight default link AuditNoteHighlight CursorLine
  ]])
  
  -- Load existing notes
  M.load_notes()
  
  -- Set up commands
  vim.api.nvim_create_user_command('AuditAddNote', M.add_note, { range = true })
  vim.api.nvim_create_user_command('AuditTogglePanel', M.toggle_notes_panel, {})
  
  -- Flag to track if auto panel display is enabled
  M.auto_panel_enabled = true
  
  -- Set up auto-commands
  local augroup = vim.api.nvim_create_augroup('AuditNotes', { clear = true })
  
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    pattern = '*',
    callback = function()
      M.mark_notes(0)
    end
  })
  
  -- Store auto panel augroup ID and create the autocmd
  M.auto_panel_augroup = vim.api.nvim_create_augroup('AuditNotesPanel', { clear = true })
  
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = M.auto_panel_augroup,
    pattern = '*',
    callback = function()
      if M.auto_panel_enabled then
        M.show_notes_panel()
      end
    end
  })
  
  return M
end

return M
