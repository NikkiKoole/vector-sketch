require 'ui'
polyline = require 'polyline'

function love.keypressed(key)
   if key == "escape" then
      love.event.quit()
   end
end

function love.mousepressed(x,y, button)
   if editingMode == 'nil' then
      editingMode = 'move'
   end
   if editingMode == 'polyline'  and not mouseState.hoveredSomething  then
      table.insert(points, {x=(x / camera.scale) - camera.x,
			    y=(y / camera.scale) - camera.y})
   end
   
end
function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = 'nil'
   end
end
function love.mousemoved(x,y,dx, dy)
   if editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      camera.x = camera.x + dx / camera.scale
      camera.y = camera.y + dy / camera.scale
   end
end


function love.wheelmoved(x,y)
   local posx, posy = love.mouse.getPosition()
   
   local wx = camera.x + ( posx / camera.scale)
   local wy = camera.y + ( posy / camera.scale)
   
   camera.scale =  camera.scale * ((y>0) and 1.1 or 0.9)

   local wx2 = camera.x + ( posx / camera.scale)
   local wy2 = camera.y + ( posy / camera.scale)
   
   camera.x = camera.x - (wx-wx2)
   camera.y = camera.y - (wy-wy2)
end

function love.load()
   love.window.setMode(1024+300, 768, {resizable=true, vsync=false, minwidth=400, minheight=300})
   points = {}
   image = love.graphics.newImage("test.png")
   quad = love.graphics.newQuad(0, 0, image:getWidth(), image:getHeight(), image:getWidth(), image:getHeight())
   camera = {x=0, y=0, scale=1}
   editingMode = 'nil'
   grid = {cellsize=100} -- cellsize is in px
   medium = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Medium.ttf", 32)
   light = love.graphics.newFont( "resources/fonts/MPLUSRounded1c-Light.ttf", 32)

   love.graphics.setFont(medium)
   
   ui = {
      polyline = love.graphics.newImage("resources/ui/polyline.png"),
      polyline_add = love.graphics.newImage("resources/ui/polyline-add.png"),
      polyline_edit = love.graphics.newImage("resources/ui/polyline-edit.png"),
      polyline_remove = love.graphics.newImage("resources/ui/polyline-remove.png"),
      backdrop = love.graphics.newImage("resources/ui/backdrop.png"),
      grid = love.graphics.newImage("resources/ui/grid.png"),
      palette = love.graphics.newImage("resources/ui/palette.png"),
      pen = love.graphics.newImage("resources/ui/pen.png"),
      pencil = love.graphics.newImage("resources/ui/pencil.png"),
      polygon = love.graphics.newImage("resources/ui/polygon.png"),
      add = love.graphics.newImage("resources/ui/add.png"),
      remove = love.graphics.newImage("resources/ui/remove.png"),
      delete = love.graphics.newImage("resources/ui/delete.png"),
      move = love.graphics.newImage("resources/ui/move.png"),
      visible = love.graphics.newImage("resources/ui/visible.png"),
      not_visible = love.graphics.newImage("resources/ui/not-visible.png"),
      resize = love.graphics.newImage("resources/ui/resize.png"),
      opacity = love.graphics.newImage("resources/ui/opacity.png"),
      settings = love.graphics.newImage("resources/ui/settings.png"),
      badge = love.graphics.newImage("resources/ui/badge.png"),
      layer_group = love.graphics.newImage("resources/ui/layer-group.png"),
      object_group = love.graphics.newImage("resources/ui/object-group.png"),
      rotate = love.graphics.newImage("resources/ui/rotate.png"),
      transform = love.graphics.newImage("resources/ui/transform.png"),
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   } 
   
   palette = {
      name='miffy',
      colors={
	 {name="green", rgb={48,112,47}},
	 {name="blue", rgb={27,84,154}},
	 {name="yellow", rgb={250,199,0}},
	 {name="orange1", rgb={233,100,14}},
	 {name="orange2", rgb={237,76,6}},
	 {name="orange3", rgb={221,61,14}},
	 {name="black1", rgb={34,30,30}},
	 {name="black2", rgb={24,26,23}},
	 {name="black2", rgb={24,26,23}},
	 {name="brown1", rgb={145,77,35}},
	 {name="brown2", rgb={114,65,11}},
	 {name="brown3", rgb={136,95,62}},
	 {name="grey1", rgb={147,142,114}},
	 {name="grey2", rgb={149,164,151}},
      }
   }

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false
   }

   mesh = love.graphics.newMesh(1000)
