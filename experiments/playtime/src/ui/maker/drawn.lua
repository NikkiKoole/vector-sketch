-- src/ui/maker/drawn.lua — Puppetmaker 2's hand-drawn widgets for the Mipo maker (docs/MIPO-MAKER.md).
-- The drawings (textures/ui/maker/, copied from experiments/puppet-maker2/assets/ui/) are white chalk
-- strokes on clear: drawn tinted, the line dark and the '-mask' pictures in a colour. Immediate mode on
-- src/ui/all.lua's pointer (ui.mouseX/Y, mousePressed/Released), so the world under a widget isn't
-- poked (ui.activeElementID while pressed). Sizes come from the caller, never from picture pixels.
local lib = {}

local ui = require('src.ui.all')

local ROOT = 'textures/ui/maker/'
local INK = { 0.12, 0.1, 0.1 } -- the chalk line

-- pictures by name ('icons/eye-wide'), false when there is none (not tried again every frame)
local images = {}
function lib.image(name)
    local img = images[name]
    if img == nil then
        local path = name:match('^textures/') and name or ROOT .. name
        if not path:match('%.png$') then path = path .. '.png' end
        local ok, loaded = pcall(love.graphics.newImage, path)
        img = ok and loaded or false
        if img then img:setFilter('linear', 'linear') end
        images[name] = img
    end
    return img
end

-- a picture fitted into w x h (aspect kept), centred; scaled by `grow` (1 = fits)
local function drawFitted(img, x, y, w, h, grow)
    if not img then return end
    local iw, ih = img:getDimensions()
    local s = math.min(w / iw, h / ih) * (grow or 1)
    love.graphics.draw(img, x + w / 2, y + h / 2, 0, s, s, iw / 2, ih / 2)
end
lib.drawFitted = drawFitted

-- a picture stretched to x, y, w, h
local function drawStretched(img, x, y, w, h)
    if not img then return end
    local iw, ih = img:getDimensions()
    love.graphics.draw(img, x, y, 0, w / iw, h / ih)
end

local function inside(x, y, w, h)
    return ui.mouseX >= x and ui.mouseX <= x + w and ui.mouseY >= y and ui.mouseY <= y + h
end

-- the picked one breathes, as in Puppetmaker 2 (sin at 5 per second)
function lib.wobble(amount)
    return 1 + math.sin(love.timer.getTime() * 5) * (amount or 0.05)
end

-- A press that ends on the widget it started on: true once, at the release.
local function pressed(id, x, y, w, h)
    local over = inside(x, y, w, h)
    if over then ui.overPanel = true end
    if over and ui.mousePressed then ui.activeElementID = id end
    if ui.activeElementID == id and ui.mouseReleased then
        ui.activeElementID = nil
        return over
    end
    return false
end

