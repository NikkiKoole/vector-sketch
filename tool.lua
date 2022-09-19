inspect = require 'vendor.inspect'

console = require 'vendor.console'
require 'lib.basic-tools' -- needs to be before console (they both overwrite print)
require 'lib.recursivelyMakeTextures'

require 'src.palettes'
require 'src.dopesheet'
require 'src.file-screen'

require 'lib.scene-graph'
require 'lib.basics'
require 'lib.copyshape'
require 'lib.main-utils'
require 'lib.polyline'
require 'lib.poly'
require 'lib.bbox'
require 'lib.border-mesh'
require 'lib.generate-polygon'
require 'lib.toolbox'
require 'lib.ui'

utf8 = require('utf8')
ProFi = require 'vendor.ProFi'
json = require 'vendor.json'

local LG = love.graphics
local LK = love.keyboard


--easing = require 'vendor.easing'
--https://github.com/rxi/lurker


-- use multiline input code to improve my inputfields
-- https://github.com/ReFreezed/InputField
local mylib = {}

function mylib:setRoot(root, folderPath)
   parentize(root)
   meshAll(root)

   mylib.root = root
   mylib.folderPath = folderPath
   print('mylib folderpath at setroot', folderPath)
   if folderPath then
      local s, e = folderPath:find("experiments/")
      if (e) then
	 local prefix = folderPath:sub(e+1) 
	 print('texture prefix: ', prefix)
      end
   end
   
end


local function getDimensions()
   return mylib.w, mylib.h
end
function mylib:resize(w,h)
   mylib.w =w
   mylib.h =h
   sceneGraph = {
      maximized = false,
      topY = 90,
      height= h-90,
      x = w-160,
   }
end





local function getCircumference()
   local total = 0
   for i=1, #currentNode.points-1 do
      local p = currentNode.points[i]
      local n = currentNode.points[i+1]

      local angle, distance = getAngleAndDistance(p[1],p[2],n[1],n[2])
      total = total + distance
   end
   return total
end





