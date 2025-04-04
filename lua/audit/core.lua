local M = {}

-- Storage for notes
M.notes = {}
-- Storage for reviewed sections
M.reviewed = {}
-- Storage for project-wide notes
M.project_notes = {}

-- Utility function to get current buffer's relative path
function M.get_buffer_path()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local cwd = vim.fn.getcwd()
  
  -- If buffer has no name or is not in the current directory
  if buf_name == "" or string.len(buf_name) <= string.len(cwd) then
    return nil
  end
  
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
    
    -- Determine note type based on first character
    local note_type = "note"
    if input:sub(1, 1) == "?" then
      note_type = "question"
    elseif input:sub(1, 1) == "!" then
      note_type = "finding"
    end
    
    table.insert(M.notes[file_path], {
      start_line = start_line,
      end_line = end_line,
      content = input,
      code = selected_text,
      type = note_type
    })
    
    -- Save notes to file
    M.save_notes()
    
    -- Add visual indicators
    require('audit.ui').mark_notes(0)
    
    vim.notify("Note added")
  end)
end

-- Mark selected text as reviewed
function M.toggle_reviewed()
  local start_line, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  local end_line, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
  
  -- Adjustments for proper indexing
  start_line = start_line - 1
  end_line = end_line - 1
  
  -- Get file path
  local file_path = M.get_buffer_path()
  if not file_path then return end
  
  -- Initialize reviewed sections for this file if needed
  if not M.reviewed[file_path] then
    M.reviewed[file_path] = {}
  end
  
  -- Check if selected region already has any reviewed sections
  local overlap_indices = {}
  for i, section in ipairs(M.reviewed[file_path]) do
    -- Check for any overlap
    if not (end_line < section.start_line or start_line > section.end_line) then
      table.insert(overlap_indices, i)
    end
  end
  
  -- If we found overlapping sections, remove them (toggle off)
  if #overlap_indices > 0 then
    -- Remove in reverse order to avoid index shifting
    for i = #overlap_indices, 1, -1 do
      table.remove(M.reviewed[file_path], overlap_indices[i])
    end
    
    -- Save to file
    M.save_notes()
    
    -- Update UI
    require('audit.ui').mark_reviewed(0)
    
    vim.notify("Removed review marks")
  else
    -- No overlap found, add new section (toggle on)
    table.insert(M.reviewed[file_path], {
      start_line = start_line,
      end_line = end_line
    })
    
    -- Save to file
    M.save_notes()
    
    -- Update UI
    require('audit.ui').mark_reviewed(0)
    
    vim.notify("Code marked as reviewed")
  end
end

-- Mark selected text as reviewed (deprecated, use toggle_reviewed instead)
function M.mark_reviewed()
  M.toggle_reviewed()
end

