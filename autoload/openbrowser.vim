" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


" Default values of global variables. "{{{
if g:__openbrowser_platform.cygwin
    function! s:get_default_open_commands()
        return ['cygstart']
    endfunction
    function! s:get_default_open_rules()
        return {'cygstart': '{browser} {shellescape(uri)} &'}
    endfunction
elseif g:__openbrowser_platform.macunix
    function! s:get_default_open_commands()
        return ['open']
    endfunction
    function! s:get_default_open_rules()
        return {'open': '{browser} {shellescape(uri)} &'}
    endfunction
elseif g:__openbrowser_platform.mswin
    function! s:get_default_open_commands()
        return ['cmd.exe']
    endfunction
    function! s:get_default_open_rules()
        " NOTE: On MS Windows, 'start' command is not executable.
        " NOTE: If &shellslash == 1,
        " `shellescape(uri)` uses single quotes not double quote.
        return {'cmd.exe': 'cmd /c start rundll32 url.dll,FileProtocolHandler {openbrowser#shellescape(uri)}'}
    endfunction
elseif g:__openbrowser_platform.unix
    function! s:get_default_open_commands()
        return ['xdg-open', 'x-www-browser', 'firefox', 'w3m']
    endfunction
    function! s:get_default_open_rules()
        return {
        \   'xdg-open':      '{browser} {shellescape(uri)} &',
        \   'x-www-browser': '{browser} {shellescape(uri)} &',
        \   'firefox':       '{browser} {shellescape(uri)} &',
        \   'w3m':           '{browser} {shellescape(uri)} &',
        \}
    endfunction
endif

" Do not remove g:__openbrowser_platform for debug.
" unlet g:__openbrowser_platform

" }}}

" Global Variables {{{
if !exists('g:openbrowser_open_commands')
    let g:openbrowser_open_commands = s:get_default_open_commands()
endif
if !exists('g:openbrowser_open_rules')
    let g:openbrowser_open_rules = s:get_default_open_rules()
endif
if !exists('g:openbrowser_fix_schemes')
    let g:openbrowser_fix_schemes = {
    \   'ttp': 'http',
    \   'ttps': 'https',
    \}
endif
if !exists('g:openbrowser_fix_hosts')
    let g:openbrowser_fix_hosts = {}
endif
if !exists('g:openbrowser_fix_paths')
    let g:openbrowser_fix_paths = {}
endif
if exists('g:openbrowser_isfname')
    " Backward compatibility.
    let g:openbrowser_iskeyword = g:openbrowser_isfname
endif
if !exists('g:openbrowser_iskeyword')
    " Getting only URI from <cword>.
    " NOTE: Removed valid URL characters "(", ")".
    let g:openbrowser_iskeyword = join(
    \   range(char2nr('A'), char2nr('Z'))
    \   + range(char2nr('a'), char2nr('z'))
    \   + range(char2nr('0'), char2nr('9'))
    \   + [
    \   '_',
    \   ':',
    \   '/',
    \   '.',
    \   '-',
    \   '+',
    \   '%',
    \   '#',
    \   '?',
    \   '&',
    \   '=',
    \   ';',
    \   '@',
    \   '$',
    \   ',',
    \   '[',
    \   ']',
    \   '!',
    \   "'",
    \   "*",
    \   "~",
    \], ',')
endif
if !exists('g:openbrowser_default_search')
    let g:openbrowser_default_search = 'google'
endif

let g:openbrowser_search_engines = extend(
\   get(g:, 'openbrowser_search_engines', {}),
\   {
\       'alc': 'http://eow.alc.co.jp/{query}/UTF-8/',
\       'askubuntu': 'http://askubuntu.com/search?q={query}',
\       'baidu': 'http://www.baidu.com/s?wd={query}&rsv_bp=0&rsv_spt=3&inputT=2478',
\       'blekko': 'http://blekko.com/ws/+{query}',
\       'cpan': 'http://search.cpan.org/search?query={query}',
\       'duckduckgo': 'http://duckduckgo.com/?q={query}',
\       'github': 'http://github.com/search?q={query}',
\       'google': 'http://google.com/search?q={query}',
\       'google-code': 'http://code.google.com/intl/en/query/#q={query}',
\       'php': 'http://php.net/{query}',
\       'python': 'http://docs.python.org/dev/search.html?q={query}&check_keywords=yes&area=default',
\       'twitter-search': 'http://twitter.com/search/{query}',
\       'twitter-user': 'http://twitter.com/{query}',
\       'verycd': 'http://www.verycd.com/search/entries/{query}',
\       'vim': 'http://www.google.com/cse?cx=partner-pub-3005259998294962%3Abvyni59kjr1&ie=ISO-8859-1&q={query}&sa=Search&siteurl=www.vim.org%2F#gsc.tab=0&gsc.q={query}&gsc.page=1',
\       'wikipedia': 'http://en.wikipedia.org/wiki/{query}',
\       'wikipedia-ja': 'http://ja.wikipedia.org/wiki/{query}',
\       'yahoo': 'http://search.yahoo.com/search?p={query}',
\   },
\   'keep'
\)

if !exists('g:openbrowser_open_filepath_in_vim')
    let g:openbrowser_open_filepath_in_vim = 1
endif
if !exists('g:openbrowser_open_vim_command')
    let g:openbrowser_open_vim_command = 'vsplit'
endif

if !exists('g:openbrowser_use_vimproc')
    let g:openbrowser_use_vimproc = 1
endif
" on MS Windows, invoking cmd.exe via vimproc#system() won't open given URI.
let s:use_vimproc = g:openbrowser_use_vimproc && !g:__openbrowser_platform.mswin
" }}}


" Interfaces {{{

function! openbrowser#load() "{{{
    " dummy function to load this file.
endfunction "}}}



" :OpenBrowser
function! openbrowser#open(uri) "{{{
    let uri = a:uri
    if uri =~# '^\s*$'
        " Error
        return
    endif

    let query_type = s:detect_query_type(uri, s:Q_OPEN)
    if query_type ==# s:QT_FILEPATH    " Existed file path or 'file://'
        " Convert to full path.
        if stridx(uri, 'file://') is 0    " file://
            let fullpath = substitute(uri, '^file://', '', '')
        elseif uri[0] ==# '/'    " full path
            let fullpath = uri
        else    " relative path
            let fullpath = s:convert_to_fullpath(uri)
        endif
        if s:get_var('openbrowser_open_filepath_in_vim')
            let command = s:get_var('openbrowser_open_vim_command')
            execute command fullpath
        else
            " Convert to file:// string.
            " NOTE: cygwin cannot treat file:// URI,
            " pass a string as fullpath.
            if !g:__openbrowser_platform.cygwin
                let fullpath = 'file://' . fullpath
            endif
            call s:open_browser(fullpath)
        endif
    elseif query_type ==# s:QT_URI    " other URI
        let obj = urilib#new_from_uri_like_string(uri, s:NONE)
        if obj is s:NONE
            " Error
            return
        endif
        " Fix scheme, host, path.
        " e.g.: "ttp" => "http"
        for where in ['scheme', 'host', 'path']
            let fix = s:get_var('openbrowser_fix_'.where.'s')
            let value = obj[where]()
            if has_key(fix, value)
                call call(obj[where], [fix[value]], obj)
            endif
        endfor
        let uri = obj.to_string()
        call s:open_browser(uri)
    else
        " Error
        return
    endif
endfunction "}}}

" :OpenBrowserSearch
function! openbrowser#search(query, ...) "{{{
    let engine = a:0 ? a:1 :
    \   s:get_var('openbrowser_default_search')
    let search_engines =
    \   s:get_var('openbrowser_search_engines')
    if !has_key(search_engines, engine)
        echohl WarningMsg
        echomsg "Unknown search engine '" . engine . "'."
        echohl None
        return
    endif

    call openbrowser#open(
    \   s:expand_keywords(search_engines[engine], {'query': a:query})
    \)
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#smart_search(query, ...) "{{{
    let query_type = s:detect_query_type(a:query, s:Q_SMART_SEARCH)
    if query_type ==# s:QT_URI ||
    \  s:get_var('openbrowser_open_filepath_in_vim') &&
    \  query_type ==# s:QT_FILEPATH
        return openbrowser#open(a:query)
    else
        return openbrowser#search(
        \   a:query,
        \   (a:0 ? a:1 : s:get_var('openbrowser_default_search'))
        \)
    endif
endfunction "}}}

" so-called thinca-san escaping ;)
" http://d.hatena.ne.jp/thinca/20100210/1265813598
" NOTE: on MS Windows, invoking cmd.exe via vimproc#system() won't open given URI.
function! openbrowser#shellescape(uri) "{{{
    let uri = a:uri

    " 1. Escape all special characers (& | < > ( ) ^ " %) with hat (^).
    "    (Escaping percent (%) keeps hat (^) not to expand)
    let uri = substitute(uri, '[&|<>()^"%]', '^\0', 'g')

    " 2. Escape successive backslashes (\) before double-quote (") with the same number of backslashes.
    let uri = substitute(uri, '\\\+\ze"', '\0\0', 'g')

    " 3. Escape all double-quote (") with backslash (\)
    "    (though _"_ has been already escaped by hat (^) , escape it again.
    "     thus, double-quote (") becomes backslash + hat + double-quote (\^"))
    let uri = substitute(uri, '"', '\\\0', 'g')

    " 4. Wrap whole string with hat + double-quote (^").
    "    (Simply wrapping with _""_ results in _^_ gets invalid)
    let uri = '^"' . uri . '^"'

    return uri
