function love.conf(t)

   t.window.width = 1024
   t.window.height = 768
   --t.window.width = 2388
   --t.window.height= 1668

   t.window.title = "Strolling world"
   t.window.icon = "icon.png"

   t.window.resizable = true
   t.window.msaa = 4
   t.window.highdpi = true
   t.window.vsync = 0
   t.window.borderless = true -- setting this will hide the status bar
end