set ai
set ts=4
set shiftwidth=4
set sw=4
set ruler
set showmode
set showmatch
set viminfo=
map \s :set et<CR>:retab<CR>:set noet<CR>
map \t	:retab!

if has("syntax")
  syntax on
endif
