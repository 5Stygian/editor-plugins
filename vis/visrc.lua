-- ~/.config/vis/visrc.lua
require('vis')

package.path = os.getenv("HOME") .. "/.config/vis/?.lua;" .. package.path

-- Automatically apply the c3 lexer when opening a .c3 file
vis.events.subscribe(vis.events.WIN_OPEN, function(win)
    if win.file and win.file.path and win.file.path:match('%.c3$') then
        win:set_syntax('c3')
    end
end)