endfunction "}}}

" }}}

" Implementations {{{

let s:NONE = []
lockvar s:NONE

" See s:detect_query_type()
let [
\   s:QT_URI,
\   s:QT_FILEPATH,
\   s:QT_UNKNOWN
\] = range(3)
let [
\   s:Q_OPEN,
\   s:Q_SMART_SEARCH
\] = range(2)



function! s:parse_and_delegate(excmd, parse, delegate, cmdline) "{{{
    let cmdline = substitute(a:cmdline, '^\s\+', '', '')

    try
        let [engine, cmdline] = {a:parse}(cmdline)
    catch /^parse error/
        echohl WarningMsg
        echomsg 'usage:'
        \       a:excmd
        \       '[-{search-engine}]'
        \       '{query}'
        echohl None
        return
    endtry

    let args = [cmdline] + (engine is s:NONE ? [] : [engine])
    return call(a:delegate, args)
endfunction "}}}
function! s:parse_cmdline(cmdline) "{{{
    let m = matchlist(a:cmdline, '^-\(\S\+\)\s\+\(.*\)')
    return !empty(m) ? m[1:2] : [s:NONE, a:cmdline]
endfunction "}}}

" :OpenBrowserSearch
function! openbrowser#_cmd_open_browser_search(cmdline) "{{{
    return s:parse_and_delegate(
    \   ':OpenBrowserSearch',
    \   's:parse_cmdline',
    \   'openbrowser#search',
    \   a:cmdline
    \)
