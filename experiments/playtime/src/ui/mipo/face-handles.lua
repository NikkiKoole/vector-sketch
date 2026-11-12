-- face-handles: the Mipo editor's face set by hand on the Mipo itself (BESPOKE-UI.md BU3). While
-- the face section is open, the eyes, brows, nose and mouth on the stage get a frame with a dot in
-- the middle (drag: move it) and a square on its corner (drag: size it). The same values the face
-- sliders set (mipo-appearance FACE_FIELDS), so the sliders follow; the face is laid out by
-- mipo-textures.faceLayout, as it's drawn. Symmetric: both eyes and brows move together.
--
-- Drawn in the UI pass on screen, after the editor's panel (its list clips to itself). A press on
-- a handle is the handle's: hovering one sets ui.overPanel, which the world's input reads.

local ui = require('src.ui.all')
local CharacterManager = require('src.character-manager')
local textures = require('src.mipo-textures')
local camera = require('src.camera')

local lib = {}

local cam = camera.getInstance()
local GRAB = 11          -- px: how near a handle a press takes it
local drag = nil         -- { feature, kind = 'move' | 'size', start = {...} } while dragging
local wasDown = false

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- body-local <-> the UI's units (the UI is drawn at ui.scale)
local function toScreen(body, x, y)
    return ui.toUI(cam:getScreenCoordinates(body:getWorldPoint(x, y)))
end
local function toLocal(body, ux, uy)
    return body:getLocalPoint(cam:getWorldCoordinates(ux * ui.scale, uy * ui.scale))
end

-- The features with their handles: where (from the layout), and what a move or a size sets.
-- u, v: the pointer across the head's box (0..1). For a size: the new half width / height over
-- the one at the press, times the value at the press.
local FEATURES = {
    { key = 'rightEye', move = function(u, v) return { eyeX = clamp(u - 0.5, 0, 0.5), eyeY = clamp(v, 0, 1) } end,
      size = function(kx, ky, st)
          return { eyeWMul = clamp(st.wMul * kx, 0.25, 2), eyeHMul = clamp(st.hMul * ky, 0.25, 2) }
      end, start = function(face) return { wMul = face.eye.wMul, hMul = face.eye.hMul } end },
    { key = 'leftEye', move = function(u, v) return { eyeX = clamp(0.5 - u, 0, 0.5), eyeY = clamp(v, 0, 1) } end },
    { key = 'rightBrow', move = function(_, v) return { browY = clamp(v, 0.1, 0.5) } end,
      size = function(kx, ky, st)
          return { browWMul = clamp(st.wMul * kx, 0.25, 2), browHMul = clamp(st.hMul * ky, 0.25, 2) }
      end, start = function(face) return { wMul = face.brow.wMul, hMul = face.brow.hMul } end },
    { key = 'leftBrow', move = function(_, v) return { browY = clamp(v, 0.1, 0.5) } end },
    { key = 'nose', move = function(_, v) return { noseY = clamp(v, 0, 1) } end,
      size = function(kx, ky, st)
          return { noseWMul = clamp(st.wMul * kx, 0.5, 3), noseHMul = clamp(st.hMul * ky, 0.5, 3) }
      end, start = function(face) return { wMul = face.nose.wMul, hMul = face.nose.hMul } end },
    { key = 'mouth', move = function(_, v, layout)
          -- the mouth's y is its anchor; the frame's middle sits off it by the shape's own offset
          return { mouthY = clamp(v - layout.mouthOffsetV, 0.5, 0.95) }
      end,
      size = function(kx, ky, st)
          return { mouthWMul = clamp(st.wMul * kx, 0.3, 2), mouthHMul = clamp(st.hMul * ky, 0.3, 2) }
      end, start = function(face) return { wMul = face.mouth.wMul, hMul = face.mouth.hMul } end },
}

-- the corner a size handle sits on: top right, away from the face's middle
local function cornerOf(f) return f.x + f.hw, f.y - f.hh end

