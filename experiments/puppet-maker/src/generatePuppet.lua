local parentize       = require 'lib.parentize'
local mesh            = require 'lib.mesh'
local bbox            = require 'lib.bbox'
local canvas          = require 'lib.canvas'
local render          = require 'lib.render'
local text            = require 'lib.text'
local node            = require 'lib.node'
local createFromImage = require 'src.createFromImage'

-- REMEMBER IF YOU SEE BLACK SHADOWING AROUND THE COLORED PARTS
-- ususally the fix is simply to call a redo..X in the changeX too.
-- for example in changeFeet
-- the location where you do this is quite im;ortant.

-- parentize.parentize(root)
-- redoFeet(biped, values)
-- biped:give('biped', bipedArguments(biped, values))
-- myWorld:emit("bipedAttachFeet", biped)
-- mesh.meshAll(root)


local function getPNGMaskUrl(url)
   return text.replace(url, '.png', '-mask.png')
end

function getAngleAndDistance(x1, y1, x2, y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local angle = math.atan2(dy, dx)
   local distance = math.sqrt((dx * dx) + (dy * dy))

   return angle, distance
end

function setAngleAndDistance(sx, sy, angle, distance)
   local newx = sx + distance * math.cos(angle)
   local newy = sy + distance * math.sin(angle)
   return newx, newy
end

-- getting positions for attachments via the 8way meta object
-- this should also work in the furture for parts that are flipped vertically
-- this way i can, for free, have double the amount of shapes, no extra sprites needed.

-- another thing that needs to happen, now i just deirectly get apoint on the 8way polygon
-- i want to lerp between 2 or more points to get a position, this way i can move attachements positions in the editor

local function getMeta(parent)
   for i = 1, #parent.children do
      if (parent.children[i].type == 'meta' and #parent.children[i].points == 8) then
         return parent.children[i]
      end
   end
end

-- this one is fro the case where i dont have a potato component around
function getHeadPointsFromValues(values, headPart, headPartName)
   local parent = headPart --e.potato.head
   local parentName = headPartName -- e.potato.values.potatoHead and 'body' or 'head'
   local meta = getMeta(parent)

   if meta then
      local flipx = values[parentName].flipx or 1
      local flipy = values[parentName].flipy or 1
      local points = meta.points
      local newPoints = getFlippedMetaObject(flipx, flipy, points)

      return newPoints
   end

   return { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
end

function getHeadPoints(e)
   local parent = e.potato.head
   -- print(e.potato)
   local parentName = e.potato.values.potatoHead and 'body' or 'head'
   local meta = getMeta(parent)

   if meta then
      local flipx = e.potato.values[parentName].flipx or 1
      local flipy = e.potato.values[parentName].flipy or 1
      local points = meta.points
      local newPoints = getFlippedMetaObject(flipx, flipy, points)

      return newPoints
   end

   return { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
end

function getFlippedMetaObject(flipx, flipy, points)
   local tlx, tly, brx, bry = bbox.getPointsBBox(points)
   local mx = tlx + (brx - tlx) / 2
   local my = tly + (bry - tly) / 2
   local newPoints = {}

   for i = 1, #points do
      local newY = points[i][2]
      if flipy == -1 then
         local dy = my - points[i][2]
         newY = my + dy
      end
      local newX = points[i][1]
      if flipx == -1 then
         local dx = mx - points[i][1]
         newX = mx + dx
      end
      newPoints[i] = { newX, newY }
   end
   local temp = copy3(newPoints)
   if flipy == -1 and flipx == 1 then
      newPoints[1] = temp[5]
      newPoints[2] = temp[4]
      newPoints[3] = temp[3]
      newPoints[4] = temp[2]
      newPoints[5] = temp[1]
      newPoints[6] = temp[8]
      newPoints[7] = temp[7]
      newPoints[8] = temp[6]
   end
   if flipx == -1 and flipy == 1 then
      newPoints[1] = temp[1]
      newPoints[2] = temp[8]
      newPoints[3] = temp[7]
      newPoints[4] = temp[6]
      newPoints[5] = temp[5]
      newPoints[6] = temp[4]
      newPoints[7] = temp[3]
      newPoints[8] = temp[2]
   end
   if flipx == -1 and flipy == -1 then
      newPoints[1] = temp[5]
      newPoints[2] = temp[6]
      newPoints[3] = temp[7]
      newPoints[4] = temp[8]
      newPoints[5] = temp[1]
      newPoints[6] = temp[2]
      newPoints[7] = temp[3]
      newPoints[8] = temp[4]
   end


   return newPoints
end

function guyChildren(editingGuy)
   local eg = editingGuy
   if (eg.values.potatoHead) then
      return {
          eg.body,
          eg.leg1, eg.leg2, eg.leghair1, eg.leghair2, eg.feet1, eg.feet2,
          eg.arm1, eg.arm2, eg.armhair1, eg.armhair2, eg.hand1, eg.hand2,
      }
   else
      return {
          eg.body, eg.neck, eg.head,
          eg.leg1, eg.leg2, eg.leghair1, eg.leghair2, eg.feet1, eg.feet2,
          eg.arm1, eg.arm2, eg.armhair1, eg.armhair2, eg.hand1, eg.hand2,
      }
   end
end

function bipedArguments(editingGuy)
   return {
       guy = editingGuy.guy,
       body = editingGuy.body,
       neck = editingGuy.neck,
       head = editingGuy.head,
       leg1 = editingGuy.leg1,
       leg2 = editingGuy.leg2,
       leghair1 = editingGuy.leghair1,
       leghair2 = editingGuy.leghair2,
       feet1 = editingGuy.feet1,
       feet2 = editingGuy.feet2,
       armhair1 = editingGuy.armhair1,
       armhair2 = editingGuy.armhair2,
       arm1 = editingGuy.arm1,
       arm2 = editingGuy.arm2,
       hand1 = editingGuy.hand1,
       hand2 = editingGuy.hand2,
       values = editingGuy.values
   }
end

function potatoArguments(editingGuy)
   --print(editingGuy)
   -- print('potato argumnets', editingGuy.teeth)
   return {
       head = editingGuy.values.potatoHead and editingGuy.body or editingGuy.head,
       eye1 = editingGuy.eye1,
       eye2 = editingGuy.eye2,
       pupil1 = editingGuy.pupil1,
       pupil2 = editingGuy.pupil2,
       ear1 = editingGuy.ear1,
       ear2 = editingGuy.ear2,
       brow1 = editingGuy.brow1,
       brow2 = editingGuy.brow2,
       nose = editingGuy.nose,
       values = editingGuy.values,
   }
end

function mouthArguments(editingGuy)
   return {
       values = editingGuy.values,
       teeth = editingGuy.teeth,
       upperlip = editingGuy.upperlip,
       lowerlip = editingGuy.lowerlip,
       head = editingGuy.values.potatoHead and editingGuy.body or editingGuy.head,
   }
end

function arrangeBrows()
   local bends = { { 0, 0, 0 }, { 1, 0, -1 }, { -1, 0, 1 }, { 1, 0, 1 }, { -1, 0, -1 }, { 1, 0, 0 },
       { -1, 0, 0 }, { 0, -1, 1 }, { 0, 1, 1 }, { -1, 1, 1 }, }

   local p = findPart('brows').imgs
   local img = mesh.getImage(p[editingGuy.values.brows.shape])
   local width, height = img:getDimensions()
   local multiplier = (height / 2)
   local picked = bends[editingGuy.values.browsDefaultBend]

   local b1p = { picked[1] * multiplier, picked[2] * multiplier, picked[3] * multiplier }

   height = height * editingGuy.values.browsWideMultiplier
   -- todo currently I am just mirroring the brows, not always what we want
   editingGuy.brow1.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
   editingGuy.brow2.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
   editingGuy.brow2.transforms.l[4] = -1
   -- brow2.transforms.l[5] = 3
   --brow2.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
end

local function getIndexOfGraphicPart(part)
   if part.children then
      local metaIndex = nil
      for i = 1, #part.children do
         if part.children[i].type == 'meta' then
            metaIndex = i
         end
      end
      if metaIndex then return metaIndex - 1 end
      return 1
   end
end

function helperTexturedCanvas(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, optionalSettings,
                              renderPatch)
   local img = mesh.getImage(url, optionalSettings)
   local maskUrl = getPNGMaskUrl(url)
   local mask = mesh.getImage(maskUrl)
   --local cnv = love.image.newImageData(url) -- canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, renderPatch)
   local cnv = canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, renderPatch)

   return cnv
end

function redoGraphicHelper(part, name, values)
   -- print(name, part.children, #part.children)

   local index = getIndexOfGraphicPart(part)
   local p = part.children and part.children[index] or part
   if p.texture and p.texture.url then
      local textured, url = partToTexturedCanvas(name, values, p.texture)
      --print(textured)
      if p.texture.canvas then
         --   print(p.texture.canvas)
         p.texture.canvas:release()
      end
      local m = mesh.makeMeshFromSibling(p, textured)
      textured:release()
      p.texture.canvas = m
      --p.texture.texture = textured
      -- print(' texture updat for', name)
   else
      print('not foing texture updat for', name)
   end
   return part
end

function partToTexturedCanvas(partName, values, optionalImageSettings)
   --print('partToTexturedCanvas', partName)
   local p = findPart(partName)
   local url = p.imgs[values[partName].shape]

   local flipX = values[partName].flipx or 1
   local flipY = values[partName].flipy or 1

   --print(partName, flipX, flipY)
   local renderPatch = {}

   if (partName == 'head' and not values.potatoHead) or (partName == 'body' and values.potatoHead) then
      if not isNullObject('skinPatchSnout', values) then
         local p = {}

         p.imageData = partToTexturedCanvas('skinPatchSnout', values)
         p.sx = values.skinPatchSnoutScaleX
         p.sy = values.skinPatchSnoutScaleY
         p.r = values.skinPatchSnoutAngle
         p.tx = values.skinPatchSnoutX
         p.ty = values.skinPatchSnoutY
         table.insert(renderPatch, p)
      end
      if not isNullObject('skinPatchEye1', values) then
         local p     = {}
         p.imageData = partToTexturedCanvas('skinPatchEye1', values)
         p.sx        = values.skinPatchEye1ScaleX
         p.sy        = values.skinPatchEye1ScaleY
         p.r         = values.skinPatchEye1Angle
         p.tx        = values.skinPatchEye1X
         p.ty        = values.skinPatchEye1Y
         table.insert(renderPatch, p)
      end
      if not isNullObject('skinPatchEye2', values) then
         local p     = {}
         p.imageData = partToTexturedCanvas('skinPatchEye2', values)
         p.sx        = values.skinPatchEye2ScaleX
         p.sy        = values.skinPatchEye2ScaleY
         p.r         = values.skinPatchEye2Angle
         p.tx        = values.skinPatchEye2X
         p.ty        = values.skinPatchEye2Y
         table.insert(renderPatch, p)
      end
   end
   --print(url)
   local texturedcanvas = helperTexturedCanvas(
           url,
           textures[values[partName].bgTex],
           palettes[values[partName].bgPal],
           values[partName].bgAlpha,
           textures[values[partName].fgTex],
           palettes[values[partName].fgPal],
           values[partName].fgAlpha,
           values[partName].texRot,
           texscales[values[partName].texScale],
           palettes[values[partName].linePal],
           values[partName].lineAlpha,
           flipX, flipY,
           optionalImageSettings,
           renderPatch
       )
   return texturedcanvas, url
end

function isNullObject(partName, values)
   local p = findPart(partName)
   local url = p.imgs[values[partName].shape]
   return url == 'assets/null.png'
end

function createHairVanillaLine(values, hairLine)
   local textured, url = partToTexturedCanvas('hair', values)

   return createFromImage.vanillaline(
           url, textured,
           values.hairWidthMultiplier, values.hairTension, hairLine)
end

function createBrowBezier(values, points)
   local textured, url = partToTexturedCanvas('brows', values)

   return createFromImage.bezier(
           url, textured,
           values.browsWidthMultiplier, points)
end

function createUpperlipBezier(values, points)
   local textured, url = partToTexturedCanvas('upperlip', values)

   --local w,h = mesh.getImage(url):getDimensions()
   --local r = 0.5 + love.math.random() * 0.5
   --local p = { { (h / 2) * r, 0 }, { 0, -w * love.math.random() }, { (-h / 2) * r, 0 } }

   return createFromImage.bezier(url, textured, 1, points)
end

function createLowerlipBezier(values, points)
   local textured, url = partToTexturedCanvas('lowerlip', values)
   return createFromImage.bezier(url, textured, 1, points)
end

function createArmRubberhose(armNr, values, points)
   local flop = armNr == 1 and values.arm1flop or values.arm2flop

   local textured, url = partToTexturedCanvas('arms', values)

   return createFromImage.rubberhose(
           url, textured,
           flop,
           values.armLength,
           values.armWidthMultiplier,
           points, flop * -1)
end

function createArmHairRubberhose(armNr, values, points)
   local flop = armNr == 1 and values.arm1flop or values.arm2flop
   local textured, url = partToTexturedCanvas('armhair', values)

   return createFromImage.rubberhose(
           url, textured,
           flop,
           values.armLength,
           values.armWidthMultiplier,
           points, flop)
end

function createLegHairRubberhose(armNr, values, points)
   local flop = armNr == 1 and values.leg1flop or values.leg2flop
   local textured, url = partToTexturedCanvas('leghair', values)

   return createFromImage.rubberhose(
           url, textured,
           flop,
           leglengths[values.legLength],
           values.legWidthMultiplier,
           points, flop)
end

function createLegRubberhose(legNr, values, points)
   local flop = legNr == 1 and values.leg1flop or values.leg2flop
   local textured, url = partToTexturedCanvas('legs', values)

   return createFromImage.rubberhose(
           url, textured,
           flop
           , leglengths[values.legLength],
           values.legWidthMultiplier,
           points, flop * -1)
end

function createNeckRubberhose(values, points)
   local flop = 1 -- this needs to be set accoridng to how th eneck is positioned
   local textured, url = partToTexturedCanvas('neck', values)
   return createFromImage.rubberhose(
           url, textured,
           flop,
           values.neckLength,
           values.neckWidthMultiplier,
           points)
end

function updateChild(container, oldValue, newResult)
   --print('updateChild', container.name, 'looking for')
   --print(oldValue and oldValue.name)
   --print(newResult and newResult.name)
   --prof.push('update-child')
   for i = 1, #container.children do
      if container.children[i] == oldValue then
         --print('changed something', container.name)

         container.children[i] = newResult
         if (container.children[i].transforms) then
            local oldTransforms = oldValue.transforms and copy3(oldValue.transforms.l)
            -- I need to get t the pivot point from the new thing.
            if newResult.transforms then
               oldTransforms[6] = newResult.transforms.l[6]
               oldTransforms[7] = newResult.transforms.l[7]
            end
            --print(oldTransforms[1], oldTransforms[2])
            container.children[i].transforms.l = oldTransforms
         end
         return container.children[i]
      end
   end
   --prof.pop('update-child')
end

function copyAndRedoGraphic(name, values)
   local part = findPart(name)
   local partArray = part.p
   local original = partArray[values[name].shape]
   return redoGraphicHelper(copy3(original), name, values)
end

function removeChild(elem)
   if elem._parent then
      local index = node.getIndex(elem)
      if index >= 0 then table.remove(elem._parent.children, index) end
   end
end

function attachAllMouthParts(guy)
   removeChild(guy.teeth)
   removeChild(guy.upperlip)
   removeChild(guy.lowerlip)

   local addTo = guy.head --guy.values.potatoHead and guy.body or guy.head
   if (guy.values.overBite == true) then
      table.insert(addTo.children, guy.lowerlip)
      table.insert(addTo.children, guy.teeth)
      table.insert(addTo.children, guy.upperlip)
   else
      table.insert(addTo.children, guy.teeth)
      table.insert(addTo.children, guy.lowerlip)
      table.insert(addTo.children, guy.upperlip)
   end
end

function attachAllFaceParts(guy)
   removeChild(guy.eye1)
   removeChild(guy.eye2)
   removeChild(guy.pupil1)
   removeChild(guy.pupil2)
   removeChild(guy.nose)
   removeChild(guy.brow1)
   removeChild(guy.brow2)
   removeChild(guy.ear1)
   removeChild(guy.ear2)
   removeChild(guy.hair)


   local addTo = guy.values.potatoHead and guy.body or guy.head

   table.insert(addTo.children, guy.eye1)
   table.insert(addTo.children, guy.eye2)
   table.insert(addTo.children, guy.pupil1)
   table.insert(addTo.children, guy.pupil2)

   if (guy.values.earUnderHead == true) then
      table.insert(addTo.children, 1, guy.ear1)
      table.insert(addTo.children, 1, guy.ear2)
   else
      table.insert(addTo.children, guy.ear1)
      table.insert(addTo.children, guy.ear2)
   end




   table.insert(addTo.children, guy.brow1)
   table.insert(addTo.children, guy.brow2)
   table.insert(addTo.children, guy.nose)
   table.insert(addTo.children, guy.hair)


   attachAllMouthParts(guy)
   changePart('hair', guy.values)
end

function changePart(name)
   local values = editingGuy.values
   local guy = editingGuy.guy
   local container = values.potatoHead and editingGuy.body or editingGuy.head

   if name == 'body' then
      editingGuy.body = updateChild(guy, editingGuy.body, copyAndRedoGraphic('body', values))
      parentize.parentize(root)

      if (values.potatoHead) then
         attachAllFaceParts(editingGuy)
         changePart('hair')
      end

      mesh.meshAll(root)
      render.justDoTransforms(root) -- why is this needed for body?? (because we need the correct points to attach other things too)

      biped:give('biped', bipedArguments(editingGuy))
      myWorld:emit("bipedAttachHead", biped)
      myWorld:emit("bipedAttachLegs", biped) -- todo
      myWorld:emit("bipedAttachArms", biped) -- todo
      myWorld:emit("bipedAttachHands", biped) -- todo
   elseif name == 'skinPatchSnout' then
      if values.potatoHead then
         changePart('body')
      else
         changePart('head')
      end
   elseif name == 'skinPatchEye1' then
      if values.potatoHead then
         changePart('body')
      else
         changePart('head')
      end
   elseif name == 'skinPatchEye2' then
      if values.potatoHead then
         changePart('body')
      else
         changePart('head')
      end
   elseif name == 'neck' then
      editingGuy.neck = updateChild(guy, editingGuy.neck, createNeckRubberhose(values, editingGuy.neck.points))
   elseif name == 'head' then
      editingGuy.head = copyAndRedoGraphic('head', values)
      guy.children = guyChildren(editingGuy)
      editingGuy.head.transforms.l[4] = values.headWidthMultiplier
      editingGuy.head.transforms.l[5] = values.headHeightMultiplier

      if (not values.potatoHead) then
         attachAllFaceParts(editingGuy)
      end
      myWorld:emit("bipedAttachHead", biped)
      changePart('hair') ----
   elseif name == 'hair' then
      if isNullObject(name, values) then
         editingGuy.hair = updateChild(container, editingGuy.hair, copy3(nullChild))
         --  print('hair', hair)
         --print('hair was null ')
      else
         -- this was a change but isnt needed anymore I  think
         local headPart = values.potatoHead and editingGuy.body or editingGuy.head
         local headPartName = values.potatoHead and 'body' or 'head'
         local hp = getHeadPointsFromValues(values, headPart, headPartName)

         local hairLine = { hp[7], hp[8], hp[1], hp[2], hp[3] }
         editingGuy.hair = updateChild(container, editingGuy.hair, createHairVanillaLine(values, hairLine))
      end
   elseif name == 'ears' then
      editingGuy.ear1 = updateChild(container, editingGuy.ear1, copyAndRedoGraphic('ears', values))
      editingGuy.ear2 = updateChild(container, editingGuy.ear2, copyAndRedoGraphic('ears', values))
   elseif name == 'teeth' then
      local r = copyAndRedoGraphic('teeth', values)
      --print(inspect(editingGuy.teeth))
      editingGuy.teeth = updateChild(container, editingGuy.teeth, r)
      print(editingGuy.teeth)
   elseif name == 'eyes' then
      editingGuy.eye1 = updateChild(container, editingGuy.eye1, copyAndRedoGraphic('eyes', values))
      editingGuy.eye2 = updateChild(container, editingGuy.eye2, copyAndRedoGraphic('eyes', values))
   elseif name == 'pupils' then
      editingGuy.pupil1 = updateChild(container, editingGuy.pupil1, copyAndRedoGraphic('pupils', values))
      editingGuy.pupil2 = updateChild(container, editingGuy.pupil2, copyAndRedoGraphic('pupils', values))
   elseif name == 'brows' then
      arrangeBrows()
      editingGuy.brow1 = updateChild(container, editingGuy.brow1, createBrowBezier(values, editingGuy.brow1.points))
      editingGuy.brow2 = updateChild(container, editingGuy.brow2, createBrowBezier(values, editingGuy.brow2.points))
   elseif name == 'nose' then
      -- print('changeart nose')
      if isNullObject(name, values) then
         print('nullobject nose')
         editingGuy.nose = updateChild(container, editingGuy.nose, copy3(nullFolder))
      else
         print('not nullobject nose', editingGuy.nose)
         editingGuy.nose = updateChild(container, editingGuy.nose, copyAndRedoGraphic('nose', values))
      end
   elseif name == 'lowerlip' then
      editingGuy.lowerlip = updateChild(container, editingGuy.lowerlip,
              createLowerlipBezier(values, editingGuy.lowerlip.points))
   elseif name == 'upperlip' then
      editingGuy.upperlip = updateChild(container, editingGuy.upperlip,
              createUpperlipBezier(values, editingGuy.upperlip.points))
   elseif name == 'feet' then
      editingGuy.feet1 = updateChild(guy, editingGuy.feet1, copyAndRedoGraphic('feet', values))
      editingGuy.feet2 = updateChild(guy, editingGuy.feet2, copyAndRedoGraphic('feet', values))
      myWorld:emit("bipedAttachFeet", biped)
   elseif name == 'hands' then
      editingGuy.hand1 = updateChild(guy, editingGuy.hand1, copyAndRedoGraphic('hands', values))
      editingGuy.hand2 = updateChild(guy, editingGuy.hand2, copyAndRedoGraphic('hands', values))
      myWorld:emit("bipedAttachHands", biped)
   elseif name == 'armhair' then
      if isNullObject(name, values) then
         --print(armhair1.transforms)
         editingGuy.armhair1 = updateChild(guy, editingGuy.armhair1, copy3(nullChild))
         editingGuy.armhair2 = updateChild(guy, editingGuy.armhair2, copy3(nullChild))
      else
         editingGuy.armhair1 = updateChild(guy, editingGuy.armhair1,
                 createArmHairRubberhose(1, values, editingGuy.armhair1.points))
         editingGuy.armhair2 = updateChild(guy, editingGuy.armhair2,
                 createArmHairRubberhose(2, values, editingGuy.armhair2.points))
         myWorld:emit('setArmHairToArms', biped)
      end
   elseif name == 'arms' then
      editingGuy.arm1 = updateChild(guy, editingGuy.arm1, createArmRubberhose(1, values, editingGuy.arm1.points))
      editingGuy.arm2 = updateChild(guy, editingGuy.arm2, createArmRubberhose(2, values, editingGuy.arm2.points))
      myWorld:emit("bipedAttachFeet", biped)
   elseif name == 'legs' then
      editingGuy.leg1 = updateChild(guy, editingGuy.leg1, createLegRubberhose(1, values, editingGuy.leg1.points))
      editingGuy.leg2 = updateChild(guy, editingGuy.leg2, createLegRubberhose(2, values, editingGuy.leg2.points))
      myWorld:emit("bipedAttachFeet", biped)
      changePart('leghair')
   elseif name == 'leghair' then
      if isNullObject(name, values) then
         --print(armhair1.transforms)
         editingGuy.leghair1 = updateChild(guy, editingGuy.leghair1, copy3(nullChild))
         editingGuy.leghair2 = updateChild(guy, editingGuy.leghair2, copy3(nullChild))
      else
         editingGuy.leghair1 = updateChild(guy, editingGuy.leghair1,
                 createLegHairRubberhose(1, values, editingGuy.leghair1.points))
         editingGuy.leghair2 = updateChild(guy, editingGuy.leghair2,
                 createLegHairRubberhose(2, values, editingGuy.leghair2.points))
         myWorld:emit('setLegHairToLegs', biped)
      end
   end
   parentize.parentize(editingGuy.guy)
   -- this is very costly, mayeb do this on a need basis
   if name == 'armhair' or name == 'leghair' or name == 'arms' or name == 'legs' or name == 'upperlip' or name == 'lowerlip' or name == 'hair' or name == 'brows' or name == 'neck' then
      mesh.meshAll(editingGuy.guy)
   end

   biped:give('biped', bipedArguments(editingGuy))
   potato:give('potato', potatoArguments(editingGuy))
   mouth:give('mouth', mouthArguments(editingGuy))
   -- print(potato.potato.teeth, name)
   myWorld:emit("potatoInit", potato)
   myWorld:emit("mouthInit", mouth)
end
