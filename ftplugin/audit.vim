if exists("b:did_ftplugin_audit")
  finish
endif
let b:did_ftplugin_audit = 1

" Map <Leader>an to add a note for the visual selection
vnoremap <buffer> <Leader>an :AuditAddNote<CR> 