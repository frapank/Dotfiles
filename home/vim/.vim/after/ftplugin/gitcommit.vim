vim9script

# typos underlined in amber; Italian too where its spell file is installed
setlocal spell spelllang=en
if !empty(globpath(&runtimepath, 'spell/it.utf-8.spl'))
    setlocal spelllang+=it
endif
