
let s:lum = {hex -> sqrt(
  \ 0.299*pow(0+("0x".hex[1:2]), 2) +
  \ 0.587*pow(0+("0x".hex[3:4]), 2) +
  \ 0.114*pow(0+("0x".hex[5:6]), 2)
  \)}


let s:gget = { what ->
  \ get(get(g:, 'tmux_color_menu', {}), what, '')
  \}


function! tmuxColorMenu#create_menu(file='') abort
  let file = a:file == '' ? s:gget('menu') : a:file
  let initial = get(g:, 'colors_name', 'default')
  let menufile = s:check_menu_file(file)
  if menufile != file
    return
  endif
  let do_tmux_commands = s:validate_tmux_connection()
  set tgc
  try
    let schemes = s:obtain(initial)
  finally
    exe 'silent noau colo' initial
  endtry
  let sorted  = s:merge(schemes)
  call s:generate_menu_script(sorted)
  if do_tmux_commands
    call system('tmux unbind m-c \; source ' . menufile)
  endif
  redraw! | echo "Completed"
endfunction


function s:validate_tmux_connection() abort
  return filereadable(split(get(environ(),'TMUX', ''), ',')[0])
endfunction


function! s:check_menu_file(file) abort
  if ! filereadable(a:file)
    let base = fnamemodify(a:file, ':p:h')
    if isdirectory(base)
      return a:file
    endif
    echom a:file .. ' is unreadable. and ' .. base .. ' Doesnt exist.'
    throw ''
  endif
  let header = readfile(a:file, '', 10)
  let check = filter(copy(s:banner), 'len(v:val)')
  let satisfied = 0
  for line in header
    let satisfied += line == check[satisfied]
    if satisfied == len(check)
      return a:file
    endif
  endfor
  echom 'refusing to overwrite ' .. a:file .. "\n banner is not present"
  throw ''
endfunction


function! s:get_base_16() abort
  let colors = []
  if has('nvim')
    for [n,c] in map(range(16),'[v:key, v:val]')
      call add(colors, get(g:, 'terminal_color_'..c, ''))
    endfor
  else
    let colors = copy(get(g:, 'terminal_ansi_colors', []))
  endif
  " if len(colors) == 16
  "   let colors[0]  = synIDattr(hlID('normal'),'bg#')
  "   let colors[15] = synIDattr(hlID('normal'),'fg#')
  " endif
  return colors
endfunction


function! s:obtain(initial) abort
  let initialcolor = a:initial
  let colors = {}

  for scheme in getcompletion('', 'color')
      let colors[scheme] = {}
      for bg in ['dark', 'light']
        let &bg = bg
        highlight clear
        try
          exe 'noau silent! colo' scheme
        catch /.*/
          exe 'noau silent! colo' initialcolor
          continue
        endtry
        let c = s:get_base_16()
        if len(c) == 16 && index(c, '') == -1
          let colors[scheme][bg] = copy(c)
          unlet c
        endif
      endfor
  endfor
  noau exe 'silent! noau colo' initialcolor

  for scheme in keys(colors)
    if len(colors[scheme]) == 2
      let [k1, k2] = [keys(colors[scheme])[0], keys(colors[scheme])[1]]
      if len(colors[scheme]) == 0 | unlet colors[scheme] | continue | endif

      let s:diff = v:false
      for n in range(1,15) " 1-15 i.e. ignore background colour
        let s:diff = s:diff || (colors[scheme][k1][n] == colors[scheme][k2][n])
      endfor
      if s:diff == v:true
        unlet colors[scheme][k2]
      endif

      for k in keys(colors[scheme])
        if len(colors[scheme][k]) != 16 | unlet colors[scheme][k] | endif
      endfor
    endif

    if empty(colors[scheme])
      unlet colors[scheme]
    elseif len(colors[scheme]) == 1
      let colors[scheme] = colors[scheme][keys(colors[scheme])[0]]
    elseif  len(colors[scheme]) == 2
      let colors[scheme..k1] = colors[scheme][k1]
      let colors[scheme..k2] = colors[scheme][k2]
      unlet! colors[scheme][k1] colors[scheme][k2] colors[scheme] k1 k2
    endif
  endfor

  noau exe 'silent! noau colo' initialcolor
  return colors
endfunction


" 1. load cached colours,
" 2. merge with supplied dict
" 3. write back to the cache
function! s:merge(current, inplace=v:true) abort
  let cache = s:gget('cache')
  if cache != '' && filereadable(cache)
    let read = readfile(cache)
    if type(read) == v:t_list
      let contents = json_decode(join(read,''))
    else
      let contents = json_decode(read)
    endif
    unlet read
    let contents = reduce(contents,
      \ {a,v -> extend(a, {v[0] : v[1]})}, {})
  else
    let contents = {}
  endif

  call extend(contents, a:current, 'force')

  " de-duplicate
  let bad = []
  for c1 in keys(contents)
    if index(bad, c1) > -1 | continue | endif
    for c2 in keys(contents)
      if c1 == c2 | continue | endif
      if index(bad, c2) > -1 | continue | endif
      if c1 != c2
        let same = v:true
        for c in range(15)
          if contents[c1][c] != contents[c2][c]
            let same = v:false | break
          endif
        endfor
        if same | call add(bad, c2) | endif
      endif
    endfor
  endfor
  for c in bad | unlet contents[c] | endfor

  let sorted = map(deepcopy(contents), { _,v -> map(v, {_,val -> s:lum(v:val)})})
    \->items()->sort(funcref("s:sort_buckets_2"))
  \->map({ _,v -> [v[0], contents[v[0]]] })

  if cache != '' && filereadable(cache) && a:inplace
    call writefile([json_encode(sorted)], cache)
  endif
  return sorted
