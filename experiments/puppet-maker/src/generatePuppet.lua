local parentize = require 'lib.parentize'
local mesh      = require 'lib.mesh'
local canvas    = require 'lib.canvas'
local render    = require 'lib.render'



function guyChildren(e)
   if (e.biped.potatoHead) then
      return {
         body, 
         eye1, eye2, nose,
         leg1, leg2, feet1, feet2,
         arm1, arm2, hand1, hand2,
      }
   else
      return {
         body, neck, head, 
         eye1, eye2, nose,
         leg1, leg2, feet1, feet2,
         arm1, arm2, hand1, hand2,
      }
   end
end

function bipedArguments(e, values)
   return {
      guy = guy, body = body, neck = neck, head = head, eye1 = eye1, eye2 = eye2, nose=nose,
      leg1 = leg1, leg2 = leg2, feet1 = feet1, feet2 = feet2,
      arm1 = arm1, arm2 = arm2, hand1 = hand1, hand2 = hand2, potatoHead = e.biped.potatoHead, values = values
   }
end

function createRubberHoseFromImage(url, bg, fg, bgp, fgp, lp, flop, length, widthMultiplier, optionalPoints, flipx, flipy)
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

   --local flipx = 1
   --local flipy = 1

   if (true) then
      local lineart = img
      local maskUrl = getPNGMaskUrl(url)
      local mask = mesh.getImage(maskUrl)
      if mask then
         local cnv = canvas.makeTexturedCanvas(lineart, mask, bgp, bg, fgp, fg, lp, flipx, flipy)
         currentNode.texture.retexture = love.graphics.newImage(cnv)
      end
   end

   return currentNode
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

function redoTheGraphicInPart(part, bg, fg, bgp, fgp, lineColor, flipx, flipy)
   local p = part.children and part.children[1] or part

   local lineartUrl = p.texture.url
   local lineart = mesh.getImage(lineartUrl, p.texture)
   local mask

   mask = mesh.getImage(getPNGMaskUrl(lineartUrl))
   if mask == nil then
      print('no mask found', lineartUrl, getPNGMaskUrl(lineartUrl))
   end

   if (lineart) then
      local canvas = canvas.makeTexturedCanvas(lineart, mask, bgp, bg, fgp, fg, lineColor, flipx, flipy)
      if p.texture.canvas then
         p.texture.canvas:release()
      end
      local m = mesh.makeMeshFromSibling(p, canvas)
      canvas:release()
      p.texture.canvas = m
   end
end

function createArmRubberhose(armNr, values, points)
   local flop = armNr == 1 and values.arm1flop or values.arm2flop

   return createRubberHoseFromImage(
      legUrls[values.arms.shape],
      palettes[values.arms.bgPal], palettes[values.arms.fgPal],
      textures[values.arms.bgTex], textures[values.arms.fgTex], palettes[values.arms.linePal], flop
      , values.armLength,
      values.armWidthMultiplier,
      points)
end

function createLegRubberhose(legNr, values, points)
   local flop = legNr == 1 and values.leg1flop or values.leg2flop

   return createRubberHoseFromImage(
      legUrls[values.legs.shape],
      palettes[values.legs.bgPal], palettes[values.legs.fgPal],
      textures[values.legs.bgTex], textures[values.legs.fgTex], palettes[values.legs.linePal], flop
      , values.legLength,
      values.legWidthMultiplier,
      points, values.legs.flipx or 1, values.legs.flipy or 1)
end

