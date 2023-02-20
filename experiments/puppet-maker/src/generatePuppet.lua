local parentize = require 'lib.parentize'
local mesh      = require 'lib.mesh'
local bbox      = require 'lib.bbox'
local canvas    = require 'lib.canvas'
local render    = require 'lib.render'


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
          leg1, leg2, feet1, feet2,
          arm1, arm2, hand1, hand2,
      }
   else
      return {
          body, neck, head,
          leg1, leg2, feet1, feet2,
          arm1, arm2, hand1, hand2,
      }
   end
end

function bipedArguments(e, values)
   return {
       guy = guy,
       body = body,
       neck = neck,
       head = head,
       leg1 = leg1,
       leg2 = leg2,
       feet1 = feet1,
       feet2 = feet2,
       arm1 = arm1,
       arm2 = arm2,
       hand1 = hand1,
       hand2 = hand2,
       values = values
   }
end

function potatoArguments(e, values)
   return {
       head = values.potatoHead and body or head,
       eye1 = eye1,
       eye2 = eye2,
       pupil1 = pupil1,
       pupil2 = pupil2,
       ear1 = ear1,
       ear2 = ear2,
       brow1 = brow1,
       brow2 = brow2,
       nose = nose,
       values = values
   }
end

function createBrowBezier(values, points)
   return createBezierFromImage(
           browImgUrls[values.brows.shape],
           textures[values.brows.bgTex],
           palettes[values.brows.bgPal],
           values.brows.bgAlpha,
           textures[values.brows.fgTex],
           palettes[values.brows.fgPal],
           values.brows.fgAlpha,
           values.brows.texRot,
           texscales[values.brows.texScale],
           palettes[values.brows.linePal],
           values.brows.lineAlpha,
           values.browsWidthMultiplier,
           points)
end

function arrangeBrows()
   local bends = { { 0, 0, 0 }, { 1, 0, -1 }, { -1, 0, 1 }, { 1, 0, 1 }, { -1, 0, -1 }, { 1, 0, 0 },
       { -1, 0, 0 }, { 0, -1, 1 }, { 0, 1, 1 }, { -1, 1, 1 }, }

   local img = mesh.getImage(browImgUrls[values.brows.shape])
   local width, height = img:getDimensions()
   local multiplier = (height / 2)
   local picked = bends[values.browsDefaultBend]

   local b1p = { picked[1] * multiplier, picked[2] * multiplier, picked[3] * multiplier }

   height = height * values.browsWideMultiplier
   -- todo currently I am just mirroring the brows, not always what we want
   brow1.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
   brow2.points = { { height / 2, b1p[1] }, { 0, b1p[2] }, { -height / 2, b1p[3] } }
   --brow2.points = { { -height / 2, b1p[1] }, { 0, b1p[2] }, { height / 2, b1p[3] } }
end

local function getDistance(x1, y1, x2, y2)
   local dx = x1 - x2
   local dy = y1 - y2
   local distance = math.sqrt((dx * dx) + (dy * dy))

   return distance
end

local function getLengthOfPath(path)
   local result = 0
   for i = 1, #path - 1 do
      local a = path[i]
      local b = path[i + 1]
      result = result + getDistance(a[1], a[2], b[1], b[2])
   end
   return result
end



function createVanillaLineFromImage(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la,
                                    hairWidthMultiplier, hairTension, optionalPoints,
                                    flipx, flipy)
   local img = mesh.getImage(url)
   local width, height = img:getDimensions()

   local currentNode = {}
   currentNode.texture = {}
   currentNode.texture.url = url
   currentNode.texture.wrap = 'repeat'
   currentNode.texture.filter = 'linear'
   currentNode.type = 'vanillaline'
   currentNode.color = { 1, 1, 1 }

   currentNode.points = optionalPoints or { { 0, 0 }, { 0, 100 }, { 100, 100 } }
   local length = getLengthOfPath(currentNode.points)

   local factor = (length / height)
   currentNode.data = {}
   currentNode.data.width = (width * factor) * hairWidthMultiplier
   currentNode.data.tension = hairTension
   currentNode.data.spacing = 5


   if (true) then
      local lineart = img

      local maskUrl = getPNGMaskUrl(url)
      local mask = mesh.getImage(maskUrl)

      if not mask then print('NO MASK FOUND', maskUrl) end
      --if mask then
      local cnv = canvas.makeTexturedCanvas(lineart, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy)
      currentNode.texture.retexture = love.graphics.newImage(cnv)
      --end
   end

   return currentNode
end

