local parentize = require 'lib.parentize'
local mesh      = require 'lib.mesh'
local bbox      = require 'lib.bbox'
local canvas    = require 'lib.canvas'
local render    = require 'lib.render'

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
function getHeadPoints(e)
   local parent = e.potato.head
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

function guyChildren(e)
   if (e.biped.values.potatoHead) then
      return {
          body,
          leg1, leg2, leghair1, leghair2, feet1, feet2,
          arm1, arm2, armhair1, armhair2, hand1, hand2,
      }
   else
      return {
          body, neck, head,
          leg1, leg2, leghair1, leghair2, feet1, feet2,
          arm1, arm2, armhair1, armhair2, hand1, hand2,
      }
   end
end

function bipedArguments(values)
   return {
       guy = guy,
       body = body,
       neck = neck,
       head = head,
       leg1 = leg1,
       leg2 = leg2,
       leghair1 = leghair1,
       leghair2 = leghair2,
       feet1 = feet1,
       feet2 = feet2,
       armhair1 = armhair1,
       armhair2 = armhair2,
       arm1 = arm1,
       arm2 = arm2,
       hand1 = hand1,
       hand2 = hand2,
       values = values
   }
end

function potatoArguments(values)
   return {
       head = values.potatoHead and body or head,
       eye1 = eye1,
       eye2 = eye2,
       pupil1 = pupil1,
       pupil2 = pupil2,
       ear1 = ear1,
       ear2 = ear2,
       upperlip = upperlip,
       lowerlip = lowerlip,
       brow1 = brow1,
       brow2 = brow2,
       nose = nose,
       values = values
   }
end

function arrangeBrows()
   local bends = { { 0, 0, 0 }, { 1, 0, -1 }, { -1, 0, 1 }, { 1, 0, 1 }, { -1, 0, -1 }, { 1, 0, 0 },
       { -1, 0, 0 }, { 0, -1, 1 }, { 0, 1, 1 }, { -1, 1, 1 }, }

   local p = findPart('brows').imgs
   local img = mesh.getImage(p[values.brows.shape])
   local width, height = img:getDimensions()
   local multiplier = (height / 2)
   local picked = bends[values.browsDefaultBend]

   local b1p = { picked[1] * multiplier, picked[2] * multiplier, picked[3] * multiplier }

   height = height * values.browsWideMultiplier
   -- todo currently I am just mirroring the brows, not always what we want
   brow1.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
   brow2.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
   brow2.transforms.l[4] = -1
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
   local cnv = canvas.makeTexturedCanvas(img, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy, renderPatch)
   return cnv
end

function redoGraphicHelper(part, name, values)
   local index = getIndexOfGraphicPart(part)
   local p = part.children and part.children[index] or part
   if p.texture and p.texture.url then
      local textured, url = partToTexturedCanvas(name, values, p.texture)

      if p.texture.canvas then
         p.texture.canvas:release()
      end
      local m = mesh.makeMeshFromSibling(p, textured)
      textured:release()
      p.texture.canvas = m
   end
   return part
end

function partToTexturedCanvas(partName, values, optionalImageSettings)
   local p = findPart(partName)
   local url = p.imgs[values[partName].shape]

   local flipX = values[partName].flipx or 1
   local flipY = values[partName].flipy or 1

   --print(partName, flipX, flipY)
   local renderPatch = nil

   if partName == 'head' then
      if not isNullObject('skinPatchSnout', values) then
         renderPatch = {}
         renderPatch.imageData = partToTexturedCanvas('skinPatchSnout', values)
         renderPatch.sx = values.skinPatchSnoutScaleX
         renderPatch.sy = values.skinPatchSnoutScaleY
         renderPatch.r = values.skinPatchSnoutAngle
         renderPatch.tx = values.skinPatchSnoutX
         renderPatch.ty = values.skinPatchSnoutY
      end
   end

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
   local flop = 0 -- this needs to be set accoridng to how th eneck is positioned
   local textured, url = partToTexturedCanvas('neck', values)
   return createFromImage.rubberhose(
           url, textured,
           flop,
           values.neckLength,
           values.neckWidthMultiplier,
           points)
end

function updateChild(container, oldValue, newResult)
   --print(container.name, inspect(oldValue))

   for i = 1, #container.children do
      if container.children[i] == oldValue then
         --print('changed something', inspect(oldValue))

         container.children[i] = newResult
         if (container.children[i].transforms) then
            local oldTransforms = oldValue.transforms and copy3(oldValue.transforms.l)
            -- I need to get t the pivot point from the new thing.
            if newResult.transforms then
               oldTransforms[6] = newResult.transforms.l[6]
               oldTransforms[7] = newResult.transforms.l[7]
            end

            container.children[i].transforms.l = oldTransforms
         end
         return container.children[i]
      end
   end
end

function copyAndRedoGraphic(name, values)
   local part = findPart(name)
   local partArray = part.p
   --earParts[values.ears.shape]
   local original = partArray[values[name].shape]
   return redoGraphicHelper(copy3(original), name, values)
end

