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

Or in Vim script:

```vim
" In your vimrc or init.vim
" Add a note from visual mode
vnoremap <Leader>an :AuditAddNote<CR>

" Toggle the notes panel
nnoremap <Leader>at :AuditTogglePanel<CR>

" Save changes from the panel (when the panel has focus)
nnoremap <Leader>as :AuditSyncNotes<CR>
```

#### Using with which-key

If you're using [which-key.nvim](https://github.com/folke/which-key.nvim), you can organize these keybindings in a "notes" group:

```lua
-- Setup which-key.nvim with a notes group
require('which-key').register({
  n = {
    name = "Notes", -- group name
    a = { "<cmd>AuditAddNote<CR>", "Add note" },
    t = { "<cmd>AuditTogglePanel<CR>", "Toggle notes panel" },
    s = { "<cmd>AuditSyncNotes<CR>", "Sync notes changes" },
  }
}, { prefix = "<leader>" })
```

This creates a `<Leader>n` group with the following mappings:
- `<Leader>na` - Add a note (in visual mode)
- `<Leader>nt` - Toggle the notes panel
- `<Leader>ns` - Sync notes changes

For visual mode mappings, you can define them separately:

```lua
require('which-key').register({
  n = {
    name = "Notes",
    a = { "<cmd>AuditAddNote<CR>", "Add note" },
  }
}, { prefix = "<leader>", mode = "v" })
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