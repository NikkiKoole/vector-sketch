-- A quick look at a drawn outline on random polygons (playtime docs/BURROW.md, "an interesting
-- outline for any shape"): a scanned crayon stroke repeated along the outline, a wobble, tapered
-- ends that overshoot where they meet, line boil and misregistration as toggles.
--
-- keys: space new shapes, t stroke, b boil, m misregistration, h hatch fill, f fill on/off,
--       x mix, up/down width, left/right wobble, o overshoot, s screenshot.  `love . shot` saves one and quits.

-- the strokes: every strokes/line*.png (drawn upwards) and strokes/track*.png (drawn sideways).
-- Per stroke: whether the line runs along its x, and the part of it to use (the ends fade).
-- Drop in more and they join the mix of their kind.
local FAMILIES = {
   line = { alongX = false, from = 0.1, to = 0.9 },
   track = { alongX = true, from = 0.02, to = 0.98 },
}
local STROKES = {}

local PAPER = { 0.93, 0.89, 0.80 }
local INK = { 0.22, 0.15, 0.12 }
local FILLS = {
   { 0.85, 0.62, 0.42 }, { 0.62, 0.72, 0.55 }, { 0.90, 0.78, 0.45 },
   { 0.60, 0.68, 0.80 }, { 0.82, 0.55, 0.52 }, { 0.72, 0.60, 0.48 },
}

local settings = {
   stroke = 1, boil = false, misreg = false, hatch = false, fill = true,
   width = 9, wobble = 1.5, overshoot = true, mix = true,
}

local shapes = {}
local hatchImage
local boilClock, boilStep = 0, 0
local shotFrames

local function chaikin(points, rounds)
   for _ = 1, rounds do
      local out = {}
      for i = 1, #points do
         local a, b = points[i], points[i % #points + 1]
         out[#out + 1] = { a[1] * 0.75 + b[1] * 0.25, a[2] * 0.75 + b[2] * 0.25 }
         out[#out + 1] = { a[1] * 0.25 + b[1] * 0.75, a[2] * 0.25 + b[2] * 0.75 }
      end
      points = out
   end
   return points
end

-- star-shaped around the centre, so it never crosses itself
local function randomPolygon(cx, cy, blobby)
   local n = blobby and love.math.random(6, 10) or love.math.random(3, 8)
   local r = love.math.random(70, 110)
   local points = {}
   local start = love.math.random() * math.pi * 2
   for i = 1, n do
      local a = start + (i - 1 + (love.math.random() - 0.5) * 0.5) / n * math.pi * 2
      local rr = r * (blobby and (0.6 + love.math.random() * 0.5) or (0.55 + love.math.random() * 0.45))
      points[#points + 1] = { cx + math.cos(a) * rr, cy + math.sin(a) * rr }
   end
   if blobby then points = chaikin(points, 3) end
   return points
end

-- a long thin rectangle, standing or lying, its corners a little off; sometimes rounded
local function randomPlank(cx, cy)
   local long = love.math.random(150, 210)
   local short = love.math.random(18, 55)
   local w, h = short, long
   if love.math.random() < 0.4 then w, h = long * 1.3, short end
   local function jitter() return (love.math.random() - 0.5) * 8 end
   local points = {
      { cx - w / 2 + jitter(), cy - h / 2 + jitter() },
      { cx + w / 2 + jitter(), cy - h / 2 + jitter() },
      { cx + w / 2 + jitter(), cy + h / 2 + jitter() },
      { cx - w / 2 + jitter(), cy + h / 2 + jitter() },
   }
   -- a slight lean
   local lean = (love.math.random() - 0.5) * 0.25
   for _, p in ipairs(points) do
      local dx, dy = p[1] - cx, p[2] - cy
      p[1] = cx + dx * math.cos(lean) - dy * math.sin(lean)
      p[2] = cy + dx * math.sin(lean) + dy * math.cos(lean)
   end
   if love.math.random() < 0.3 then points = chaikin(points, 3) end
   return points
end

local function newShapes()
   shapes = {}
   local cols, rows = 4, 3
   for row = 1, rows do
      for col = 1, cols do
         local cx = (col - 0.5) * 1200 / cols
         local cy = 40 + (row - 0.5) * 700 / rows
         local points
         if love.math.random() < 0.45 then
            points = randomPlank(cx, cy)
         else
            points = randomPolygon(cx, cy, love.math.random() < 0.5)
         end
         local flat = {}
         local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
         for _, p in ipairs(points) do
            flat[#flat + 1] = p[1]; flat[#flat + 1] = p[2]
            minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
            minY, maxY = math.min(minY, p[2]), math.max(maxY, p[2])
         end
         shapes[#shapes + 1] = {
            points = points,
            -- a narrow shape gets less wobble, or its two sides wander into each other
            wobbleScale = math.max(0.3, math.min(1, math.min(maxX - minX, maxY - minY) / 120)),
            triangles = love.math.triangulate(flat),
            color = FILLS[love.math.random(#FILLS)],
            seed = love.math.random() * 1000,
            -- where the hand started, and how far off the fill was printed
            startAt = love.math.random(),
            misreg = { love.math.random(-6, 6), love.math.random(-6, 6) },
         }
      end
   end
end

-- points every `spacing` along the closed outline, keeping the corners
local function resample(points, spacing)
   local out = {}
   for i = 1, #points do
      local a, b = points[i], points[i % #points + 1]
      local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
      local k = math.max(1, math.ceil(len / spacing))
      for j = 0, k - 1 do
         local t = j / k
         out[#out + 1] = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
      end
   end
   return out
end

local function smoothstep(x)
   x = math.max(0, math.min(1, x))
   return x * x * (3 - 2 * x)
end

-- the path the pen took: once round from a random start, then a little past it
local function penPath(shape)
   local loop = resample(shape.points, 5)
   local n = #loop
   local first = math.floor(shape.startAt * n)
   local path = {}
   for i = 0, n do path[#path + 1] = loop[(first + i) % n + 1] end
   if settings.overshoot then
      local extra = math.floor(n * 0.06) + 2
      for i = 1, extra do path[#path + 1] = loop[(first + i) % n + 1] end
   end
   return path
end

-- a strip of triangles along the path; the stroke picture repeats along it. With mix on,
-- each repeat picks another picture of the same kind, and any repeat may be mirrored or run
-- backwards, so the pattern doesn't show. One mesh per picture used.
local function strokeMeshes(shape, stroke, seed)
   local path = penPath(shape)
   local rng = love.math.newRandomGenerator(math.floor(seed * 1000))
   local family = {}
   for _, other in ipairs(STROKES) do
      if other.family == stroke.family then family[#family + 1] = other end
   end

   local distances, total = { 0 }, 0
   for i = 2, #path do
      local a, b = path[i - 1], path[i]
      total = total + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
      distances[i] = total
   end
   local taper = math.min(40, total * 0.1)

   -- centre line with the wobble, and its width, per point
   local centre, widths = {}, {}
   for i, p in ipairs(path) do
      local d = distances[i]
      local nx, ny = 0, 0
      local a = path[math.max(1, i - 1)]
      local b = path[math.min(#path, i + 1)]
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 0 then nx, ny = -dy / len, dx / len end
      local amount = settings.wobble * shape.wobbleScale
      local wob = (love.math.noise(seed, d * 0.012) - 0.5) * 2 * amount * 4
      wob = wob + (love.math.noise(seed + 50, d * 0.05) - 0.5) * amount
      centre[i] = { p[1] + nx * wob, p[2] + ny * wob }
      local w = settings.width * (0.8 + love.math.noise(seed + 100, d * 0.02) * 0.4)
      widths[i] = w * (0.25 + 0.75 * smoothstep(d / taper)) * (0.25 + 0.75 * smoothstep((total - d) / taper))
   end

   local function sides(i)
      local a = centre[math.max(1, i - 1)]
      local b = centre[math.min(#centre, i + 1)]
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local len = math.sqrt(dx * dx + dy * dy)
      if len == 0 then len = 1 end
      local nx, ny = -dy / len, dx / len
      local c, w = centre[i], widths[i]
      return c[1] + nx * w, c[2] + ny * w, c[1] - nx * w, c[2] - ny * w
   end

   -- the tiles, one after another along the line
   local tile
   local function nextTile(startAt)
      local picture = stroke
      if settings.mix then picture = family[rng:random(#family)] end
      local iw, ih = picture.image:getDimensions()
      local thick = picture.alongX and ih or iw
      local long = picture.alongX and iw or ih
      tile = {
         picture = picture,
         start = startAt,
         length = long * (picture.to - picture.from) * (settings.width * 2 / thick),
         mirror = settings.mix and rng:random() < 0.5,
         backwards = settings.mix and rng:random() < 0.5,
      }
   end

   local vertsPerPicture = {}
   local function vertex(x, y, across, d)
      local along = (d - tile.start) / tile.length
      if tile.mirror then across = 1 - across end
      if tile.backwards then along = 1 - along end
      local p = tile.picture
      along = p.from + (p.to - p.from) * along
      if p.alongX then return { x, y, along, across } end
      return { x, y, across, along }
   end
   local function quad(ax, ay, bx, by, d0, cx, cy, dx, dy, d1)
      local verts = vertsPerPicture[tile.picture]
      if not verts then verts = {}; vertsPerPicture[tile.picture] = verts end
      local q = { vertex(ax, ay, 0, d0), vertex(bx, by, 1, d0), vertex(cx, cy, 0, d1), vertex(dx, dy, 1, d1) }
      verts[#verts + 1] = q[1]; verts[#verts + 1] = q[2]; verts[#verts + 1] = q[3]
      verts[#verts + 1] = q[2]; verts[#verts + 1] = q[4]; verts[#verts + 1] = q[3]
   end

   nextTile(0)
   tile.start = -((seed * 0.37) % 1) * tile.length
   for i = 2, #centre do
      local d0, d1 = distances[i - 1], distances[i]
      local ax, ay, bx, by = sides(i - 1)
      local cx, cy, dx, dy = sides(i)
      -- this piece may cross into the next tiles: end the old tile there, start a new one
      while d1 > tile.start + tile.length and d1 > d0 do
         local dm = tile.start + tile.length
         local s = (dm - d0) / (d1 - d0)
         local mx1, my1 = ax + (cx - ax) * s, ay + (cy - ay) * s
         local mx2, my2 = bx + (dx - bx) * s, by + (dy - by) * s
         quad(ax, ay, bx, by, d0, mx1, my1, mx2, my2, dm)
         nextTile(dm)
         -- the rest of the piece, from the split on
         ax, ay, bx, by, d0 = mx1, my1, mx2, my2, dm
         cx, cy, dx, dy = cx, cy, dx, dy
      end
      quad(ax, ay, bx, by, d0, cx, cy, dx, dy, d1)
   end

   local meshes = {}
   for picture, verts in pairs(vertsPerPicture) do
      local mesh = love.graphics.newMesh(verts, 'triangles', 'static')
      mesh:setTexture(picture.image)
      meshes[#meshes + 1] = mesh
   end
   return meshes
end

local function fillMesh(shape, dx, dy)
   local verts = {}
   local iw, ih = hatchImage:getDimensions()
   for _, tri in ipairs(shape.triangles) do
      for k = 1, 6, 2 do
         local x, y = tri[k] + dx, tri[k + 1] + dy
         verts[#verts + 1] = { x, y, x / iw * 1.5, y / ih * 1.5 }
      end
   end
   local mesh = love.graphics.newMesh(verts, 'triangles', 'static')
   mesh:setTexture(hatchImage)
   return mesh
end

local function rebuild()
   local stroke = STROKES[settings.stroke]
   for _, shape in ipairs(shapes) do
      local seed = shape.seed + (settings.boil and boilStep * 7.3 or 0)
      shape.outline = strokeMeshes(shape, stroke, seed)
      local dx, dy = 0, 0
      if settings.misreg then dx, dy = shape.misreg[1], shape.misreg[2] end
      shape.fillOffset = { dx, dy }
      shape.hatchMesh = fillMesh(shape, dx, dy)
   end
end

function love.load(args)
   love.graphics.setDefaultFilter('linear', 'linear')
   local files = love.filesystem.getDirectoryItems('strokes')
   table.sort(files)
   for _, file in ipairs(files) do
      local family = file:match('^(%a+)%d*%.png$')
      local f = FAMILIES[family]
      if f then
         STROKES[#STROKES + 1] = { file = 'strokes/' .. file, family = family, alongX = f.alongX, from = f.from, to = f.to }
      end
   end
   for _, stroke in ipairs(STROKES) do
      stroke.image = love.graphics.newImage(stroke.file, { mipmaps = true })
      stroke.image:setMipmapFilter('linear')
   end
   hatchImage = love.graphics.newImage('strokes/hatch.png')
   hatchImage:setWrap('repeat', 'repeat')
   for _, a in ipairs(args or {}) do
      if a == 'shot' then shotFrames = 3 end
      -- shot options: t2 (stroke 2), b, m, h, w14 (width 14)
      if a:match('^t%d$') then settings.stroke = tonumber(a:sub(2)) end
      if a:match('^w%d+$') then settings.width = tonumber(a:sub(2)) end
      if a == 'm' then settings.misreg = true end
      if a == 'h' then settings.hatch = true end
      if a == 'nomix' then settings.mix = false end
      if a == 'seed' then love.math.setRandomSeed(1) end
   end
   newShapes()
   rebuild()
end

function love.update(dt)
   if settings.boil then
      boilClock = boilClock + dt
      -- re-drawn 10 times a second, like a hand-animated line, not every frame
      if boilClock > 0.1 then
         boilClock = boilClock - 0.1
         boilStep = (boilStep + 1) % 3
         rebuild()
      end
   end
end

local function drawFill(shape)
   local dx, dy = shape.fillOffset[1], shape.fillOffset[2]
   love.graphics.setColor(shape.color)
   for _, tri in ipairs(shape.triangles) do
      love.graphics.polygon('fill', tri[1] + dx, tri[2] + dy, tri[3] + dx, tri[4] + dy, tri[5] + dx, tri[6] + dy)
   end
   if settings.hatch then
      love.graphics.setColor(1, 1, 1, 0.35)
      love.graphics.draw(shape.hatchMesh)
   end
end

function love.draw()
   love.graphics.clear(PAPER)
   for _, shape in ipairs(shapes) do
      if settings.fill then drawFill(shape) end
      love.graphics.setColor(INK)
      for _, mesh in ipairs(shape.outline) do love.graphics.draw(mesh) end
   end
   love.graphics.setColor(INK)
   love.graphics.print(string.format(
      'space new  t stroke: %s  x mix: %s  b boil: %s  m misreg: %s  h hatch: %s  f fill: %s  up/down width: %d  left/right wobble: %.1f  o overshoot: %s',
      STROKES[settings.stroke].file:match('[^/]+$'), tostring(settings.mix), tostring(settings.boil), tostring(settings.misreg),
      tostring(settings.hatch), tostring(settings.fill), settings.width, settings.wobble, tostring(settings.overshoot)),
      10, 745)

   if shotFrames then
      shotFrames = shotFrames - 1
      if shotFrames == 0 then
         love.graphics.captureScreenshot(function(data)
            data:encode('png', 'shot.png')
            love.event.quit()
         end)
      end
   end
end

function love.keypressed(key)
   if key == 'escape' then love.event.quit() end
   if key == 'space' then newShapes() end
   if key == 't' then settings.stroke = settings.stroke % #STROKES + 1 end
   if key == 'b' then settings.boil = not settings.boil end
   if key == 'm' then settings.misreg = not settings.misreg end
   if key == 'h' then settings.hatch = not settings.hatch end
   if key == 'f' then settings.fill = not settings.fill end
   if key == 'o' then settings.overshoot = not settings.overshoot end
   if key == 'x' then settings.mix = not settings.mix end
   if key == 'up' then settings.width = math.min(30, settings.width + 1) end
   if key == 'down' then settings.width = math.max(2, settings.width - 1) end
   if key == 'right' then settings.wobble = math.min(6, settings.wobble + 0.5) end
   if key == 'left' then settings.wobble = math.max(0, settings.wobble - 0.5) end
   if key == 's' then
      love.graphics.captureScreenshot('shot-' .. os.time() .. '.png')
   end
   rebuild()
end
