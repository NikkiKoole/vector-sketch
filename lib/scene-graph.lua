-- scene graph function are functions that are related to the child.parent relation of nodes
-- or to the transformation stuff inside of them

-- a bunch of global functions in editor need to go here

-- todo move parentize here

local graph = {}





--[[
function setX(node, x)
   node.transforms.l[1] = x
end

function setY(node, y)
   node.transforms.l[2] = y
end

function setPos(node, x, y)
   node.transforms.l[1] = x
   node.transforms.l[2] = y
end

function movePos(node, dx, dy)
   node.transforms.l[1] = node.transforms.l[1] + dx
   node.transforms.l[2] = node.transforms.l[2] + dy
end

function setRotation(node, r)
   node.transforms.l[3] = r
end

function setScale(node, s)
   node.transforms.l[4] = s
   node.transforms.l[5] = s
end

function setScaleX(node, sx)
   node.transforms.l[4] = sx
end

function setScaleY(node, sy)
   node.transforms.l[5] = sy
end

function setPivotX(node, px)
   node.transforms.l[6] = px
end

function setPivotY(node, py)
   node.transforms.l[7] = py
end

function setPivot(node, px, py)
   node.transforms.l[6] = px
   node.transforms.l[7] = py
end

function setSkewX(node, x)
   node.transforms.l[8] = x
end

function setSkewY(node, y)
   node.transforms.l[9] = y
end
--]]


return graph