" vim: ts=4 sw=4 et
scriptencoding utf-8

function! jobmake#utils#LogMessage(level, msg) abort
    let verbose = get(g:, 'jobmake_verbose', 1)
    let logfile = get(g:, 'jobmake_logfile')
    let msg ='Jobmake: '.a:msg
    if verbose >= a:level
        if a:level ==# 0
            echohl ErrorMsg
        endif
        echom msg
        if a:level ==# 0
            echohl None
        endif
    endif
    if type(logfile) ==# type('') && len(logfile)
        let date = strftime('%Y-%m-%dT%H:%M:%S%z')
        call writefile([date.' Log level '.a:level.': '.msg], logfile, 'a')
    endif
endfunction

function! jobmake#utils#ErrorMessage(msg) abort
    call jobmake#utils#LogMessage(0, a:msg)
endfunction

function! jobmake#utils#QuietMessage(msg) abort
    call jobmake#utils#LogMessage(1, a:msg)
endfunction

function! jobmake#utils#LoudMessage(msg) abort
    call jobmake#utils#LogMessage(2, a:msg)
endfunction

function! jobmake#utils#DebugMessage(msg) abort
    call jobmake#utils#LogMessage(3, a:msg)
endfunction

function! jobmake#utils#Stringify(obj) abort
    if type(a:obj) == type([])
        let ls = map(copy(a:obj), 'jobmake#utils#Stringify(v:val)')
        return '['.join(ls, ', ').']'
    elseif type(a:obj) == type({})
        let ls = []
        for key in keys(a:obj)
            call add(ls, key.': '.jobmake#utils#Stringify(a:obj[key]))
        endfor
        return '{'.join(ls, ', ').'}'
    else
        return ''.a:obj
    endif
endfunction

function! jobmake#utils#DebugObject(msg, obj) abort
    call jobmake#utils#DebugMessage(a:msg.' '.jobmake#utils#Stringify(a:obj))
endfunction

" This comes straight out of syntastic.
"print as much of a:msg as possible without "Press Enter" prompt appearing
function! jobmake#utils#WideMessage(msg) abort " {{{2
    let old_ruler = &ruler
    let old_showcmd = &showcmd

    "This is here because it is possible for some error messages to
    "begin with \n which will cause a "press enter" prompt.
    let msg = substitute(a:msg, "\n", '', 'g')

    "convert tabs to spaces so that the tabs count towards the window
    "width as the proper amount of characters
    let chunks = split(msg, "\t", 1)
    let msg = join(map(chunks[:-2], 'v:val . repeat(" ", &tabstop - strwidth(v:val) % &tabstop)'), '') . chunks[-1]
    let msg = strpart(msg, 0, &columns - 1)

    set noruler noshowcmd
    redraw

    call jobmake#utils#DebugMessage('WideMessage echo '.msg)
    echo msg

    let &ruler = old_ruler
    let &showcmd = old_showcmd
endfunction " }}}2

" This comes straight out of syntastic.
function! jobmake#utils#IsRunningWindows() abort
    return has('win32') || has('win64')
endfunction

" This comes straight out of syntastic.
function! jobmake#utils#DevNull() abort
    if jobmake#utils#IsRunningWindows()
        return 'NUL'
    endif
    return '/dev/null'
endfunction

function! jobmake#utils#Exists(exe) abort
    " DEPRECATED: just use executable() directly.
    return executable(a:exe)
endfunction

function! jobmake#utils#Random() abort
    call jobmake#utils#DebugMessage('Calling jobmake#utils#Random')
    if jobmake#utils#IsRunningWindows()
        let cmd = 'Echo %RANDOM%'
    else
        let cmd = 'echo $RANDOM'
    endif
    let answer = 0 + system(cmd)
    if v:shell_error
        " If complaints come up about this, consider using python
        throw "Can't generate random number for this platform"
    endif
    return answer
endfunction

" Get property from highlighting group.
function! jobmake#utils#GetHighlight(group, what) abort
  let reverse = synIDattr(synIDtrans(hlID(a:group)), 'reverse')
  let what = a:what
  if reverse
    if what ==# 'fg'
      let what = 'bg'
    elseif what ==# 'bg'
      let what = 'fg'
    elseif what ==# 'fg#'
      let what = 'bg#'
    elseif what ==# 'bg#'
      let what = 'fg#'
    endif
  endif
  if what[-1:] ==# '#'
      let val = synIDattr(synIDtrans(hlID(a:group)), what, 'gui')
  else
      let val = synIDattr(synIDtrans(hlID(a:group)), what, 'cterm')
  endif
  if empty(val) || val == -1
    let val = 'NONE'
  endif
  return val
endfunction
