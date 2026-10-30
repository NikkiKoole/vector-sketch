-- src/render/omp-bake.lua (split from physics/box2d-draw-textured.lua, SPLIT1)
local lib = {}
local registry = require('src.registry')
local ribbon = require('src.render.ribbon')
local state = require('src.state')
local color = require('src.color')

local function safeLoadImage(path)
    local info = love.filesystem.getInfo(path)
    if not info then return nil end
    return love.graphics.newImage(path)
end

local tex1 = safeLoadImage('textures/pat/type0.png')
if not tex1 then
    -- Fallback: 1x1 white pixel so textured rendering doesn't crash on nil
    local pd = love.image.newImageData(1, 1)
    pd:setPixel(0, 0, 1, 1, 1, 1)
    tex1 = love.graphics.newImage(pd)
end
tex1:setWrap('mirroredrepeat', 'mirroredrepeat')

local line = safeLoadImage('textures/shapes6.png')
local maskTex = safeLoadImage('textures/shapes6-mask.png')
local imageCache = {}
-- Paths that aren't there, so they're looked up once, not every frame (a bodyhair's fgURL names a
-- mask that doesn't exist: 40 filesystem lookups a frame with 20 Mipos). A picture added while the
-- game runs shows after a hot reload of this file, which empties both.
local missingImages = {}
-- Baked OMP images are 1/shrinkFactor of the source size. 2 = a quarter of the texture
-- memory (4.5 -> 1.1 MB per Mipo) and ~40% faster bakes; at the dollhouse zoom the
-- sources carry ~4.5x more pixels than reach the screen, so it only shows close up as
-- slightly softer grain. Patches stay put (their own bake shrinks too). Measured in
-- experiments/omp-bench (results/results.md, patch-check).
local shrinkFactor = 2

-- Composited textures made since the last full GC. Replaced textures are only
-- freed by the GC, which barely notices them (GPU memory, tiny Lua objects):
-- 25 randomizes took texture memory from 41 to 105 MB. main.lua runs a full
-- collect once this passes a threshold.
lib.texturesCreated = 0

local function getLoveImage(path, settings)
    if missingImages[path] then return nil, nil, nil end
    if not imageCache[path] then
        local info = love.filesystem.getInfo(path)
        if not info or info.type ~= 'file' then
            missingImages[path] = true
            return nil, nil, nil
        end
        local img = love.graphics.newImage(path)
        if img then
            local imgw, imgh = img:getDimensions()
            imageCache[path] = { img = img, imgw = imgw, imgh = imgh }
        end
    end

    -- Apply wrap on cache hits too: the cache is keyed by path only, so an
    -- image first loaded without settings would otherwise never get its
    -- wrap mode. Only touch the image when the mode actually changes.
    local entry = imageCache[path]
    if entry and settings and settings.wrapX and settings.wrapY
        and (entry.wrapX ~= settings.wrapX or entry.wrapY ~= settings.wrapY) then
        entry.img:setWrap(settings.wrapX, settings.wrapY)
        entry.wrapX, entry.wrapY = settings.wrapX, settings.wrapY
    end

    if imageCache[path] then
        return imageCache[path].img, imageCache[path].imgw, imageCache[path].imgh
    else
        return nil, nil, nil
    end
end

local settings = { wrapX = 'mirroredrepeat', wrapY = 'mirroredrepeat' }
getLoveImage('textures/pat/type0.png', settings)
getLoveImage('textures/pat/type1.png', settings)
getLoveImage('textures/pat/type2.png', settings)
getLoveImage('textures/pat/type3.png', settings)
getLoveImage('textures/pat/type4.png', settings)
getLoveImage('textures/pat/type5.png', settings)
getLoveImage('textures/pat/type6.png', settings)
getLoveImage('textures/pat/type7.png', settings)
getLoveImage('textures/pat/type8.png', settings)


--todo the things that have a hex, should have the rgba values directly so we dont have to calculate them every frame.
-- fix this with something like function setBgColor(item, val)
--    item.bgR, item.bgG, item.bgB, item.bgA = ToColor(val)-
--end

local function setBgColor(item, val)
    item.bgHex = val
    item.cached.bgR, item.cached.bgG, item.cached.bgB, item.cached.bgA = color.hexToColor(val)
    item.cached.bgRGB = { item.cached.bgR, item.cached.bgG, item.cached.bgB }
end

local function setFgColor(item, val)
    item.fgHex = val
    item.cached.fgR, item.cached.fgG, item.cached.fgB, item.cached.fgA = color.hexToColor(val)
    item.cached.fgRGB = { item.cached.fgR, item.cached.fgG, item.cached.fgB }
end

local function setPColor(item, val)
    item.pHex = val
    item.cached.pR, item.cached.pG, item.cached.pB, item.cached.pA = color.hexToColor(val)
    item.cached.pRGB = { item.cached.pR, item.cached.pG, item.cached.pB }
end

function lib.makeCached(item)
    if not item.cached then item.cached = {} end
    setBgColor(item, item.bgHex)
    setFgColor(item, item.fgHex)
    setPColor(item, item.pHex)
end


-- only thing thats no longer possible == using an alpha for the background color
local maskShader = love.graphics.newShader([[
	uniform Image fill;
    uniform vec4 backgroundColor;
    uniform mat2 uvTransform;
    uniform vec2 uvTranslation;

	vec4 effect(vec4 color, Image mask, vec2 uv, vec2 fc) {
        vec2 transformedUV = uv * uvTransform;
        transformedUV.x += uvTranslation.x;
        transformedUV.y += uvTranslation.y;
        vec3 patternMix = mix(backgroundColor.rgb, color.rgb, Texel(fill, transformedUV).a * color.a);
        return vec4(patternMix, Texel(mask, uv).r * backgroundColor.a  );
	}
]])
local function getDrawParams(flipx, flipy, imgw, imgh)
    local sx = flipx
    local sy = flipy

    local ox = flipx == -1 and imgw or 0
    local oy = flipy == -1 and imgh or 0

    return sx, sy, ox, oy
end

lib.makeTexturedCanvas = function(lineart, mask, color1, alpha1, texture2, color2, alpha2, texRot, texScaleX, texScaleY,
                                  texOffX, texOffY,
                                  lineColor, lineAlpha,
                                  flipx, flipy, patches)

    local lineartColor = lineColor or { 0, 0, 0, 1 }
    local lw, lh = lineart:getDimensions()
        local canvas = love.graphics.newCanvas(lw, lh, { dpiscale = 1 })

        love.graphics.setCanvas({ canvas, stencil = false }) --<<<

        --

        -- the reason for outline ghost stuff is this color
        -- its not a simple fix, you could make it so we use color A if some layer is lpha 0 etc
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<

        love.graphics.setShader(maskShader)
        local transform = love.math.newTransform()

        transform:rotate(texRot)
        transform:scale(texScaleX, texScaleY)

        local m1, m2, _, _, m5, m6 = transform:getMatrix()
        local dx = texOffX --love.math.random() * .001
        local dy = texOffY
        if texture2 then
            maskShader:send('fill', texture2)
        end

        maskShader:send('backgroundColor', { color1[1], color1[2], color1[3], alpha1 })
        maskShader:send('uvTransform', { { m1, m2 }, { m5, m6 } })
        maskShader:send('uvTranslation', { dx, dy })

        if mask then
            local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
            love.graphics.setColor(color2[1], color2[2], color2[3], alpha2)
            love.graphics.draw(mask, 0, 0, 0, sx, sy, ox, oy)
        end
        love.graphics.setShader()

        if patches then
            for i = 1, #patches do
                local patch = patches[i]
                if patch and patch.img then
                    love.graphics.setColorMask(true, true, true, false)
                    local r, g, b, a = color.hexToColor(patch.tint)
                    love.graphics.setColor(r, g, b, a)
                    local image = patch.img
                    local imgw, imgh = image:getDimensions()
                    local xOffset = (patch.tx or 0) * (imgw) * shrinkFactor
                    local yOffset = (patch.ty or 0) * (imgh) * shrinkFactor
                    love.graphics.draw(image, (lw) / 2 + xOffset, (lh) / 2 + yOffset,
                        (patch.r or 0) * ((math.pi * 2) / 16),
                        (patch.sx or 1) * shrinkFactor,
                        (patch.sy or 1) * shrinkFactor,
                        imgw / 2, imgh / 2)
                    love.graphics.setColorMask(true, true, true, true)
                end
            end
        end

        -- I want to know If we do this or not..
        -- if (true and renderPatch) then

        love.graphics.setColor(lineartColor[1], lineartColor[2], lineartColor[3], lineAlpha)
        local sx, sy, ox, oy = getDrawParams(flipx, flipy, lw, lh)
        love.graphics.draw(lineart, 0, 0, 0, sx, sy, ox, oy)

        love.graphics.setColor(0, 0, 0) --- huh?!
        love.graphics.setCanvas()       --- <<<<<

        local otherCanvas = love.graphics.newCanvas(lw / shrinkFactor, lh / shrinkFactor,
            { dpiscale = 1 })
        love.graphics.setCanvas({ otherCanvas, stencil = false })                 --<<<
        love.graphics.clear(lineartColor[1], lineartColor[2], lineartColor[3], 0) ---<<<<
        love.graphics.setColor(1, 1, 1)
        --- huh?!
        love.graphics.draw(canvas, 0, 0, 0, 1 / shrinkFactor, 1 / shrinkFactor)
        love.graphics.setCanvas()       --- <<<<<
        local imageData = otherCanvas:newImageData()
        love.graphics.setColor(0, 0, 0) --- huh?!

        canvas:release()
        otherCanvas:release()
        return imageData
end

local function makePatch(name, ud)
    local result = nil
    if ud.extra[name] and ud.extra[name].bgURL then
        local outlineImage = getLoveImage('textures/' .. ud.extra[name].bgURL)
        local olr, olg, olb, ola = color.hexToColor(ud.extra[name].bgHex)
        local maskImage = getLoveImage('textures/' .. ud.extra[name].fgURL)
        local mr, mg, mb, ma = color.hexToColor(ud.extra[name].fgHex)
        local patternImage = getLoveImage('textures/pat/' .. ud.extra[name].pURL)
        local pr, pg, pb, pa = color.hexToColor(ud.extra[name].pHex)
        if outlineImage then
            local imgData = lib.makeTexturedCanvas(
                outlineImage,            -- line art
                maskImage,               -- mask
                { mr, mg, mb },          -- color1
                ma,                      -- alpha1
                patternImage or tex1,    -- texture2 (fill texture)
                { pr, pg, pb },          -- color2
                pa,                      -- alpha2
                ud.extra[name].pr or 0,  -- texRot
                ud.extra[name].psx or 1, -- texScale
                ud.extra[name].psy or 1, -- texScale
                ud.extra[name].ptx or 0,
                ud.extra[name].pty or 0,
                { olr, olg, olb },      -- lineColor
                ola,                    -- lineAlpha
                ud.extra[name].fx or 1, -- flipx (normal)
                ud.extra[name].fy or 1  -- flipy (normal)
            )
            lib.texturesCreated = lib.texturesCreated + 1
            local img = love.graphics.newImage(imgData)
            imgData:release()
            result = {
                img = img,
                --img = getLoveImage('textures/' .. ud.extra.patch1URL),
                tint = ud.extra[name].tint or 'ffffff',
                tx = ud.extra[name].tx,
                ty = ud.extra[name].ty,
                sx = ud.extra[name].sx,
                sy = ud.extra[name].sy,
                r = ud.extra[name].r
            }
        end
        return result
    end
    return result
end

-- Release baked images that were replaced by a re-bake, instead of leaving their GPU memory
-- to the GC (omp-bench 'release': randomizing a Mipo 25x left +5 MB without this, 0 with it).
-- A cloned fixture shares its original's image until it is re-baked itself, so only release
-- what no fixture holds any more. The strip/fan meshes cached per image go with it.
local function releaseReplacedImages(replaced, bodies)
    local inUse = {}
    for _, body in ipairs(bodies) do
        for _, fixture in ipairs(body:getFixtures()) do
            local ud = fixture:getUserData()
            if type(ud) == 'table' and ud.extra and ud.extra.ompImage then
                inUse[ud.extra.ompImage] = true
            end
        end
    end
    for _, img in ipairs(replaced) do
        if not inUse[img] then
            inUse[img] = true -- the same image can be in the list twice
            ribbon.releaseImage(img)
            img:release()
        end
    end
end

local function releasePatches(patches)
    for _, patch in ipairs(patches) do
        if patch then patch.img:release() end
    end
end

-- The sfixtures to look at for a picture to (re)bake: OMP pictures only live on sfixtures, so this
-- is the registry's, kept as a list until it changes. Walking every fixture of every body each
-- frame (love.draw calls this) was 2.4 ms with 100 Mipos. userData is still read each frame, so a
-- `dirty` set anywhere is seen.
local bakeList = { version = nil, fixtures = {} }
local function sfixturesToCheck()
    if bakeList.version ~= registry.sfixtureVersion then
        local list = {}
        for _, fixture in pairs(registry.sfixtures) do list[#list + 1] = fixture end
        bakeList.version, bakeList.fixtures = registry.sfixtureVersion, list
    end
    return bakeList.fixtures
end

function lib.makeCombinedImages()
    local replaced = nil
    local fixtures = sfixturesToCheck()
    for i = 1, #fixtures do
        local ud = not fixtures[i]:isDestroyed() and fixtures[i]:getUserData()
        if ud and type(ud) == 'table' and ud.extra and ud.extra.OMP and ud.extra.dirty then
            repeat -- break = done (no goto: the web build's Lua 5.1 has none)
            local patch1 = makePatch('patch1', ud)
            local patch2 = makePatch('patch2', ud)
            local patch3 = makePatch('patch3', ud)
            local patches = { patch1 or false, patch2 or false, patch3 or false } -- avoid sparse table
            local main = ud.extra.main
            if ud.extra.ompImage then
                replaced = replaced or {}
                replaced[#replaced + 1] = ud.extra.ompImage
            end

            if not main.cached then
                lib.makeCached(main)
            end
            local cached = main.cached

            -- bgURL can be deliberately cleared by the Mipo editor's "null"
            -- thumbnail. Drop ompImage and skip recompose so the renderer's
            -- non-OMP fallback path also short-circuits cleanly.
            if not main.bgURL or main.bgURL == '' then
                releasePatches(patches)
                ud.extra.ompImage = nil
                ud.extra.dirty = false
                break
            end

            local outlineImage = getLoveImage('textures/' .. main.bgURL)
            local hasFgURL = main.fgURL and main.fgURL ~= ''
            local maskImage = hasFgURL and getLoveImage('textures/' .. main.fgURL) or nil
            local patternImage = getLoveImage('textures/pat/' .. main.pURL)

            if outlineImage or line then
                local imgData = lib.makeTexturedCanvas(
                    outlineImage or line, -- line art
                    maskImage or (hasFgURL and maskTex) or nil, -- mask (nil for outline-only textures)
                    cached.fgRGB,         -- color1
                    cached.fgA,           -- alpha1
                    patternImage or tex1, -- texture2 (fill texture)
                    cached.pRGB,          -- color2
                    cached.pA,            -- alpha2
                    main.pr or 0,         -- texRot
                    main.psx or 1,        -- texScale
                    main.psy or 1,        -- texScale
                    main.ptx or 0,
                    main.pty or 0,
                    cached.bgRGB,              -- lineColor
                    cached.bgA,                -- lineAlpha
                    main.fx or 1,              -- flipx (normal)
                    main.fy or 1,              -- flipy (normal)
                    patches               -- renderPatch
                )
                local image = love.graphics.newImage(imgData)
                imgData:release()
                lib.texturesCreated = lib.texturesCreated + 1
                ud.extra.ompImage = image
            end
            releasePatches(patches)
            fixtures[i]:setUserData(ud)

            ud.extra.dirty = false
            until true
        end
    end
    if replaced then releaseReplacedImages(replaced, state.physicsWorld:getBodies()) end
end


lib.getLoveImage = getLoveImage

return lib