endfunction


" sort into X buckets based on background brightness
" sort each based on brightness between fgs and bg
function! s:sort_buckets_2(a, b) abort
  let Compare = {ca, cb -> ca == cb ? 0 : ca > cb ? 1 : -1}
  let Avg = {x-> reduce(x, { a,v -> a+v }, 0)/len(x) }
  let [a, b] = [a:a[-1], a:b[-1]]
  let [aa, bb] = [Avg(a[1:]), Avg(b[1:])]
  return Compare(
    \ a[0] + (a[0]-aa) / 2,
    \ b[0] + (b[0]-bb) / 2
    \)
endfunction


function s:menu_title_formatter(title, colors) abort
  let [fg, bg] = ["#[fg=#{l:%s}]", "#[bg=#{l:%s}]"]
  let [title, colors] = [a:title, a:colors]
  return "< " .. printf(bg, colors[0]) . ' '
  \ .. join(map(range(1,len(colors)-1), {_,n -> printf(fg, colors[n])..'●'}), '')
  \ .. printf(fg .. ' %-20s', colors[-1], title)
  \ .. ' #[default] '
endfunction


" write a new tmux menu script
function! s:generate_menu_script(colors, file='') abort
  let outfile = a:file == '' ? s:gget('menu') : a:file
  call writefile(
    \ s:banner +
    \ s:script_header +
    \ s:script_bind,
    \ outfile)
  for [name, scheme] in a:colors
    let title = s:menu_title_formatter(name, scheme)
    let tmp = printf(s:menu_item_fmt, title, join(scheme, ','), scheme[0], scheme[-1])
    call writefile(split(tmp, "\n"), outfile, 'a')
  endfor
  call writefile(s:script_tail, outfile, 'a')
endfunction

" date, templates {{{1


let s:banner =<< END
# vim:ft=tmux:
# generated by tmux-theme-switcher

END


" LINES
let s:script_header =<< END
set -g @theme-switch-pre {
  set -gF mode-style                   "#{s/bg=[^,]*/bg=default:mode-style}"
  set -gF message-style                "#{s/bg=[^,]*/bg=default:message-style}"
  set -gF pane-border-style            "#{s/bg=[^,]*/bg=default:pane-border-style}"
  set -gF pane-active-border-style     "#{s/bg=[^,]*/bg=default:pane-active-border-style}"
  set -gF window-active-style          "#{s/bg=[^,]*/bg=default:window-active-style}"
  set -gF window-style                 "#{s/bg=[^,]*/bg=default:window-style}"
  set -gF window-status-activity-style "#{s/bg=[^,]*/bg=default:window-status-activity-style}"
  set -gF window-status-current-style  "#{s/bg=[^,]*/bg=default:window-status-current-style}"
  set -gF window-status-last-style     "#{s/bg=[^,]*/bg=default:window-status-last-style}"
  set -gF status-style                 "#{s/bg=[^,]*/bg=default:status-style}"
  set -gu pane-colours
  set -gu window-style
}

set -g @theme-switch-post {
  set -gF mode-style                   "#{s/bg=[^,]*/bg=#{pane-colours[0]}:mode-style}"
  set -gF message-style                "#{s/bg=[^,]*/bg=#{pane-colours[0]}:message-style}"
  set -gF pane-border-style            "#{s/bg=[^,]*/bg=#{pane-colours[0]}:pane-border-style}"
  set -gF pane-active-border-style     "#{s/bg=[^,]*/bg=#{pane-colours[0]}:pane-active-border-style}"
  set -gF window-active-style          "#{s/bg=[^,]*/bg=#{pane-colours[0]}:window-active-style}"
  set -gF window-style                 "#{s/bg=[^,]*/bg=#{pane-colours[0]}:window-style}"
  set -gF window-status-activity-style "#{s/bg=[^,]*/bg=#{pane-colours[0]}:window-status-activity-style}"
  set -gF window-status-current-style  "#{s/bg=[^,]*/bg=#{pane-colours[0]}:window-status-current-style}"
  set -gF window-status-last-style     "#{s/bg=[^,]*/bg=#{pane-colours[0]}:window-status-last-style}"
  set -gF status-style                 "#{s/bg=[^,]*/bg=#{pane-colours[0]}:status-style}"
}

bind -N 'choose theme' M-c {
END

let s:script_tail =<< END
}
END

let s:script_bind =<< END
  menu -T '[#[fg=red] Choose Theme #[default]]' \
  " Default " "r" {
    run -C "#{l:#{E:@theme-switch-pre}}"
  } \
  "-  0123456789ABCDEF" "" "" \
END

let s:menu_item_fmt =<< END
  "%s" "" {
    run -C "#{l:#{E:@theme-switch-pre}}"
    set -g pane-colours "#{l:%s}"
    set -g window-style "#{l:bg=%s,fg=%s}"
    run -C "#{l:#{E:@theme-switch-post}}"
  } \
END

let s:commands_to_switch_theme =<< END
END

let s:menu_item_fmt = join(s:menu_item_fmt, "\n")

" debug {{{1

" command! -nargs=+ Echo call s:Log(eval(<q-args>))
" function s:Log(msg='') abort
"   let s:buf = get(s:, 'buf', -2)
"   if index(tabpagebuflist(), s:buf) == -1
"     let s:buf = bufadd('')
"     let w = winnr()
"     noau split
"     noau keepj exe 'buffer' s:buf
"     setl bt=nofile bh=wipe
"     noau keepj exe w . 'wincmd w'
"   endif
"   if ! empty(a:msg)
"     call appendbufline(s:buf, '$', a:msg)
"   endif
" endfunction
