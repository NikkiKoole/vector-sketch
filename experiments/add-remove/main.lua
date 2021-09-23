package.path = package.path .. ";../../?.lua"


require 'lib.editor-utils'
require 'lib.poly'
require 'lib.main-utils'
require 'lib.toolbox'

inspect = require 'vendor.inspect'


function love.keypressed(key)
   if key == 'escape' then
      love.event.quit()
   end

   if key == 'space' then
      root = root2
      local x1,y1 = group._globalTransform:transformPoint(0,0)
      removeNodeFrom(group, group._parent)


      addNodeInGroup(group, root2)
      renderThings(root)
      renderThings(root2)
      local x2,y2 = group._globalTransform:transformPoint(0,0)
      local dx, dy = x1-x2, y1-y2

      local x0,y0 = group._globalTransform:inverseTransformPoint(0,0)
      local dx1, dy1 =  group._globalTransform:inverseTransformPoint(dx,dy)
      print (x0-dx1, y0-dy1)
      group.transforms.l[1] = group.transforms.l[1] - (x0-dx1)
      group.transforms.l[2] = group.transforms.l[2] - (y0-dy1)

   end

end

function love.load()
   root = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={400,650,0,.25,.25,0,0}},
      children ={
	 {
	    folder = true,
	    transforms =  {l={-400,-500,0,1,1,0,0,0,0}},
	    name="group",
	    children ={{
		  name="child1 ",
		  color = {1,1,0, 0.8},
		  points = {{0,0},{200,0},{200,200},{0,200}},
	 }}}
      }
   }

   root2 = {
      folder = true,
      name = 'root',
      transforms =  {g={0,0,0,1,1,0,0},l={600,650,0,.25,.25,0,0}},
      children ={
	 {
	    folder = true,
	    transforms =  {l={-400,-500,0,1,1,0,0,0,0}},
	    name="group",
	    children ={{
		  name="child1 ",
		  color = {1,1,0, 0.8},
		  points = {{0,0},{200,0},{200,200},{0,200}},
	 }}}

      }
   }



   group = findNodeByName(root, 'group')

   parentize(root)
   parentize(root2)
   meshAll(root)
   meshAll(root2)
   renderThings(root)
   renderThings(root2)


end

function love.draw()
   renderThings(root)
   renderThings(root2)

end
