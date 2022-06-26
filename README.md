Tmux Color Menu (For vim/neovim)
================================

Generate a tmux menu script based off of colorschemes loaded in vim.

**Warning: This plugin is in early stages of development**

![screenshot](/media/screenshot1.jpg)

## Commands

- `ColorsDumpToTmux [file]`

## Basic Config

vimrc
```vim
let g:tmux_color_menu = #{
  \  cache: expand('~/.cache/tmux-theme-menu.json'),
  \  menu: expand('~/.config/tmux/theme-menu.tmux'),
  \}
```

tmux.conf
```tmux
source "~/.config/tmux/theme-menu.tmux"
```