endfunction "}}}
function! openbrowser#_cmd_complete(unused1, cmdline, unused2) "{{{
    let excmd = '^\s*OpenBrowser\w\+\s\+'
    if a:cmdline !~# excmd
        return
    endif
    let cmdline = substitute(a:cmdline, excmd, '', '')

    let engine_options = map(
    \   sort(keys(s:get_var('openbrowser_search_engines'))),
    \   '"-" . v:val'
    \)
    if cmdline ==# '' || cmdline ==# '-'
        " Return all search engines.
        return engine_options
    endif

    " Inputting search engine.
    " Find out which engine.
    return filter(engine_options, 'stridx(v:val, cmdline) is 0')
endfunction "}}}

" :OpenBrowserSmartSearch
function! openbrowser#_cmd_open_browser_smart_search(cmdline) "{{{
    return s:parse_and_delegate(
    \   ':OpenBrowserSmartSearch',
    \   's:parse_cmdline',
    \   'openbrowser#smart_search',
    \   a:cmdline
    \)
endfunction "}}}

" <Plug>(openbrowser-open)
function! openbrowser#_keymapping_open(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#open(s:get_url_on_cursor())
    else
        return openbrowser#open(s:get_selected_text())
    endif
endfunction "}}}

" <Plug>(openbrowser-search)
function! openbrowser#_keymapping_search(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#search(expand('<cword>'))
    else
        return openbrowser#search(s:get_selected_text())
    endif
