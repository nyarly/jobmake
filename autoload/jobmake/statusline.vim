function! s:setCount(counts, item, buf) abort
    let type = toupper(a:item.type)
    if len(type) && (!a:buf || a:item.bufnr ==# a:buf)
        let a:counts[type] = get(a:counts, type, 0) + 1
    endif
endfunction

function! jobmake#statusline#ResetCountsForBuf(buf) abort
    let s:loclist_counts[a:buf] = {}
endfunction

function! jobmake#statusline#ResetCounts() abort
    let s:qflist_counts = {}
    let s:loclist_counts = {}
endfunction
call jobmake#statusline#ResetCounts()

function! jobmake#statusline#AddLoclistCount(buf, item) abort
    let s:loclist_counts[a:buf] = get(s:loclist_counts, a:buf, {})
    call s:setCount(s:loclist_counts[a:buf], a:item, a:buf)
endfunction

function! jobmake#statusline#AddQflistCount(item) abort
    call s:setCount(s:qflist_counts, a:item, 0)
endfunction

function! jobmake#statusline#LoclistCounts(...) abort
    let buf = a:0 ? a:1 : bufnr('%')
    if buf ==# 'all'
        return s:loclist_counts
    endif
    return get(s:loclist_counts, buf, {})
endfunction

function! jobmake#statusline#QflistCounts() abort
    return s:qflist_counts
endfunction

function! s:showErrWarning(counts, prefix)
    let w = get(a:counts, 'W', 0)
    let e = get(a:counts, 'E', 0)
    if w || e
        let result = a:prefix
        if e
            let result .= 'E:'.e
        endif
        if w
            let result .= 'W:'.w
        endif
        return result
    else
        return ''
    endif
endfunction

function! jobmake#statusline#LoclistStatus(...) abort
    return s:showErrWarning(jobmake#statusline#LoclistCounts(), a:0 ? a:1 : '')
endfunction

function! jobmake#statusline#QflistStatus(...) abort
    return s:showErrWarning(jobmake#statusline#QflistCounts(), a:0 ? a:1 : '')
endfunction