-- Save notes to notes.md file
function M.save_notes()
  local lines = {"# Audit Notes", ""}
  
  -- Save project notes first
  if #M.project_notes > 0 then
    table.insert(lines, "## Project Notes")
    table.insert(lines, "")
    
    for i, note in ipairs(M.project_notes) do
      table.insert(lines, "### Note " .. i)
      table.insert(lines, "")
      
      -- Split content into lines
      for _, content_line in ipairs(vim.split(note.content, "\n")) do
        table.insert(lines, content_line)
      end
      table.insert(lines, "")
    end
  end
  
  -- Save file-specific notes
  for file, file_notes in pairs(M.notes) do
    table.insert(lines, "## " .. file)
    table.insert(lines, "")
    
    for i, note in ipairs(file_notes) do
      local line_ref = (note.start_line + 1) .. "-" .. (note.end_line + 1)
      table.insert(lines, "### Note " .. i .. " (Lines " .. line_ref .. ")")
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
  end
  
  -- Save reviewed sections
  table.insert(lines, "# Reviewed Sections")
  table.insert(lines, "")
  
  for file, sections in pairs(M.reviewed) do
    table.insert(lines, "## " .. file)
    table.insert(lines, "")
    
    for _, section in ipairs(sections) do
      local line_ref = (section.start_line + 1) .. "-" .. (section.end_line + 1)
      table.insert(lines, "- Lines " .. line_ref)
    end
    
    table.insert(lines, "")
  end
  
  -- Try to write the file, with error handling
  local success, err = pcall(function()
    vim.fn.writefile(lines, "notes.md")
  end)
  
  if not success then
    vim.notify("Error writing notes.md: " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Load notes from file
function M.load_notes()
  local filename = "notes.md"
  
  -- Always initialize the notes structure
  M.notes = {}
  M.reviewed = {}
  
  -- Return early if the file doesn't exist
  if not vim.fn.filereadable(filename) then
    return
  end
  
  -- Use pcall to safely read the file
  local success, content = pcall(function()
    return vim.fn.readfile(filename)
  end)
  
  -- If reading failed or content is empty, return
  if not success or not content or #content == 0 then
    return
  end
  
  local current_file = nil
  local current_note = nil
  local current_section = nil
  local code_block = false
  local code_content = {}
  local in_reviewed_section = false
  local in_project_notes = false
  
  for _, line in ipairs(content) do
    if line == "# Reviewed Sections" then
      in_reviewed_section = true
      current_file = nil
    elseif line:match("^# ") then
      in_reviewed_section = false
      current_file = nil
    elseif line:match("^## (.+)$") then
      current_file = line:match("^## (.+)$")
      
      if in_reviewed_section then
        M.reviewed[current_file] = {}
      else
        M.notes[current_file] = {}
      end
      
      current_note = nil
    
    elseif in_reviewed_section and current_file and line:match("^%- Lines (%d+)%-(%d+)$") then
      local start_line, end_line = line:match("^%- Lines (%d+)%-(%d+)$")
      if not M.reviewed[current_file] then
        M.reviewed[current_file] = {}
      end
      
      table.insert(M.reviewed[current_file], {
        start_line = tonumber(start_line) - 1, -- Convert to 0-indexed
        end_line = tonumber(end_line) - 1      -- Convert to 0-indexed
      })
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
      
      -- Determine note type based on first character
      current_note.type = "note"
      if line:sub(1, 1) == "?" then
        current_note.type = "question"
      elseif line:sub(1, 1) == "!" then
        current_note.type = "finding"
      end
      
      current_section = "after_note"
    elseif line == "## Project Notes" then
      in_project_notes = true
      current_file = nil
    elseif in_project_notes and line:match("^### Note (%d+)") then
      current_note = {
        content = "",
        type = "note"
      }
      current_section = "note"
    elseif in_project_notes and current_note and current_section == "note" and line ~= "" then
      current_note.content = line
      
      -- Determine note type based on first character
      if line:sub(1, 1) == "?" then
        current_note.type = "question"
      elseif line:sub(1, 1) == "!" then
        current_note.type = "finding"
      end
      
      table.insert(M.project_notes, current_note)
      current_note = nil
      current_section = nil
    end
  end
end

-- Get all notes at the specified line number
function M.get_notes_at_line(line_number)
  local file_path = M.get_buffer_path()
  if not file_path or not M.notes[file_path] then
    return {}
  end
  
  local notes_at_line = {}
  for i, note in ipairs(M.notes[file_path]) do
    if line_number >= note.start_line and line_number <= note.end_line then
      table.insert(notes_at_line, {id = i, note = note})
    end
  end
  
  return notes_at_line
end

-- Delete a note from the current buffer
function M.delete_note(note_id)
  local file_path = M.get_buffer_path()
  if not file_path or not M.notes[file_path] then
    vim.notify("No notes found for this file", vim.log.levels.WARN)
    return
  end
  
  -- Check if note_id is valid for this file
  if note_id <= 0 or note_id > #M.notes[file_path] then
    vim.notify("Invalid note ID: " .. note_id, vim.log.levels.ERROR)
    return
  end
  
  -- Remove the specified note
  table.remove(M.notes[file_path], note_id)
  
  -- If no notes left for this file, remove the file entry from notes
  if #M.notes[file_path] == 0 then
    M.notes[file_path] = nil
  end
  
  -- Save updated notes to file
  M.save_notes()
  
  -- Update UI
  require('audit.ui').mark_notes(0)
  
  vim.notify("Note " .. note_id .. " deleted")
end

-- Add a project-wide note
function M.add_project_note()
  vim.ui.input({
    prompt = "Enter project note: ",
  }, function(input)
    if not input or input == "" then
      return
    end
    
    -- Determine note type based on first character
    local note_type = "note"
    if input:sub(1, 1) == "?" then
      note_type = "question"
    elseif input:sub(1, 1) == "!" then
      note_type = "finding"
    end
    
    -- Add note to project notes
    table.insert(M.project_notes, {
      content = input,
      type = note_type,
      timestamp = os.time()
    })
    
    -- Save notes to file
    M.save_notes()
    
    vim.notify("Project note added")
  end)
end

return M 