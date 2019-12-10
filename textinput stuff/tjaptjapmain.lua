
Signal = require 'vendor.signal'
Gamestate = require "vendor.gamestate"
Camera = require "vendor.camera"
inspect = require "vendor.inspect"

InterActiveMovieMode = require "modes.interactive_movie"
GameMode = require "modes.game"

StageMode = require "modes.stage"
DragMode = require "modes.drag_item"
DrawLineMode = require "modes.draw_line"
DrawPolyMode = require "modes.draw_poly"

ItemMode = require "modes.edit_item"
PolygonMode = require "modes.edit_polygon"
SmartLineMode = require "modes.edit_smartline"

Mesh3dMode = require "modes.edit_mesh3d"
RectMode = require "modes.edit_rect"

Hammer = require "hammer"
utils = require "utils"
local shapes = require "shapes"
poly = require 'poly'
utf8 = require 'utf8'
local pointers = require "pointer"
flux = require "vendor.flux"
local a = require "vendor.affine"

--------------------------------

SCREEN_WIDTH = 1024
SCREEN_HEIGHT = 768


function parentize(root)
   if root.children then
      for i=1, #root.children do
         root.children[i].parent = root
         parentize(root.children[i]);
      end
   end
end

function updateGraph(root, dt)

   if root.pivot then
      local T = a.trans(root.pos.x, root.pos.y)
      local P = a.trans(-root.pivot.x, -root.pivot.y)
      local R = a.rotate(root.rotation or 0)
      local S = a.scale(root.scale and root.scale.x or 1, root.scale and root.scale.y or 1)

      root.local_trans = T*R*S*P
   else
      local T = a.trans(root.pos.x, root.pos.y)
      local R = a.rotate(root.rotation or 0)
      local S = a.scale(root.scale and root.scale.x or 1, root.scale and root.scale.y or 1)

      root.local_trans = T*R*S
   end

   if not root.world_pos then
      root.world_pos = {{x=0,y=0,z=0,rot=0,scaleX=1,scaleY=1}}

   end

   if root.parent then
      if root.parent.type == "smartline" then
         -- Here we use the  last coord of the samrtline to calculate a custom local_trans
         local c = root.parent.data.coords
         local x,y = c[#c-1], c[#c]
         local T = a.trans(x+root.pos.x, y+root.pos.y)

         local P
         if root.pivot then
            P = a.trans(-root.pivot.x or 0, -root.pivot.y or 0)
         end

         local R = a.rotate(root.rotation or 0)
         local S = a.scale(root.scale and root.scale.x or 1, root.scale and root.scale.y or 1)

         root.local_trans = T*R*S
         if root.pivot then
            root.local_trans = root.local_trans * P
         end
      end


      root.world_trans = root.parent.world_trans * root.local_trans
      root.inverse = a.inverse(root.world_trans)
      root.world_pos.rot = (root.rotation or 0) + root.parent.world_pos.rot


      if root.scale then
         root.world_pos.scaleX = root.parent.world_pos.scaleX * root.scale.x
         root.world_pos.scaleY = root.parent.world_pos.scaleY * root.scale.y
      else
         root.world_pos.scaleX = root.parent.world_pos.scaleX
         root.world_pos.scaleY = root.parent.world_pos.scaleY
      end
   else
      root.world_trans = root.local_trans
      root.world_pos.rot = root.rotation or 0
      root.world_pos.scaleX = (root.scale and root.scale.x) or 1
      root.world_pos.scaleY = (root.scale and root.scale.y) or 1
   end


   --if root.dirty then
   if root.type and root.dirty then
      if root.dirty_types then
         if not root.animation then
            root.animation = {}
         end
         table.insert(root.animation, (root.dirty_types))
      else
      end


      local shape = shapes.makeShape({type=root.type, pos={x=0,y=0},data=root.data})

      if root.type == "smartline" then
      else
         shape = shapes.scaleShape(shape, root.world_pos.scaleX, root.world_pos.scaleY)
      end

      if root.rotation or root.world_pos.rot then
         shape = shapes.rotateShape(0, 0, shape, root.world_pos.rot)
      end

      local x,y = root.world_trans(0,0)
      shape = shapes.transformShape(x,y,shape,root)
      root.triangles = poly.triangulate(root.type, shape)




      if root.data.vertex_colors then
         while #root.triangles > #root.data.vertex_colors do
            table.insert(root.data.vertex_colors, { {255,255,0,255}, {0,0,255,255}, {255,100,100,100}})
         end
         while #root.triangles < #root.data.vertex_colors do
            table.remove(root.data.vertex_colors)
         end
      end

      if root.data.triangle_colors then
         while #root.triangles > #root.data.triangle_colors do
            if root.color then
               table.insert(root.data.triangle_colors, {root.color[1], root.color[2], root.color[3], root.color[4]})
            else
               table.insert(root.data.triangle_colors, {255,255,0,255})
            end
         end
         while #root.triangles < #root.data.triangle_colors do
            table.remove(root.data.triangle_colors)
         end

      end
      if root.data.vertex_colors then
         while #root.triangles > #root.data.vertex_colors do
            table.insert(root.data.vertex_colors, { {255,255,255,255} , {255,255,255,255}, {255,255,255,255} })
         end
          while #root.triangles < #root.data.vertex_colors do
            table.remove(root.data.vertex_colors)
         end

      end


      root.dirty = false

      if root.children then
         for i=1,#root.children do
            root.children[i].dirty = true
         end
      end
   end

   if root.children then
      for i=1, #root.children do
         updateGraph(root.children[i], dt)
      end
   end
end


function updateSceneGraph(init, root, dt)
   parentize(root)
   updateGraph(root, dt)
end


function initWorld(world)

   world.dirty = true
   if world.children then
      for i=1, #world.children do
         initWorld(world.children[i])
      end
   end
end

function string_split_on(str, splitter)
   local result = {}
   local index1 = 1

   for i=1, utf8.len(str) do
      if str:sub(i, i) == splitter then
         table.insert(result, str:sub(index1, i-1) )
         index1 = i+1
      end
   end

   table.insert(result, str:sub(index1, utf8.len(str)) )


   return result
end


function love.load()
   if arg[#arg] == "-debug" then require("mobdebug").start() end

   ---- profiler block
   profilerInitted = false
   ---- end profiler

   love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT, {resizable=true, vsync=true, fullscreen=false})

   helvetica = love.graphics.newFont("resources/helvetica_bold.ttf", 18)
   --helvetica = love.graphics.newFont("resources/sansmono.ttf", 14)

   love.graphics.setFont(helvetica)
   Hammer.pointers = pointers
   show_profile_screen = false


   world = {
      pos={x=0,y=0,z=0},
      id="world",
      children={

         {
            type = "polygon",
            id="slimthing",
            pos = {x=0, y=0, z=0},
            data = {
               points={{x=100,y=50}, {x=200,y=0}, {x=200, y=200}, {x=0, y=250}},
               triangle_colors={{200,200,100,255},{100,100,200,255}}
            },
         },
         {
            type = "polygon",
            id="slimthing",
            pos = {x=500, y=0, z=0},
            data = {
               steps=3,
               points={{x=100,y=50}, {x=200,y=0}, {x=200, y=200}, {x=0, y=250}},
               triangle_colors={{200,100,100,255},{100,100,200,255}}
            },
         },
         -- {type="circle", pos={x=500, y=100, z=0.4}, data={radius=200, steps=8}},
         -- {type="circle", pos={x=200, y=100, z=0.4}, data={radius=200, steps=8}},
         -- {type="circle", pos={x=100, y=100, z=0.7}, data={radius=200, steps=8}},
         -- {type="circle", pos={x=500, y=800, z=0.9}, data={radius=200, steps=8}},


      },
   }

   -- world = {
   --    children = { {
   --          data = {
   --             coords = {  },
   --             join = "miter",
   --             lengths = { 120, 120, 100, 50 },
   --             relative_rotations = { },
   --             thicknesses = { 40, 40, 30, 20, 20 },
   --             type = "world",
   --             use_relative_rotation = false,
   --             world_rotations = { 4.7123889803847, 0.10848259561446, -0.081958043518471, -0.26585057575965 }
   --          },
   --          id = "TheSmartLine3",
   --          pos = {
   --             x = -106,
   --             y = 182,
   --             z = 0
   --          },
   --          type = "smartline"
   --    } },
   --    id = "world",
   --    pos = {
   --       x = 0,
   --       y = 0,
   --       z = 0
   --    }
   -- }

   -- local child = world.children[1].data.world_rotations


   -- flux.to(child, 4, {[1] = 6.1512134849629,[2]= -2.048634444241901, [3]=-0.14204059054711,[4]= -0.348894473195010}):onupdate(
   --    function()
   --       world.children[1].data.world_rotations = child;
   --       local new_coords = utils.calculateCoordsFromRotationsAndLengths(false, world.children[1].data)
   --       world.children[1].data.coords = new_coords;
   --       world.children[1].dirty = true; end
   --                                       )

   initWorld(world)
   spent_time = 0

   updateSceneGraph(true, world, 0)
   camera = Camera(0, 0)
   clipboard = {}
   Gamestate.registerEvents()
   Gamestate.switch(StageMode)


   --Gamestate.switch(InteractiveMovieMode)

   Signal.register(
      'copy-to-clipboard',
      function(thing)
         local add =  inspect(serializeRecursive(thing), {indent=""})
         print(add)

         if #clipboard <= 5 then
            table.insert(clipboard, add)
         else
            table.remove(clipboard, 1)
            table.insert(clipboard, add)
         end
      end
   )

   Signal.register(
      'switch-state',
      function(state, data)
         local State = nil
         if state == "stage" then
            --State = InteractiveMovieMode
            State = StageMode
         elseif state == "drag-item" then
            State = DragMode
         elseif state == "draw-line" then
            State = DrawLineMode
         elseif state == "draw-poly" then
            State = DrawPolyMode

         elseif state == "edit-item" then
            State = ItemMode
         elseif state == "edit-polygon" then
            State = PolygonMode
         elseif state == "edit-mesh3d" then
            State = Mesh3dMode
         elseif state == "edit-rect" then
            State = RectMode
         elseif state == "edit-smartline" then
            State = SmartLineMode
         elseif state == "interactive-movie" then
            State = InterActiveMovieMode
         elseif state == "game" then
            State = GameMode
         end
         Gamestate.switch(State, data)
      end
   )

   --load_myfile("leg")
   --Signal.emit("switch-state", "interactive-movie", {})


end




function serializeRecursive(root)
   local blacklist = {"dirty", "tween", "local_trans", "world_trans", "world_pos", "parent", "inverse", "triangles", "children"}


   local result = {}


   for k,_ in pairs(root) do
      local isBlacklisted = false

      for bi=1, #blacklist do
         if blacklist[bi] == k then
            isBlacklisted = true
         end
      end
      if not isBlacklisted then
         result[k] = (_)
      end
   end

   if root.children then
      result.children = {}
      for i=1, #root.children do
         result.children[i] = serializeRecursive(root.children[i])
      end
   end

   return result
end

function love.keypressed(key)
   if key == "escape" then
      love.event.quit()
   end

   Hammer:handle_keypressed(key)
end


function love.filedropped(file)

   --local data = love.filesystem.newFileData(file)
   --local path_parts = string_split_on( file.getFilename(file), "\\")
   --print(inspect(path_parts))
   -- world = loadstring("return "..data:getString())()

   -- initWorld(world)
   -- updateSceneGraph(true, world, 0)
   -- camera = Camera(0, 0)

   --world = bitser.loadData(data:getPointer(), data:getSize())
end


function getFullGraphName(node, name)
   local str = (node.id or "").."/"
   str = str..name
   if node.parent then
      str = getFullGraphName(node.parent, str)
   end
   return str
end



function drawSceneGraph(root)
   local simple_format = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
      {"VertexColor"   , "byte",  4}      -- The r,g,b,a color of each vertex.
   }
   local triangle_count = 0

   if root.children then
      for i=1, #root.children do
         if root.children[i].belowParent then
            triangle_count = triangle_count + drawSceneGraph(root.children[i])
         end
      end
   end

   if root.triangles then

         local color = root.color
         for j=1, #root.triangles do
            if triangle_count % 3 == 0 then
               love.graphics.setColor(100/255, 175/255,55/255, 155)   --- hercules green monitor.
            elseif triangle_count % 3 == 1 then
               love.graphics.setColor(100/255, 175/255,55/255, 130)   --- hercules green monitor.
               --love.graphics.setColor(150, 155  ,55, 155) -- hercules amber
            elseif triangle_count % 3 == 2 then
               love.graphics.setColor(100/255, 175/255,55/255, 100)   --- hercules green monitor.
               --love.graphics.setColor(175, 75   ,75, 155) -- hercules pink
            end
            local use_color = {0,255,0,255}
            if color then
               love.graphics.setColor(color[1], color[2],color[3], color[4] or 255)
               if root.color_setting then
                  if root.color_setting == 'triple' then
                     use_color = {color[1], color[2],color[3], 255 - (triangle_count%3)*60}
                     --love.graphics.setColor(color[1], color[2],color[3], 255 - (triangle_count%3)*60)
                  end
               end
            end
            local tc = root.data.triangle_colors
            if tc then
               use_color = {tc[j][1], tc[j][2], tc[j][3], tc[j][4] or 255}
            end

            --print(inspect(root.children[i].data.triangle_colors ))
            love.graphics.setColor(255,255,255)
            --print(inspect(root.children[i].triangles[j]))


            local vertices = {};
            if root.data.vertex_colors then
               vertices = get_colored_vertices_for_vertex(root.triangles[j], root.data.vertex_colors[j])

            else
               vertices = get_colored_vertices_for_triangle(root.triangles[j], use_color)
            end


            --love.graphics.polygon("fill", root.children[i].triangles[j])
            local mesh = love.graphics.newMesh(simple_format, vertices, "strip")
            local parallax = {x= camera.x - ((root.pos.z+1) * camera.x),
                              y= camera.y - ((root.pos.z+1) * camera.y) }
            root.parallax = {x=-parallax.x, y=-parallax.y}
            --love.graphics.draw(mesh,  -parallax.x, -parallax.y)

            love.graphics.draw(mesh,  0, 0)

            triangle_count = triangle_count + 1
         end


   end

   if root.children then
      for i=1, #root.children do
         if not root.children[i].belowParent then
            triangle_count = triangle_count + drawSceneGraph(root.children[i])
         end
      end
   end


   return triangle_count