end

function drawGrid()
   local w, h = love.graphics.getDimensions( )
   local size = grid.cellsize * camera.scale
   if (size < 10) then return end 
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (camera.x*camera.scale) % size
   local yOffset = (camera.y*camera.scale) % size

   for x =0, vlines do
      love.graphics.line(xOffset + x*size, 0,xOffset +  x*size, h)
   end
   for y =0, hlines do
      love.graphics.line( 0, yOffset + y*size, w, yOffset +  y*size)
   end
end

function drawPalette(palette, x, y)
   local w = #(palette.colors) * 64
   local h = 64
   love.graphics.setColor(1,1,1,1)
   local strw = medium:getWidth(palette.name)
   love.graphics.print(palette.name, x, y)
   love.graphics.rectangle("fill", x+strw,y, w,h )
   for i = 1, #(palette.colors) do
      local rgb = palette.colors[i].rgb
      love.graphics.setColor(rgb[1]/255,rgb[2]/255,rgb[3]/255)
      love.graphics.rectangle("fill", x+strw+(i-1)*64, y , 64, 64)
   end
end


function handleMouseClickStart()
   mouseState.hoveredSomething = false
   mouseState.down = love.mouse.isDown(1 )
   mouseState.click = false

   if mouseState.down ~= mouseState.lastDown then
      if mouseState.down  then
         mouseState.click  = true
      end
   end
    mouseState.lastDown =  mouseState.down

end


