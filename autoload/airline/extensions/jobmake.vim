" vim: ts=4 sw=4 et

if exists('g:jobmake_airline') && g:jobmake_airline == 0
    finish
endif

let s:spc = g:airline_symbols.space

function! airline#extensions#jobmake#apply(...)
    let w:airline_section_warning = get(w:, 'airline_section_warning', g:airline_section_warning)
    let w:airline_section_warning .= s:spc.'%{jobmake#statusline#LoclistStatus()}'
endfunction

function! airline#extensions#jobmake#init(ext)
    call airline#parts#define_raw('jobmake', '%{jobmake#statusline#LoclistStatus()}')
    call a:ext.add_statusline_func('airline#extensions#jobmake#apply')
endfunction
