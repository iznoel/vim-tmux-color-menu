if &cp || exists("loaded_tmux_color_menu")
    finish
endif

let loaded_tmux_color_menu = 1
let s:save_cpo = &cpo
set cpo&vim

let g:tmux_color_menu = #{
  \  cache: get(environ(), 'XDG_CACHE_HOME', environ()['HOME'] .. '/.cache')
  \         .. '/tmux-theme-menu.json',
  \  menu: get(environ(), 'XDG_CONFIG_HOME', environ()['HOME'] .. '/.config')
  \         .. '/tmux/tmux-theme-menu.tmux',
  \}

command! -bar -nargs=? ColorsGenerateTmuxMenu
  \ call tmuxColorMenu#create_menu(<args>)

let &cpo = s:save_cpo
unlet s:save_cpo