function love.draw()
   handleMouseClickStart()
   love.mouse.setCursor(cursors.arrow)
   local w, h = love.graphics.getDimensions( )
   love.graphics.clear(34/255, 30/255, 30/255)
   

   love.graphics.push()
   love.graphics.scale(camera.scale, camera.scale  )
   love.graphics.translate( camera.x, camera.y )
  
   love.graphics.setColor(1,1,1, 0.5)
   love.graphics.draw(image, quad, 0, 0)


   if (#points >= 3 ) then
      local scale = 1
      local coords = {}
      for i=1, #points do
	 table.insert(coords, points[i].x)
	 table.insert(coords, points[i].y)
      end
      love.graphics.setLineStyle('rough')
      love.graphics.setLineJoin('miter')
      love.graphics.setLineWidth(3)
      local vertices, indices, draw_mode = polyline(
	 love.graphics.getLineJoin(),
	 coords, love.graphics.getLineWidth() / 2,
	 1/scale,
	 love.graphics.getLineStyle() == 'smooth')
      mesh:setVertices(vertices)
      mesh:setDrawMode(draw_mode)
      mesh:setVertexMap(indices)
      if indices then
	 mesh:setDrawRange(1, #indices)
      else
	 mesh:setDrawRange(1, #vertices)
      end
      love.graphics.draw(mesh)
   end
   

   
   love.graphics.setColor(1,1,1,1)

   
   love.graphics.setLineWidth(2.0  / camera.scale )
   local p_size = 10
   local p_h  = p_size/2
   for i=1, #points do
      love.graphics.rectangle("line",
			      points[i].x - p_h/camera.scale,
			      points[i].y - p_h/camera.scale,
			      p_size / camera.scale,
			      p_size / camera.scale)
   end
   love.graphics.setLineWidth(1)
   
   love.graphics.pop()
   
   love.graphics.setColor(1,1,1, 0.1)
   drawGrid()
   love.graphics.push()
   local s = 0.5
   local buttons = {
      'move', 'polyline', 'polygon', 'pen', 'pencil', 'palette'
   }
   for i = 1, #buttons do
      if imgbutton(buttons[i], ui[buttons[i]], 16, 64*i*s, s).clicked then
	 editingMode = buttons[i]
      end
   end

   love.graphics.pop()

end


function old()
       
   love.graphics.draw(ui.polyline, 0, 0)
   love.graphics.draw(ui.polyline_edit, 64*1, 0)
   love.graphics.draw(ui.polyline_add, 64*2, 0)
   love.graphics.draw(ui.polyline_remove, 64*3, 0)
   love.graphics.draw(ui.backdrop, 0, 64*1)
   love.graphics.draw(ui.grid, 0, 64*2)
   love.graphics.draw(ui.palette, 0, 64*3)
   love.graphics.draw(ui.pen, 0, 64*4)
   love.graphics.draw(ui.polygon, 0, 64*5)
   love.graphics.draw(ui.add, 0, 64*6)
   love.graphics.draw(ui.remove, 64, 64*6)
   love.graphics.draw(ui.delete, 64*2, 64*6)
   love.graphics.setColor(1,1,1, 1)
   love.graphics.draw(ui.move, 0, 64*7)
   love.graphics.setColor(1,1,1, .1)
   love.graphics.draw(ui.resize, 0, 64*8)

   love.graphics.draw(ui.visible, 0, 64*9)
   love.graphics.draw(ui.not_visible, 64, 64*9)

   love.graphics.draw(ui.opacity, 0, 64*10)
   love.graphics.draw(ui.settings, 0, 64*11)
   love.graphics.draw(ui.badge, 0, 64*12)

   love.graphics.draw(ui.layer_group, 0, 64*13)
   love.graphics.draw(ui.object_group, 0, 64*14)
   love.graphics.draw(ui.rotate, 0, 64*15)
   love.graphics.draw(ui.transform, 64, 64*15)


   love.graphics.setColor(1,1,1, 1)
   love.graphics.setColor(250/255, 199/255, 0/255)
   --love.graphics.setColor(149/255, 164/255, 151/255, 0.5)
   --love.graphics.rectangle("fill", 0, 0, 64, h )
   --love.graphics.rectangle("fill", 64, 0, w-64, 20 )
   --love.graphics.rectangle("fill", w-100, 0, 100, h )
   love.graphics.print("Test 123 miffy nijntje Sesamstraat")
   --love.graphics.print("█░▒▓□▪▫▭▮△▽◊○◯★", 100, 200)
   --love.graphics.print("≒≓≔≕≖≗≙≚≜≟≠≡≢≤≥≦≨≩≪≫≬≭≮≯≰≱≲≳≴≵≶≷≸≹≺≻≼≽≾≿⊀⊁⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋⊍⊎⊏⊐⊑⊒⊓⊔⊕⊖⊗⊘", 100, 200)
    --love.graphics.print("⊕⊖⊗⊘⊙⊚⊛⊝⊞⊟⊠⊡⊢⊣⊤⊥⊧⊨⊩⊪⊫⊬⊭⊮⊯⊰⊲⊳⊴⊵⊶⊷⊸⊹⊺⊻⊽⊾⊿⋀⋁⋂⋃⋄⋅⋆⋇⋈⋉⋊⋋⋌⋍⋎⋏⋐⋑⋒⋓⋔⋕⋖⋗⋘⋙", 100, 200)
     --love.graphics.print("⎱⎴⎵⎶⏜⏝⏞⏟⏢⏧␣Ⓢ─│┌┐└┘├┤┬┴┼═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬▀▄", 100, 200)
    --print("█░▒▓□▪▫▭▮▱△▴▵▸▹▽▾▿◂◃◊○◬◯◸◹◺◻◼★")
   --print"≒≓≔≕≖≗≙≚≜≟≠≡≢≤≥≦≨≩≪≫≬≭≮≯≰≱≲≳≴≵≶≷≸≹≺≻≼≽≾≿⊀⊁⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋⊍⊎⊏⊐⊑⊒⊓⊔⊕⊖⊗⊘"
   --print"⊙⊚⊛⊝⊞⊟⊠⊡⊢⊣⊤⊥⊧⊨⊩⊪⊫⊬⊭⊮⊯⊰⊲⊳⊴⊵⊶⊷⊸⊹⊺⊻⊽⊾⊿⋀⋁⋂⋃⋄⋅⋆⋇⋈⋉⋊⋋⋌⋍⋎⋏⋐⋑⋒⋓⋔⋕⋖⋗⋘⋙"
   --print"⋚⋛⋞⋟⋠⋡⋢⋣⋦⋧⋨⋩⋪⋫⋬⋭⋮⋯⋰⋱⋲⋳⋴⋵⋶⋷⋹⋺⋻⋼⋽⋾⌅⌆⌈⌉⌊⌋⌌⌍⌎⌏⌐⌒⌓⌕⌖⌜⌝⌞⌟⌢⌣⌭⌮⌶⌽⌿⍼⎰"
   --print"⎱⎴⎵⎶⏜⏝⏞⏟⏢⏧␣Ⓢ─│┌┐└┘├┤┬┴┼═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬▀▄"

end
