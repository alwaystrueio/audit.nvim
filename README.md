# audit.nvim

A Neovim plugin that enables code auditors to take notes about the code they're reviewing without modifying the source code.

## Features

- Highlight code and add notes without changing the source
- Store all notes in a separate "notes.md" file
- Link notes to specific lines of code
- Display visual indicators on lines with notes
- Show relevant notes in a side panel when cursor is on a line with notes
- Edit notes directly in the panel and save changes to the notes file

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'username/audit.nvim',
  config = function()
    require('audit').setup()
  end
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'username/audit.nvim'
```

## Usage

1. Select text in visual mode
2. Press `<Leader>an` or run `:AuditAddNote`
3. Enter your note
4. Notes will be saved to `notes.md` in your working directory

### Commands

- `:AuditAddNote` - Add a note for the selected text (visual mode only)
- `:AuditTogglePanel` - Toggle the notes panel on/off and enable/disable automatic panel display
- `:AuditSyncNotes` - Manually sync edited notes from the panel to the notes.md file

### Editing Notes

You can edit notes directly in the notes panel:

1. When a note is displayed in the panel, you can modify its content
2. Save your changes using one of these methods:
   - Press `<Leader>as` in the notes panel
   - Use `:w` in the notes panel
   - Run `:AuditSyncNotes` from any buffer

Changes to notes are automatically saved to the notes.md file. Note that only the content of notes can be edited; the code snippets remain unchanged to preserve the original references.

## Configuration

The plugin works with default settings, but can be customized:

```lua
require('audit').setup({
  -- Future configuration options will be added here
})
```

## Notes Format

Notes are stored in a Markdown file with the following structure:

```markdown
# Audit Notes

## path/to/file.ext

### Note 1 (Lines 10-15)

This is a note about the code.

```
The actual code snippet
```
```

## License

MIT 