command! -nargs=* -bang -bar
      \ Jmake call jobmake#Make(<bang>1, 'quickfix', [<f-args>])

command! -nargs=* -bang -bar
      \ Jlmake call jobmake#Make(<bang>1, 'location', [<f-args>])


" The idea here is to run a :Jmake with the named compiler
"command! -nargs=* -bang -bar -complete=compilers
"      \ JmakeC call jobmake#MakeC(<bang>1, [<f-args>])
"
" These commands are available for clarity
"command! -nargs=* -bar -complete=customlist,jobmake#CompleteMakers
"      \ JobmakeProject Jobmake! <args>
"command! -nargs=* -bar -complete=customlist,jobmake#CompleteMakers
"      \ JobmakeFile Jobmake <args>
"
"command! -nargs=+ -complete=shellcmd JobmakeSh call jobmake#Sh(<q-args>)

command! JobmakeListJobs call jobmake#ListJobs()
command! -nargs=1 JobmakeCancelJob call jobmake#CancelJob(<args>)

augroup jobmake
  au!
augroup END

" vim: sw=2 et
