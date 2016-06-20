**[Maintainers needed!](https://github.com/jobmake/jobmake)** Contact an organization owner if interested.

[![Build Status](https://travis-ci.org/jobmake/jobmake.svg?branch=master)](https://travis-ci.org/jobmake/jobmake)

# Jobmake

A plugin for asynchronous `:make` using [Neovim's](http://neovim.org/)
job-control functionality. It is inspired by the excellent vim plugins
[Syntastic](https://github.com/scrooloose/syntastic) and
[Dispatch](https://github.com/tpope/vim-dispatch).

It is a direct fork of [Neomake](https://github.com/neomake/neomake) which you may prefer.

The minimum Neovim version supported by Jobmake is `NVIM 0.0.0-alpha+201503292107` (commit `960b9108c`).

## How to use

Just set your `makeprg` and `errorformat` as normal, and run:

    :Jmake!

If your makeprg can take a filename as an input, then you can run `:Jobmake`
(no exclamation point) to pass the current file as the first argument.
Otherwise, it is simply invoked in vim's current directory with no arguments.

Here's an example of how to run jobmake on the current file on every write:

    autocmd! BufWritePost * Jobmake

The make command will be run in an asynchronous job. The results will be
populated in the window's quickfix list for `:Jobmake!` and the location
list for `:Jobmake` as the job runs. Run `:copen` or `:lopen` to see the
whole list.

## Rationale

This fork of Neomake is engendered by the desire to have the plugin be
as simple as possible - to do exactly one thing well
and to conform to the existing framework for :make that Vim already defines.

The original idea was simply to take the description of the :make command
and wrap the actual execution of the 'makeprg' in job control.
Neomake already does that - and so much more.
So rather than re-learn the lessons Neomake already addresses,
the idea was to strip out the maker stuff (neatly handled by
Vim's compilers and autocmds)
and remove the sign management
(which is a neat feature, already implemented elsewhere.)