function changePart(name, values)
   local container = values.potatoHead and body or head

   if name == 'body' then
      body = updateChild(guy, body, copyAndRedoGraphic('body', values))
      parentize.parentize(root)

      if (values.potatoHead) then
         attachAllFaceParts()
         changePart('hair', values)
      end

      mesh.meshAll(root)
      render.justDoTransforms(root) -- why is this needed for body?? (because we need the correct points to attach other things too)

      biped:give('biped', bipedArguments(values))
      myWorld:emit("bipedAttachHead", biped)
      myWorld:emit("bipedAttachLegs", biped) -- todo
      myWorld:emit("bipedAttachArms", biped) -- todo
      myWorld:emit("bipedAttachHands", biped) -- todo
   elseif name == 'skinPatchSnout' then
      if values.potatoHead then
         changePart('body', values)
      else
         changePart('head', values)
      end
   elseif name == 'neck' then
      neck = updateChild(guy, neck, createNeckRubberhose(values, neck.points))
   elseif name == 'head' then
      head = copyAndRedoGraphic('head', values)
      guy.children = guyChildren(biped)
      head.transforms.l[4] = values.headWidthMultiplier
      head.transforms.l[5] = values.headHeightMultiplier
      if (not values.potatoHead) then
         attachAllFaceParts()
      end
      myWorld:emit("bipedAttachHead", biped)
      changePart('hair', values) ----
   elseif name == 'hair' then
      if isNullObject(name, values) then
         hair = updateChild(container, hair, copy3(nullChild))
         --  print('hair', hair)
      else
         local hp = getHeadPoints(potato)
         local hairLine = { hp[7], hp[8], hp[1], hp[2], hp[3] }
         hair = updateChild(container, hair, createHairVanillaLine(values, hairLine))
      end
   elseif name == 'ears' then
      ear1 = updateChild(container, ear1, copyAndRedoGraphic('ears', values))
      ear2 = updateChild(container, ear2, copyAndRedoGraphic('ears', values))
   elseif name == 'eyes' then
      eye1 = updateChild(container, eye1, copyAndRedoGraphic('eyes', values))
      eye2 = updateChild(container, eye2, copyAndRedoGraphic('eyes', values))
   elseif name == 'pupils' then
      pupil1 = updateChild(container, pupil1, copyAndRedoGraphic('pupils', values))
      pupil2 = updateChild(container, pupil2, copyAndRedoGraphic('pupils', values))
   elseif name == 'brows' then
      arrangeBrows()
      brow1 = updateChild(container, brow1, createBrowBezier(values, brow1.points))
      brow2 = updateChild(container, brow2, createBrowBezier(values, brow2.points))
   elseif name == 'nose' then
      if isNullObject(name, values) then
         nose = updateChild(container, nose, copy3(nullFolder))
      else
         nose = updateChild(container, nose, copyAndRedoGraphic('nose', values))
      end
   elseif name == 'lowerlip' then
      lowerlip = updateChild(container, lowerlip, createLowerlipBezier(values, lowerlip.points))
   elseif name == 'upperlip' then
      upperlip = updateChild(container, upperlip, createUpperlipBezier(values, upperlip.points))
   elseif name == 'feet' then
      feet1 = updateChild(guy, feet1, copyAndRedoGraphic('feet', values))
      feet2 = updateChild(guy, feet2, copyAndRedoGraphic('feet', values))
      myWorld:emit("bipedAttachFeet", biped)
   elseif name == 'hands' then
      hand1 = updateChild(guy, hand1, copyAndRedoGraphic('hands', values))
      hand2 = updateChild(guy, hand2, copyAndRedoGraphic('hands', values))
      myWorld:emit("bipedAttachHands", biped)
   elseif name == 'armhair' then
      if isNullObject(name, values) then
         --print(armhair1.transforms)
         armhair1 = updateChild(guy, armhair1, copy3(nullChild))
         armhair2 = updateChild(guy, armhair2, copy3(nullChild))
      else
         armhair1 = updateChild(guy, armhair1, createArmHairRubberhose(1, values, armhair1.points))
         armhair2 = updateChild(guy, armhair2, createArmHairRubberhose(2, values, armhair2.points))
         myWorld:emit('setArmHairToArms', biped)
      end
   elseif name == 'arms' then
      arm1 = updateChild(guy, arm1, createArmRubberhose(1, values, arm1.points))
      arm2 = updateChild(guy, arm2, createArmRubberhose(2, values, arm2.points))
      myWorld:emit("bipedAttachFeet", biped)
   elseif name == 'legs' then
      leg1 = updateChild(guy, leg1, createLegRubberhose(1, values, leg1.points))
      leg2 = updateChild(guy, leg2, createLegRubberhose(2, values, leg2.points))
      myWorld:emit("bipedAttachFeet", biped)
   elseif name == 'leghair' then
      if isNullObject(name, values) then
         --print(armhair1.transforms)
         leghair1 = updateChild(guy, leghair1, copy3(nullChild))
         leghair2 = updateChild(guy, leghair2, copy3(nullChild))
      else
         leghair1 = updateChild(guy, leghair1, createLegHairRubberhose(1, values, leghair1.points))
         leghair2 = updateChild(guy, leghair2, createLegHairRubberhose(2, values, leghair2.points))
         myWorld:emit('setLegHairToLegs', biped)
      end
   end
   parentize.parentize(root)
   mesh.meshAll(root)
   biped:give('biped', bipedArguments(values))
   potato:give('potato', potatoArguments(values))
   myWorld:emit("potatoInit", potato)
end