local function apply(instance, layout, values)
    -- only when something changed (each change rebuilds the Mipo's pictures)
    local face, changed = layout.face, false
    local now = {
        eyeX = face.positioners.eye.x, eyeY = face.positioners.eye.y, browY = face.positioners.brow.y,
        noseY = face.positioners.nose.y, mouthY = face.positioners.mouth.y,
        eyeWMul = face.eye.wMul, eyeHMul = face.eye.hMul, browWMul = face.brow.wMul, browHMul = face.brow.hMul,
        noseWMul = face.nose.wMul, noseHMul = face.nose.hMul, mouthWMul = face.mouth.wMul, mouthHMul = face.mouth.hMul,
    }
    for k, v in pairs(values) do
        if math.abs((now[k] or 0) - v) > 0.002 then changed = true end
    end
    if not changed then return end
    CharacterManager.updateFaceOfPart(instance, layout.owner, values)
    CharacterManager.rebuildTextures(instance)
end

local function frame(body, f, hot)
    local pts = {}
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local x, y = toScreen(body, f.x + c[1] * f.hw, f.y + c[2] * f.hh)
        pts[#pts + 1], pts[#pts + 2] = x, y
    end
    love.graphics.setLineWidth(hot and 2 or 1)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.polygon('line', pts)
    love.graphics.setColor(1, 1, 1, hot and 0.95 or 0.55)
    love.graphics.polygon('line', pts)
end

local function dot(x, y, hot, square)
    love.graphics.setColor(0, 0, 0, 0.6)
    if square then love.graphics.rectangle('fill', x - 6, y - 6, 12, 12) else love.graphics.circle('fill', x, y, 7) end
    love.graphics.setColor(hot and { 1, 0.4, 0.45, 1 } or { 0.6, 0.9, 1, 1 })
    if square then love.graphics.rectangle('fill', x - 4, y - 4, 8, 8) else love.graphics.circle('fill', x, y, 5) end
end

function lib.draw(instance)
    local layout = instance and textures.faceLayout(instance)
    if not layout then
        drag = nil
        return
    end
    local body, box = layout.body, layout.box
    -- the mouth's frame middle off its anchor (positioners.mouth.y), as a share of the head's height
    if layout.mouth then
        local anchorY = box.topY + (box.botY - box.topY) * layout.face.positioners.mouth.y
        layout.mouthOffsetV = (layout.mouth.y - anchorY) / box.headH
    end
    local mx, my = ui.toUI(love.mouse.getPosition()) -- (not ui.mouseX: a scrolled list shifts that)
    local down = love.mouse.isDown(1)
    -- what's under the pointer: the nearest handle within reach
    local hover, hoverD
    for _, def in ipairs(FEATURES) do
        local f = layout[def.key]
        if f then
            local cx, cy = toScreen(body, f.x, f.y)
            local d = (cx - mx) ^ 2 + (cy - my) ^ 2
            local function near(kind)
                if d < GRAB * GRAB and (not hoverD or d < hoverD) then hover, hoverD = { def = def, kind = kind }, d end
            end
            near('move')
            if def.size then
                local kx, ky = toScreen(body, cornerOf(f))
                d = (kx - mx) ^ 2 + (ky - my) ^ 2
                near('size')
            end
        end
    end
    if down and not wasDown and hover and not ui.activeElementID then
        local f = layout[hover.def.key]
        drag = { def = hover.def, kind = hover.kind, hw = f.hw, hh = f.hh,
            start = hover.def.start and hover.def.start(layout.face) }
    elseif not down then
        drag = nil
    end
    wasDown = down
    if hover or drag then ui.overPanel = true end -- the press is ours, not the world's
    if drag then
        local lx, ly = toLocal(body, mx, my)
        local f = layout[drag.def.key]
        if drag.kind == 'move' then
            apply(instance, layout, drag.def.move((lx - box.leftX) / box.headW, (ly - box.topY) / box.headH, layout))
        elseif f then
            local kx = math.max(4, math.abs(lx - f.x)) / math.max(1e-3, drag.hw)
            local ky = math.max(4, math.abs(ly - f.y)) / math.max(1e-3, drag.hh)
            apply(instance, layout, drag.def.size(kx, ky, drag.start))
        end
        layout = textures.faceLayout(instance) or layout -- where it is now
    end
    for _, def in ipairs(FEATURES) do
        local f = layout[def.key]
        if f then
            -- the handle being dragged, or else the one under the pointer, lights up
            local active = drag or hover
            local on = active and active.def == def
            frame(body, f, on)
            local cx, cy = toScreen(body, f.x, f.y)
            dot(cx, cy, on and active.kind == 'move', false)
            if def.size then
                local kx, ky = toScreen(body, cornerOf(f))
                dot(kx, ky, on and active.kind == 'size', true)
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function lib.isDragging() return drag ~= nil end

return lib
