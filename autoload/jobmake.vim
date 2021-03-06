" vim: ts=2 sw=2 et
scriptencoding utf-8

let s:make_id = 1
let s:jobs = {}
let s:cur_job = {}
let s:current_errors = {
      \ 'project': {},
      \ 'file': {}
      \ }
let s:need_errors_cleaning = {
      \ 'project': 1,
      \ 'file': {}
      \ }

function! jobmake#GetJobs() abort
  return s:jobs
endfunction

function! jobmake#ListJobs() abort
  call jobmake#utils#DebugMessage('call jobmake#ListJobs()')
  for jobinfo in values(s:jobs)
    echom jobinfo.id.' '.jobinfo.name
  endfor
endfunction

function! jobmake#CancelJob(job_id) abort
  if !has_key(s:jobs, a:job_id)
    return
  endif
  call jobstop(s:jobs[a:job_id])
endfunction

function! s:gettabwinvar(t, w, v, d)
  " Wrapper around gettabwinvar that has no default (Vim in Travis).
  let r = gettabwinvar(a:t, a:w, a:v)
  if r is ''
    unlet r
    let r = a:d
  endif
  return r
endfunction

function! s:getwinvar(w, v, d)
  " Wrapper around getwinvar that has no default (Vim in Travis).
  let r = getwinvar(a:w, a:v)
  if r is ''
    unlet r
    let r = a:d
  endif
  return r
endfunction

" Make emulates the :make builtin whose behavior is copied here verbatim
":mak[e][!] [arguments]
"           1. All relevant |QuickFixCmdPre| autocommands are
"			   executed.
"			2. If the 'autowrite' option is on, write any changed
"			   buffers
"			3. An errorfile name is made from 'makeef'.  If
"			   'makeef' doesn't contain "##", and a file with this
"			   name already exists, it is deleted.
"
"  NB: the errorfile thing is currently omitted. It's assumed
"    (and this is probably a bad assumption)
"    that the makeprg emits all its useful output to stdout/error
"    which is where it will be captured.
"    Might fix this if it hits me, or PRs accepted
"
"			4. The program given with the 'makeprg' option is
"			   started (default "make") with the optional
"			   [arguments] and the output is saved in the
"			   errorfile (for Unix it is also echoed on the
"			   screen).
"
"  These parts are handled by the job event handlers
"			5. The errorfile is read using 'errorformat'.
"			6. All relevant |QuickFixCmdPost| autocommands are
"			   executed. See example below.
"			7. If [!] is not given the first error is jumped to.
"			8. The errorfile is deleted.
function! s:Make(options, args) abort
  let buf = bufnr('%')
  let win = winnr()
  let location_mode = 0
  if get(a:options, 'list', 'quickfix') == 'quickfix'
    let location_mode = 0
  else
    let location_mode = 1
  endif
  let jump = get(a:options, '0')

"1. All relevant |QuickFixCmdPre| autocommands are
"   executed.
  doautocmd QuickFixCmdPre

"2. If the 'autowrite' option is on, write any changed
"   buffers
  if &autowrite
    wall
  endif

  if location_mode
    lgetexpr ''
  else
    cgetexpr ''
  endif

  if location_mode
    call jobmake#statusline#ResetCountsForBuf(buf)
  else
    call jobmake#statusline#ResetCounts()
  endif

  let job_ids = []


  "XXX need to handle the case where there is an existing make job
  let job = jobmake#MakeJob(a:args, location_mode, jump)

"			4. The program given with the 'makeprg' option is
"			   started (default "make") with the optional
"			   [arguments] and the output is saved in the
"			   errorfile (for Unix it is also echoed on the
"			   screen).
  let job_id = job.start()

  return [job_id]
endfunction