function createRubberHoseFromImage(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flop, length, widthMultiplier,
                                   optionalPoints,
                                   flipx, flipy)
   local img = mesh.getImage(url)
   local width, height = img:getDimensions()
   local magic = 4.46
   local currentNode = {}

   currentNode.type = 'rubberhose'
   currentNode.data = currentNode.data or {}
   currentNode.texture = {}
   currentNode.texture.url = url
   currentNode.texture.wrap = 'repeat'
   currentNode.texture.filter = 'linear'
   currentNode.data.length = height * magic
   currentNode.data.width = width * 2 * widthMultiplier
   currentNode.data.flop = flop
   currentNode.data.borderRadius = .5
   currentNode.data.steps = 20
   currentNode.color = { 1, 1, 1 }
   currentNode.data.scaleX = 1
   currentNode.data.scaleY = length / height
   currentNode.points = optionalPoints or { { 0, 0 }, { 0, height / 2 } }

   if (true) then
      local lineart = img
      local maskUrl = getPNGMaskUrl(url)
      local mask = mesh.getImage(maskUrl)
      --if mask then
      local cnv = canvas.makeTexturedCanvas(lineart, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy)
      currentNode.texture.retexture = love.graphics.newImage(cnv)
      --end
   end



   return currentNode
end

function createBezierFromImage(url, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, widthMultiplier, optionalPoints, flipx,
                               flipy)
   -- print(inspect(optionalPoints))
   local img = mesh.getImage(url)
   local width, height = img:getDimensions()
   local currentNode = {}
   --print(inspect(optionalPoints), inspect(optionalPoints))
   currentNode = {
       color = { 1, 1, 1, 1 },
       data = {
           length = height,
           steps = 15,
           width = (widthMultiplier and widthMultiplier or 1) * (width / 2)
       },
       name = "beziered",
       points = optionalPoints or { { height / 2, 0 }, { 0, 0 }, { -height / 2, 0 } },
       texture = {
           filter = "linear",
           url = url,
           wrap = "repeat"
       },
       type = "bezier"
   }

   if (true) then
      local lineart = img
      local maskUrl = getPNGMaskUrl(url)
      local mask = mesh.getImage(maskUrl)
      --if mask then
      local cnv = canvas.makeTexturedCanvas(lineart, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lp, la, flipx, flipy)
      currentNode.texture.retexture = love.graphics.newImage(cnv)
      --end
   end

   --return currentNode


   local result = {}
   result.folder = true
   result.transforms = {
       l = { 0, 0, 0, 1, 1, 0, 0 }
   }
   result.children = { currentNode }
   --print('jo!')
   return result
end

local function makeDynamicCanvas(imageData, mymesh)
   local w, h = imageData:getDimensions()
   local w2 = w / 2
   local h2 = h / 2

   local result = {}
   result.color = { 1, 1, 1 }
   result.name = 'generated'
   result.points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } }
   result.texture = {
       filter = "linear",
       canvas = mymesh,
       wrap = "repeat",
   }

   return result
end

local function createRectangle(x, y, w, h, r, g, b)
   local w2 = w / 2
   local h2 = h / 2

   local result = {}
   result.folder = true
   result.transforms = {
       l = { x, y, 0, 1, 1, 0, 0 }
   }
   result.children = { {

       name = 'rectangle',
       points = { { -w2, -h2 }, { w2, -h2 }, { w2, h2 }, { -w2, h2 } },
       color = { r or 1, g or 0.91, b or 0.15, 1 }
   } }
   return result
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

function redoTheGraphicInPart(part, bgt, bg, bga, fgt, fg, fga, tr, ts, lineColor, lineAlpha, flipx, flipy)
   local index = getIndexOfGraphicPart(part)
   local p = part.children and part.children[index] or part
   if p.texture then
      local lineartUrl = p.texture.url
      local lineart = mesh.getImage(lineartUrl, p.texture)
      local mask
      print(lineartUrl)
      mask = mesh.getImage(getPNGMaskUrl(lineartUrl))
      if mask == nil then
         print('no mask found', lineartUrl, getPNGMaskUrl(lineartUrl))
      end

      if (lineart) then
         local canvas = canvas.makeTexturedCanvas(lineart, mask, bgt, bg, bga, fgt, fg, fga, tr, ts, lineColor, lineAlpha,
                 flipx,
                 flipy)
         if p.texture.canvas then
            p.texture.canvas:release()
         end

         local m = mesh.makeMeshFromSibling(p, canvas)
         canvas:release()
         p.texture.canvas = m
      end
   end
end

function createArmRubberhose(armNr, values, points)
   local flop = armNr == 1 and values.arm1flop or values.arm2flop

   return createRubberHoseFromImage(
           legUrls[values.arms.shape],
           textures[values.arms.bgTex],
           palettes[values.arms.bgPal],
           values.arms.bgAlpha,
           textures[values.arms.fgTex],
           palettes[values.arms.fgPal],
           values.arms.fgAlpha,
           values.arms.texRot,
           texscales[values.arms.texScale],
           palettes[values.arms.linePal],
           values.arms.lineAlpha,
           flop
           , values.armLength,
           values.armWidthMultiplier,
           points)
