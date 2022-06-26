
let g:tmux_color_menu = #{
  \  cache: get(environ(), 'XDG_CACHE_HOME', environ()['HOME'] .. '/.cache')
  \         .. '/tmux-theme-menu.json',
  \  menu: get(environ(), 'XDG_CONFIG_HOME', environ()['HOME'] .. '/.config')
  \         .. '/tmux/tmux-theme-menu.tmux',
  \}



command! -bar -nargs=? ColorsGenerateTmuxMenu
  \ call tmuxColorMenu#create_menu(<args>)