endfunction "}}}

" <Plug>(openbrowser-smart-search)
function! openbrowser#_keymapping_smart_search(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#smart_search(s:get_url_on_cursor())
    else
        return openbrowser#smart_search(s:get_selected_text())
    endif
endfunction "}}}


function! s:seems_path(uri) "{{{
    " - Has no invalid filename character (seeing &isfname)
    " and, either
    " - file:// prefixed string and existed file path
    " - Existed file path
    if stridx(a:uri, 'file://') is 0
        let path = substitute(a:uri, '^file://', '', '')
    else
        let path = a:uri
    endif
    return getftype(path) !=# ''
endfunction "}}}

function! s:seems_uri(uri) "{{{
    let uri = urilib#new_from_uri_like_string(a:uri, s:NONE)
    return uri isnot s:NONE
    \   && uri.scheme() !=# ''
    \   && uri.host() =~# '\.'
endfunction "}}}

function! s:detect_query_type(query, callee) "{{{
    let seems = {
    \   'uri': s:seems_uri(a:query),
    \   'filepath': s:seems_path(a:query),
    \}

    if a:callee ==# s:Q_OPEN
        " filepath -> uri -> unknown
        return seems.filepath ? s:QT_FILEPATH :
        \      seems.uri      ? s:QT_URI :
        \      s:QT_UNKNOWN
    elseif a:callee ==# s:Q_SMART_SEARCH
        " uri -> filepath -> unknown
        return seems.uri      ? s:QT_URI :
        \      seems.filepath ? s:QT_FILEPATH :
        \      s:QT_UNKNOWN
    else
        " uri -> filepath -> unknown
        return seems.filepath ? s:QT_FILEPATH :
        \      seems.uri      ? s:QT_URI :
        \      s:QT_UNKNOWN
    endif
endfunction "}}}

function! s:convert_to_fullpath(path) "{{{
    let save_shellslash = &shellslash
    let &l:shellslash = 1
    try
        return fnamemodify(a:path, ':p')
    finally
        let &l:shellslash = save_shellslash
    endtry
endfunction "}}}

function! s:open_browser(uri) "{{{
    let uri = a:uri

    redraw
    echo "opening '" . uri . "' ..."

    for browser in s:get_var('openbrowser_open_commands')
        if !executable(browser)
            continue
        endif
        let open_rules = s:get_var('openbrowser_open_rules')
        if !has_key(open_rules, browser)
            continue
        endif

        " On Windows, URL encode may result in
        " unexpected expansion by environment variable.
        " https://www.google.co.jp/search?q=%89%cd%90%ec&ie=sjis
        " -> https://www.google.co.jp/search?q=%89C:\Vim90%ec&ie=sjis
        " cf. https://github.com/tyru/open-browser.vim/issues/14
        if g:__openbrowser_platform.mswin
            " Avoid crappy escaping hell.
            let $OPENBROWSER_URI = uri
        endif
        let cmdline = s:expand_keywords(
        \   open_rules[browser],
        \   {'browser': browser, 'uri': uri}
        \)
        call s:system(cmdline)

        " No need to check v:shell_error
        " because browser is spawned in background process
        " so can't check its return value.

        if g:__openbrowser_platform.mswin
            let $OPENBROWSER_URI = ''
        endif

        redraw
        echo "opening '" . uri . "' ... done! (" . browser . ")"
        return
    endfor

    echohl WarningMsg
    redraw
    echomsg "open-browser doesn't know how to open '" . uri . "'."
    echohl None
