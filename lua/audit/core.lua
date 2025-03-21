local M = {}

-- Storage for notes
M.notes = {}

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
    
    table.insert(M.notes[file_path], {
      start_line = start_line,
      end_line = end_line,
      content = input,
      code = selected_text
    })
    
    -- Save notes to file
    M.save_notes()
    
    -- Add visual indicators
    require('audit.ui').mark_notes(0)
    
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

return M 