inspect = require 'vendor.inspect'
require 'ui'
require 'palettes'
require 'editor-utils'
require 'main-utils'
polyline = require 'polyline'
poly = require 'poly'
utf8 = require("utf8")
ProFi = require 'vendor.ProFi'
json = require 'vendor.json'
easing = require 'vendor.easing'


-- investigate
-- https://github.com/TannerRogalsky/lua-poly2tri

-- posennette
-- 0	nose
-- 1	leftEye
-- 2	rightEye
-- 3	leftEar
-- 4	rightEar
-- 5	leftShoulder
-- 6	rightShoulder
-- 7	leftElbow
-- 8	rightElbow
-- 9	leftWrist
-- 10	rightWrist
-- 11	leftHip
-- 12	rightHip
-- 13	leftKnee
-- 14	rightKnee
-- 15	leftAnkle
-- 16	rightAnkle

function makeMeshFromVertices(vertices, originalPoints)
   if (vertices and vertices[1] and vertices[1][1]) then
      -- vertices should be more rounded
      local moreRounded = {}
      for i=1 ,#vertices do
         moreRounded[i] = {
            round2(vertices[i][1], 3),
            round2(vertices[i][2], 3)
         }
      end
      
      --print(inspect(moreRounded))
      --print(inspect(originalPoints))
      local mesh = love.graphics.newMesh(simple_format, vertices, "triangles")
      return mesh
   end
   return nil
end
function meshAll(root) -- this needs to be done recursive
   for i=1, #root.children do
      if (not root.children[i].folder) then
         --print('color: '..inspect(root.children[i].color))
         root.children[i].mesh = makeMeshFromVertices(poly.makeVertices(root.children[i]), root.children[i].points)
      else
         meshAll(root.children[i])
      end
   end
end

function getLocalDelta(transform, dx, dy)
   local dx1, dy1 = transform:inverseTransformPoint( 0, 0 )
   local dx2, dy2 = transform:inverseTransformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end

function getGlobalDelta(transform, dx, dy)
   -- this one is only used in the wheel moved offset stuff
   local dx1, dy1 = transform:transformPoint( 0, 0 )
   local dx2, dy2 = transform:transformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end

function setCurrentNode(newNode)
   if currentNode and not currentNode.folder then
      currentNode.mesh = makeMeshFromVertices(poly.makeVertices(currentNode), currentNode.points)
   end
   currentNode = newNode
end

function resizeGroup(children, scale)

   for i=1, #children do
      if children[i].points then
         local scaledPoints = {}
         for p=1, #children[i].points do

            scaledPoints[p] = {children[i].points[p][1] * scale, children[i].points[p][2] * scale}
         end
         children[i].points = scaledPoints
         children[i].mesh= makeMeshFromVertices(poly.makeVertices(children[i]))
      end
   end

end
function flipGroup(children, xaxis, yaxis)
   for i=1, #children do
      if children[i].points then
         local scaledPoints = {}
         for p=1, #children[i].points do
            scaledPoints[p] = {children[i].points[p][1] * (xaxis ), children[i].points[p][2] * (yaxis )}
         end
         children[i].points = scaledPoints
         children[i].mesh= makeMeshFromVertices(poly.makeVertices(children[i]))
      end
   end
end

