function love.conf(t)

   t.window.width = 1024
   t.window.height = 768
   --t.window.width = 2388
   --t.window.height= 1668
   t.window.icon = "assets/icon.png"
   t.window.title = "handdrawn"


   t.window.resizable = true
   t.window.msaa = 0
   t.window.highdpi = true
   t.window.vsync = false
   t.window.borderless = true -- setting this will hide the status bar
end
