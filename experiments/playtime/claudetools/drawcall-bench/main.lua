-- claudetools/drawcall-bench: how much do draw calls cost on this machine (docs/MIPO-DRAWING.md L2)?
-- 100 "Mipos" x 30 parts, each part a 10-vertex textured fan; run: love claudetools/drawcall-bench
-- On the phone: LOVE_DIR=claudetools/drawcall-bench native/ios/device.sh (replaces Playtime there
-- until the next plain run); the results stay on screen and go to drawcall-bench.txt in the save
-- folder. iOS keeps vsync on, so 'frame' can't go under 16.7 ms there: 'submit' is the CPU's part.
local MIPOS, PARTS, FRAMES = 100, 30, 300
love.filesystem.remove('drawcall-bench.txt') -- the last run's: an install keeps the save folder
local function texture(seed)
    local d = love.image.newImageData(64, 64)
    d:mapPixel(function(x, y) return (x * seed % 64) / 64, (y * 7 % 64) / 64, (seed % 5) / 5, 1 end)
    return love.graphics.newImage(d)
end
local function fanVerts(cx, cy, r, u0, v0, du, dv)
    local v = { { cx, cy, u0 + du / 2, v0 + dv / 2 } }
    for i = 0, 8 do
        local a = i / 8 * math.pi * 2
        v[#v + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r, u0 + (math.cos(a) + 1) / 2 * du, v0 + (math.sin(a) + 1) / 2 * dv }
    end
    return v
end
-- where Mipo m's part p sits
local function place(m, p)
    return 20 + (m % 20) * 58 + (p % 6) * 6, 20 + math.floor(m / 20) * 150 + math.floor(p / 6) * 25
end

-- A: today: every part its own mesh and its own texture
local perPart = {}
for m = 0, MIPOS - 1 do for p = 0, PARTS - 1 do
    local mesh = love.graphics.newMesh(fanVerts(0, 0, 12, 0, 0, 1, 1), 'fan', 'dynamic')
    mesh:setTexture(texture(m * PARTS + p + 1))
    local x, y = place(m, p)
    perPart[#perPart + 1] = { mesh = mesh, x = x, y = y }
end end
-- D: same draws, one shared texture
local shared = texture(3)
local sharedMesh = love.graphics.newMesh(fanVerts(0, 0, 12, 0, 0, 1, 1), 'fan', 'dynamic')
sharedMesh:setTexture(shared)
-- B/C: one atlas (6x5 cells) and one triangle mesh per Mipo
local atlas = texture(9)
local function mipoTriangles(m, ox, oy)
    local tris = {}
    for p = 0, PARTS - 1 do
        local x, y = place(m, p)
        local cu, cv = (p % 6) / 6, math.floor(p / 6) / 5
        local fan = fanVerts(x + ox, y + oy, 12, cu, cv, 1 / 6, 1 / 5)
        for i = 2, #fan - 1 do
            tris[#tris + 1] = fan[1]; tris[#tris + 1] = fan[i]; tris[#tris + 1] = fan[i + 1]
        end
    end
    return tris
end
local perMipo = {}
for m = 0, MIPOS - 1 do
    local mesh = love.graphics.newMesh(mipoTriangles(m, 0, 0), 'triangles', 'dynamic')
    mesh:setTexture(atlas)
    perMipo[#perMipo + 1] = mesh
end

local cases = {
    { 'A  3000 meshes, 3000 textures (today)', draws = MIPOS * PARTS, function() for _, d in ipairs(perPart) do love.graphics.draw(d.mesh, d.x, d.y) end end },
    { 'D  3000 meshes, 1 texture', draws = MIPOS * PARTS, function() for _, d in ipairs(perPart) do love.graphics.draw(sharedMesh, d.x, d.y) end end },
    { 'B  100 meshes, atlas, static', draws = MIPOS, function() for _, mesh in ipairs(perMipo) do love.graphics.draw(mesh) end end },
    { 'C  100 meshes, atlas, rewritten per frame', draws = MIPOS, function(frame)
        local wobble = (frame % 2)
        for m, mesh in ipairs(perMipo) do
            mesh:setVertices(mipoTriangles(m - 1, wobble, 0))
            love.graphics.draw(mesh)
        end
    end },
}
local results = {}
function love.run()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    for _, case in ipairs(cases) do
        for frame = 1, 30 do love.graphics.origin(); love.graphics.clear(); case[2](frame); love.graphics.present() end -- warm up
        local cpu, total = 0, 0
        for frame = 1, FRAMES do
            love.event.pump()
            -- timed after clear: on iOS the frame's first graphics call waits for a free screen
            -- buffer (vsync), which made 100 draws look as dear as 3000
            local tf = love.timer.getTime()
            love.graphics.origin(); love.graphics.clear()
            local t0 = love.timer.getTime()
            case[2](frame)
            local t1 = love.timer.getTime()
            love.graphics.present()
            local t2 = love.timer.getTime()
            cpu, total = cpu + (t1 - t0), total + (t2 - tf)
        end
        results[#results + 1] = string.format('%-44s submit %6.2f ms (%5.2f us a draw)   frame %6.2f ms',
            case[1], cpu / FRAMES * 1000, cpu / FRAMES / case.draws * 1e6, total / FRAMES * 1000)
    end
    local _, _, _, device = love.graphics.getRendererInfo()
    table.insert(results, 1, love.system.getOS() .. ', ' .. device .. ', ' .. MIPOS * PARTS .. ' parts')
    local text = table.concat(results, '\n')
    print(text)
    love.filesystem.write('drawcall-bench.txt', text .. '\n')
    return function() -- keep the results on screen (a phone has no console); esc or quit ends
        love.event.pump()
        for name, a in love.event.poll() do
            if name == 'quit' or (name == 'keypressed' and a == 'escape') then return 0 end
        end
        love.graphics.origin(); love.graphics.clear(0.1, 0.1, 0.1)
        love.graphics.print(text, 20, 20)
        love.graphics.present()
        love.timer.sleep(0.05)
    end
end