endfunction "}}}

" Get selected text in visual mode.
function! s:get_selected_text() "{{{
    let save_z = getreg('z', 1)
    let save_z_type = getregtype('z')

    try
        normal! gv"zy
        return @z
    finally
        call setreg('z', save_z, save_z_type)
    endtry
endfunction "}}}

function! s:get_url_on_cursor() "{{{
    let save_iskeyword = &iskeyword
    " Avoid rebuilding of `chartab`.
    " (declared in globals.h, rebuilt by did_set_string_option() in option.c)
    if &iskeyword !=# g:openbrowser_iskeyword
        let &iskeyword = g:openbrowser_iskeyword
    endif
    try
        return expand('<cword>')
    finally
        " Avoid rebuilding of `chartab`.
        if &iskeyword !=# save_iskeyword
            let &iskeyword = save_iskeyword
        endif
    endtry
endfunction "}}}

" This function is from quickrun.vim (http://github.com/thinca/vim-quickrun)
" Original function is `s:Runner.expand()`.
"
" NOTE: Original version recognize more keywords.
" This function is speciallized for open-browser.vim
" - @register @{register}
" - &option &{option}
" - $ENV_NAME ${ENV_NAME}
"
" Expand the keywords.
" - {expr}
"
" Escape by \ if you does not want to expand.
" - "\{keyword}" => "{keyword}", not expression `keyword`.
"   it does not expand vim variable `keyword`.
function! s:expand_keywords(str, options)  " {{{
    if type(a:str) != type('') || type(a:options) != type({})
        echoerr 's:expand_keywords(): invalid arguments. (a:str = '.string(a:str).', a:options = '.string(a:options).')'
        return ''
    endif
    let rest = a:str
    let result = ''

    " Assign these variables for eval().
    for [name, val] in items(a:options)
        " unlockvar l:
        " let l:[name] = val
        execute 'let' name '=' string(val)
    endfor

    while 1
        let f = match(rest, '\\\?[{]')

        " No more special characters. end parsing.
        if f < 0
            let result .= rest
            break
        endif

        " Skip ordinary string.
        if f != 0
            let result .= rest[: f - 1]
            let rest = rest[f :]
        endif

        " Process special string.
        if rest[0] == '\'
            let result .= rest[1]
            let rest = rest[2 :]
        elseif rest[0] == '{'
            let e = matchend(rest, '\\\@<!}')
            let expr = substitute(rest[1 : e - 2], '\\}', '}', 'g')
            let result .= eval(expr)
            let rest = rest[e :]
        else
            echohl WarningMsg
            echomsg 'parse error: rest = '.rest.', result = '.result
            echohl None
        endif
    endwhile
    return result
endfunction "}}}

function! s:get_var(varname) "{{{
    for ns in [b:, w:, t:, g:]
        if has_key(ns, a:varname)
            return ns[a:varname]
        endif
    endfor
    throw 'openbrowser: internal error: '
    \   . "s:get_var() couldn't find variable '".a:varname."'."
endfunction "}}}

if s:use_vimproc && globpath(&rtp, 'autoload/vimproc.vim') !=# ''
    function! s:system(...)
        return call('vimproc#system', a:000)
    endfunction
else
    function! s:system(...)
        return call('system', a:000)
    endfunction
endif

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