end

function createLegRubberhose(legNr, values, points)
   local flop = legNr == 1 and values.leg1flop or values.leg2flop

   return createRubberHoseFromImage(
           legUrls[values.legs.shape],
           textures[values.legs.bgTex],
           palettes[values.legs.bgPal],
           values.legs.bgAlpha,
           textures[values.legs.fgTex],
           palettes[values.legs.fgPal],
           values.legs.fgAlpha,
           values.legs.texRot,
           texscales[values.legs.texScale],
           palettes[values.legs.linePal],
           values.legs.lineAlpha,
           flop
           , values.legLength,
           values.legWidthMultiplier,
           points, values.legs.flipx or 1, values.legs.flipy or 1)
end

function createHairVanillaLine(values, hairLine)
   return createVanillaLineFromImage(
           hairUrls[values.hair.shape],
           textures[values.hair.bgTex],
           palettes[values.hair.bgPal],
           values.hair.bgAlpha,
           textures[values.hair.fgTex],
           palettes[values.hair.fgPal],
           values.hair.fgAlpha,
           values.hair.texRot,
           texscales[values.hair.texScale],
           palettes[values.hair.linePal],
           values.hair.lineAlpha, values.hairWidthMultiplier, values.hairTension, hairLine)
end

function createNeckRubberhose(values, points)
   local flop = 0 -- this needs to be set accoridng to how th eneck is positioned
   return createRubberHoseFromImage(
           legUrls[values.neck.shape],
           textures[values.neck.bgTex],
           palettes[values.neck.bgPal],
           values.neck.bgAlpha,
           textures[values.neck.fgTex],
           palettes[values.neck.fgPal],
           values.neck.fgAlpha,
           values.neck.texRot,
           texscales[values.neck.texScale],
           palettes[values.neck.linePal],
           values.neck.lineAlpha,
           flop
           , values.neckLength,
           values.neckWidthMultiplier,
           points)
end

function changeNeck(biped, values)
   neck = createNeckRubberhose(values, neck.points) -- copy3(headParts[values.neck.shape])
   guy.children = guyChildren(biped)
   parentize.parentize(root)
   redoNeck(biped, values)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
   mesh.meshAll(root)
end