local function getAngleAndDistance(x1,y1,x2,y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local angle =  math.atan2(dy, dx)
   local distance =  math.sqrt ((dx*dx) + (dy*dy))

   return angle, distance
end

local function getLocalDelta(transform, dx, dy)
   local dx1, dy1 = transform:inverseTransformPoint( 0, 0 )
   local dx2, dy2 = transform:inverseTransformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end

local function getGlobalDelta(transform, dx, dy)
   -- this one is only used in the wheel moved offset stuff
   local dx1, dy1 = transform:transformPoint( 0, 0 )
   local dx2, dy2 = transform:transformPoint( dx, dy )
   local dx3 = dx2 - dx1
   local dy3 = dy2 - dy1
   return dx3, dy3
end


local function recursiveCloseAll(node)
   if node.folder then
      node.open = false
   end

   if node.children then
      for i =1, #node.children do
         recursiveCloseAll(node.children[i])
      end
   end
end
local function recursiveOpenSome(node, toOpen)
   if node.folder then
      for j=#toOpen, 1, -1 do
         if toOpen[j] == node then
            node.open = true
            table.remove(toOpen, j)
         end
      end
   end

   if node.children then
      for i = 1, #node.children do
         recursiveOpenSome(node.children[i], toOpen)
      end
   end
end
local function recursiveGetRunningYForNode(node, lookFor, runningY)
   -- this one assumes the nodes are already opened up correctly
   local rowHeight = 27 - 4
   for i = 1,#node.children do
      local child = node.children[i]
      if child == lookFor then
         return runningY
      else
         runningY = runningY + rowHeight
         if child.folder and child.open then
            return recursiveGetRunningYForNode(node.children[i], lookFor, runningY)
         end
      end
   end

   return runningY
end


local function tryToCenterUI(node2)
   local root = mylib.root
   recursiveCloseAll(root)
   local reversePath = {}
   local node = node2
   while node ~= root do
      table.insert(reversePath,node._parent)
      node = node._parent
   end
   recursiveOpenSome(root, reversePath)
   local ry = recursiveGetRunningYForNode(root, node2, 0)
   local w, h = getDimensions()
   if ry > h then
      scrollviewOffset = ry
   else
      scrollviewOffset = 0
   end
end



local function setCurrentNode(newNode)
   if currentNode and not currentNode.folder then
      remeshNode(currentNode)
   end
   currentNode = newNode
end

function isPartOfKeyframePose(node)
   local root = mylib.root

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

local function nodeIsMyOwnOffspring(me, node)
   if (me == node) then return true end
   if (node._parent == me) then
      return true
   end
   if (node._parent.name == 'root') then
      return false
   end
   return nodeIsMyOwnOffspring(me, node._parent)
end

local function rotateGroup(node, degrees)
   local tlx, tly, brx, bry = getPointsBBox(node.points)
   local w2 = (brx - tlx)/2
   local h2 = (bry - tly)/2
   local cx = tlx+w2
   local cy = tly+h2

   local s = math.sin(degrees*0.0174532925)
   local c = math.cos(degrees*0.0174532925)

   for i=1, #node.points do
      local p = {
         node.points[i][1] - cx,
         node.points[i][2] - cy,
      }
      local xnew = p[1] * c - p[2] * s
      local ynew = p[1] * s + p[2] * c
      p[1] = xnew + cx
      p[2] = ynew + cy
      node.points[i] =  {p[1], p[2]}
   end
   remeshNode(node)
end

local function recenterGroup(group, dx, dy)
   for i =1, #group do
      for j = 1, #(group[i].points) do
         group[i].points[j][1] = group[i].points[j][1] + dx
         group[i].points[j][2] = group[i].points[j][2] + dy
      end
   end
end

local function recenterPoints(points)
   local tlx, tly, brx, bry = getPointsBBox(points)
   local w2 = (brx - tlx)/2
   local h2 = (bry - tly)/2
   for i=1, #points do
      points[i][1] = points[i][1] -  (tlx + w2)
      points[i][2] = points[i][2] -  (tly + h2)
   end
   return points
end

local function resizeGroup(node, children, scale)
   if type(children[1]) == 'number' then
      for i = 1, #children do
	 local index = children[i]
         node.points[index] = {node.points[index][1] * scale, node.points[index][2] * scale}
      end
   else
      for i = 1, #children do
         for j =1 , #children[i].points do
            children[i].points[j] = {
               children[i].points[j][1] * scale,
               children[i].points[j][2] * scale
            }
         end
         remeshNode(children[i])
      end
      if node then
	 remeshNode(node)
      end
      
   end
end

local function flipGroup(node, children, xaxis, yaxis)
   if type(children[1]) == 'number' then
      for p=1, #children do
	 local index = children[p]
	 node.points[index] =  {node.points[index][1] * xaxis, node.points[index][2] * yaxis}
      end
      remeshNode(node)
   else
      for i=1, #children do

	 if children[i].points then
	    local scaledPoints = {}
	    for p=1, #children[i].points do
	       scaledPoints[p] = {children[i].points[p][1] * (xaxis ), children[i].points[p][2] * (yaxis )}
	    end
	    children[i].points = scaledPoints
	    remeshNode(children[i])
	 end
      end
   end
end

local function removeCurrentNode()
   if (currentNode) then
      return table.remove(currentNode._parent.children, getIndex(currentNode))
   end
end


local function deleteNode(node)
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

local function removeGroupOfThings(group)
   local root =  currentNode or mylib.root
   for i = 1, #group do
      table.remove(root.children, getIndex(group[i]))
   end
end

local function addGroupAtEnd(group, parent)
   for i = 1, #group do
      local thing = group[i]
      thing._parent = parent
      table.insert(parent.children, #parent.children + 1, thing)
   end
end

local function addThingAtEnd(thing, parent)
   thing._parent = parent
   table.insert(parent.children, #parent.children + 1, thing)
end

local function addShapeAtRoot(shape)
   local root = mylib.root

   table.insert(root.children, #root.children + 1, shape)
end

local function addShapeAfter(shape, after)
   local index = getIndex(after)
   if (index > 0) then
      table.insert(after._parent.children, index+1, shape)
   end
end


local function removeShapeAtPath(path)
   local root = mylib.root

   return table.remove(root.children, path[1])
end

local function moveItemsInRectangleSelect(dx, dy)
   for i = 1, #childrenInRectangleSelect do
      local child = childrenInRectangleSelect[i]
      if child then
         for j = 1, #child.points do
            child.points[j] = {child.points[j][1] + dx, child.points[j][2] + dy}
         end
         remeshNode( child)
      end
   end
end


local function movePoints(node, dx, dy)
   if node.folder then
      for i = 1, #childrenInRectangleSelect do
	 local child = childrenInRectangleSelect[i]
	 local childIndex = getIndex(child)
	 for j = 1, #node.children[childIndex].points do
	    node.children[childIndex].points[j] = {node.children[childIndex].points[j][1] + dx,
						   node.children[childIndex].points[j][2] + dy}
	 end
	 remeshNode( node.children[childIndex])
      end
   end

   if node.points then
      for i = 1, #childrenInRectangleSelect do
	 local index = childrenInRectangleSelect[i]
	 node.points[index] = {node.points[index][1] + dx, node.points[index][2] + dy}
      end
      remeshNode(node)
   end
end

local function arrayHas(tab, val)
   for index, value in ipairs(tab) do
      if value == val then
         return true
      end
   end

   return false
end

local function deletePoints(node)
   local newPoints = {}
   
   for i = 1, #node.points do
      if not arrayHas(childrenInRectangleSelect, i) then
         table.insert(newPoints, {node.points[i][1], node.points[i][2]})
      end
   end
   node.points = newPoints
   remeshNode(node)
end

local function  makeNewFolder()
   local shape = {
      folder = true,
      transforms =  {l={0,0,0,1,1,0,0, 0,0}},
      children = {}
   }

   if currentNode and not currentNode.folder then
      remeshNode(currentNode)
   end
   if (currentNode) then
      shape._parent = currentNode and currentNode._parent
      addShapeAfter(shape, currentNode)
   else
      local root = mylib.root

      shape._parent = root
      addShapeAtRoot(shape)
   end
   return shape
end


local function distancePointSegment(x,y, x1,y1, x2, y2)
   local A = x - x1
   local B = y - y1
   local C = x2 - x1
   local D = y2 - y1
   local dot    = A * C + B * D
   local len_sq = C * C + D * D
   local param = -1

   if (len_sq ~= 0) then
      param = dot / len_sq
   end

   local xx, yy
   if (param < 0) then
      xx = x1
      yy = y1
   elseif (param > 1) then
      xx = x2
      yy = y2
   else
      xx = x1 + param * C
      yy = y1 + param * D
   end

   local dx = x - xx
   local dy = y - yy
   return math.sqrt(dx * dx + dy*dy)
end

local function getClosestEdgeIndex(wx, wy, points)
   local closestEdgeIndex = 0
   local closestDistance = 99999999999999
   for j = 1, #points do
      local next = (j == #points and 1) or j+1
      local d = distancePointSegment(wx, wy, points[j][1], points[j][2], points[next][1], points[next][2])
      if (d < closestDistance) then
	 closestDistance = d
	 closestEdgeIndex = j
      end
   end
   return closestEdgeIndex
end





------------ editor specific code

local function drawUIAroundGraphNodes(w,h)
   local root = mylib.root -- needed for some functions

   local rows = {}

   
   local row0 = {
      startX=w - 200,
      startY=10,
   }
   row0.runningX = row0.startX
   row0.runningY = row0.startY

   table.insert(
      row0,
      {
         'add-something', ui.add, 'add a new thing',
         function()
            openedAddPanel = not openedAddPanel

         end
         

      }
   )
   if openedAddPanel then
      table.insert(
         row0,
         {
            'add-meta', ui.move, 'add a meta',
            function()
               --openedAddPanel = not openedAddPanel

               local shape = {
		  color = {1,0,0,1},
		  points = {{0,0}},
		  type = 'meta'
	       }
	       if (currentNode) then
		  shape._parent = currentNode and currentNode._parent
		  addShapeAfter(shape, currentNode)
	       else
		  local root = mylib.root

		  shape._parent = root
		  addShapeAtRoot(shape)
	       end

            end
            

         }
      )
      table.insert(
         row0,
         {
            'add-shape', ui.object_group, 'add a shape',
            function()
	       local shape = {
		  color = {0,0,0,1},
		  outline = true,
		  points = {},
	       }

	       if currentNode and not currentNode.folder then
		  remeshNode(currentNode)
	       end
	       if (currentNode) then
		  shape._parent = currentNode and currentNode._parent
		  addShapeAfter(shape, currentNode)
	       else
		  local root = mylib.root

		  shape._parent = root
		  addShapeAtRoot(shape)
	       end

	       editingMode = 'polyline'
	       editingModeSub = 'polyline-insert'

            end
            

         }
      )
      table.insert(
         row0,
         {
            'add-folder', ui.folder, 'add a folder',
            function()
	       local f = makeNewFolder()
	       editingMode = 'polyline'
	       editingModeSub = 'polyline-insert'

            end
            

         }
      )
      
   end
   

   

   table.insert(rows, row0)

   local row0b = {
      startX = w-40,
      startY = 10
      
   }
   row0b.runningX = row0b.startX
   row0b.runningY = row0b.startY
   table.insert(
      row0b,
      {
	 'show help', ui.help, 'show-shortcuts',
	 function()
	    showHelp = not showHelp
	    --local f = makeNewFolder()
	    --editingMode = 'polyline'
	    --editingModeSub = 'polyline-insert'

	 end
	 

      }
   )
   
   table.insert(rows, row0b)
   
   local row1 = {
      startX=w - 240,
      startY=50,
   }
   row1.runningX = row1.startX
   row1.runningY = row1.startY
   table.insert(row1, "whitespace")
   if (currentNode) then

      table.insert(
         row1,
         {
            'polyline-clone', ui.clone, 'clone',
            function()
               if (editingMode == 'polyline') then
                  local cloned = copyShape(currentNode)
                  cloned._parent = currentNode._parent
                  cloned.name = (cloned.name)
                  addShapeAfter(cloned, currentNode)
                  setCurrentNode(cloned)
               elseif  (editingMode == 'folder') then
                  local cloned = copyShape(currentNode)
                  cloned._parent = currentNode._parent
                  parentize(cloned)
                  cloned.name = (cloned.name)..' copy'
                  addShapeAfter(cloned, currentNode)
                  meshAll(cloned)
                  setCurrentNode(cloned)
               end
               
            end
      })
      
      table.insert(
         row1,
         {
            'delete', ui.delete, 'delete',
            function()
               deleteNode(currentNode)
            end
         }
      )

      -- table.insert(row1, "newline")
      
      table.insert(
         row1,
         {
            'badge', ui.badge, 'rename',
            function()
               changeName = not changeName
               local name = currentNode and currentNode.name
               changeNameCursor = name and utf8.len(name) or 1

            end
         }
      )
      table.insert(
         row1,
         {
            'connector', ui.parent, 'parentize',
            function()
               lastDraggedElement = {id = 'connector', pos = {row1.runningX, row1.runningY} }
            end
         }
      )
   end

   table.insert(row1, "newline")
   table.insert(row1, "newline")

   -- table.insert(row1, "whitespace")
   

   if (currentNode) then
      local index = getIndex(currentNode)
      if index > 1 then
         table.insert(
            row1,
            {
               'polyline-move-up', ui.move_up, 'move up in tree',
               function()
                  local taken_out = removeCurrentNode()
                  table.insert(taken_out._parent.children, index-1, taken_out)

               end
            }
         )
      end
   end
   table.insert(row1, "newline")
   --table.insert(row1, "whitespace")

   if (currentNode) then
      local index = getIndex(currentNode)
      if index < #currentNode._parent.children then
         table.insert(
            row1,
            {
               'polyline-move-mown', ui.move_down, 'move down in tree',
               function()
                  local taken_out = removeCurrentNode()
		  if (taken_out) then
		     table.insert(taken_out._parent.children, index+1, taken_out)
		  end
               end
            }
         )

      end
   end

   table.insert(rows, row1)


   local row2 = {
      startX=w - 300 - 160,
      startY=h - 150,
   }
   row2.runningX = row2.startX
   row2.runningY = row2.startY


   -- folder
   
   if editingMode == 'folder' and currentNode and currentNode.folder then
      table.insert(
         row2,
         {
            'transform-toggle', ui.transform, 'do the transformations',
            function()
               showTheParentTransforms = not showTheParentTransforms
            end
         }
      )

      table.insert(
         row2,
         {
            'folder-pan-pivot', ui.pan, 'pivot pooint',
            function()
               if editingModeSub == 'folder-pan-pivot' then
                  editingModeSub = nil
               else
                  editingModeSub = 'folder-pan-pivot'
               end
            end
         }
      )
      table.insert(
         row2,
         {
            'folder-move', ui.move,  'move whole',
            function()
               editingModeSub = 'folder-move'


            end
         }
      )
      table.insert(row2, 'whitespace')
      table.insert(
         row2,
         {
            'optimizer', ui.layer_group,  'optimize check',
            function()
               if (currentNode.optimizedBatchMesh) then
                  currentNode.optimizedBatchMesh = nil
               else
                  makeOptimizedBatchMesh(currentNode)
               end

            end
         }
      )
      table.insert(row2, "printOptimizedBatchMesh")
      table.insert(
         row2,
         {
            'change-perspective', ui.change,  'debug perspective thing',
            function()
               editingModeSub = 'change-perspective'
               local bbox = getBBoxOfChildren(currentNode.children)
               local t = currentNode.transforms._g
               local TLX,TLY = t:transformPoint( bbox.tl.x,bbox.tl.y )
               local BRX,BRY = t:transformPoint( bbox.br.x, bbox.br.y )
               perspective ={ {TLX, TLY},{BRX, TLY},{BRX, BRY}, {TLX, BRY}}



            end
         }
      )
      table.insert(row2, 'newline')
      -- do the grid
      table.insert(row2, '9grid')

      if currentNode and currentNode.folder and #currentNode.children >= 2 and #currentNode.children < 5 and  (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
         
         table.insert(
            row2,
            {
               'transition', ui.transition, 'pose animation',
               function()
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
            }

         )
      end

      if currentNode and currentNode.folder and #currentNode.children >= 4 and
	 (not isPartOfKeyframePose(currentNode) or currentNode.keyframes)  then
         table.insert(
            row2,
            {
               'joystick', ui.joystick, '4way pose animation',
               function()
                  if (currentNode.keyframes) then
                     currentNode.keyframes = nil
                     currentNode.lerpValue = nil
                     currentNode.lerpX = nil
                     currentNode.lerpY = nil
                     currentNode.frame = nil
                  else
                     currentNode.keyframes = #currentNode.children
                     currentNode.lerpX = 0.5
                     currentNode.lerpY = 0.5
                     currentNode.frame = 1
                  end

               end
            }

         )
         
      end

      -- avoid the 9grid from above
      table.insert(row2, "newline")
      table.insert(row2, "whitespace")
      table.insert(row2, "whitespace")

      
   end

   

   -- this is adirect copy of code
   if #childrenInRectangleSelect > 0  and type(childrenInRectangleSelect[1])=='table' then

      if currentNode and currentNode.folder then

	 table.insert(
            row2,
            {
               'children-flip-vertical', ui.flip_vertical, 'flip vertically',
               function()
                  flipGroup(currentNode, childrenInRectangleSelect, 1,-1)
               end
            }
         )
         table.insert(
            row2,
            {
               'children-flip-horizontal', ui.flip_horizontal, 'flip vertically',
               function()
                  flipGroup(currentNode, childrenInRectangleSelect, -1,1)
               end
            }
         )
         table.insert(
            row2,
            {
               'children-scale-up', ui.resize, 'scale up',
               function()
                  if LK.isDown('a') then
                     resizeGroup(currentNode, childrenInRectangleSelect, .75)
                  else
                     resizeGroup(currentNode, childrenInRectangleSelect, 0.95)
                  end

               end
            }
         )
         table.insert(
            row2, 
            {
               'children-scale-down', ui.resize, 'scale down',
               function()
                  if LK.isDown('a') then
                     resizeGroup(currentNode, childrenInRectangleSelect, 1.25)
                  else
                     resizeGroup(currentNode, childrenInRectangleSelect, 1.05)
                  end

               end
            }
         )
      end
      
   end
   
   
   
   
   
   ---  polyline
   
   if (editingMode == 'polyline' and currentNode and currentNode.type ~= 'meta') then
      table.insert(
         row2,
         {
            'polyline-edit', ui.polyline_edit, 'move point in poly',
            function()
               editingModeSub = 'polyline-edit'
            end
         }
      )
      if (not isPartOfKeyframePose(currentNode)) then

         table.insert(
            row2,
            {
               'polyline-insert', ui.polyline_add, 'add point to poly',
               function()
                  editingModeSub = 'polyline-insert'

               end
            }
         )

         table.insert(
            row2,
            {
               'polyline-remove', ui.polyline_remove, 'remove point from poly',
               function()
                  editingModeSub = 'polyline-remove'

               end
            }
         )
      end
      table.insert(row2, "whitespace")
      table.insert(
         row2,
         {
            'polyline-palette', ui.palette, 'pick color',
            function()
               if editingModeSub == 'polyline-palette' then
                  editingModeSub = 'polyline-edit'
               else
                  editingModeSub = 'polyline-palette'
               end
               
            end
         }
      )
      table.insert(
         row2,
         {
            'polyline-move', ui.move, 'move thing',
            function()
               editingModeSub = 'polyline-move'

            end
         }
      )
      table.insert(row2, "newline")
      table.insert(
         row2,
         {
            'mask', ui.mask, 'turn to mask',
            function()
               currentNode.mask = not currentNode.mask
               currentNode.hole = false
            end
         }
      )
      table.insert(
         row2,
         {
            'hole', ui.hole, 'turn to hole',
            function()
               currentNode.hole = not currentNode.hole
               currentNode.mask = false
            end
         }
      )
      table.insert(
         row2,
         {
            'close_stencil', ui.close_stencil, 'close stencil marker',
            function()
               currentNode.closeStencil = not currentNode.closeStencil
               currentNode.mask = false
               currentNode.hole = false
            end
         }
      )
      table.insert(row2, "whitespace")
      table.insert(
         row2,
         {
            'polyline-recenter', ui.pivot, 'recenter',
            function()
               editingModeSub = 'polyline-recenter'
               local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
               local w2 = (brx - tlx)/2
               local h2 = (bry - tly)/2
               for i=1, #currentNode.points do
                  currentNode.points[i][1] = currentNode.points[i][1] -  (tlx + w2)
                  currentNode.points[i][2] = currentNode.points[i][2] -  (tly + h2)
               end

            end
         }
      )
      table.insert(
         row2,
         {
            'rectangle-point-select', ui.select, 'select points in child',
            function()
               if #childrenInRectangleSelect > 0 then
		  editingModeSub = 0
		  childrenInRectangleSelect = {}
	       else
		  editingModeSub = 'rectangle-point-select'
	       end

            end
         }
      )

      table.insert(row2, "printChildrenInRectangleSelect")
      table.insert(row2, "newline")
      
      table.insert(
         row2,
         {
            'border', ui.polygon, 'border settings',
            function()
               currentNode.border = not currentNode.border
               if currentNode.border then
                  if currentNode.borderThickness == nil then
                     currentNode.borderThickness = 1
                  end
                  if currentNode.borderSpacing == nil then
                     currentNode.borderSpacing = 10
                  end
                  if currentNode.borderTension == nil then
                     currentNode.borderTension = 0
                  end
                  if currentNode.borderRandomizerMultiplier == nil then
                     currentNode.borderRandomizerMultiplier = 0
                  end
               end
            end
         }
      )
      table.insert(
         row2,
         {
            'rotate', ui.rotate, 'rotate with 22.5',
            function()
               rotateGroup(currentNode, 22.5)
            end
         }
      )

      if (currentNode) then
	 table.insert(
	    row2,
	    {
	       'enabledisabletext', ui.backdrop, 'enable/disable texture functionality',
	       function()
		  if currentNode.texture then
		     -- remove the texture
		     currentNode.texture = nil
		  else
		     -- add the texture
		     currentNode.texture = {}
		     currentNode.texture.url = ''
		     currentNode.texture.wrap='repeat'
		     currentNode.texture.filter='linear'
		  end
		  remeshNode(currentNode)
		  
	       end
         })
      end
      if (currentNode and currentNode.texture and (currentNode.type ~= 'rubberhose' and currentNode.type ~= 'bezier' )) then
	 table.insert(
	    row2,
	    {
	       'squish', ui.squish, 'enable/disable squishable',
	       function()
		  currentNode.texture.squishable = not  currentNode.texture.squishable
		  
		  remeshNode(currentNode)
		  
	       end
         })
      end

      if (currentNode.texture  and currentNode.type == 'rubberhose') then
	 table.insert(
	    row2,
	    {
	       'fit rubberhose to image', ui.backdropscale, 'fit rubberhose to image',
	       function()
		  local img =imageCache[currentNode.texture.url]
		  if not img then return end -- todo this exits early preventing a crash, but meh
		  local width, height = img:getDimensions( )
		  local   magic = 4.46
		  currentNode.data.length = height * magic
		  currentNode.data.width = width * 2
		  remeshNode(currentNode)
	       end
	    }
	 )
      end

      if (currentNode.texture and currentNode.type == 'bezier') then
	 table.insert(
	    row2,
	    {
	       'fit bezier to image', ui.backdropscale, 'fit bezier to image',
	       function()
		  local img =imageCache[currentNode.texture.url]
		  if not img then return end -- todo this exits early preventing a crash, but meh
		  local width, height = img:getDimensions( )
		  currentNode.points = {};
		  currentNode.points[1] = {0,0}
		  currentNode.points[2] = {0,height/2 }
		  currentNode.points[3] = {0,height}

		  -- todo, i dont like this here, its correct though and it will be fed into polyline as halfwidth
		  currentNode.data.width = width/2
		  
	       end
	    }
	 )
      end
      
      
      if (currentNode.texture and  currentNode.type ~= 'bezier' and  currentNode.type ~= 'rubberhose') then
	 table.insert(
	    row2,
	    {
	       'fit polygon to image', ui.backdropscale4, 'make fitting  4 point polygon for image',
	       function()
		  local img =imageCache[currentNode.texture.url]
		  if not img then return end -- todo this exits early preventing a crash, but meh
		  local width, height = img:getDimensions( )
		  --local mx, my = getMiddleOfPoints(currentNode.points)
		  local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
		  currentNode.points = {};
		  currentNode.points[1] = {0,0}
		  currentNode.points[2] = {width,0}
		  currentNode.points[3] = {width,height}
		  currentNode.points[4] = {0,height}

		  for i =1 , #currentNode.points do
		     currentNode.points[i][1] =  currentNode.points[i][1] + tlx
		     currentNode.points[i][2] =  currentNode.points[i][2] + tly
		  end
		  
		  remeshNode(currentNode)
	       end
         })
	 if currentNode.texture.squishable then
	    table.insert(
	       row2,
	       {
		  'fit polygon to image', ui.backdropscale5, 'make fitting  5 point polygon for image',
		  function()
		     local img =imageCache[currentNode.texture.url]
		     if not img then return end -- todo this exits early preventing a crash, but meh
		     local width, height = img:getDimensions( )
		     local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
		     currentNode.points = {};
		     currentNode.points[1] = {width/2,height/2}
		     
		     currentNode.points[2] = {0,0}
		     currentNode.points[3] = {width,0}
		     currentNode.points[4] = {width,height}
		     currentNode.points[5] = {0,height}
		     
		      for i =1 , #currentNode.points do
		     currentNode.points[i][1] =  currentNode.points[i][1] + tlx
		     currentNode.points[i][2] =  currentNode.points[i][2] + tly
		     end
		     remeshNode(currentNode)
		  end
	       }
	    )
	    table.insert(
	       row2,
	       {
		  'fit polygon to image', ui.backdropscale9, 'make fitting  9 point polygon for image',
		  function()
		     local img =imageCache[currentNode.texture.url]
		     if not img then return end -- todo this exits early preventing a crash, but meh
		     local width, height = img:getDimensions( )
		     local tlx, tly, brx, bry = getPointsBBox(currentNode.points)
		     currentNode.points = {};
		     
		     currentNode.points[1] = {width/2,height/2}
		     
		     currentNode.points[2] = {0,0}
		     currentNode.points[3] = {width/2,0}
		     currentNode.points[4] = {width,0}
		     currentNode.points[5] = {width,height/2}

		     currentNode.points[6] = {width,height}
		     currentNode.points[7] = {width/2,height}

		     currentNode.points[8] = {0,height}
		     currentNode.points[9] = {0,height/2}
		     
		     for i =1 , #currentNode.points do
		     currentNode.points[i][1] =  currentNode.points[i][1] + tlx
		     currentNode.points[i][2] =  currentNode.points[i][2] + tly
		     end
		     remeshNode(currentNode)
		  end
	       }
	    )
	 end
      end

      if currentNode.type == 'rubberhose' then
         LG.setFont(smallest)

         LG.setColor(1,1,1, 1)

         LG.print("flipflop",   100, 100 )

         local v =  h_slider("flop", 100, 120, 200,  currentNode.data.flop , -1, 1)
         if v.value ~= nil then
            currentNode.data.flop = v.value
         end
         LG.print("steps",   100, 130 )
         
         local v =  h_slider("steps", 100, 150, 200,  currentNode.data.steps , 1, 20)
         if v.value ~= nil then
            currentNode.data.steps = v.value
         end
         
      end
      if currentNode.type == 'bezier' then
         LG.setFont(smallest)

         LG.setColor(1,1,1, 1)

         LG.print("steps",   100, 130 )

         local v =  h_slider("steps", 100, 150, 200,  currentNode.data.steps , 1, 20)
         if v.value ~= nil then
            currentNode.data.steps = v.value
         end
      end
      
      
      table.insert(row2, "newline")
      if #childrenInRectangleSelect > 0 and type(childrenInRectangleSelect[1])=='number' then

         table.insert(
            row2,
            {
               'children-flip-vertical', ui.flip_vertical, 'flip vertically',
               function()
                  flipGroup(currentNode, childrenInRectangleSelect, 1,-1)
               end
            }
         )
         table.insert(
            row2,
            {
               'children-flip-horizontal', ui.flip_horizontal, 'flip vertically',
               function()
                  flipGroup(currentNode, childrenInRectangleSelect, -1,1)
               end
            }
         )
         table.insert(
            row2,
            {
               'children-scale-up', ui.resize, 'scale up',
               function()
                  if LK.isDown('a') then
                     resizeGroup(currentNode, childrenInRectangleSelect, .75)
                  else
                     resizeGroup(currentNode, childrenInRectangleSelect, 0.95)
                  end

               end
            }
         )
         table.insert(
            row2, 
            {
               'children-scale-down', ui.resize, 'scale down',
               function()
                  if LK.isDown('a') then
                     resizeGroup(currentNode, childrenInRectangleSelect, 1.25)
                  else
                     resizeGroup(currentNode, childrenInRectangleSelect, 1.05)
                  end

               end
            }
         )

      end
      
      
      
      
   end
   

   table.insert(rows, row2)


   local row3 = {
      startX=w -400,
      startY=10,
   }
   row3.runningX = row3.startX
   row3.runningY = row3.startY

   if (#childrenInRectangleSelect > 0) then
      table.insert(
	 row3,
	 {
	    'connector-group', ui.parent,'parentize',
	    function()
	       lastDraggedElement = {id = 'connector-group', pos = {row3.runningX, row3.runningY} }
	    end
	 }
      )
      
      table.insert(
	 row3,
	 {
	    'object_group', ui.object_group, 'turn group to object',
	    function()
	       for i =1, #childrenInRectangleSelect do
                  local n = childrenInRectangleSelect[i]
                  table.remove(n._parent.children, getIndex(n))
               end

               local shape = {
                  folder = true,
                  transforms =  {l={0,0,0,1,1,0,0, 0,0}},
                  children = {}
               }
               
               if not currentNode then
                  shape._parent = root
                  addShapeAtRoot(shape)
               else
                  addThingAtEnd(shape, currentNode)
               end
               local f = shape

               local tlx,tly,brx,bry = getGroupBBox(childrenInRectangleSelect)

               local w2 = (brx - tlx)/2
               local h2 = (bry - tly)/2
               local offX = -  (tlx + w2)
               local offY = -  (tly + h2)

               recenterGroup(childrenInRectangleSelect, offX, offY)
               f.children = childrenInRectangleSelect
               parentize(f._parent)
               setPos(f, -offX, -offY)
               meshAll(f._parent)
               childrenInRectangleSelect = {}


	    end
	 }
      )
      
   end



   table.insert(
      row3,
      {
	 'rectangle-select', ui.select, 'rectangle select',
	 function()
	    if (editingMode == 'rectangle-select') then
	       editingMode = nil
	       editingModeSub = nil
	       print('todo take me where i came from')
	    else
	       editingMode = 'rectangle-select'
	    end
	 end
      }
   )

   if (#childrenInRectangleSelect > 0) then
      table.insert(row3, "printChildrenInRectangleSelect")

      table.insert(
	 row3,
	 {
	    'group-move', ui.move, 'move group',
	    function()
	       if (editingModeSub == 'group-move') then
		  editingModeSub = nil
	       else
		  editingModeSub = 'group-move'
	       end
	       
	    end
	 }
      )
      
      
   end

   table.insert(rows, row3)


   for ri = 1, #rows do
      local row = rows[ri]
      for i =1, #row do
	 local v = row[i]
	 if (type(v) == 'table') then
	    
	    if imgbutton(v[1], v[2], row.runningX, row.runningY, v[3]).clicked then
	       v[4]()
	    end
	    
	    row.runningX = row.runningX + 40
	 end
	 if (type(v) == 'string') then
	    if v == 'newline' then
	       row.runningX = row.startX
	       row.runningY = row.runningY + 40
	    end
	    if v == 'whitespace' then
	       row.runningX = row.runningX + 40
	    end
	    -- the 'exceptions or lets call them hacks'
	    LG.setColor(1,1,1,1)
	    if v == 'printChildrenInRectangleSelect' then
	       if (#childrenInRectangleSelect > 0) then
		  LG.print(#childrenInRectangleSelect, row.runningX-40, row.runningY)
	       end
	    end
	    if v == 'printOptimizedBatchMesh' then
	       if currentNode and currentNode.optimizedBatchMesh and #currentNode.optimizedBatchMesh then
		  LG.print(#currentNode.optimizedBatchMesh, row.runningX-40, row.runningY)
	       end
	    end

	    if v =='9grid' then
	       LG.setColor(1,1,1,.5)
	       ----------
	       local runningX = row.runningX
	       local runningY = row.runningY
	       local oldRunningX = row.runningX


	       runningX = runningX - 6
	       function get6(node)
		  local tlx, tly, brx, bry = getDirectChildrenBBox(currentNode)
		  local mx = tlx + (brx - tlx)/2
		  local my = tly + (bry - tly)/2
		  return tlx, tly, brx, bry, mx, my
	       end
	       if (currentNode and currentNode.children and #currentNode.children > 0) then
		  LG.rectangle("fill", runningX, runningY, 20, 20)
		  if getUIRect('p1', runningX, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, tlx, tly)
		  end

		  LG.rectangle("fill", runningX+24, runningY, 20, 20)
		  if getUIRect('p2', runningX+24, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, mx, tly)
		  end

		  LG.rectangle("fill", runningX+48, runningY, 20, 20)
		  if getUIRect('p3', runningX+48, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, brx, tly)
		  end

		  runningY = runningY + 24

		  LG.rectangle("fill", runningX, runningY, 20, 20)
		  if getUIRect('p4', runningX, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, tlx, my)

		  end

		  LG.rectangle("fill", runningX+24, runningY, 20, 20)
		  if getUIRect('p5', runningX+24, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, mx, my)
		  end

		  LG.rectangle("fill", runningX+48, runningY, 20, 20)
		  if getUIRect('p6', runningX+48, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, brx, my)
		  end

		  runningY = runningY + 24

		  LG.rectangle("fill", runningX, runningY, 20, 20)
		  if getUIRect('p7', runningX, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, tlx, bry)
		  end

		  LG.rectangle("fill", runningX+24, runningY, 20, 20)
		  if getUIRect('p8', runningX+24, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, mx, bry)
		  end

		  LG.rectangle("fill", runningX+48, runningY, 20, 20)
		  if getUIRect('p9', runningX+48, runningY, 20,20).clicked then
		     local tlx, tly, brx, bry, mx, my = get6(currentNode)
		     setPivot(currentNode, brx, bry)

		  end

		  runningY = runningY + 40
	       end

	       row.runningX = oldRunningX + 80
	    end
	 end
      end
   end

   if currentNode then
      if (editingMode == 'polyline') and currentNode and currentNode.type ~= 'meta'  then
	 if currentNode and currentNode.border then

	    LG.setFont(smallest)
	    LG.setColor(1,1,1, 1)
	    LG.print("tension",   100, 100 )
	    
	    local v =  h_slider("splinetension", 100, 120, 200,  currentNode.borderTension , 0.00001, 1)
	    if v.value ~= nil then
	       currentNode.borderTension = v.value
	    end
	    LG.print("spacing",   100, 140 )

	    local v =  h_slider("splineSpacing", 100, 160, 200,  currentNode.borderSpacing , 2, 50)
	    if v.value ~= nil then
	       currentNode.borderSpacing = v.value
	    end
	    LG.print("thickness",   100, 180 )

	    local v =  h_slider("splineLinethick", 100, 200, 200,  currentNode.borderThickness , .1, 10)
	    if v.value ~= nil then
	       currentNode.borderThickness = v.value
	    end

	    LG.print("rnd multiplier",   100, 220 )

	    local v =  h_slider("splinerndmul", 100, 240, 200,  currentNode.borderRandomizerMultiplier , 0, 10)
	    if v.value ~= nil then
	       currentNode.borderRandomizerMultiplier = v.value
	    end
	 end
      end
   end
end


function mylib:mousepressed(x,y, button)
   lastDraggedElement = nil
   local root = mylib.root

   if editingMode == nil then
      editingMode = 'move'
   end

   if ( LK.isDown( 'lctrl' )) then
      local d = findMeshThatsHit(root, x, y, LK.isDown( 'lctrl' ) )
      if d then
         setCurrentNode(d)
         tryToCenterUI(d, root)
         editingMode = 'polyline'
      else
         setCurrentNode(nil)
         editingMode = nil
         editingModeSub = nil
      end
   end

   if editingMode == 'rectangle-select' or editingModeSub == 'rectangle-point-select'  then
      rectangleSelect.startP = {x=x, y=y}
   end

   if currentNode then
      local points = currentNode and currentNode.points
      local t = currentNode._parent.transforms._g

      local px, py = t:inverseTransformPoint( x, y )
      local scale = root.transforms.l[4]

      if editingModeSub == 'change-perspective' and currentNode then
	 function simplecheck(x2,y2, width)
	    if pointInRect(x,y, x2, y2, width,width) then
	       return true
	    end
	    return false
	 end
	 for i = 1, 4 do
	    if simplecheck(perspective[i][1] - 5,perspective[i][2] - 5, 10) then
	       lastDraggedElement = {id='perspective-corner', index=i}
	    end
	 end
      end

      if points then
	 if editingMode == 'polyline' and not mouseState.hoveredSomething   then
	    local w, h = getLocalDelta(t, 10, 10)
	    w = math.max(math.abs(w), math.abs(h))

	    local index =  0
	    for i = 1, #points do
	       if pointInRect(px,py,
			      points[i][1] - w/2,
			      points[i][2] - w/2,
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
   end
end


function mylib:mousereleased(x,y, button)
   local root = mylib.root
   if editingMode == 'move' then
      editingMode = nil
   end

   if editingModeSub == 'rectangle-point-select' then
      if  (rectangleSelect.startP and rectangleSelect.endP) then
	 print('why isnt this selcting children that have a parent?')
         childrenInRect = {}
         local parent = currentNode._parent or root
         local t = not  currentNode._parent and  parent.transforms._l or parent.transforms._g
         local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
         local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
         local tl = {x=math.min(sx, ex), y=math.min(sy, ey)}
         local br = {x=math.max(sx, ex), y=math.max(sy, ey)}
         local childrenInRect = {}

         if currentNode.points then
            for i=1, #currentNode.points do
               local p = currentNode.points[i]
               if p[1] >= tl.x and p[1] <= br.x  and  p[2] >= tl.y and p[2] <= br.y then
                  table.insert(childrenInRect, i)
               end
            end
         end
         childrenInRectangleSelect = childrenInRect
         rectangleSelect = {}
	 editingModeSub = nil
      end
   end

   if (editingMode == 'rectangle-select') then
      -- todo this doenst work 100% under ingame editing

      if (rectangleSelect.startP and rectangleSelect.endP) then
         local root = currentNode or root
	 print('why isnt this selcting children that have a parent again???')

         local t = (not currentNode and  root.transforms and root.transforms._l) or (root.transforms and root.transforms._g)
         
         if root ~= currentNode and root._parent then
            print('is this only hapening when ingame editing?')
            t = (not currentNode and  root._parent.transforms and root.transforms._g)
         end
         
         if t then
            local sx, sy = t:inverseTransformPoint( rectangleSelect.startP.x, rectangleSelect.startP.y )
            local ex, ey = t:inverseTransformPoint( rectangleSelect.endP.x, rectangleSelect.endP.y )
            --print(sx,sy, ex,ey)
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
      if not currentlyHoveredUINode then
         currentlyHoveredUINode = root
      end

      if (currentlyHoveredUINode and  currentlyHoveredUINode.folder) then
         removeGroupOfThings(childrenInRectangleSelect)
         local tlx,tly,brx,bry = getGroupBBox(childrenInRectangleSelect)
         local w2 = (brx - tlx)/2
         local h2 = (bry - tly)/2
         local offX = -  (tlx + w2)
         local offY = -  (tly + h2)

         recenterGroup(childrenInRectangleSelect, offX, offY)

         addGroupAtEnd(childrenInRectangleSelect, currentlyHoveredUINode)
         meshAll(currentlyHoveredUINode)
         childrenInRectangleSelect = {}
         scrollviewOffset = 0
      end

   end
   lastDraggedElement = nil
end


function mylib:mousemoved(x,y, dx, dy)
   local root = mylib.root

   currentlyHoveredUINode = nil
   local snap = false
   if  LK.isDown( 'r' ) then
      snap = true
   end

   if currentNode == nil and lastDraggedElement == nil and editingMode == 'move' and editingModeSub ~= 'group-move' and love.mouse.isDown(1) or LK.isDown('space') then
      
      local ddx,  ddy  = dx, dy
      -- when ingame editing, sometimes you edit a root with a parent 
      if root._parent ~= nil then
         print('todo this has issues too')
         ddx, ddy = getLocalDelta(root._parent.transforms._g, dx, dy)
      end

      love.mouse.setCursor(handCursor)

      movePos(root,  ddx,  ddy)
   else
      love.mouse.setCursor()
   end

   if editingMode == 'backdrop' and  editingModeSub == 'backdrop-move' and love.mouse.isDown(1) then
      backdrop.x = backdrop.x + dx / root.transforms.l[4]
      backdrop.y = backdrop.y + dy / root.transforms.l[4]
   end

   if editingModeSub == 'group-move' and love.mouse.isDown(1) then
      moveItemsInRectangleSelect(dx/ root.transforms.l[4], dy/ root.transforms.l[4])
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
         local ddx, ddy = getLocalDelta(currentNode._parent.transforms._g, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
	 movePos(currentNode, ddx, ddy)
      end
   end

   if (editingMode == 'folder' and editingModeSub ==  'folder-pan-pivot' and not isConnecting) then
      if (currentNode and currentNode.transforms and love.mouse.isDown(1)) then
         local ddx, ddy = getLocalDelta(currentNode.transforms._g, dx, dy)
         if snap then
            ddx = round2(ddx, 0)
            ddy = round2(ddy, 0)
         end
	 -- todo make a movePivot ?
	 setPivot(currentNode, currentNode.transforms.l[6] - ddx, currentNode.transforms.l[7] - ddy)

      end
   end

   if editingMode == 'polyline' and  editingModeSub == 'polyline-move' and love.mouse.isDown(1) and mouseState.hoveredSomething == false  then
      local points = currentNode and currentNode.points
      local dx3, dy3 = getLocalDelta(currentNode._parent.transforms._g, dx, dy)
      if snap then
         dx3 = round2(dx3, 0)
         dy3 = round2(dy3, 0)
      end

      if (points) then
         local beginIndex = 2 -- if first and last arent identical
         if not (points[1] == points[#points]) then
            beginIndex = 1
         end
         -- this one is to move single points, usefull for metadata
         -- the meshing will break on this
         if (points[1] == points[#points] and #points==1) then
            beginIndex = 1
         end

         for i = beginIndex, #points do
            local p = points[i]
            p[1] = p[1] + dx3
            p[2] = p[2] + dy3
         end
      end
   end

   if editingModeSub == 'change-perspective' then
      if lastDraggedElement then
         local index = lastDraggedElement.index
         if  snap then
            perspective[index][1] = round2(x,0)
            perspective[index][2] = round2(y,0)
         else
            if perspective[index] then
               perspective[index][1] = x
               perspective[index][2] = y
            end
         end
      end
   end

   if (editingMode == 'polyline') and (editingModeSub == 'polyline-edit') and (mouseState.hoveredSomething == false) then
      if (lastDraggedElement and lastDraggedElement.id == 'polyline') then
         local dragIndex = lastDraggedElement.index
         if dragIndex > 0 then
            local points = currentNode and currentNode.points
            local t = currentNode._parent.transforms._g
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

local function calcY(i)
   return (16 + (24 + 8 + 4) * i)
end
local function calcX(i)
   return ((24 + 8 + 4) * i)
end





local startTime = love.timer.getTime()

local function getNodeYPosition(node, lookFor)
   return recursiveGetRunningYForNode(node, lookFor, 0)
end

local function renderGraphNodes(node, level, startY, beginX, totalHeight)
   local w, h = getDimensions() 
   local beginRightX = beginX + level*6
   local rightX = beginRightX
   local nested = 0
   local runningY = 0
   local rowHeight = 27 - 5

   for i=1, #node.children do

      local yPos = -scrollviewOffset + startY  + runningY
      local child = node.children[i]
      local icon = ui.object_group

      if (child.folder ) then
         icon = child.open and ui.folder_open or ui.folder
      end
      if (child.line) then
         icon = ui.polyline
      end
      if (child.type and child.type == 'meta') then
         icon = ui.move
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
      if child.closeStencil then
         icon = ui.close_stencil
         color = {0,0,0}
      end

      local b = {}
      if (yPos >=0 and yPos <= h) then
         b = iconlabelbutton('object-group'..i, icon, color, child == currentNode, child.name or "", rightX , yPos, 128, -4)
      end

      if (child.folder and child.open ) then
         local add = renderGraphNodes(child, level + 1, runningY + startY + rowHeight, beginX, totalHeight)
         runningY = runningY + add
      end

      if b.clicked then
         local dblClicked = false
         if lastClickedGraphButton and lastClickedGraphButton.name == 'object-group'..i then
            local duration = (love.timer.getTime() - lastClickedGraphButton.time )
            if duration < .5 then
               dblClicked = true
               changeName=true
               changeNameCursor= child.name and #child.name or 0
            end
         end

         if not dblClicked then
            changeName=false
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
            lastClickedGraphButton = {name='object-group'..i, time=love.timer.getTime(), x= rightX , y=yPos, childName=child.name}
         end
      end

      if b.hover then
         currentlyHoveredUINode = node.children[i]
      end
      runningY = runningY + rowHeight
   end
   return runningY
end

function mylib:wheelmoved(x,y)
   local posx, posy = love.mouse.getPosition()
   local w, h = getDimensions() 
   local root = mylib.root

   --if posx > sceneGraph.x then
   -- scrollviewOffset = scrollviewOffset + y*24
   --else
   local scale = root.transforms.l[4]
   local ix1, iy1 = root.transforms._g:inverseTransformPoint(posx, posy)

   setScale(root,  scale *  ((y>0) and 1.1 or 0.9))

   local tl = root.transforms.l
   root.transforms._l =  love.math.newTransform( tl[1], tl[2], tl[3], tl[4], tl[5], tl[6],tl[7])
   root.transforms._g = root.transforms._l

   local ix2, iy2 = root.transforms._g:inverseTransformPoint(posx, posy)
   local dx = ix1 - ix2
   local dy = iy1 - iy2

   local dx3, dy3 = getGlobalDelta(root.transforms._g, dx, dy)

   movePos(root,  -dx3,  -dy3)

   --end
end


function mylib:load(arg)
   --if arg[#arg] == "-debug" then require("mobdebug").start() end
   --print(inspect(_G))

   --for i in pairs( _G) do
   --   print(i)
   --end
   
   shapeName = 'untitled'
   shapePath = ''
   LK.setKeyRepeat( true )
   editingMode = nil
   editingModeSub = nil
   --local ffont = "resources/fonts/cooper-bold-bt.ttf"
   --local ffont = "resources/fonts/Turbo Pascal Font.ttf"
   --local ffont = "resources/fonts/MonacoB.otf"
   --local ffont = "resources/fonts/agave.ttf"
   local ffont = "resources/fonts/WindsorBT-Roman.otf"
   local otherfont = "resources/fonts/NotoSansMono-Regular.ttf"
   
   --   local otherfont = "resources/fonts/Monaco.ttf"
   supersmallest = LG.newFont(ffont , 8)
   smallester = LG.newFont(ffont , 14)

   smallest = LG.newFont(ffont , 16)
   small = LG.newFont(ffont, 24)
   medium = LG.newFont( ffont, 32)
   large = LG.newFont(ffont , 48)

   canvas = LG.newCanvas()

   handCursor = love.mouse.getSystemCursor("hand")

   introSound = love.audio.newSource("resources/sounds/supermarket.wav", "static")
   introSound:setVolume(0.1)
   introSound:setPitch(0.9 + 0.2*love.math.random())
   --introSound:play()

   simple_format = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   }
   simple_format_colors = {
      {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
      {"VertexColor", "float", 4}, -- The x,y position of each vertex.
   }
   ui = {
      polyline = LG.newImage("resources/ui/polyline.png"),
      polyline_add = LG.newImage("resources/ui/polyline-add.png"),
      polyline_edit = LG.newImage("resources/ui/polyline-edit.png"),
      polyline_remove = LG.newImage("resources/ui/polyline-remove.png"),
      insert_link = LG.newImage("resources/ui/insert-link.png"),
      backdrop = LG.newImage("resources/ui/backdrop.png"),
      backdropscale = LG.newImage("resources/ui/backdropscale.png"),
      backdropscale4 = LG.newImage("resources/ui/backdropscale4.png"),
      backdropscale5 = LG.newImage("resources/ui/backdropscale5.png"),
      backdropscale9 = LG.newImage("resources/ui/backdropscale9.png"),
      squish = LG.newImage("resources/ui/squish.png"),
      grid = LG.newImage("resources/ui/grid.png"),
      palette = LG.newImage("resources/ui/palette.png"),
      pen = LG.newImage("resources/ui/pen.png"),
      pencil = LG.newImage("resources/ui/pencil.png"),
      polygon = LG.newImage("resources/ui/polygon.png"),
      add = LG.newImage("resources/ui/add.png"),
      remove = LG.newImage("resources/ui/remove.png"),
      delete = LG.newImage("resources/ui/delete.png"),
      move = LG.newImage("resources/ui/move.png"),
      visible = LG.newImage("resources/ui/visible.png"),
      not_visible = LG.newImage("resources/ui/not-visible.png"),
      resize = LG.newImage("resources/ui/resize.png"),
      opacity = LG.newImage("resources/ui/opacity.png"),
      settings = LG.newImage("resources/ui/settings.png"),
      badge = LG.newImage("resources/ui/badge.png"),
      layer_group = LG.newImage("resources/ui/layer-group.png"),
      object_group = LG.newImage("resources/ui/object-group.png"),
      rotate = LG.newImage("resources/ui/rotate.png"),
      transform = LG.newImage("resources/ui/transform.png"),
      next = LG.newImage("resources/ui/next.png"),
      previous = LG.newImage("resources/ui/previous.png"),
      lines = LG.newImage("resources/ui/lines.png"),
      lines2 = LG.newImage("resources/ui/lines2.png"),
      move_up = LG.newImage("resources/ui/move-up.png"),
      move_down = LG.newImage("resources/ui/move-down.png"),
      mesh = LG.newImage("resources/ui/mesh.png"),
      parent = LG.newImage("resources/ui/parent.png"),
      folder = LG.newImage("resources/ui/folder.png"),
      folder_open = LG.newImage("resources/ui/folderopen.png"),
      pivot = LG.newImage("resources/ui/pivot.png"),
      pan = LG.newImage("resources/ui/pan.png"),
      mask = LG.newImage("resources/ui/mask.png"),
      clone = LG.newImage("resources/ui/clone.png"),
      joystick = LG.newImage("resources/ui/joystick.png"),
      transition = LG.newImage("resources/ui/transition.png"),
      select = LG.newImage("resources/ui/select.png"),
      hole = LG.newImage("resources/ui/keyhole.png"),
      change = LG.newImage("resources/ui/change.png"),
      add_to_list = LG.newImage("resources/ui/add-to-list.png"),
      flip_vertical = LG.newImage("resources/ui/flip-vertical.png"),
      flip_horizontal = LG.newImage("resources/ui/flip-horizontal.png"),
      dopesheet = LG.newImage("resources/ui/spreadsheet.png"),
      curve = LG.newImage("resources/ui/curve.png"),
      close_stencil = LG.newImage("resources/ui/close-stencil.png"),
      help = LG.newImage("resources/ui/help.png"),
   }

   cursors = {
      hand= love.mouse.getSystemCursor("hand"),
      arrow= love.mouse.getSystemCursor("arrow")
   }
   
   palette = getAllPalettes()

   mouseState = {
      hoveredSomething = false,
      down = false,
      lastDown = false,
      click = false,
      offset = {x=0, y=0}
   }

   currentNode = nil
   currentlyHoveredUINode = nil

   backdrop = {
      grid = {cellsize=100}, -- cellsize is in px
      bg_color = {.53, .70, .76},
      visible = false,
      alpha = 0.5,
      x = 0,
      y = 0,
      scale = 1
   }

   fileDropPopup = nil
   showTheParentTransforms = false
   wireframe = false
   profiling = false
   simplifyValue = 0.2
   scrollviewOffset = 0
   lastDraggedElement = {}
   quitDialog = false
   rectangleSelect = {}
   childrenInRectangleSelect = {}
   splineTension = 0
   splineSpacing = 20
   splineLineThickness = 2
   dopesheet = {}
   dopesheetEditing = false
   cellCount =  12*1
   openFileScreen = false
   gatheredData = {}
   openedAddPanel = false
end

local function drawGrid()
   local root = mylib.root

   local scale = root.transforms.l[4]
   local size = backdrop.grid.cellsize * scale
   if (size < 10) then return end

   local w, h = getDimensions() 
   local vlines = math.floor(w/size)
   local hlines = math.floor(h/size)
   local xOffset = (root.transforms.l[1]) % size
   local yOffset = (root.transforms.l[2]) % size

   for x =0, vlines do
      LG.line(xOffset + x*size, 0,xOffset +  x*size, h)
   end
   for y =0, hlines do
      LG.line( 0, yOffset + y*size, w, yOffset +  y*size)
   end
end



local step = 0

local function labelPos(x,y)
   return x,y-20
end







function mylib:draw()

   local root = mylib.root
   if openFileScreen then
      handleMouseClickStart()

      renderOpenFileScreen(root)
   else

      if true then
	 step = step + 1
	 local mx,my = love.mouse.getPosition()

	 handleMouseClickStart()

	 local w, h = getDimensions() 
         LG.setScissor( 0, 0, w, h )
         local rightX = w - (64 + 500+ 10)/2

         LG.setColor(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3], 0.8)

         LG.rectangle('fill',0,0,w,h)

	 --         LG.clear(backdrop.bg_color[1], backdrop.bg_color[2], backdrop.bg_color[3], 0.4)
         

	 if  backdrop.visible then
	    LG.setColor(1,1,1, backdrop.alpha)
	    LG.draw(backdrop.image, backdrop.x, backdrop.y, 0, backdrop.scale, backdrop.scale)
	 end

	 LG.setWireframe(wireframe )
	 renderThings(root)
         comparemode, comparevalue = LG.getStencilTest( )

         if (comparemode ~= 'always' or comparevalue ~= 0) then
            print('disabling stencil for ya, you still hvae to fix something in the tree though, probably a missing close stencil command')
            LG.setStencilTest()
         end
         
	 if (currentlyHoveredUINode) then
	    local alpha = 0.5 + math.sin(step/100)
	    LG.setColor(alpha,1,1, alpha) -- i want this blinkiung

	    local editing = false 

	    if (editing and #editing > 0) then
	       local editingMesh = makeMeshFromVertices(editing)
	       LG.draw(editingMesh,  currentlyHoveredUINode._parent.transforms._g)
	    end
	 end

	 LG.setWireframe( false )
	 drawUIAroundGraphNodes(w,h)

	 if currentNode then
	    local t = root.transforms._l
	    local x,y = t:transformPoint(0,0)
	    LG.setColor(1,1,1)
	    LG.line(x-5, y, x+5, y)
	    LG.line(x, y-5, x, y+5)
	 end

	 if currentNode and currentNode.folder and  currentNode.transforms._g then
	    local t = currentNode.transforms.l
	    local pivotX, pivotY = currentNode.transforms._g:transformPoint( t[6], t[7] )
	    LG.setColor(0,0,0)
	    LG.circle("line", pivotX-1, pivotY, 10)
	    LG.setColor(1,1,1)
	    LG.circle("line", pivotX, pivotY, 10)
	 end

	 if editingModeSub == 'change-perspective' and currentNode then
	    if currentNode.children then
	       if (true) then
		  local bbox = getBBoxOfChildren(currentNode.children)
		  local t = currentNode.transforms._g
		  local TLX,TLY = t:transformPoint( bbox.tl.x,bbox.tl.y )
		  local BRX,BRY = t:transformPoint( bbox.br.x, bbox.br.y )

		  local ip1x, ip1y = t:inverseTransformPoint(perspective[1][1], perspective[1][2])
		  local ip2x, ip2y = t:inverseTransformPoint(perspective[2][1], perspective[2][2])
		  local ip3x, ip3y = t:inverseTransformPoint(perspective[3][1], perspective[3][2])
		  local ip4x, ip4y = t:inverseTransformPoint(perspective[4][1], perspective[4][2])

		  local source = {bbox.tl.x,bbox.tl.y,  bbox.br.x, bbox.br.y}
		  local dest = {{ip1x, ip1y},{ip2x, ip2y},{ip3x, ip3y},{ip4x, ip4y}}
		  for i = 1, #currentNode.children do

		     if currentNode.children[i].points then

			if (currentNode.children[i].mesh) then

			   local count = currentNode.children[i].mesh:getVertexCount()
			   local result = {}

			   for v = 1, count do
			      local x, y = currentNode.children[i].mesh:getVertex(v)
			      local r = transferPoint (x, y, source, dest)
			      table.insert(result, {r.x, r.y})
			   end

			   if currentNode.children[i].perspectiveMesh then
			      if #result ~= currentNode.children[i].perspectiveMesh:getVertexCount() then
				 currentNode.children[i].perspectiveMesh = LG.newMesh(simple_format, result , "triangles", "stream")
			      else
				 currentNode.children[i].perspectiveMesh:setVertices(result, 1, #result)
			      end
			   else
			      currentNode.children[i].perspectiveMesh = LG.newMesh(simple_format, result , "triangles", "stream")
			   end

			   LG.setColor(currentNode.children[i].color[1],
				       currentNode.children[i].color[2],
				       currentNode.children[i].color[3],0.3)
			   LG.draw(currentNode.children[i].perspectiveMesh,
				   currentNode.transforms._g)

			end
		     end
		  end
	       end

	       local TLX,TLY = perspective[1][1], perspective[1][2]
	       local BRX,BRY = perspective[3][1], perspective[3][2]

	       LG.setColor(1,1,1)

	       function simplehover(x,y, width)
		  if pointInRect(mx,my, x, y, width,width) then
		     LG.rectangle('fill', x,y, width,width)
		  else
		     LG.rectangle('line', x,y, width,width)
		  end
	       end

	       for i=1, 4 do
		  local nxt = i -1
		  if nxt < 1 then nxt = 4 end

		  LG.line(
		     perspective[i][1], perspective[i][2],
		     perspective[nxt][1], perspective[nxt][2]
		  )
	       end

	       simplehover( perspective[1][1]-5, perspective[1][2]-5, 10)
	       simplehover( perspective[2][1]-5, perspective[2][2]-5, 10)
	       simplehover( perspective[3][1]-5, perspective[3][2]-5, 10)
	       simplehover( perspective[4][1]-5, perspective[4][2]-5, 10)
	    end
	 end

	 if editingMode == 'polyline' and currentNode and currentNode.points then
	    local points =  currentNode and currentNode.points or {}
	    local globalX, globalY = currentNode._parent.transforms._g:inverseTransformPoint( mx, my )
	    local transformedPoints = {}
	    local t = currentNode._parent.transforms._g
	    for i=1, #points do
	       local lx, ly = t:transformPoint( points[i][1], points[i][2] )
	       table.insert(transformedPoints, {lx, ly})
	    end

	    LG.setLineWidth(2.0  )
	    LG.setColor(1,1,1)
	    local w, h = getLocalDelta(t, 10, 10)
	    w = math.max(math.abs(w), math.abs(h))
	    for i=1, #points do
	       local kind = "line"
	       if (editingModeSub == 'polyline-remove' or editingModeSub == 'polyline-edit') then
		  local scale = root.transforms.l[4]
		  if pointInRect(globalX,globalY,  points[i][1] - w/2, points[i][2] - w/2,   w, w) then
		     kind= "fill"
		     LG.print(round2(points[i][1],3)..", "..round2(points[i][2],3), 8, LG.getHeight()-32)

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
	       LG.setColor(0,0,0)
	       LG.rectangle(kind, dot_x-1, dot_y, dot_size, dot_size)

	       LG.setColor(1,1,1)
	       LG.rectangle(kind, dot_x, dot_y, dot_size, dot_size)
	    end


	 end
	 LG.setLineWidth(1)
	 LG.setColor(1,1,1, 1)

	 if (editingMode == 'rectangle-select' or  editingModeSub =='rectangle-point-select')  and rectangleSelect.startP and rectangleSelect.endP then
	    LG.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.startP.y)
	    LG.line(rectangleSelect.startP.x, rectangleSelect.endP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)
	    LG.line(rectangleSelect.startP.x, rectangleSelect.startP.y, rectangleSelect.startP.x, rectangleSelect.endP.y)
	    LG.line(rectangleSelect.endP.x, rectangleSelect.startP.y, rectangleSelect.endP.x, rectangleSelect.endP.y)

	 end

	 LG.setColor(1,1,1, 0.1)
	 drawGrid()

	 LG.push()

	 local s = 1

	 if (editingMode == 'folder' and currentNode and  currentNode.transforms) then

	    if (showTheParentTransforms) then
	       LG.setFont(smallest)

	       LG.setColor(1,1,1, 1)

	       local scrollerWidth = 314*2
	       LG.print("scale x and y",  labelPos(calcX(1), calcY(2))  )
	       if (currentNode.transforms.l[4] == currentNode.transforms.l[5]) then
		  local v =  h_slider("folder-scale-xy", calcX(1), calcY(2), scrollerWidth,  currentNode.transforms.l[5] , 0.00001, 10)
		  if (v.value ~= nil) then
		     setScale(currentNode, v.value)
		     editingModeSub = 'folder-scale'
		     LG.print(string.format("%0.2f", v.value), calcX(1), calcY(2))
		  end
	       end

	       LG.setColor(1,1,1, 1)
	       LG.print("scale x",  labelPos(calcX(1), calcY(3)) )
	       local v =  h_slider("folder-scale-x", calcX(1),  calcY(3) , scrollerWidth,  currentNode.transforms.l[4] , -2, 2)
	       if (v.value ~= nil) then
		  setScaleX(currentNode, v.value)
		  editingModeSub = 'folder-scale'
		  LG.print(string.format("%0.2f", v.value), calcX(1),  calcY(3))
	       end
	       LG.setColor(1,1,1, 1)
	       LG.print(
                  "scale y",  labelPos(calcX(1), calcY(4)) )

	       local v =  h_slider("folder-scale-y", calcX(1), calcY(4), scrollerWidth,  currentNode.transforms.l[5] , -2, 2)
	       if (v.value ~= nil) then
		  setScaleY(currentNode, v.value)
		  editingModeSub = 'folder-scale'
		  LG.print(string.format("%0.2f", v.value), calcX(1), calcY(4))
	       end
	       LG.setColor(1,1,1, 1)
	       LG.print("skew x",  labelPos(calcX(1), calcY(5)) )
	       local v = h_slider('folder_skew_x', calcX(1), calcY(5), scrollerWidth, currentNode.transforms.l[8] or 0,  -math.pi, math.pi )
	       if (v.value ~= nil) then
		  setSkewX(currentNode, v.value)
		  LG.print(string.format("%0.2f", v.value), calcX(1), calcY(5))
	       end
	       LG.setColor(1,1,1, 1)
	       LG.print("skew y",  labelPos(calcX(1), calcY(6))  )
	       local v = h_slider('folder_skew_y', calcX(1), calcY(6), scrollerWidth, currentNode.transforms.l[9] or 0,    -math.pi, math.pi )
	       if (v.value ~= nil) then
		  setSkewY(currentNode, v.value)
		  LG.print(string.format("%0.2f", v.value), calcX(1), calcY(6))
	       end

	       LG.setColor(1,1,1, 1)
	       LG.print("rotate", labelPos(calcX(1), calcY(7)) )
	       local v =  h_slider("folder-rotate", calcX(1),  calcY(7) , scrollerWidth,  currentNode.transforms.l[3] , -1 * math.pi, 1 * math.pi)

	       if (v.value ~= nil) then
		  setRotation(currentNode, v.value)
		  editingModeSub = 'folder-rotate'
		  LG.print(string.format("%0.2f", v.value), calcX(1), calcY(7))
	       end
	    end
	    LG.setFont(small)
	 end

	 if (editingModeSub == 'polyline-palette' and currentNode and currentNode.color) then

            local w,h = getDimensions()

            local thumbSize = 14
	    local colorsInRow = math.floor(w/(thumbSize))
            local paletteHeight = (math.ceil(#palette.colors / colorsInRow) +1 ) * thumbSize
            
	    for i = 1, #palette.colors do
	       local rgb = palette.colors[i].rgb
	       local x =  ((i-1) % colorsInRow) * (thumbSize)
	       local y = math.ceil((i) / colorsInRow)* (thumbSize)
	       
               y = h*0.75 - paletteHeight + y
               
	       if (currentNode.color[1] == rgb[1]/255 and
		   currentNode.color[2] == rgb[2]/255 and
		   currentNode.color[3] == rgb[3]/255) then
		  LG.setColor(1,1,1)
		  LG.rectangle("fill",x-2,y-2,thumbSize+4,thumbSize+4)
	       end

	       if rgbbutton('palette#'..i, {rgb[1]/255,rgb[2]/255,rgb[3]/255}, x,y ,thumbSize).clicked then
		  currentNode.color =  {rgb[1]/255,rgb[2]/255,rgb[3]/255, currentNode.color[4] or 1}
	       end


	    end
	    LG.setColor(1,1,1, 1)
	    LG.print("alpha",  labelPos(calcX(0), calcY(10)) )
	    local v =  h_slider("polyline_alpha", calcX(0), calcY(10), 100,  currentNode.color[4] , 0, 1)
	    if (v.value ~= nil) then
	       currentNode.color[4] = v.value
	       LG.print(currentNode.color[4], calcX(0), calcY(10))
	    end
	 end

	 if (editingMode == 'backdrop') then
	    if imgbutton('polyline-wireframe', ui.lines,  calcX(0), calcY(0), 'wireframe mode').clicked then
	       wireframe = not wireframe
	    end

	    if imgbutton('polyline-palette', ui.palette,  calcX(7), calcY(0), 'background palette').clicked then
	       editingModeSub = 'backdrop-palette'
	    end
	    if imgbutton('backdrop_visibility', backdrop.visible and ui.visible or ui.not_visible,  calcX(8), calcY(0), 'backdrop visible').clicked then
	       editingModeSub = nil
	       backdrop.visible = not backdrop.visible
	    end

	    LG.setColor(1,1,1, 1)
	    LG.print("simplify svg",  labelPos(calcX(1), calcY(1)) )
	    local v =  h_slider("simplify_value", calcX(1), calcY(1), 200,  simplifyValue , 0, 10)
	    if (v.value ~= nil) then
	       simplifyValue= v.value
	       LG.print(simplifyValue, calcX(1), 20)
	    end

	    if (backdrop.visible) then
	       if imgbutton('backdrop-move', ui.move, calcX(9), calcY(1), 'move backdrop').clicked then
		  if (editingModeSub == 'backdrop-move') then
		     editingModeSub = nil
		  else
		     editingModeSub = 'backdrop-move'
		  end
	       end

	       LG.setColor(1,1,1, 1)
	       LG.print("alpha",  labelPos(calcX(10), calcY(1)) )
	       local vslider =  h_slider("backdrop_alpha", calcX(10), calcY(1), 200, backdrop.alpha, 0, 1)
	       if (vslider.value ~= nil) then
		  backdrop.alpha = vslider.value
		  editingModeSub = nil
		  LG.print(string.format("%0.2f", vslider.value),  calcX(10), calcY(1))
	       end

	       LG.setColor(1,1,1, 1)
	       LG.print("scale",  labelPos(calcX(18), calcY(1)) )
	       local hslider =  h_slider("backdrop_scale", calcX(18), calcY(1), 200, backdrop.scale, 0, 5)
	       if (hslider.value ~= nil) then
		  backdrop.scale = hslider.value
		  editingModeSub = nil
		  LG.print(string.format("%0.2f", hslider.value),  calcX(18), calcY(1))
	       end
	    end

	    if (editingModeSub == 'backdrop-palette') then
	       local colorsInRow = 20
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
	    if currentNode  then
	       LG.setColor(.1,.1,.1, 0.6)
            end

            LG.setColor(0,0,0,1)
            
	    LG.setFont(smallester)
            LG.setScissor( 0, sceneGraph.topY, w, sceneGraph.height-20 )

            
            
	    local totalHeightGraphNodes = renderGraphNodes(root, 0, sceneGraph.topY, sceneGraph.x, sceneGraph.height -20)
            LG.setScissor()
            
	    if (scrollviewOffset > totalHeightGraphNodes) then
	       scrollviewOffset = totalHeightGraphNodes
	    end

	    LG.setFont(small)
	    local scrollBarH =  sceneGraph.height -20

	    if totalHeightGraphNodes > scrollBarH  then

	       local ding = scrollbarV('hierarchyslider', sceneGraph.x -40, sceneGraph.topY , scrollBarH, totalHeightGraphNodes, scrollviewOffset)
	       if ding.value ~= nil then
		  scrollviewOffset = ding.value
	       end
	    else

               
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
               if (changeName) then
                  local str =  currentNode and currentNode.name  or ""
                  local substr = string.sub(str, 1, changeNameCursor)
                  local cursorX = (LG.getFont():getWidth(substr))
                  local cursorH = (LG.getFont():getHeight(str))
                  LG.setColor(1,1,1,0.5)
                  LG.rectangle('fill', 0, h*0.75 - cursorH - 26, 300 + 20,  cursorH + 20 )
                  LG.setColor(1,1,1)
                  LG.print(str , 0, h*0.75 - cursorH - 20)
                  LG.setColor(1,1,1, math.abs(math.sin(step/ 100)))
                  LG.rectangle('fill', 0 + cursorX+2, h*0.75 - cursorH - 20,  2, cursorH)
                  LG.setColor(1,1,1)

                  if lastClickedGraphButton then
                     local sx = lastClickedGraphButton.x+24+12
                     local sy = lastClickedGraphButton.y+2
                     
                     LG.rectangle('line',sx,sy , 100,23)
                     LG.setColor(1,0.75,0.75)
                     LG.setFont(smallester)
                     LG.print(str,sx,sy)
                     LG.setColor(1,1,1)

                     local substr =(string.sub(str, 1 , changeNameCursor))
                     local cursorX = (LG.getFont():getWidth(substr))

                     LG.rectangle('line', sx + cursorX, sy, 1, 23)
                  end
               end
            end
         end

         LG.pop()
         LG.setFont(small)
         if not quitDialog then
            LG.print(tostring(love.timer.getFPS( )), 2,0)
            LG.print(shapeName, 64, 0)
         end

         if lastDraggedElement and (lastDraggedElement.id == 'connector' or lastDraggedElement.id == 'connector-group' ) then
            LG.line(lastDraggedElement.pos[1]+16, lastDraggedElement.pos[2]+16, mx, my)
         end

         local mousex = love.mouse.getX()
         local mousey = love.mouse.getY()

         doDopeSheetEditing(mousex, mousey)

         if quitDialog then
            local quitStr = "Quit? Seriously?! [ESC] "
            LG.setFont(large)
            LG.setColor(0,0,0, 1)
            LG.print(quitStr, 114, 11)
            LG.setColor(1,0.5,0.5, 1)
            LG.print(quitStr, 116, 13)
            LG.setColor(1,1,1, 1)
            LG.print(quitStr, 115, 12)
         end

         if fileDropPopup then
            LG.setFont(smallest)
            LG.setColor(1,1,1, 1)
            LG.rectangle("fill", 100, 100, w-200, h-200)
            LG.setColor(0,0,0)
            local name =  fileDropPopup:getFilename()
            LG.print("dropped file: "..name, 140, 120)
            
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
                  recursivelyMakeTextures(root)
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
                  recursivelyMakeTextures(root)
                  fileDropPopup = nil
               end

            else

               
               if currentNode and currentNode.texture then
                  local s, e = name:find("/experiments/", 1 , true)
                  
                  if s then
                     local url = name:sub(s)
                     
                     if (mylib.folderPath) then
                        local s1, e1 = mylib.folderPath:find("experiments/",1 , true)
                        if (e1) then
                           local prefix = mylib.folderPath:sub(e1+1)
                           local s2,e2 = url:find(prefix, 1, true)
                           local postfix = url:sub(e2+2)
                           print('postfix', postfix)
                           url = postfix
                        end
                     end
                     
                     LG.print("asset: "..url, 140, 150)
                     currentNode.texture.url= url
                     recursivelyMakeTextures(currentNode)
                  end
                  
               end
               
               if iconlabelbutton('ok-bye', ui.add, nil, false,  'ok bye',  120, 200).clicked then
                  fileDropPopup = nil
               end
            end
         end
      end
   end

   if showHelp then
      LG.setColor(1,1,1,1)
      LG.print('KEYBOARD SHORTCUTS:\nesc: quit\np: profile\n-: zoom out\n=: zoom in\n0: reset to origin\no: open file screen\nh: save hotrelaoded\ns: save normally\na: render big image\nj: save json\narrows + optional shift: move selection around', 50, 50)
   end
   
   local work =  nil
   console.draw()
   --LG.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)
   --LG.print(inspect(LG.getStats()), 10, 40)
end


function mylib:textinput(t)
   if (changeName and currentNode) then
      local str = currentNode and currentNode.name or ""
      if (changeNameCursor > #str) then
         changeNameCursor = #str
      end

      local a,b = split(str, changeNameCursor+1)
      local r = table.concat{a, t, b}
      changeNameCursor = changeNameCursor + 1
      currentNode.name = r
   end

   console.textinput(t)
end

function mylib:filedropped(file)
   fileDropPopup = file
end

function mylib:keypressed(key, scancode, isrepeat)
   local root = mylib.root

   console.keypressed(key, scancode, isrepeat)
   if not console.isEnabled() then
      if key == 'lshift' then
         editingMode = 'rectangle-select'
      end

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
      if #childrenInRectangleSelect == 0 then
         if key == 'down' then
            if currentNode then
               local index = getIndex(currentNode)
               if #currentNode._parent.children > index + 1 then
                  setCurrentNode(currentNode._parent.children[index + 1])
               end
            end
         end
         if key == 'up' then
            if currentNode then
               local index = getIndex(currentNode)
               if index > 1 then
                  setCurrentNode(currentNode._parent.children[index -1])
               end
            end
         end
      end

      if key == "escape" then
         if openFileScreen == true then
            openFileScreen = false
         elseif (editingModeSub ~= nil) then
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
         setPos(root, 0,0)
      end
      if key == 'o' and not changeName then 
         openFileScreen = not openFileScreen
         gatherData('')
      end

      if key == 'h' and not changeName then
         print('this will be used to hot reload the thing you are working on into the origin file')
         
         local readurl = mylib.folderPath..'/'..mylib.root.origin.path
         local writeurl = readurl
         
         local file = io.open(readurl, "r")
         local contents = file:read("*all")
         file:close()

         local parsed = (loadstring("return ".. contents)())

         if (mylib.root.origin.index >= 0) then
            parsed[mylib.root.origin.index] = mylib.root
         else
            parsed[1] = mylib.root
         end
         
         local toSave = {}
         for i=1 , #parsed do
            table.insert(toSave, copyShape(parsed[i]))
         end
         
         -- overwriting the file
         file = io.open(writeurl, "w")

         io.output(file)
         io.write(inspect(toSave, {indent=""}))
         io.close(file)

         -- saving a backup file
         file = io.open(writeurl..'-'..os.time()..'-.bak', "w")
         io.output(file)
         io.write(contents)
         io.close(file)

      end
      
      if (key == 's' and not changeName) then
         local path = shapePath..shapeName..".polygons.txt"
         local info = love.filesystem.getInfo( path )
         if (info) then
            shapeName = shapeName..'_'
            path =  shapePath..shapeName..".polygons.txt"
         end
         local toSave = {}
         for i=1 , #root.children do
            table.insert(toSave, copyShape(root.children[i]))
         end

         if #shapePath > 0 then
            love.filesystem.createDirectory( shapePath )
         end

         love.filesystem.write(path, inspect(toSave, {indent=""}))
         renderNodeIntoCanvas(root, LG.newCanvas(1024/2, 1024/2),  shapePath..shapeName..".polygons.png")
         local openURL = "file://"..love.filesystem.getSaveDirectory()..'/'..shapePath
         love.system.openURL(openURL)
      end

      if key == 'a' and not changeName then
         print("rendering a large file: "..shapePath..shapeName..".x4.polygons.png")
         renderNodeIntoCanvas(root, LG.newCanvas(1024*4, 1024*4),  shapePath..shapeName..".x4.polygons.png")

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
      if not changeName and (not currentNode or not currentNode.points) then
         if #childrenInRectangleSelect > 0 then
	    if LK.isDown("delete") then
	       local indexes = type(childrenInRectangleSelect[1]) == "number"
	       if indexes then
	       else
		  for i =1, #childrenInRectangleSelect do
		     local n = childrenInRectangleSelect[i]
		     table.remove(n._parent.children, getIndex(n))
		  end
	       end
	       childrenInRectangleSelect = {}
	    end
         end
         
      end
      

      if #childrenInRectangleSelect > 0 and currentNode then
         local shift = LK.isDown("lshift") or LK.isDown("rshift")
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
            print("yes i hope?")
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
end

return mylib
