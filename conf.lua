-- alt + L on keyboard to run
function love.conf(t)
   t.title = "Test Project"
   t.version = "11.5"
   t.console = true -- attach a console, boolean, windows only
   t.window.width = 1280
   t.window.height = 768
   t.window.resizable = true -- Allow the user to resize the window  
end