function deleteNode(node)
   local index = getIndex(node)
   local taken_out = removeCurrentNode()
   if (index > 1) then
      setCurrentNode(node._parent.children[index -1])
   elseif (index == 1 and #(node._parent.children) > 0 ) then
      setCurrentNode(node._parent.children[index])
   else
      setCurrentNode(nil)
   end
end


function getIndex(item)
   if (item) then
      for k,v in ipairs(item._parent.children) do
         if v == item then return k end
      end
   end
   return -1
end

function removeGroupOfThings(group)
   local root =  currentNode or root
   for i = 1, #group do
      table.remove(root.children, getIndex(group[i]))
   end


end
function addGroupAtEnd(group, parent)
   for i = 1, #group do
      local thing = group[i]
      thing._parent = parent
      table.insert(parent.children, #parent.children + 1, thing)
   end

end


function addThingAtEnd(thing, parent)
   thing._parent = parent
   table.insert(parent.children, #parent.children + 1, thing)
end

function addShapeAtRoot(shape)
   table.insert(root.children, #root.children + 1, shape)
end

function addShapeAfter(shape, after)
   local index = getIndex(after)
   if (index > 0) then
      table.insert(after._parent.children, index+1, shape)
   end
end

function removeCurrentNode()
   if (currentNode) then
      return table.remove(currentNode._parent.children, getIndex(currentNode))
   end
end

function removeShapeAtPath(path)
   return table.remove(root.children, path[1])
end


function getPointsBBox(points)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999
   for ip=1, #points do
      if points[ip][1] < tlx then tlx = points[ip][1] end
      if points[ip][1] > brx then brx = points[ip][1] end
      if points[ip][2] < tly then tly = points[ip][2] end
      if points[ip][2] > bry then bry = points[ip][2] end
   end
   return tlx, tly, brx, bry
end

function getDirectChildrenBBox(node)
   local tlx = 9999999999
   local tly = 9999999999
   local brx = -9999999999
   local bry = -9999999999

   for i=1, #node.children do
      local points = node.children[i].points
      if points then
         for ip=1, #points do
            if points[ip][1] < tlx then tlx = points[ip][1] end
            if points[ip][1] > brx then brx = points[ip][1] end
            if points[ip][2] < tly then tly = points[ip][2] end
            if points[ip][2] > bry then bry = points[ip][2] end
         end
      end
   end

   if ( tlx == 9999999999 and tly == 9999999999 and brx == -9999999999 and bry == -9999999999) then
      print('no direct children you pancake!')
      return 0,0,0,0
   else
      return tlx, tly, brx, bry
   end

end
function movePoints(node, dx, dy)
   for i = 1, #childrenInRectangleSelect do
      local index = childrenInRectangleSelect[i]
      node.points[index] = {node.points[index][1] + dx, node.points[index][2] + dy}

   end
   node.mesh = makeMeshFromVertices(poly.makeVertices(node))
end

local function arrayHas(tab, val)
   for index, value in ipairs(tab) do
      if value == val then
         return true
      end
   end

   return false
end

function deletePoints(node)
   local newPoints = {}
   for i = 1, #node.points do
      if not arrayHas(childrenInRectangleSelect, i) then
         table.insert(newPoints, {node.points[i][1], node.points[i][2]})
      end

      -- if i isnt in childreninrectangelselct the n add
   end
   node.points = newPoints
   node.mesh = makeMeshFromVertices(poly.makeVertices(node))

end


function isPartOfKeyframePose(node)
   if (node.keyframes) then return true end
   if (node._parent == root) then return false end
   if (node._parent) then
      return isPartOfKeyframePose(node._parent)
   end
end

function countNestedChildren(node, total)
   for i=1, #node.children do
      if (node.children[i].children) then
         local r = countNestedChildren(node.children[i], 0)
         total = total + r
      end
      total = total+1
   end
   return total
end
function nodeIsMyOwnOffspring(me, node)
   if (me == node) then return true end
   if (node._parent == me) then
      return true
   end
   if (node._parent.name == 'root') then
      return false
   end
   return nodeIsMyOwnOffspring(me, node._parent)
end


function love.mousepressed(x,y, button)
   lastDraggedElement = nil
   if editingMode == nil then
      editingMode = 'move'
   end

   if editingMode == 'rectangle-select' or editingModeSub == 'rectangle-point-select'  then
      rectangleSelect.startP = {x=x, y=y}
   end

   local points = currentNode and currentNode.points
   if not points then return end

   local t = currentNode._parent._globalTransform
   local px, py = t:inverseTransformPoint( x, y )
   local scale = root.transforms.l[4]
   if editingMode == 'polyline' and not mouseState.hoveredSomething   then
      local w, h = getLocalDelta(t, 10, 10)
      w = math.max(math.abs(w), math.abs(h))

      local index =  0
      for i = 1, #points do
         if pointInRect(px,py,
                        points[i][1] - w/2, points[i][2] - w/2,
                        w, w) then
            index = i
         end
      end

      if (index > 0) then
         if (editingModeSub == 'polyline-remove') then
            table.remove(points, index)
         end
         if (editingModeSub == 'polyline-edit') then
            lastDraggedElement = {id='polyline', index=index}
         end
      end

      if (editingModeSub == 'polyline-insert') then
         local closestEdgeIndex = getClosestEdgeIndex(px, py, points)
         table.insert(points, closestEdgeIndex+1, {px, py})
      end
   end
end


function love.mousereleased(x,y, button)
   if editingMode == 'move' then
      editingMode = nil
   end
   if editingModeSub == 'rectangle-point-select' then
      if  (rectangleSelect.startP and rectangleSelect.endP) then
         childrenInRect = {}
         local parent = currentNode._parent or root
         local t = not  currentNode._parent and  parent._localTransform or parent._globalTransform
         local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
         local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
         local tl = {x=math.min(sx, ex), y=math.min(sy, ey)}
         local br = {x=math.max(sx, ex), y=math.max(sy, ey)}
         local childrenInRect = {}
         for i=1, #currentNode.points do
            local p = currentNode.points[i]
            if p[1] >= tl.x and p[1] <= br.x  and  p[2] >= tl.y and p[2] <= br.y then
               table.insert(childrenInRect, i)
            end
         end
         childrenInRectangleSelect = childrenInRect
         rectangleSelect = {}
      end
   end

   if (editingMode == 'rectangle-select') then
      if (rectangleSelect.startP and rectangleSelect.endP) then
         local root = currentNode or root

         local t = not currentNode and  root._localTransform or root._globalTransform
         local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
         local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
         local tl = {x=math.min(sx, ex), y=math.min(sy, ey)}
         local br = {x=math.max(sx, ex), y=math.max(sy, ey)}
         local childrenInRect = {}
         for i=1, #root.children do
            local child = root.children[i]
            if (child.points) then
               local failed = false
               for pi = 1, #child.points do
                  local p = child.points[pi]
                  if p[1] < tl.x or p[1] > br.x then failed = true end
                  if p[2] < tl.y or p[2] > br.y then failed = true end
               end

               if not failed then
                  table.insert(childrenInRect, child)
               end
            end
         end
         if #childrenInRect > 0 then
            childrenInRectangleSelect = childrenInRect
         else
            childrenInRectangleSelect = {}
         end
         editingMode = nil
      end

      rectangleSelect = {}
   end

   if lastDraggedElement and lastDraggedElement.id == 'connector' then
      if (currentNode and currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
         if not (nodeIsMyOwnOffspring(currentNode, currentlyHoveredUINode)) then
            addThingAtEnd( removeCurrentNode(), currentlyHoveredUINode)
         end
      else
         addThingAtEnd(removeCurrentNode(), root)
      end
   end
   if lastDraggedElement and lastDraggedElement.id == 'connector-group' then
      if (currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
         removeGroupOfThings(childrenInRectangleSelect)
         addGroupAtEnd(childrenInRectangleSelect, currentlyHoveredUINode)
         childrenInRectangleSelect = {}
      end
   end
   lastDraggedElement = nil
end

function love.mousemoved(x,y, dx, dy)
   currentlyHoveredUINode = nil
   local snap = false
   if  love.keyboard.isDown( 'r' ) then
      snap = true
   end

   if currentNode == nil and lastDraggedElement == nil and editingMode == 'move' and love.mouse.isDown(1) or love.keyboard.isDown('space') then
      root.transforms.l[1] = root.transforms.l[1] + dx
      root.transforms.l[2] = root.transforms.l[2] + dy

   end
   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / root.transforms.l[4]
      backdrop.y = backdrop.y + dy / root.transforms.l[4]
   end

   local isConnecting = lastDraggedElement and lastDraggedElement.id == 'connector'

   if editingMode == 'rectangle-select' and rectangleSelect.startP then
      rectangleSelect.endP = {x=x, y=y}
   end
   if editingModeSub == 'rectangle-point-select' and rectangleSelect.startP then
      rectangleSelect.endP = {x=x, y=y}
   end

   if (editingMode == 'folder' and editingModeSub ==  'folder-move' and mouseState.hoveredSomething == false and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
         local ddx, ddy = getLocalDelta(currentNode._parent._globalTransform, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
         currentNode.transforms.l[1]= currentNode.transforms.l[1] + ddx
         currentNode.transforms.l[2]= currentNode.transforms.l[2] + ddy
      end
   end
   if (editingMode == 'folder' and editingModeSub ==  'folder-pan-pivot' and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
         local ddx, ddy = getLocalDelta(currentNode._globalTransform, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
         currentNode.transforms.l[6]= currentNode.transforms.l[6] - ddx
         currentNode.transforms.l[7]= currentNode.transforms.l[7] - ddy
      end
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1)  then
      local points = currentNode and currentNode.points
      local dx3, dy3 = getLocalDelta(currentNode._parent._globalTransform, dx, dy)
      if snap then
         dx3 = round2(dx3, 0)
         dy3 = round2(dy3, 0)
      end

      if (points) then
         local beginIndex = 2 -- if first and last arent identical
         if not (points[1] == points[#points]) then
            beginIndex = 1
         end
         for i = beginIndex, #points do
            local p = points[i]
            p[1] = p[1] + dx3
            p[2] = p[2] + dy3
         end
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
         local dragIndex = lastDraggedElement.index
         if dragIndex > 0 then
            local points = currentNode and currentNode.points
            local t = currentNode._parent._globalTransform
            local globalX, globalY = t:inverseTransformPoint( x, y )

            if (dragIndex <= #points) then
               if  snap then
                  points[dragIndex][1] = round2(globalX,0)
                  points[dragIndex][2] = round2(globalY,0)
               else
                  points[dragIndex][1] = globalX
                  points[dragIndex][2] = globalY
               end
            end
         end
      end
   end
end

function calcY(i)
   return (16 + (24 + 8 + 4) * i)
end
function calcX(i)
   return ((24 + 8 + 4) * i)
end

function renderGraphNodes(node, level, startY)
   local w, h = love.graphics.getDimensions( )
   local beginRightX = w - 280 + level*6
   local rightX = beginRightX
   local nested = 0

   local runningY = 0

   local rowHeight = 27

   for i=1, #node.children do
      
      local yPos = -scrollviewOffset + startY  + runningY
      local child = node.children[i]
      local icon = ui.object_group

      if (child.folder ) then
         icon = child.open and ui.folder_open or ui.folder
      end
      local color = child.color

      if child.mask then
         icon = ui.mask
         color = {0,0,0}
      end
      if child.hole then
         icon = ui.hole
         color = {0,0,0}
      end


      local b = {}
      if (yPos >=0 and yPos <= h) then
         b = iconlabelbutton('object-group', icon, color, child == currentNode, child.name or "", rightX , yPos, 200-(level*6))
      end
      if (child.folder and child.open ) then
         local add = renderGraphNodes(child, level + 1, runningY + startY + rowHeight)
         runningY = runningY + add
      end

      if b.clicked then
         if currentNode == child then
            setCurrentNode(nil)
            editingMode = nil
            editingModeSub = nil
            if (child.folder) then
               child.open = false
            end
         else
            if (child._parent.keyframes) then
               child._parent.frame = getIndex(child)
            end

            setCurrentNode(child)
            if (child.folder) then
               child.open = true
               editingMode = 'folder'
               editingModeSub = 'folder-move'
            else
               editingMode = 'polyline'
               editingModeSub = 'polyline-edit'
            end
         end
      end

      if b.hover then
         currentlyHoveredUINode = node.children[i]
      end
      runningY = runningY + rowHeight
   end
   return runningY
end

function love.wheelmoved(x,y)
   local scale = root.transforms.l[4]

   local posx, posy = love.mouse.getPosition()
   local ix1, iy1 = root._globalTransform:inverseTransformPoint(posx, posy)

   root.transforms.l[4] = scale *  ((y>0) and 1.1 or 0.9)
   root.transforms.l[5] = scale *  ((y>0) and 1.1 or 0.9)

   --- ugh
   --local tg = root.transforms.g
   local tl = root.transforms.l
   root._localTransform =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
   root._globalTransform = root._localTransform
   ---

   local ix2, iy2 = root._globalTransform:inverseTransformPoint(posx, posy)
   local dx = ix1 - ix2
   local dy = iy1 - iy2

   local dx3, dy3 = getGlobalDelta(root._globalTransform, dx, dy)
   root.transforms.l[1] = root.transforms.l[1] - dx3
   root.transforms.l[2] = root.transforms.l[2] - dy3
end


function love.load(arg)
   print(inspect(arg))
   shapeName = 'untitled'
   love.keyboard.setKeyRepeat( true )
   editingMode = nil
   editingModeSub = nil
   local ffont = "resources/fonts/cooper-bold-bt.ttf"
   --
   --ffont = "resources/fonts/WindsorBT-Roman.otf"
   supersmallest = love.graphics.newFont(ffont , 8)
   smallest = love.graphics.newFont(ffont , 16)
   small = love.graphics.newFont(ffont, 24)
   medium = love.graphics.newFont( ffont, 32)
   large = love.graphics.newFont(ffont , 48)

   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:setPitch(0.9 + 0.2*love.math.random())
   introSound:play()

   simple_format = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   }

   ui = {
      polyline = love.graphics.newImage("resources/ui/polyline.png"),
      polyline_add = love.graphics.newImage("resources/ui/polyline-add.png"),
      polyline_edit = love.graphics.newImage("resources/ui/polyline-edit.png"),
      polyline_remove = love.graphics.newImage("resources/ui/polyline-remove.png"),
      insert_link = love.graphics.newImage("resources/ui/insert-link.png"),
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
      next = love.graphics.newImage("resources/ui/next.png"),
      previous = love.graphics.newImage("resources/ui/previous.png"),
      lines = love.graphics.newImage("resources/ui/lines.png"),
      lines2 = love.graphics.newImage("resources/ui/lines2.png"),
      move_up = love.graphics.newImage("resources/ui/move-up.png"),
      move_down = love.graphics.newImage("resources/ui/move-down.png"),
      mesh = love.graphics.newImage("resources/ui/mesh.png"),
      parent = love.graphics.newImage("resources/ui/parent.png"),
      folder = love.graphics.newImage("resources/ui/folder.png"),
      folder_open = love.graphics.newImage("resources/ui/folderopen.png"),
      pivot = love.graphics.newImage("resources/ui/pivot.png"),
      pan = love.graphics.newImage("resources/ui/pan.png"),
      mask = love.graphics.newImage("resources/ui/mask.png"),
      clone = love.graphics.newImage("resources/ui/clone.png"),
      joystick = love.graphics.newImage("resources/ui/joystick.png"),
      transition = love.graphics.newImage("resources/ui/transition.png"),
      select = love.graphics.newImage("resources/ui/select.png"),
      hole = love.graphics.newImage("resources/ui/keyhole.png"),
      change = love.graphics.newImage("resources/ui/change.png"),
      add_to_list = love.graphics.newImage("resources/ui/add-to-list.png"),
      flip_vertical = love.graphics.newImage("resources/ui/flip-vertical.png"),
      flip_horizontal = love.graphics.newImage("resources/ui/flip-horizontal.png"),
      dopesheet = love.graphics.newImage("resources/ui/spreadsheet.png"),
      curve = love.graphics.newImage("resources/ui/curve.png"),
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }

   palette = {
      name='mix-and-match', -- nijntje , classic lego & fabuland
      colors={}
   }
   for i = 1, #miffy.colors do
      table.insert(palette.colors, miffy.colors[i])
   end
   for i = 1, #pico.colors do
      table.insert(palette.colors, pico.colors[i])
   end
   for i = 1, #lego.colors do
      table.insert(palette.colors, lego.colors[i])
   end
   for i = 1, #fabuland.colors do
      table.insert(palette.colors, fabuland.colors[i])
   end
   for i = 1, #james.colors do
      table.insert(palette.colors, james.colors[i])
   end

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }




   root = {
      folder = true,
      name = 'root',
      transforms =  {l={0,0,0,1,1,0,0,0,0}},
      children = {
         {
            folder = true,
            transforms =  {l={0,0,0,1,1,0,0,0,0}},
            name="rood",
            children ={{
                  name="chi22ld:"..1,
                  color = {1,0,0, 0.8},
                  points = {{0,0},{200,0},{200,200},{0,200}},
                       }
            }
         },
      },
   }


   for i = 1, 6 do
      local r = {
         folder = true,
         transforms =  {l={200,200,0,1,1,0,0,0,0}},
         name="geel",
         children ={
            {
               name="child:"..1,
               color = {1,1,0, 0.8},
               points = {{0,0},{200,0},{200,200},{0,200}},
            }
         }
      }
      table.insert(root.children[1].children, r)
   end
   

   
   parentize(root)
   currentNode = nil
   currentlyHoveredUINode = nil

   backdrop = {
      grid = {cellsize=100}, -- cellsize is in px
      bg_color = {34/255,30/255,30/255},
      image = love.graphics.newImage("resources/backdrops/offshore-707.jpg"),
      visible = false,
      alpha = 0.5,
      x = 0,
      y = 0,
      scale = 1
   }

   fileDropPopup = nil

   wireframe = false
   profiling = false
   simplifyValue = 0.2
   scrollviewOffset = 0
   lastDraggedElement = {}
   quitDialog = false
   rectangleSelect = {}
   childrenInRectangleSelect = {}
   meshAll(root)

   
   dopesheet = {}
   dopesheetEditing = false
   cellCount =  12*1 
   
end

function drawGrid()
   local scale = root.transforms.l[4]
   local size = backdrop.grid.cellsize * scale
   if (size < 10) then return end

   local w, h = love.graphics.getDimensions( )
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (root.transforms.l[1]) % size
   local yOffset = (root.transforms.l[2]) % size

   for x =0, vlines do
      love.graphics.line(xOffset + x*size, 0,xOffset +  x*size, h)
   end
   for y =0, hlines do
      love.graphics.line( 0, yOffset + y*size, w, yOffset +  y*size)
   end
end




local step = 0
function love.update(dt)
   -- if dopesheet and dopesheet.sliderValue ~= nil then
   --    dopesheet.sliderValue = dopesheet.sliderValue  + dt
   --    if dopesheet.sliderValue > 1 then
   --       dopesheet.sliderValue = 0
   --    end
   --    calculateDopesheetRotations(dopesheet.sliderValue)
   -- end
   
end


function labelPos(x,y)
   return x,y-20
end


function love.draw()

   step = step + 1
   local mx,my = love.mouse.getPosition()

   handleMouseClickStart()
   love.mouse.setCursor(cursors.arrow)
   local w, h = love.graphics.getDimensions( )
   local rightX = w - (64 + 500+ 10)/2

   
   love.graphics.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3])
   
   if  backdrop.visible then
      love.graphics.setColor(1,1,1, backdrop.alpha)
      love.graphics.draw(backdrop.image, backdrop.x, backdrop.y, 0, backdrop.scale, backdrop.scale)
   end
   
   love.graphics.setWireframe(wireframe )
   renderThings(root)

   if (currentlyHoveredUINode) then
      local alpha = 0.5 + math.sin(step/100)
      love.graphics.setColor(alpha,1,1, alpha) -- i want this blinkiung
      local editing = poly.makeVertices(currentlyHoveredUINode)
      if (editing and #editing > 0) then
         local editingMesh = makeMeshFromVertices(editing, currentlyHoveredUINode.points)
         love.graphics.draw(editingMesh,  currentlyHoveredUINode._parent._globalTransform)
      end
   end

   love.graphics.setWireframe( false )

   if currentNode then
      local t = root._localTransform
      local x,y = t:transformPoint(0,0)
      love.graphics.setColor(1,1,1)
      love.graphics.line(x-5, y, x+5, y)
      love.graphics.line(x, y-5, x, y+5)
   end

   if currentNode and currentNode.folder and  currentNode._globalTransform then
      local t = currentNode.transforms.l
      local pivotX, pivotY = currentNode._globalTransform:transformPoint( t[6], t[7] )
      love.graphics.setColor(0,0,0)
      love.graphics.circle("line", pivotX-1, pivotY, 10)
      love.graphics.setColor(1,1,1)
      love.graphics.circle("line", pivotX, pivotY, 10)
   end

   if editingMode == 'polyline' and currentNode and currentNode.points then
      local points =  currentNode and currentNode.points or {}
      local globalX, globalY = currentNode._parent._globalTransform:inverseTransformPoint( mx, my )
      local transformedPoints = {}
      local t = currentNode._parent._globalTransform
      for i=1, #points do
         local lx, ly = t:transformPoint( points[i][1], points[i][2] )
         table.insert(transformedPoints, {lx, ly})
      end

      love.graphics.setLineWidth(2.0  )
      love.graphics.setColor(1,1,1)
      local w, h = getLocalDelta(t, 10, 10)
      w = math.max(math.abs(w), math.abs(h))
      for i=1, #points do
         local kind = "line"
         if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
            local scale = root.transforms.l[4]
            if pointInRect(globalX,globalY,  points[i][1] - w/2, points[i][2] - w/2,   w, w) then
               kind= "fill"
               love.graphics.print(round2(points[i][1],3)..", "..round2(points[i][2],3), 8, love.graphics.getHeight()-32)
            end
         end

         if editingModeSub == 'polyline-insert' then
            local closestEdgeIndex = getClosestEdgeIndex(globalX, globalY, points)
            local nextIndex = (closestEdgeIndex == #transformedPoints and 1) or closestEdgeIndex+1

            if i == closestEdgeIndex or i == nextIndex then
               kind = 'fill'
            end
         end

         local dot_x = transformedPoints[i][1] - 5
         local dot_y =  transformedPoints[i][2] - 5
         local dot_size = 10
         love.graphics.setColor(0,0,0)
         love.graphics.rectangle(kind, dot_x-1, dot_y, dot_size, dot_size)

         love.graphics.setColor(1,1,1)
         love.graphics.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
      end

      love.graphics.setLineWidth(1)
   end

   love.graphics.setColor(1,1,1, 1)

   if (editingMode == 'rectangle-select' or  editingModeSub =='rectangle-point-select')  and rectangleSelect.startP and rectangleSelect.endP then
      love.graphics.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.startP.y)
      love.graphics.line(rectangleSelect.startP.x, rectangleSelect.endP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)
      love.graphics.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.startP.x, rectangleSelect.endP.y)
      love.graphics.line(rectangleSelect.endP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)

   end

   love.graphics.setColor(1,1,1, 0.1)
   drawGrid()

   love.graphics.push()

   local s = 1

   if (editingMode == 'folder' and currentNode and  currentNode.transforms) then
      if imgbutton('folder-move', ui.move,  calcX(6), calcY(0)).clicked then
         editingModeSub = 'folder-move'
      end

      if imgbutton('folder-pivot', ui.pivot,  calcX(7), calcY(0)).clicked then
         editingModeSub = nil
         if (#currentNode.children > 0) then
            local tlx, tly, brx, bry = getDirectChildrenBBox(currentNode)
            local mx = tlx + (brx - tlx)/2
            local my = tly + (bry - tly)/2
            local nx = currentNode.transforms.l[6]
            local ny = currentNode.transforms.l[7]

            if (nx == tlx and ny == tly) then
               currentNode.transforms.l[6]= brx
               currentNode.transforms.l[7]= tly
            elseif (nx == brx and ny == tly) then
               currentNode.transforms.l[6]= brx
               currentNode.transforms.l[7]= bry
            elseif (nx == brx and ny == bry) then
               currentNode.transforms.l[6]= tlx
               currentNode.transforms.l[7]= bry
            elseif (nx == tlx and ty == bry) then
               currentNode.transforms.l[6]= tlx
               currentNode.transforms.l[7]= tly
            elseif (nx == mx and ny == my) then
               currentNode.transforms.l[6]= tlx
               currentNode.transforms.l[7]= tly
            else
               currentNode.transforms.l[6]= mx
               currentNode.transforms.l[7]= my
            end
            editingModeSub = 'folder-move'
         end
      end

      if imgbutton('folder-pan-pivot', ui.pan,  calcX(8), calcY(0)).clicked then
         editingModeSub = 'folder-pan-pivot'
      end
      if imgbutton('folder-clone', ui.clone,calcX(9), calcY(0)).clicked then
         local cloned = copyShape(currentNode)
         cloned._parent = currentNode._parent
         parentize(cloned)
         cloned.name = (cloned.name)..' copy'
         addShapeAfter(cloned, currentNode)
         meshAll(cloned)
         setCurrentNode(cloned)
      end

      love.graphics.setFont(smallest)

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("scale x and y",  labelPos(calcX(1), calcY(2))  )
      if (currentNode.transforms.l[4] == currentNode.transforms.l[5]) then
         local v =  h_slider("folder-scale-xy", calcX(1), calcY(2), 200,  currentNode.transforms.l[5] , 0.00001, 10)
         if (v.value ~= nil) then
            currentNode.transforms.l[4] = v.value
            currentNode.transforms.l[5] = v.value
            editingModeSub = 'folder-scale'
            love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(2))
         end
      end

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("scale x",  labelPos(calcX(1), calcY(3)) )
      local v =  h_slider("folder-scale-x", calcX(1),  calcY(3) , 200,  currentNode.transforms.l[4] , -2, 2)
      if (v.value ~= nil) then
         currentNode.transforms.l[4] = v.value
         --currentNode.transforms.l[5] = v.value
         editingModeSub = 'folder-scale'
         love.graphics.print(string.format("%0.2f", v.value), calcX(1),  calcY(3))
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("scale y",  labelPos(calcX(1), calcY(4)) )

      local v =  h_slider("folder-scale-y", calcX(1), calcY(4), 200,  currentNode.transforms.l[5] , -2, 2)
      if (v.value ~= nil) then
         --currentNode.transforms.l[4] = v.value
         currentNode.transforms.l[5] = v.value
         editingModeSub = 'folder-scale'
         love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(4))
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("skew x",  labelPos(calcX(1), calcY(5)) )
      local v = h_slider('folder_skew_x', calcX(1), calcY(5), 200, currentNode.transforms.l[8] or 0,  -.5 * math.pi, .5 * math.pi )
      if (v.value ~= nil) then
         currentNode.transforms.l[8] = v.value
         love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(5))
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("skew y",  labelPos(calcX(1), calcY(6))  )
      local v = h_slider('folder_skew_y', calcX(1), calcY(6), 200, currentNode.transforms.l[9] or 0,  -.5 * math.pi, .5 * math.pi )
      if (v.value ~= nil) then
         currentNode.transforms.l[9] = v.value
         love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(6))
      end

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("rotate", labelPos(calcX(1), calcY(7)) )
      local v =  h_slider("folder-rotate", calcX(1),  calcY(7) , 200,  currentNode.transforms.l[3] , -1 * math.pi, 1 * math.pi)

      if (v.value ~= nil) then
         currentNode.transforms.l[3] = v.value
         editingModeSub = 'folder-rotate'
         love.graphics.print(string.format("%0.2f", v.value), calcX(1), calcY(7))
      end
      --end
   end
   love.graphics.setFont(small)



   if (editingMode == 'polyline') and currentNode  then
      if (not isPartOfKeyframePose(currentNode)) then
         if imgbutton('polyline-insert', ui.polyline_add,  calcX(6), calcY(0)).clicked then
            editingModeSub = 'polyline-insert'
         end
         if imgbutton('polyline-remove', ui.polyline_remove,  calcX(7), calcY(0)).clicked then
            editingModeSub = 'polyline-remove'
         end
      end
      if imgbutton('polyline-edit', ui.polyline_edit,  calcX(8), calcY(0)).clicked then
         editingModeSub = 'polyline-edit'
      end
      if imgbutton('polyline-palette', ui.palette,  calcX(9), calcY(0)).clicked then
         editingModeSub = 'polyline-palette'
      end

      if imgbutton('polyline-move', ui.move,  calcX(10), calcY(0)).clicked then
         editingModeSub = 'polyline-move'
      end

      if imgbutton('polyline-clone', ui.clone,  calcX(11), calcY(0)).clicked then
         local cloned = copyShape(currentNode)
         cloned._parent = currentNode._parent
         cloned.name = (cloned.name)..' copy'
         addShapeAfter(cloned, currentNode)
         setCurrentNode(cloned)
      end

      if imgbutton('polyline-recenter', ui.pivot, calcX(12), calcY(0)).clicked then
         editingModeSub = 'polyline-recenter'
         local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
         local w2 = (brx - tlx)/2
         local h2 = (bry - tly)/2
         for i=1, #currentNode.points do
            currentNode.points[i][1] = currentNode.points[i][1] -  (tlx + w2)
            currentNode.points[i][2] = currentNode.points[i][2] -  (tly + h2)
         end
      end


      if currentNode and currentNode.points then
         if imgbutton('rectangle-point-select', ui.select, calcX(13), calcY(0)).clicked then
            editingModeSub = 'rectangle-point-select'
         end
      end

   end

   if (editingModeSub == 'polyline-palette' and currentNode and currentNode.color) then
      local colorsInRow = 10
      for i = 1, #palette.colors do
         local rgb = palette.colors[i].rgb
         local x = ((i-1) % colorsInRow)*50
         local y = math.ceil((i) / colorsInRow)*50
         y = y + 50
         x = x + 50
         if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,s).clicked then
            currentNode.color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, currentNode.color[4] or 1}
         end
      end
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("alpha",  labelPos(calcX(0), calcY(10)) )
      local v =  h_slider("polyline_alpha", calcX(0), calcY(10), 100,  currentNode.color[4] , 0, 1)
      if (v.value ~= nil) then
         currentNode.color[4] = v.value
         love.graphics.print(currentNode.color[4], calcX(0), calcY(10))
      end
   end

   if (editingMode == 'backdrop') then
      if imgbutton('polyline-wireframe', ui.lines,  calcX(0), calcY(0)).clicked then
         wireframe = not wireframe
      end

      if imgbutton('polyline-palette', ui.palette,  calcX(7), calcY(0)).clicked then
         editingModeSub = 'backdrop-palette'
      end
      if imgbutton('backdrop_visibility', backdrop.visible and ui.visible or ui.not_visible,  calcX(8), calcY(0)).clicked then
         editingModeSub = nil
         backdrop.visible = not backdrop.visible
      end
      

      love.graphics.setColor(1,1,1, 1)
      love.graphics.print("simplify svg",  labelPos(calcX(1), calcY(1)) )
      local v =  h_slider("simplify_value", calcX(1), calcY(1), 200,  simplifyValue , 0, 10)
      if (v.value ~= nil) then
         simplifyValue= v.value
         love.graphics.print(simplifyValue, calcX(1), 20)
      end

      if (backdrop.visible) then
         if imgbutton('backdrop-move', ui.move, calcX(9), calcY(1)).clicked then
            if (editingModeSub == 'backdrop-move') then
               editingModeSub = nil
            else
               editingModeSub = 'backdrop-move'
            end
         end

         love.graphics.setColor(1,1,1, 1)
         love.graphics.print("alpha",  labelPos(calcX(10), calcY(1)) )
         local vslider =  h_slider("backdrop_alpha", calcX(10), calcY(1), 200, backdrop.alpha, 0, 1)
         if (vslider.value ~= nil) then
            backdrop.alpha = vslider.value
            editingModeSub = nil
            love.graphics.print(string.format("%0.2f", vslider.value),  calcX(10), calcY(1))
         end
         
         love.graphics.setColor(1,1,1, 1)
         love.graphics.print("scale",  labelPos(calcX(18), calcY(1)) )
         local hslider =  h_slider("backdrop_scale", calcX(18), calcY(1), 200, backdrop.scale, 0, 5)
         if (hslider.value ~= nil) then
            backdrop.scale = hslider.value
            editingModeSub = nil
            love.graphics.print(string.format("%0.2f", hslider.value),  calcX(18), calcY(1))
         end
         
      end

      if (editingModeSub == 'backdrop-palette') then
         local colorsInRow = 10
         for i = 1, #palette.colors do
            local rgb = palette.colors[i].rgb
            local x = ((i-1) % colorsInRow)*50
            local y = math.ceil((i) / colorsInRow)*50

            y = y + 50
            x = x + 50
            if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,s).clicked then
               backdrop.bg_color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255}
               print("bg_color: ", rgb[1]/255,rgb[2]/255,rgb[3]/255)
            end
         end
      end
   end

   if  editingMode ~= 'dopesheet' then
      love.graphics.setFont(smallest)
      local totalHeightGraphNodes = renderGraphNodes(root, 0, 90+8)
      love.graphics.setFont(small)
      local scrollBarH = (h-16-90)
      if totalHeightGraphNodes > scrollBarH then
         local ding = scrollbarV('hierarchyslider', w-40, 24, scrollBarH, totalHeightGraphNodes, scrollviewOffset)
         if ding.value ~= nil then
            scrollviewOffset = ding.value
         end
      end
      
      if imgbutton('backdrop', ui.backdrop, rightX - 50, calcY(0)).clicked then
         if (editingMode == 'backdrop') then
            editingMode = nil
         else
            editingMode = 'backdrop'
         end
         editingModeSub = nil
      end
      if not currentNode or not currentNode.points then
         if imgbutton('select', ui.select, rightX - 100, calcY(0)).clicked then
            editingMode = 'rectangle-select'
         end
         if #childrenInRectangleSelect > 0 then
            if imgbutton('connector-group', ui.parent, rightX - 150, 10).clicked then
               lastDraggedElement = {id = 'connector-group', pos = {rightX - 150, 10} }
            end

            if imgbutton('children-flip-vertical', ui.flip_vertical, rightX - 350, 10).clicked  then
               flipGroup(childrenInRectangleSelect, 1,-1)
            end
            if imgbutton('children-fliph-horizontal', ui.flip_horizontal, rightX - 300, 10).clicked  then
               flipGroup(childrenInRectangleSelect, -1,1)
            end

            if imgbutton('children-scale', ui.resize, rightX - 250, 10).clicked  then
               resizeGroup(childrenInRectangleSelect, 0.95)
            end
            if imgbutton('children-scale', ui.resize, rightX - 200, 10).clicked  then
               resizeGroup(childrenInRectangleSelect, 1.05)
            end
         end
      end

      
      if iconlabelbutton('add-shape', ui.add, nil, false,  'add shape',  rightX-10, calcY(0)).clicked then
         local shape = {
            color = {0,0,0,1},
            outline = true,
            points = {},
         }

         if currentNode and not currentNode.folder then
            currentNode.mesh= makeMeshFromVertices(poly.makeVertices(currentNode))
         end
         if (currentNode) then
            shape._parent = currentNode and currentNode._parent
            addShapeAfter(shape, currentNode)
         else
            shape._parent = root
            addShapeAtRoot(shape)
         end

         editingMode = 'polyline'
         editingModeSub = 'polyline-insert'
      end
      
      if iconlabelbutton('add-parent', ui.add, nil, false,  'add folder',  rightX-10,calcY(1)).clicked then
         local shape = {
            folder = true,
            transforms =  {l={0,0,0,1,1,0,0, 0,0}},
            children = {}
         }

         if currentNode and not currentNode.folder then
            currentNode.mesh= makeMeshFromVertices(poly.makeVertices(currentNode))
         end
         if (currentNode) then
            shape._parent = currentNode and currentNode._parent
            addShapeAfter(shape, currentNode)
         else
            shape._parent = root
            addShapeAtRoot(shape)
         end

         editingMode = 'polyline'
         editingModeSub = 'polyline-insert'
      end

      if (currentNode) then
         local index = getIndex(currentNode)
         if (currentNode and index > 1) then
            index = getIndex(currentNode)
            if index > 1 and imgbutton('polyline-move-up', ui.move_up,  rightX - 50, calcY(1) ).clicked then
               local taken_out = removeCurrentNode()
               table.insert(taken_out._parent.children, index-1, taken_out)
            end
         end

         if (index < #currentNode._parent.children) and imgbutton('polyline-move-down', ui.move_down,  rightX - 50, calcY(2) ).clicked then
            local taken_out = removeCurrentNode()
            if (taken_out) then
               table.insert(taken_out._parent.children, index+1, taken_out)
            end
         end
      end

      if currentNode and currentNode.keyframes then
         if (currentNode.keyframes == 2) then
            local v = h_slider("lerp-keyframes", rightX-300, 100, 200,  currentNode.lerpValue , 0,1)
            if v.value then
               currentNode.lerpValue = v.value
            end
         end
         if (currentNode.keyframes == 4 or currentNode.keyframes == 5  ) then
            local v = joystick('lerp-keyframes', rightX-300, 100, 200, currentNode.lerpX or 0,currentNode.lerpY or 0, 0, 1)
            if v.value then
               currentNode.lerpX = v.value.x
               currentNode.lerpY = v.value.y
            end
         end
      end

      if (currentNode) then
         if imgbutton('delete', ui.delete,  rightX - 50, calcY(3)).clicked then
            deleteNode(currentNode)
         end

         if imgbutton('badge', ui.badge, rightX - 50, calcY(4)).clicked then
            changeName = not changeName
            local name = currentNode and currentNode.name
            changeNameCursor = name and utf8.len(name) or 1
         end

         if imgbutton('connector', ui.parent, rightX - 50, calcY(5)).clicked then
            lastDraggedElement = {id = 'connector', pos = {rightX - 50, calcY(5)} }
         end

         if currentNode and currentNode.points then
            if imgbutton('mask', ui.mask, rightX - 50, calcY(6)).clicked then
               currentNode.mask = not currentNode.mask
            end
            if imgbutton('hole', ui.hole, rightX - 50, calcY(7)).clicked then
               currentNode.hole = not currentNode.hole
            end
         end

         if currentNode and currentNode.folder and #currentNode.children >= 2 and #currentNode.children < 5 and
         (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
            if (imgbutton('transition', ui.transition, rightX - 50, calcY(7,s))).clicked then
               if (currentNode.keyframes) then
                  currentNode.keyframes = nil
                  currentNode.lerpValue = nil
                  currentNode.frame = nil
               else
                  currentNode.keyframes = 2
                  currentNode.lerpValue = 0.5
                  currentNode.frame = 1
               end
            end
         end
         
         if currentNode and currentNode.folder and #currentNode.children >= 4 and (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
            if (imgbutton('joystick', ui.joystick, rightX - 50, calcY(8))).clicked then
               if (currentNode.keyframes) then
                  currentNode.keyframes = nil
                  currentNode.lerpValue = nil
                  currentNode.lerpX = nil
                  currentNode.lerpY = nil
                  currentNode.frame = nil
               else
                  assert(#currentNode.children == 4 or #currentNode.children == 5)
                  currentNode.keyframes = #currentNode.children
                  currentNode.lerpX = 0.5
                  currentNode.lerpY = 0.5
                  currentNode.frame = 1
               end
            end
         end


         if (changeName) then
            local str =  currentNode and currentNode.name  or ""
            local substr = string.sub(str, 1, changeNameCursor)
            local cursorX = (love.graphics.getFont():getWidth(substr))
            local cursorH = (love.graphics.getFont():getHeight(str))
            love.graphics.setColor(1,1,1,0.5)
            love.graphics.rectangle('fill', w-700 - 10, calcY(4) + 8*4 - 10, 300 + 20,  cursorH + 20 )
            love.graphics.setColor(1,1,1)
            love.graphics.print(str , w - 700, calcY(4) + 8*4)
            love.graphics.rectangle('fill', w- 700 + cursorX, calcY(4) , 2, cursorH)
         end
      end
   end
   
   -- local count = countNestedChildren(root, 0)
   -- if (count * 50 > h) then
   --    local v2 = v_slider("scrollview", w - 50, calcY(4) , 100, scrollviewOffset, 0, count * 50)
   --    if (v2.value ~= nil) then
   --       scrollviewOffset = v2.value
   --    end
   -- end

   love.graphics.pop()
   love.graphics.setFont(small)
   if not quitDialog then
      love.graphics.print(tostring(love.timer.getFPS( )), 2,0)
      love.graphics.print(shapeName, 64, 0)
   end

   if lastDraggedElement and (lastDraggedElement.id == 'connector' or lastDraggedElement.id == 'connector-group' ) then
      love.graphics.line(lastDraggedElement.pos[1]+16, lastDraggedElement.pos[2]+16, mx, my)
   end


   --if not dopesheetEditing then
   function initializeDopeSheet()
      dopesheet = {
         scrollOffset = 0,
         node=currentNode,
         names = {},
         refs = {}
      }
      if currentNode then
         --local flatted = {}
         local d = fetchAllNames(currentNode)
         dopesheet.names = d
         local refs = {}
         for i = 1, #d do
            refs[d[i]] = findNodeByName(root, d[i])
         end
         dopesheet.refs = refs
      end

      data = {}
      for i =1, #dopesheet.names do
         local row = {}
         
         for j = 1, cellCount do
            row[j] = {}
         end
         row[1] = {rotation=currentNode.transforms.l[3], ease='linear'}
         row[cellCount] = {rotation=currentNode.transforms.l[3], ease='linear'}
         
         data[i] = row
      end
      dopesheet.data = data
      dopesheet.selectedCell = nil
      dopesheet.sliderValue = 0
      dopesheet.drawMode = 'sheet'
      
      

      
   end

   function calculateDopesheetRotations(sliderValue)
      
      local frameIndex = (math.floor(sliderValue*(cellCount-1))+1)
      if frameIndex > cellCount-1 then frameIndex = cellCount-1 end
      
      for i = 1, #dopesheet.names do
         local nodeBefore, nodeBeforeIndex = lookForFirstIndexBefore(dopesheet.data[i],frameIndex)
         local nodeAfter, nodeAfterIndex =  lookForFirstIndexAfter(dopesheet.data[i],frameIndex)

         print(inspect(nodeBefore))
         local durp = mapInto(1+ sliderValue * (cellCount-1), nodeBeforeIndex, nodeAfterIndex, 0,1)
         

         -- local beginVal = 0
         -- local endVal = 1
         -- local change = endVal - beginVal
         -- local duration = 1
         local ease = nodeBefore.ease or 'linear'
         local l1 = easing[ease](durp, 0,1,1, 1/10, 1/3)
         
         local newRotation = mapInto(l1, 0, 1, nodeBefore.rotation, nodeAfter.rotation)
         dopesheet.refs[dopesheet.names[i]].transforms.l[3] = newRotation
      end
   end
   
   
   function lookForFirstIndexBefore(data, index)
      for i=index , 1 , -1 do
         if data[i].rotation then
            return data[i], i
         end
      end
      return nil
   end
   function lookForFirstIndexAfter(data, index)
      for i=index+1 , #data do
         if data[i].rotation then
            return data[i], i
         end
      end
      return nil
   end
   

   function fetchAllNames(root, result)
      result = result or {}

      if root.folder then -- only care for the names of folders atm
         table.insert(result, root.name)
      end
      
      if root.children then
         for i = 1, #root.children do
            fetchAllNames(root.children[i], result)
         end
      end
      return result
   end
   
   
   
   
   if (imgbutton('dopesheet', ui.dopesheet, 10, h - 32)).clicked then
      dopesheetEditing = not dopesheetEditing
      editingMode = dopesheetEditing and 'dopesheet' or nil
      if dopesheetEditing then -- initialize
         initializeDopeSheet(cellCount)
      end
      
   end


   
   if dopesheetEditing then
      love.graphics.setColor(1,1,1,0.5)
      love.graphics.rectangle("fill", 0, h/2, w, h/2)
      love.graphics.setLineWidth(2)

      local drawUseToggle = imgbutton("drawOrUse", (dopesheet.drawMode == 'sheet') and ui.dopesheet  or ui.pencil, 0, h/2)
      if drawUseToggle.clicked then
         dopesheet.drawMode = ( dopesheet.drawMode == 'draw') and 'sheet' or 'draw'
      end

      if (((32+24) * #dopesheet.names)  > h/2) then
         local ding = scrollbarV('dopesheetslider', 400, h/2, (h/2),48+ ((32+24) * #dopesheet.names) , dopesheet.scrollOffset or 0)
         if ding.value ~= nil then
            --if not tostring(ding.value) == "nan" then
               dopesheet.scrollOffset = ding.value
            --end
         end
      end
      
      
      if currentNode then
         for i = 1, #dopesheet.names do
            local h1 = 32
            local h2 = 24

            local x1 = 0
            local y1 = 32 + h/2 + ((i-1)*(h1+h2))
            y1 = y1 - dopesheet.scrollOffset
            local w1 = 200
            local b = getUIRect('dope-bone'..i, x1,y1,w1,h1)

            local cellWidth = 12
            local cellHeight = 24
            local node = dopesheet.refs[dopesheet.names[i]]
            
            if y1 >= h/2 then -- dont draw things that are scrolled away
               
               if b.clicked then
                  setCurrentNode(node)
               end

               if currentNode == node then
                  love.graphics.setLineWidth(3)
                  love.graphics.setColor(0,0,0)
               else
                  love.graphics.setLineWidth(2)
                  love.graphics.setColor(0.5,0.5,0.5)
               end
               
               love.graphics.rectangle("line",  x1,y1,w1,h1)
               
               love.graphics.setLineWidth(2)
               love.graphics.setColor(0.7,0.7,0.7)
               for ci = 1,cellCount do
                  --print(ci, inspect(dopesheet.data[i][ci]))
                  local myX = x1+w1+((ci-1)*cellWidth)
                  local myY = y1 + h1
                  love.graphics.rectangle("line",myX,myY,cellWidth,cellHeight)
                  if dopesheet.data[i][ci] then
                     
                     love.graphics.setColor(0,0,0)
                     love.graphics.rectangle("line",myX+1,myY+1,cellWidth,cellHeight)
                     
                     love.graphics.setColor(0.7,0.7,0.7)
                     love.graphics.rectangle("line",myX,myY,cellWidth,cellHeight)
                     
                     if dopesheet.data[i][ci].rotation then
                        love.graphics.setColor(0,1,0,0.3)

                        if dopesheet.selectedCell and
                           dopesheet.selectedCell[1]==i and
                        dopesheet.selectedCell[2]==ci then
                           love.graphics.setColor(0,1,0,0.8)
                        end
                        
                        love.graphics.rectangle("fill",myX+2,myY+2,cellWidth-4,cellHeight-4)
                     end
                  end

                  b = getUIRect(i..ci..'cell', myX, myY, cellWidth,cellHeight)
                  if b.clicked then
                     
                     if dopesheet.drawMode == 'draw' then
                        if dopesheet.data[i][ci].rotation then
                           if ci > 1 then -- you cannot delete the first one
                              dopesheet.data[i][ci] = {}
                           end
                           
                        else
                           dopesheet.data[i][ci] = {rotation = dopesheet.data[i][1].rotation, ease='linear'}
                        end
                     end
                     if dopesheet.drawMode == 'sheet' then
                        if  dopesheet.data[i][ci].rotation then
                           
                           dopesheet.sliderValue = (ci-1)/(cellCount-1)
                           
                           dopesheet.selectedCell = {i, ci}
                           calculateDopesheetRotations(dopesheet.sliderValue)
                           
                           -- local name = dopesheet.names[i]
                           -- local node2 = dopesheet.data[i][ci]
                           -- dopesheet.refs[name].transforms.l[3] = node2.rotation
                        else
                           dopesheet.selectedCell  = nil
                        end
                     end

                  end

                  
               end
               
               love.graphics.setColor(1,1,1,1)
               love.graphics.setFont(small)
               local strW = small:getWidth(dopesheet.names[i] )
               love.graphics.setColor(0,0,0,1)
               love.graphics.print(dopesheet.names[i], w1 - strW - 10+2, y1+1)
               love.graphics.setColor(1,1,1,1)
               love.graphics.print(dopesheet.names[i], w1 - strW - 10, y1)

               
               love.graphics.setFont(smallest)

               
               local rotStr = "rotation: "..round2(node.transforms.l[3], 3)
               local str2W = smallest:getWidth(rotStr)

               love.graphics.setColor(0,0,0,1)
               love.graphics.print(rotStr, w1 - str2W - 10 + 2, y1 + 32 +1)

               love.graphics.setColor(1,1,1,1)
               love.graphics.print(rotStr, w1 - str2W - 10, y1 + 32)
            end
            
            if dopesheet.selectedCell then
               local indx = dopesheet.selectedCell
               if iconlabelbutton('toggle_dopesheet_curve', ui.curve, nil, false,  'ease',  w/2, h/4 -50).clicked then
                  dopesheet.showEases = not dopesheet.showEases
               end
               node = dopesheet.data[indx[1]][indx[2]]
               --print(inspect(node.rotation))
               rotStr =  "rotation: "..round2(node.rotation, 3)

               local rotSlider = h_slider("dopesheetrotsliderstuff", w/2, h/4, 600, node.rotation, -math.pi, math.pi)
               if rotSlider.value then
                  local name = dopesheet.names[indx[1]]
                  dopesheet.refs[name].transforms.l[3] = rotSlider.value
                  node.rotation = rotSlider.value
                  
               end
               
               love.graphics.setColor(0,0,0,0)
               love.graphics.print(rotStr, w/2 + 2 , h/4 - 20 + 1)

               
               love.graphics.setColor(1,1,1,1)
               love.graphics.print(rotStr, w/2 , h/4 - 20)
            end

            
            
            local dsSlider = h_slider("dopesheetstuff", 200, h/2, cellWidth*cellCount, dopesheet.sliderValue, 0, 1)
            if dsSlider.value then
               
               dopesheet.sliderValue =  dsSlider.value
               
               calculateDopesheetRotations(dsSlider.value)
               
            end
            
            
         end

         if dopesheet.selectedCell and  dopesheet.showEases then
            -- make a dropdown where you can set the type of ease
            local currentEase = dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease
            local eases = {
               "linear",
               "inQuad",
               "outQuad",
               "inOutQuad",
               "outInQuad",
               "inCubic",
               "outCubic",
               "inOutCubic",
               "outInCubic",
               "inQuart",
               "outQuart",
               "inOutQuart",
               "outInQuart",
               "inQuint",
               "outQuint",
               "inOutQuint",
               "outInQuint",
               "inSine",
               "outSine",
               "inOutSine",
               "outInSine",
               "inExpo",
               "outExpo",
               "inOutExpo",
               "outInExpo",
               "inCirc",
               "outCirc",
               "inOutCirc",
               "outInCirc",
               "inBounce",
               "outBounce",
               "inOutBounce",
               "outInBounce",
            }

            local eases_1p = {
               "inBack",
               "outBack",
               "inOutBack",
               "outInBack",
            }

            local eases_2p = {
               "inElastic",
               "outElastic",
               "inOutElastic",
               "outInElastic",
            }

            local halfEases = math.floor(#eases/2)

            function makeEaseLabelButton(label, x, y, selectedEase)
               love.graphics.setColor(0,0,0, 1)
               love.graphics.print(label, x+2, y+1)
               love.graphics.setColor(1,1,1, 1)
               if (label == selectedEase) then
                  love.graphics.setColor(1,0,1, 1)
               end
               
               love.graphics.print(label, x, y)
               local labelWidth = smallest:getWidth(label)
               love.graphics.setColor(1,0,1, 0.2)
               return getUIRect('ease-select-'..label, x,y,labelWidth,20)
            end
            
            
            for i =1 , #eases do
               local y = 20 * i
               local x = 10
               if i > #eases/2 then
                  y = 20 * (i - #eases/2 )
                  x = 150
               end
               local b = makeEaseLabelButton(eases[i], x, y, currentEase)
               if b.clicked then
                  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases[i]
               end
               
            end
            for i =1 , #eases_1p do
               local b = makeEaseLabelButton(eases_1p[i], 300, 20*i, currentEase)
               if b.clicked then
                  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases_1p[i]
               end
            end
            for i =1 , #eases_2p do
               local b = makeEaseLabelButton(eases_2p[i], 450, 20*i, currentEase)
               if b.clicked then
                  dopesheet.data[dopesheet.selectedCell[1]][dopesheet.selectedCell[2]].ease = eases_2p[i]
               end
            end
         end
         
      end

      
      love.graphics.setLineWidth(1)
   end
   

   if quitDialog then
      local quitStr = "Quit? Seriously?! [ESC] "
      love.graphics.setFont(large)
      love.graphics.setColor(0,0,0, 1)
      love.graphics.print(quitStr, 114, 11)
      love.graphics.setColor(1,0.5,0.5, 1)
      love.graphics.print(quitStr, 116, 13)
      love.graphics.setColor(1,1,1, 1)
      love.graphics.print(quitStr, 115, 12)
   end

   if fileDropPopup then
      love.graphics.setFont(small)
      love.graphics.setColor(1,1,1, 1)
      love.graphics.rectangle("fill", 100, 100, w-200, h-200)
      love.graphics.setColor(0,0,0)
      local name =  fileDropPopup:getFilename()
      love.graphics.print("dropped file: "..name, 140, 120)

      if ends_with(name, 'polygons.txt') or ends_with(name, '.svg') then
         
         
         if iconlabelbutton('add-shape', ui.add_to_list, nil, false,  'add shape',  120, 300).clicked then
            local tab = getDataFromFile(fileDropPopup)
            root.children = TableConcat(root.children, tab)
            parentize(root)
            scrollviewOffset = 0
            editingMode = nil
            editingModeSub = nil
            currentNode = nil
            meshAll(root)
            fileDropPopup = nil
         end
         if iconlabelbutton('add-shape-new', ui.add, nil, false,  'new project',  120, 200).clicked then
            local tab = getDataFromFile(fileDropPopup)
            root.children = tab -- TableConcat(root.children, tab)
            parentize(root)
            scrollviewOffset = 0
            editingMode = nil
            editingModeSub = nil
            currentNode = nil
            meshAll(root)
            fileDropPopup = nil
         end

      else
         love.graphics.print("this isnt a good filetype", 140, 170)
         if iconlabelbutton('ok-bye', ui.add, nil, false,  'ok bye',  120, 200).clicked then
            fileDropPopup = nil
         end
      end
   end
   
end

function love.textinput(t)
   if (changeName) then
      local str = currentNode and currentNode.name or ""
      if (changeNameCursor > #str) then
         changeNameCursor = #str
      end

      local a,b = split(str, changeNameCursor+1)
      local r = table.concat{a, t, b}
      changeNameCursor = changeNameCursor + 1
      currentNode.name = r
   end
end

function getDataFromFile(file)
   local filename = file:getFilename()
   local tab
   local _shapeName

   if ends_with(filename, '.svg') then
      local command = 'node '..'resources/svg_to_love/index.js '..filename..' '..simplifyValue
      print(command)
      local p = io.popen(command)
      local str = p:read('*all')
      p:close()
      local obj = ('{'..str..'}')
      tab = (loadstring("return ".. obj)())
      local charIndex = string.find(filename, "/[^/]*$")
      if charIndex == nil then
         charIndex = string.find(filename, "\\[^\\]*$")
      end

      _shapeName = filename:sub(charIndex+1, -5) -- cutting off .svg
      shapeName = _shapeName

   end

   if ends_with(filename, 'polygons.txt') then
      local str = file:read('string')
      tab = (loadstring("return ".. str)())

      local index = string.find(filename, "/[^/]*$")
      if index == nil then
         index = string.find(filename, "\\[^\\]*$")
      end

      print(index, filename)
      _shapeName = filename:sub(index+1, -14) --cutting off .polygons.txt
      shapeName = _shapeName
   end
   return tab
end


function love.filedropped(file)
   fileDropPopup = file
end


function love.keypressed(key)

   if key == 't' then
      usePerspective = not usePerspective
   end
   if key == 'tab' then
      if editingMode ~= 'dopesheet' then
         editingMode = 'dopesheet'
         dopesheetEditing = true
         if not currentNode then
            currentNode = root.children[1]
         end
      else
         dopesheetEditing = false
         editingMode = nil
      end
      
      initializeDopeSheet()
   end
   if key == "escape" then
      if (editingModeSub ~= nil) then
         editingModeSub = nil
      elseif (editingMode ~= nil) then
         editingMode = nil
      else
         if (quitDialog == true) then
            love.event.quit()
         elseif (quitDialog == false) then
            quitDialog = true
         end
      end
   else
      if (quitDialog) then
         quitDialog = false
      end
   end

   if (key == 'p' and not changeName) then
      if not profiling then
         ProFi:start()
      else
         ProFi:stop()
         ProFi:writeReport( 'log/MyProfilingReport.txt' )
      end
      profiling = not profiling
   end
   if key == '-' and not changeName then
      love.wheelmoved(0,-1)
   end
   if key == '=' and not changeName then
      love.wheelmoved(0,1)
   end
   if key == '0' and not changeName then
      root.transforms.l[1] = 0
      root.transforms.l[2] = 0
   end


   if (key == 's' and not changeName) then
      local path = shapeName..".polygons.txt"
      local info = love.filesystem.getInfo( path )
      if (info) then
         shapeName = shapeName..'_'
         path =  shapeName..".polygons.txt"
      end
      local toSave = {}
      for i=1 , #root.children do
         table.insert(toSave, copyShape(root.children[i]))
      end

      love.filesystem.write(path, inspect(toSave, {indent=""}))
      love.system.openURL("file://"..love.filesystem.getSaveDirectory())
   end
   if (key == 'j' and not changeName) then
      local path = shapeName..".polygons.txt.json"
      local info = love.filesystem.getInfo( path )
      if (info) then
         shapeName = shapeName..'_'
         path =  shapeName..".polygons.txt.json"
      end
      local toSave = {}
      for i=1 , #root.children do
         table.insert(toSave, copyShape(root.children[i]))
      end

      love.filesystem.write(path, json.encode(toSave, {indent=""}))
      love.system.openURL("file://"..love.filesystem.getSaveDirectory())
   end
   if not changeName and currentNode and not #childrenInRectangleSelect then
      if (key == 'delete') then
         deleteNode(currentNode)
      end
   end
   if editingModeSub == 'rectangle-point-select' and #childrenInRectangleSelect then
      local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
      if (key == 'left') then
         movePoints(currentNode, shift and -10 or -1, 0)
      end
      if (key == 'right') then
         movePoints(currentNode, shift and 10 or 1, 0)
      end
      if (key == 'up') then
         movePoints(currentNode, 0, shift and -10 or -1)
      end
      if (key == 'down') then
         movePoints(currentNode, 0, shift and 10 or 1)
      end
      if key == 'delete' then
         deletePoints(currentNode)
      end

   end



   if (changeName) then
      if (key == 'backspace') then
         local str = currentNode and currentNode.name or ""
         local a,b = split(str, changeNameCursor+1)
         currentNode.name = table.concat{split(a,utf8.len(a)), b}
         changeNameCursor = math.max(0, (changeNameCursor or 0)-1)
      end

      if (key == 'delete') then
         local str = currentNode and currentNode.name or ""
         local a,b = split(str, changeNameCursor+2)
         if (#b > 0) then
            currentNode.name = table.concat{split(a,utf8.len(a)), b}
            changeNameCursor = math.min(#currentNode.name, changeNameCursor)
         end
      end

      if (key == 'left') then
         if (changeNameCursor > 0) then
            changeNameCursor = changeNameCursor - 1
         end
      end

      if (key == 'right' ) then
         local str =  currentNode and currentNode.name or ""
         if (changeNameCursor < utf8.len(str)) then
            changeNameCursor = changeNameCursor + 1
         end
      end

      if (key == 'return') then
         changeName = false
      end
   end
end