-- The card: Puppetmaker's tall tab panel (tab1: its paper tab at the top left), filled and outlined.
-- Everything under it is the card's: the world isn't poked through it.
-- The card: a slightly uneven box, filled by a quiet shader (a flat warm colour, a touch lighter at
-- the top, no grain) and outlined in Nikki's crayon strokes (scripts/spikes/drawn-stroke.lua: the
-- strokes laid along a line, broken and overshooting at the corners). Everything under it is the
-- card's: the world isn't poked through it. (lib.cardPicture: Puppetmaker's tab picture, as before.)
local CARD_FILL = { 0.98, 0.94, 0.85 }
local CARD_STROKE = 10  -- px: the outline's width
local CARD_WOBBLE = 1.8 -- how much the stroke wanders
local STROKE         -- drawn-stroke, loaded once (a spike's file for now: moves to src/ with the maker)
local cardCache = {} -- { key, pts, meshes }

local cardShader = love.graphics.newShader([[
    uniform vec4 rect;   // x, y, w, h on screen
    uniform vec3 base;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec2 p = (sc - rect.xy) / rect.zw;
        float light = 1.0 + 0.035 * (1.0 - p.y) - 0.02 * pow(abs(p.x - 0.5) * 2.0, 3.0);
        return vec4(base * light, color.a);
    }
]])

-- the box's corners, each pushed a little off true by a fixed hash (the same box every frame)
local function cardPoints(x, y, w, h)
    local function j(k, amount) return (math.sin(k * 12.9898) * 43758.5453 % 1 - 0.5) * amount end
    local d = math.min(w, h) * 0.025
    return {
        { x + j(1, d), y + j(2, d) }, { x + w + j(3, d), y + j(4, d) },
        { x + w + j(5, d), y + h + j(6, d) }, { x + j(7, d), y + h + j(8, d) },
    }
end

function lib.card(x, y, w, h, fill)
    if inside(x, y, w, h) then ui.overPanel = true end
    STROKE = STROKE or love.filesystem.load('scripts/spikes/drawn-stroke.lua')()
    local key = table.concat({ math.floor(x), math.floor(y), math.floor(w), math.floor(h) }, ',')
    if cardCache.key ~= key then
        local pts = cardPoints(x, y, w, h)
        cardCache = { key = key, pts = pts,
            meshes = STROKE.meshes({ { pts = pts, loop = true, width = CARD_STROKE } }, CARD_WOBBLE, 0, true) }
    end
    local flat = {}
    for _, p in ipairs(cardCache.pts) do flat[#flat + 1] = p[1]; flat[#flat + 1] = p[2] end
    local dpi = love.graphics.getDPIScale() -- the shader's screen coords are pixels
    local tx, ty = love.graphics.transformPoint(x, y)
    local bx, by = love.graphics.transformPoint(x + w, y + h)
    tx, ty, bx, by = tx * dpi, ty * dpi, bx * dpi, by * dpi
    cardShader:send('rect', { tx, ty, bx - tx, by - ty })
    cardShader:send('base', fill or CARD_FILL)
    love.graphics.setShader(cardShader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon('fill', flat)
    love.graphics.setShader()
    love.graphics.setColor(INK)
    for _, mesh in ipairs(cardCache.meshes) do love.graphics.draw(mesh) end
    love.graphics.setColor(1, 1, 1)
end

function lib.cardPicture(x, y, w, h, fill)
    if inside(x, y, w, h) then ui.overPanel = true end
    love.graphics.setColor(fill or { 0.98, 0.93, 0.82 })
    drawStretched(lib.image('panels/tab1-mask'), x, y, w, h)
    love.graphics.setColor(INK)
    drawStretched(lib.image('panels/tab1'), x, y, w, h)
    love.graphics.setColor(1, 1, 1)
end

-- A taped strip behind a row (Puppetmaker's ui-header: wide strips for one row, the taller one for more).
function lib.tape(x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.45)
    drawStretched(lib.image(h / w < 0.3 and 'panels/ui-header' or 'panels/ui-header2'), x, y, w, h)
    love.graphics.setColor(1, 1, 1)
end

-- An icon button: a soft drawn square under a chalk icon; `opts.mask` (a colour) fills the icon's
-- '-mask' picture when there is one, `opts.picked` breathes and lifts it on a paper square.
-- Returns true when tapped.
function lib.iconButton(id, x, y, size, icon, opts)
    opts = opts or {}
    local grow = opts.picked and lib.wobble(0.06) or 1
    if opts.picked then
        love.graphics.setColor(0, 0, 0, 0.18)
        drawFitted(lib.image('panels/whiterect' .. (opts.paper or 1)), x + 4, y + 4, size, size)
        love.graphics.setColor(1, 0.97, 0.88)
        drawFitted(lib.image('panels/whiterect' .. (opts.paper or 1)), x, y, size, size)
    elseif not opts.bare then
        love.graphics.setColor(0, 0, 0, 0.1)
        drawFitted(lib.image('rect1'), x, y, size, size)
    end
    local mask = opts.mask and lib.image(icon .. '-mask')
    if mask then
        love.graphics.setColor(opts.mask)
        drawFitted(mask, x, y, size, size, grow * (opts.scale or 1))
    end
    love.graphics.setColor(INK[1], INK[2], INK[3], opts.dim and 0.35 or 1)
    drawFitted(lib.image(icon), x, y, size, size, grow * (opts.scale or 1))
    love.graphics.setColor(1, 1, 1)
    return pressed(id, x, y, size, size)
end

-- A drawn slider: Puppetmaker's chalk track and thumb. Dragging anywhere on it sets the value
-- (rounded to `step`). Returns the new value while it changes, else nil.
local SLIDER_PAD = 0.12 -- the track picture's ends, where the thumb stops
function lib.slider(id, x, y, w, h, value, min, max, step)
    local track, thumb = lib.image('interfaceparts/slider-track2'), lib.image('interfaceparts/slider-thumb5')
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.8)
    drawStretched(track, x, y + h * 0.2, w, h * 0.6)
    local x0, x1 = x + w * SLIDER_PAD * 0.5, x + w * (1 - SLIDER_PAD * 0.5)
    local t = (value - min) / (max - min)
    t = math.max(0, math.min(1, t))
    local tw = h * 0.85
    local dragging = ui.activeElementID == id
    love.graphics.setColor(dragging and { 0.95, 0.55, 0.3 } or { 0.98, 0.85, 0.55 })
    local thumbMask = lib.image('interfaceparts/slider-thumb1-mask')
    if thumbMask then drawFitted(thumbMask, x0 + (x1 - x0) * t - tw / 2, y, tw, h) end
    love.graphics.setColor(INK)
    drawFitted(thumb, x0 + (x1 - x0) * t - tw / 2, y, tw, h, dragging and 1.12 or 1)
    love.graphics.setColor(1, 1, 1)

    local over = inside(x, y, w, h)
    if over then ui.overPanel = true end
    if over and ui.mousePressed then
        ui.activeElementID, ui.draggingSliderID = id, id
    end
    if ui.activeElementID ~= id then return nil end
    if not ui.mouseIsDown then
        ui.activeElementID, ui.draggingSliderID = nil, nil
        return nil
    end
    local nt = math.max(0, math.min(1, (ui.mouseX - x0) / (x1 - x0)))
    local v = min + (max - min) * nt
    if step then v = math.floor(v / step + 0.5) * step end
    v = math.max(min, math.min(max, v))
    if v ~= value then return v end
    return nil
end

-- Puppetmaker's slider with an icon button at each end (mouth narrow <- -> wide): the buttons step
-- by `step`, the slider in between drags. Returns the new value when it changes, and how far along
-- it is (0..1, for the growl's pitch).
function lib.iconSlider(id, x, y, w, size, value, min, max, step, iconLess, iconMore)
    local new
    if lib.iconButton(id .. '-less', x, y, size, iconLess) then new = math.max(min, value - step) end
    if lib.iconButton(id .. '-more', x + w - size, y, size, iconMore) then new = math.min(max, value + step) end
    local v = lib.slider(id, x + size, y + size * 0.15, w - size * 2, size * 0.7, value, min, max, step / 4)
    new = new or v
    if new and new ~= value then return new, (new - min) / (max - min) end
    return nil
end

-- A paint blob (colorpick's dots, a different one per index); the picked one bigger, ringed.
function lib.blob(id, x, y, size, rgb, index, picked)
    local n = 12
    local dot = lib.image('colorpick/dot' .. (((index or 1) - 1) % n + 1) .. '.150')
    love.graphics.setColor(rgb)
    drawFitted(dot, x, y, size, size, picked and 1.25 * lib.wobble(0.04) or 0.9)
    if picked then
        love.graphics.setColor(INK)
        drawFitted(lib.image('circle1'), x, y, size, size, 1.35)
    end
    love.graphics.setColor(1, 1, 1)
    return pressed(id, x, y, size, size)
end

-- A drawn on/off switch (togglebody + togglethumb). Returns the new state when tapped, else nil.
function lib.toggle(id, x, y, w, h, on)
    love.graphics.setColor(on and { 0.75, 0.88, 0.6 } or { 0.9, 0.85, 0.78 })
    local body = lib.image('interfaceparts/togglebody1')
    drawStretched(body, x, y, w, h) -- the body's chalk, tinted: it is the only picture
    love.graphics.setColor(INK)
    local tw = h * 1.1
    local tx = on and (x + w - tw - w * 0.06) or (x + w * 0.06)
    local tmask = lib.image('interfaceparts/togglethumb1-mask')
    if tmask then
        love.graphics.setColor(on and { 0.95, 0.55, 0.3 } or { 0.98, 0.85, 0.55 })
        drawFitted(tmask, tx, y, tw, h)
        love.graphics.setColor(INK)
    end
    drawFitted(lib.image('interfaceparts/togglethumb1'), tx, y, tw, h)
    love.graphics.setColor(1, 1, 1)
    if pressed(id, x, y, w, h) then return not on end
    return nil
end

-- A cell of a part's picture as it would look on the Mipo: outline, fill and pattern baked by the
-- game's own OMP bake (src/render/omp-bake.lua bakePreview) from `look` (a texture block: bgHex, fgHex,
-- pHex, pURL...). `url` as in the shape catalogs ('mipo/eye/eye-03'); `noMask`: outline only (most
-- hair). One picture kept per url, baked again when its look changes: in lib.update, at most
-- BAKES_PER_FRAME a frame (switching parts would hitch); until then the old one or the plain outline
-- shows. Returns true when tapped.
local ompBake = require('src.render.omp-bake')
local BAKES_PER_FRAME = 3
local previews = {} -- url -> { key, image }
local wanted = {}   -- url -> { key, look, noMask }: asked for while drawing, baked in lib.update

local function lookKey(look, noMask)
    return table.concat({ look.bgHex or '', look.fgHex or '', look.pHex or '', look.pURL or '',
        look.pr or 0, look.psx or 1, look.psy or 1, look.ptx or 0, look.pty or 0, noMask and 'n' or 'm' }, '|')
end

-- while drawing: the picture if it's baked for this look, else ask for it (the old one meanwhile)
local function preview(url, look, noMask)
    local key = lookKey(look, noMask)
    local entry = previews[url]
    if entry and entry.key == key then return entry.image end
    wanted[url] = { key = key, look = look, noMask = noMask }
    return entry and entry.image
end

-- Bake what drawing asked for, a few a frame. Call from update, never while drawing: a bake
-- switches canvases (half-drawn cells and a lost frame, 2026-11-09).
function lib.update()
    local n = 0
    for url, want in pairs(wanted) do
        if n >= BAKES_PER_FRAME then break end
        n = n + 1
        wanted[url] = nil
        local maskURL = not want.noMask and love.filesystem.getInfo('textures/' .. url .. '-mask.png')
            and url .. '-mask.png'
        local image = ompBake.bakePreview(url .. '.png', maskURL, want.look)
        local entry = previews[url]
        if entry and entry.image then entry.image:release() end
        previews[url] = { key = want.key, image = image }
    end
end

function lib.partCell(id, x, y, size, url, look, picked, noMask)
    local grow = picked and lib.wobble(0.05) or 0.88
    if picked then
        love.graphics.setColor(1, 0.97, 0.88, 0.9)
        drawFitted(lib.image('panels/whiterect2'), x, y, size, size)
    end
    local image = look and preview(url, look, noMask)
    if image then
        love.graphics.setColor(1, 1, 1)
        drawFitted(image, x, y, size, size, grow)
    else
        love.graphics.setColor(INK)
        drawFitted(lib.image('textures/' .. url), x, y, size, size, grow)
    end
    love.graphics.setColor(1, 1, 1)
    return pressed(id, x, y, size, size)
end

-- The 'none' cell (no hair): an empty chalk circle, crossed. Returns true when tapped.
function lib.noneCell(id, x, y, size, picked)
    if picked then
        love.graphics.setColor(1, 0.97, 0.88, 0.9)
        drawFitted(lib.image('panels/whiterect2'), x, y, size, size)
    end
    love.graphics.setColor(INK[1], INK[2], INK[3], 0.6)
    local grow = picked and 0.7 * lib.wobble(0.05) or 0.6
    drawFitted(lib.image('circle2'), x, y, size, size, grow)
    love.graphics.setLineWidth(3)
    local d = size * 0.22
    love.graphics.line(x + size / 2 - d, y + size / 2 + d, x + size / 2 + d, y + size / 2 - d)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
    return pressed(id, x, y, size, size)
end

return lib