end



function get_colored_vertices_for_vertex(triangle, colors)
   -- colors = {color1, color2, color3}


   local result = {};
   for i=1, #triangle, 2 do
      local nested = {}
      local index = math.floor(i/2)+1

      table.insert(nested, triangle[i + 0])
      table.insert(nested, triangle[i + 1])
      table.insert(nested, colors[index][1])
      table.insert(nested, colors[index][2])
      table.insert(nested, colors[index][3])
      table.insert(nested, colors[index][4])

      table.insert(result, nested)
   end
   return result;
end


function get_adjusted_color(color, triangleindex, kind)
   return color

   -- TODO make a set of functions that change vertex colors

   -- print(triangleindex)
   -- return {
   --    color[1] - triangleindex * 20,
   --    color[2] ,
   --    color[3] ,
   --    color[4] - triangleindex * 20
   -- }

   -- return {
   --    color[1] ,
   --    color[2] - triangleindex * 20,
   --    color[3] ,
   --    color[4] - triangleindex * 20
   -- }

end


function get_colored_vertices_for_triangle(triangle, color)
   local result = {};

   --local colors = {{255,0,0},{0,255,0},{0,0,255}, {0,255,255}, {255,0,255},{255,255,0}}



   for i=1, #triangle, 2 do
      local colora = get_adjusted_color(color, i)

      local nested = {}
      table.insert(nested, triangle[i + 0])
      table.insert(nested, triangle[i + 1])
      table.insert(nested, colora[1])
      table.insert(nested, math.max(colora[2] - 5*i, 0)) -- - (i*20))
      table.insert(nested, colora[3])
      table.insert(nested, math.max(colora[4] -7*i,0)) -- - (i*30))

      table.insert(result, nested)
   end
   return result;