function createNeckRubberhose(values, points)
   local flop = 0 -- this needs to be set accoridng to how th eneck is positioned
   return createRubberHoseFromImage(
      legUrls[values.neck.shape],
      palettes[values.neck.bgPal], palettes[values.neck.fgPal],
      textures[values.neck.bgTex], textures[values.neck.fgTex], palettes[values.neck.linePal], flop
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
   local temp_x, temp_y = body.transforms.l[1], body.transforms.l[2]
   body = copy3(bodyParts[values.body.shape])

   body.transforms.l[1] = temp_x
   body.transforms.l[2] = temp_y
   body.transforms.l[4] = values.bodyWidthMultiplier
   body.transforms.l[5] = values.bodyHeightMultiplier
   guy.children = guyChildren(biped)

   parentize.parentize(root)

   redoBody(biped, values) --- this position is very iportant, if i move redoBody under the meshall we get these borders aorund images
   mesh.meshAll(root)

   render.justDoTransforms(root)

   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
   myWorld:emit("bipedAttachLegs", biped) -- todo
   myWorld:emit("bipedAttachArms", biped) -- todo
   myWorld:emit("bipedAttachHands", biped) -- todo
end

function changeLegs(biped, values)
   for i = 1, #guy.children do
      if (guy.children[i] == leg1) then
         leg1 = createLegRubberhose(1, values, leg1.points)
         guy.children[i] = leg1
      end
      if (guy.children[i] == leg2) then
         leg2 = createLegRubberhose(2, values, leg2.points)
         guy.children[i] = leg2
      end
   end
   parentize.parentize(root)

   mesh.meshAll(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
end

function changeArms(biped, values)
   for i = 1, #guy.children do
      if (guy.children[i] == arm1) then
         arm1 = createArmRubberhose(1, values, arm1.points)
         guy.children[i] = arm1
      end
      if (guy.children[i] == arm2) then
         arm2 = createArmRubberhose(2, values, arm2.points)
         guy.children[i] = arm2
      end
   end
   parentize.parentize(root)

   mesh.meshAll(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
end

function redoLegs(biped, values)
   leg1 = createLegRubberhose(1, values, leg1.points)
   leg2 = createLegRubberhose(2, values, leg2.points)

   guy.children = guyChildren(biped)
   parentize.parentize(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
   mesh.meshAll(root)
end

function redoArms(biped, values)
   arm1 = createArmRubberhose(1, values, arm1.points)
   arm2 = createArmRubberhose(2, values, arm2.points)

   guy.children = guyChildren(biped)
   parentize.parentize(root)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHands", biped)
   mesh.meshAll(root)
end

function redoGraphicHelper(part, name, values)
   redoTheGraphicInPart(
      part,
      palettes[values[name].bgPal],
      palettes[values[name].fgPal],
      textures[values[name].bgTex],
      textures[values[name].fgTex],
      palettes[values[name].linePal],
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

function changeHands(biped, values)
   for i = 1, #guy.children do
      if (guy.children[i] == hand1) then
         local r = hand1.transforms.l[3]
         local sx = hand1.transforms.l[4]
         hand1 = copy3(handParts[values.hands.shape])
         hand1.transforms.l[3] = r
         hand1.transforms.l[4] = sx
         guy.children[i] = hand1
      end

      if (guy.children[i] == hand2) then
         local r = hand2.transforms.l[3]
         local sx = hand2.transforms.l[4]
         hand2 = copy3(handParts[values.hands.shape])
         hand2.transforms.l[3] = r
         hand2.transforms.l[4] = sx
         guy.children[i] = hand2
      end
   end
   parentize.parentize(root)
   redoHands(biped, values)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHands", biped)
   mesh.meshAll(root)
end

function changeFeet(biped, values)
   for i = 1, #guy.children do
      if (guy.children[i] == feet1) then
         local r = feet1.transforms.l[3]
         local sx = feet1.transforms.l[4]
         feet1 = copy3(feetParts[values.feet.shape])
         feet1.transforms.l[3] = r
         feet1.transforms.l[4] = sx
         guy.children[i] = feet1
      end
      if (guy.children[i] == feet2) then
         local r = feet2.transforms.l[3]
         local sx = feet2.transforms.l[4]
         feet2 = copy3(feetParts[values.feet.shape])
         feet2.transforms.l[3] = r
         feet2.transforms.l[4] = sx
         guy.children[i] = feet2
      end
   end

   parentize.parentize(root)
   redoFeet()
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachFeet", biped)
   mesh.meshAll(root)
end

function changeHead(biped, values)
   head = copy3(headParts[values.head.shape])

   guy.children = guyChildren(biped)
   parentize.parentize(root)
   redoHead(biped, values)
   biped:give('biped', bipedArguments(biped, values))
   myWorld:emit("bipedAttachHead", biped)
   mesh.meshAll(root)
end