local numbers = require 'lib.numbers'

function hex2rgb(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function starts_with(str, start)
   return str:sub(1, #start) == start
end
function pointInRect(x,y, rx, ry, rw, rh)
   if x < rx or y < ry then return false end
   if x > rx+rw or y > ry+rh then return false end
   return true
end
function pointInCircle(x,y, cx, cy, cr)
   local dx = x - cx
   local dy = y - cy
   local d  = math.sqrt ((dx*dx) + (dy*dy))

   return cr > d
end

function pointInEllipse (px, py, cx, cy, rx, ry, rotation)
    local rotation = rotation or 0
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    local dx  = (px - cx)
    local dy  = (py - cy)
    local tdx = cos * dx + sin * dy
    local tdy = sin * dx - cos * dy

    return (tdx * tdx) / (rx * rx) + (tdy * tdy) / (ry * ry) <= 1;
end

function distance(x1,y1,x2,y2)
   local nx = x2 - x1
   local ny = y2 - y1
   return math.sqrt(nx * nx + ny * ny)
end

function getPerpOfLine(x1,y1,x2,y2)
    local nx = x2 - x1
    local ny = y2 - y1
    local len = math.sqrt(nx * nx + ny * ny)
    nx = nx/len
    ny = ny/len
    return ny, nx
end


function lerpLine(x1,y1, x2,y2, t)
   return {x=numbers.lerp(x1, x2, t), y= numbers.lerp(y1, y2, t)}
end


function getEllipseCircumference(w, h)
   return 2 * math.pi * math.sqrt(((w*w) + (h*h))/2)
end

function getEllipseWidth(circumf, h)
   return math.sqrt((circumf*circumf) - (2* (h*h))) / math.sqrt(2)
end

function getEllipseWidth2(c, a)
   return  math.sqrt((((c/(2* math.pi))^2)*2) - a^2)
end


function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function split(str, pos)
   local offset = utf8.offset(str, pos) or 0
   return str:sub(1, offset-1), str:sub(offset)
end

function copyArray(original)
   local result = {}
   for i=1, #original do
      table.insert(result, round2(original[i], 3))
   end
   return result
end