function! s:MakerFromCommand(shell, command) abort
    let command = substitute(a:command, '%\(:[a-z]\)*',
                           \ '\=expand(submatch(0))', 'g')
    let shell_name = split(a:shell, '/')[-1]
    if index(['sh', 'csh', 'ash', 'bash', 'dash', 'ksh', 'pdksh', 'mksh', 'zsh', 'fish'],
            \shell_name) >= 0
        let args = ['-c', command]
    else
        let shell_name = split(a:shell, '\\')[-1]
        if (shell_name ==? 'cmd.exe')
            let args = [&shellcmdflag, command]
        endif
    endif
    return {
        \ 'exe': a:shell,
        \ 'args': args
        \ }
endfunction

function! jobmake#MakeJob(arglist, location_mode, jump) abort
  let maker = s:MakerFromCommand(&shell, &makeprg)
  "let make_id = s:make_id
  "let s:make_id += 1
  let exe = maker.exe
  let args = maker.args

  if jobmake#utils#IsRunningWindows()
    " Don't expand &shellcmdflag argument of cmd.exe
    call map(args, 'v:val !=? &shellcmdflag ? expand(v:val) : v:val')
  else
    call map(args, 'expand(v:val)')
  endif

  let has_args = type(args) == type([])

  let argv = [exe]
  if has_args
    let argv = argv + args
  endif

  if len(a:arglist) > 0
      call jobmake#utils#DebugMessage('arglist: '.type(a:arglist).' '.len(a:arglist).' '.string(a:arglist))
      let argv = argv + a:arglist
  endif

  call jobmake#utils#LoudMessage('Starting: '.join(argv, ' '))
  let opts = {
        \ 'on_stdout': function('s:HandleOutput'),
        \ 'on_stderr': function('s:HandleOutput'),
        \ 'on_exit': function('s:HandleExit'),
        \ 'start': function('s:StartJob'),
        \ 'clean': function('s:CleanJobinfo'),
        \ 'window_register': function('s:AddJobinfoForCurrentWin'),
        \ 'job_output': function('s:RegisterJobOutput'),
        \ 'open_window': function('s:HandleListDisplay'),
        \ 'argv': argv,
        \ 'location_mode': a:location_mode,
        \ 'jump': a:jump,
        \ 'tab': tabpagenr(),
        \ 'win': winnr(),
        \ 'lines': {'stdout':[], 'stderr':[]},
        \ 'event_type': '',
        \ 'last_register': 0,
        \ 'compiler': s:GetVar('current_compiler', ''),
        \ 'makeprg': &makeprg,
        \ 'errorformat': &errorformat,
        \ 'makeef': &makeef,
        \ }

  call jobmake#utils#DebugMessage('Captured compiler: '.opts.compiler)

  return opts
endfunction

function! s:GetVar(name, default)
  return get(b:, a:name, get(g:, a:name, a:default))
endfunction

function! s:AddJobinfoForCurrentWin() dict
  " Add jobinfo to current window.
  call settabwinvar(self.tab, self.win, 'jobmake_job', self)
endfunction

function! s:StartJob() abort dict
  call jobmake#utils#DebugMessage('starting: '.join(self.argv, " "))

  call self.open_window(0)

  let job = jobstart(self.argv, self)

  if job == 0
    throw 'Job table is full or invalid arguments given'
  elseif job == -1
    throw 'Non executable given'
  endif

  let self.id = job
  let s:cur_job = self
  let s:jobs[job] = self
  call self.window_register()

  return job
endfunction

function! s:HandleListDisplay(on_exit) abort dict
  let open_val = get(g:, 'jobmake_open_list', 0)
  if a:on_exit
    let open_val = get(g:, 'jobmake_open_list_exit', open_val)
  else
    let open_val = get(g:, 'jobmake_open_list_start', open_val)
  endif

  if open_val
    let height = get(g:, 'jobmake_list_height', 10)
    let win_val = winnr()
    if self.location_mode
      exe 'lwindow' height
    else
      exe 'cwindow' height
    endif
    if open_val == 2 && win_val != winnr()
      wincmd p
    endif
  endif
endfunction

