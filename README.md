# audit.nvim

A Neovim plugin that enables code auditors to take notes about the code they're reviewing without modifying the source code.

## Features

- [x] Highlight code and add notes without changing the source
- [x] Store all notes in a separate "notes.md" file
- [x] Link notes to specific lines of code
- [x] Display visual indicators on lines with notes
- [x] Show relevant notes in a side panel when cursor is on a line with notes
- [x] Edit notes directly in the panel and save changes to the notes file automatically
- [x] Delete notes from the source code
- [ ] Use different notes for different things
    - [ ] Add a "question" note when starting with `?`
    - [ ] Add a "possible finding" note when starting with `!`
    - [x] Add an "info" note when starting with any other symbol

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'rober-m/audit.nvim',
  config = function()
    require('audit').setup()
  end
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'rober-m/audit.nvim'
```

## Usage

1. Select text in visual mode
2. Run `:AuditAddNote`
3. Enter your note
4. Notes will be saved to `notes.md` in your working directory

### Commands

- `:AuditAddNote` - Add a note for the selected text (visual mode only)
- `:AuditTogglePanel` - Toggle the notes panel on/off and enable/disable automatic panel display
- `:AuditSyncNotes` - Manually sync edited notes from the panel to the notes.md file

### Keybindings

The plugin doesn't set any default keybindings. Here are examples of how to set up your own keybindings:

```lua
-- In your init.lua or other configuration file
-- Add a note from visual mode
vim.keymap.set('v', '<Leader>an', ':AuditAddNote<CR>', { noremap = true, silent = true })

-- Toggle the notes panel
vim.keymap.set('n', '<Leader>at', ':AuditTogglePanel<CR>', { noremap = true, silent = true })

-- Save changes from the panel (when the panel has focus)
vim.keymap.set('n', '<Leader>as', ':AuditSyncNotes<CR>', { noremap = true, silent = true })
```

### Editing Notes

You can edit notes directly in the notes panel:

1. When a note is displayed in the panel, you can modify its content
2. Save your changes using the `:AuditSyncNotes` command or your custom keybinding

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