end


function love.update(dt)
   --- profiler code
   if show_profile_screen then
      if profilerInitted == false then
         love.profiler = require('vendor.profile')
         love.profiler.hookall("Lua")
         love.profiler.start()
         love.frame = 0
         profilerInitted = true
      end

      love.frame = love.frame + 1
      if love.frame%100 == 0 then
         love.report = love.profiler.report('time', 20)
         love.profiler.reset()
      end
   end
   -- end profiler

   flux.update(dt)
   spent_time = spent_time + dt
   updateSceneGraph(false, world, dt)
end


function love.draw()


   camera:attach()

   local triangle_count = drawSceneGraph(world)
   camera:detach()

   love.graphics.setColor(255,255,255)
   love.graphics.print("camera " .. math.floor(camera.x) .. ", " .. math.floor(camera.y) .. "," .. tonumber(string.format("%.3f", camera.scale)).." pointers : ["..(#pointers.moved)..","..(#pointers.pressed)..","..(#pointers.released).."]")
   love.graphics.print("#tris "..triangle_count,  SCREEN_WIDTH - 100, 10)
   Hammer:draw()

   if show_profile_screen then
      love.graphics.setColor(255,255,155)
      love.graphics.print(love.report or "Please wait...", 150, 150)
   end


   -- for i=1, #palette do
   --    love.graphics.setColor(palette[i][1], palette[i][2], palette[i][3])
   --    love.graphics.rectangle("fill", i*50, 50, 50,50)
   -- end

end


function love.textedited(text, start, length)
    Hammer:handle_textedited(text, start, length)
end

function love.textinput(t)
	Hammer:handle_textinput(t)
end


function setPivot(me)
   local pressed  = Hammer.pointers.pressed[1]
   local wxr, wyr = camera:worldCoords(pressed.x, pressed.y)
   local tx,ty    = me.child.world_trans(0,0)
   local diffx    = (wxr - tx)/me.child.world_pos.scaleX
   local diffy    = (wyr - ty)/me.child.world_pos.scaleY
   local t2x, t2y = utils.rotatePoint(diffx, diffy, 0, 0, -me.child.world_pos.rot)

   if not me.child.pivot then
      me.child.pivot = {x=0,y=0}
   end

   local pivotdx = t2x - (me.child.pivot.x)
   local pivotdy = t2y - (me.child.pivot.y)

   pivotdx,pivotdy = utils.rotatePoint(pivotdx, pivotdy, 0, 0, me.child.world_pos.rot)
   me.child.pos.x  = me.child.pos.x + pivotdx
   me.child.pos.y  = me.child.pos.y + pivotdy

   me.child.pivot.x = t2x
   me.child.pivot.y = t2y
   me.setPivot = false
end

function makePivotBehaviour(pivot, child)
   if pivot.dragging then
      local p = getWithID(Hammer.pointers.moved, pivot.pointerID)
      local moved = Hammer.pointers.moved[p]

      if moved then
         local wx,wy = camera:worldCoords(moved.x-pivot.dx, moved.y-pivot.dy)
         wx,wy = child.inverse(wx,wy)
         if not child.pivot then
            child.pivot = {x=0,y=0}
         end

         local dx = wx - child.pivot.x
         local dy = wy - child.pivot.y

         child.pivot.x = wx
         child.pivot.y = wy

         local sx = child.scale and child.scale.x or 1
         local sy = child.scale and child.scale.y or 1
         local t2x, t2y = utils.rotatePoint(dx*sx, dy*sy, 0, 0, child.rotation)

         child.pos.x = child.pos.x + t2x
         child.pos.y = child.pos.y + t2y

         child.dirty = true
      end
   end
end