function! s:RegisterJobOutput(lines) abort dict
  let lines = copy(a:lines)

  call jobmake#utils#DebugMessage(self.makeprg.' processing '.
        \ len(a:lines).' lines of output')
  if len(a:lines)
    let l:has_efm = 0
    if exists('&errorformat')
      let l:has_efm = 1
      let l:old_efm = &errorformat
    endif
    try
      let &errorformat = self.errorformat
      if self.location_mode
        " XXX Needs laddexpr if list=loc
        laddexpr a:lines
      else
        caddexpr a:lines
      endif
      call self.open_window(0)
    finally
      if l:has_efm
        let &errorformat = l:old_efm
      endif
    endtry
  endif
endfunction

"			5. The errorfile is read using 'errorformat'.
function! s:HandleOutput(jobid, data, event_type) dict abort
  " Register job output. Buffer registering of output for long running
  " jobs.
  let last_event_type = self.event_type
  let self.event_type = a:event_type

  let lines = self.lines[a:event_type]

  call jobmake#utils#DebugMessage( self.makeprg.' '.a:event_type.': ["'.join(lines, '", "').'"]')
  call jobmake#utils#DebugMessage( self.makeprg.' '.a:event_type.': ["'.join(a:data, '", "').'"]')
  " a:data is a List of 'lines' read. Each element *after* the first
  " element represents a newline
  " As per https://github.com/neovim/neovim/issues/3555
  if len(lines) > 0
    let lines = lines[:-2]
          \ + [lines[-1] . get(a:data, 0, '')]
          \ + a:data[1:]
  else
    let lines = a:data
  endif

  let now = localtime()
  if len(lines) > 5 || now - self.last_register > 2
    call self.job_output(lines[:-3])
    let lines = lines[-2:]
    let self.last_register = now
  endif
  call jobmake#utils#DebugMessage( self.makeprg.' '.a:event_type.': ["'.join(lines, '", "').'"]')
  call jobmake#utils#DebugMessage( self.makeprg.' '.a:event_type.': ["'.join(self.lines[a:event_type], '", "').'"]')

  let self.lines[a:event_type] = lines
endfunction

"			6. All relevant |QuickFixCmdPost| autocommands are
"			   executed. See example below.
"			7. If [!] is not given the first error is jumped to.
"			8. The errorfile is deleted.
function! s:HandleExit(job_id, data, event_type) abort dict
  if len(self.lines['stdout']) > 0 && self.lines['stdout'][-1] == ''
    call remove(self.lines['stdout'], -1)
  endif
  call self.job_output(self.lines['stdout'])

  if len(self.lines['stderr']) > 0 && self.lines['stderr'][-1] == ''
    call remove(self.lines['stderr'], -1)
  endif
  call self.job_output(self.lines['stderr'])
  "6. All relevant |QuickFixCmdPost| autocommands are
  "  executed. See example below.

  call self.open_window(1)

  doautocmd QuickFixCmdPost

  let status = a:data
  call self.clean()
  call jobmake#utils#QuietMessage(
        \ self.makeprg. ' completed with exit code '.status)

  if self.jump
    if self.location_mode
      ll
    else
      cc
    endif
  endif

endfunction

function! s:CleanJobinfo() abort dict
  call remove(s:jobs, self.id)
  if self.location_mode
    " Remove job from its window.
    call settabwinvar(self.tab, self.win, 'jobmake_job', {})
  else
    if s:cur_job == self
      let s:cur_job = {}
    endif
  endif
endfunction

function! jobmake#Make(jump_mode, list, ...) abort
  let options = { 'jump': a:jump_mode, 'list': a:list }
  return s:Make(options, a:000)
endfunction

"function! jobmake#Sh(sh_command, ...) abort
"  let options = { jump: jump_mode }
"  let custom_maker = jobmake#utils#MakerFromCommand(&shell, a:sh_command)
"  let custom_maker.name = 'sh: '.a:sh_command
"  let custom_maker.remove_invalid_entries = 0
"  let options.enabled_makers =  [custom_maker]
"  return s:Make(options)[0]
"endfunction