function redoNeck(biped, values)
   for i = 1, #guy.children do
      if (guy.children[i] == neck) then
         neck = createNeckRubberhose(values, neck.points)
         guy.children[i] = neck
      end
   end
   mesh.meshAll(root)

   parentize.parentize(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
end

function changeBody(biped, values)
   -- print(inspect(values))
   --body = copy3(nullObject)
   body = updateChild(guy, body, copy3(bodyParts[values.body.shape]))
   --body =  updateChild(guy, body, copy3(nullObject))
   parentize.parentize(root)

   redoBody(biped, values) --- this position is very iportant,
   --  if i move redoBody under the meshall we get these borders aorund images

   if (values.potatoHead) then
      attachAllFaceParts()
      changeHair(potato, values)
   end

   mesh.meshAll(root)
   render.justDoTransforms(root)

   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
   myWorld:emit("bipedAttachLegs", biped) -- todo
   myWorld:emit("bipedAttachArms", biped) -- todo
   myWorld:emit("bipedAttachHands", biped) -- todo
end

function changeLegs(biped, values)
   leg1 = updateChild(guy, leg1, createLegRubberhose(1, values, leg1.points))
   leg2 = updateChild(guy, leg2, createLegRubberhose(2, values, leg2.points))

   parentize.parentize(root)
   mesh.meshAll(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
end

function changeArms(biped, values)
   arm1 = updateChild(guy, arm1, createArmRubberhose(1, values, arm1.points))
   arm2 = updateChild(guy, arm2, createArmRubberhose(2, values, arm2.points))

   parentize.parentize(root)
   mesh.meshAll(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
end

function redoGraphicHelper(part, name, values)
   redoTheGraphicInPart(
       part,
       textures[values[name].bgTex],
       palettes[values[name].bgPal],
       values[name].bgAlpha,
       textures[values[name].fgTex],
       palettes[values[name].fgPal],
       values[name].fgAlpha,
       values[name].texRot,
       texscales[values[name].texScale],
       palettes[values[name].linePal],
       values[name].lineAlpha,
       values[name].flipx or 1,
       values[name].flipy or 1
   )
end

function redoBody(_, values)
   redoGraphicHelper(body, 'body', values)
end

function redoFeet(_, values)
   redoGraphicHelper(feet1, 'feet', values)
   redoGraphicHelper(feet2, 'feet', values)
end

function redoHands(_, values)
   redoGraphicHelper(hand1, 'hands', values)
   redoGraphicHelper(hand2, 'hands', values)
end

function redoHead(_, values)
   redoGraphicHelper(head, 'head', values)
end

function redoEars(_, values)
   redoGraphicHelper(ear1, 'ears', values)
   redoGraphicHelper(ear2, 'ears', values)
end

function changeHands(biped, values)
   hand1 = updateChild(guy, hand1, copy3(handParts[values.hands.shape]))
   hand2 = updateChild(guy, hand2, copy3(handParts[values.hands.shape]))

   parentize.parentize(root)
   redoHands(biped, values)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHands", biped)
   mesh.meshAll(root)
end

function changeFeet(biped, values)
   feet1 = updateChild(guy, feet1, copy3(feetParts[values.feet.shape]))
   feet2 = updateChild(guy, feet2, copy3(feetParts[values.feet.shape]))

   parentize.parentize(root)
   redoFeet(biped, values)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
   mesh.meshAll(root)
end

function updateChild(container, oldValue, newResult)
   local oldTransforms = oldValue.transforms and copy3(oldValue.transforms.l)
   -- I need to get t the pivot point from the new thing.
   if newResult.transforms then
      oldTransforms[6] = newResult.transforms.l[6]
      oldTransforms[7] = newResult.transforms.l[7]
   end
   for i = 1, #container.children do
      if container.children[i] == oldValue then
         container.children[i] = newResult
         if (container.children[i].transforms) then
            container.children[i].transforms.l = oldTransforms
         end
         return container.children[i]
      end
   end
end

function changeHair(potato, values)
   local container = values.potatoHead and body or head

   local hp = getHeadPoints(potato)
   local hairLine = { hp[7], hp[8], hp[1], hp[2], hp[3] }
   -- print(inspect(hairLine))

   hair = updateChild(container, hair, createHairVanillaLine(values, hairLine))

   parentize.parentize(root)
   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)
   mesh.meshAll(root)
end

function changeNose(potato, values)
   local container = values.potatoHead and body or head
   nose = updateChild(container, nose, copy3(noseParts[values.nose.shape]))

   parentize.parentize(root)
   redoNose(potato, values)
   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)
   mesh.meshAll(root)
end

function redoNose(potato, values)
   redoGraphicHelper(nose, 'nose', values)
end

function redoEyes(potato, values)
   redoGraphicHelper(eye1, 'eyes', values)
   redoGraphicHelper(eye2, 'eyes', values)
end

function redoPupils(potato, values)
   redoGraphicHelper(pupil1, 'pupils', values)
   redoGraphicHelper(pupil2, 'pupils', values)
end

function redoBrows(potato, values)
   local container = values.potatoHead and body or head
   arrangeBrows()
   --print(inspect(brow1.points), inspect(brow2.points))
   brow1 = updateChild(container, brow1, createBrowBezier(values, brow1.points))
   brow2 = updateChild(container, brow2, createBrowBezier(values, brow2.points))

   parentize.parentize(root)
   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)

   mesh.meshAll(root)
end

function changePupils(biped, values)
   local container = values.potatoHead and body or head

   pupil1 = updateChild(container, pupil1, copy3(pupilParts[values.pupils.shape]))
   pupil2 = updateChild(container, pupil2, copy3(pupilParts[values.pupils.shape]))

   parentize.parentize(root)
   redoEyes(potato, values)
   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)
   mesh.meshAll(root)
end

function changeEyes(biped, values)
   local container = values.potatoHead and body or head

   eye1 = updateChild(container, eye1, copy3(eyeParts[values.eyes.shape]))
   eye2 = updateChild(container, eye2, copy3(eyeParts[values.eyes.shape]))

   parentize.parentize(root)
   redoEyes(potato, values)
   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)
   mesh.meshAll(root)
end

function changeEars(biped, values)
   local container = values.potatoHead and body or head

   ear1 = updateChild(container, ear1, copy3(earParts[values.ears.shape]))
   ear2 = updateChild(container, ear2, copy3(earParts[values.ears.shape]))


   parentize.parentize(root)
   redoEars(potato, values)


   potato:give('potato', potatoArguments(potato, values))
   myWorld:emit("potatoInit", potato)
   mesh.meshAll(root)
end

function changeHead(biped, values)
   head = copy3(headParts[values.head.shape])
   guy.children = guyChildren(biped)

   head.transforms.l[4] = values.headWidthMultiplier
   head.transforms.l[5] = values.headHeightMultiplier
   --head = updateChild(guy, head, copy3(headParts[values.head.shape]))
   redoHead(biped, values)
   if (not values.potatoHead) then
      attachAllFaceParts()
   end
   parentize.parentize(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
   mesh.meshAll(root)

   changeHair(potato, values)
end
