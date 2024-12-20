local mesh = {}

local formats = require 'lib.formats'
local geom = require 'lib.geom'
local unloop = require 'lib.unpack-points'
local hit = require 'lib.hit'
local bbox = require 'lib.bbox'
local numbers = require 'lib.numbers'
local polyline = require 'lib.polyline'
local parse = require 'lib.parse-file'
local parentize = require 'lib.parentize'
local border = require 'lib.border-mesh'

local inspect = require 'vendor.inspect'
require 'lib.basics' --tableconcat

-- todo @global imageCache
-- todo @global meshCache

local function split_poly(poly, intersection)
    local biggestIndex = math.max(intersection.i1, intersection.i2)
    local smallestIndex = math.min(intersection.i1, intersection.i2)
    local wrap = {}
    local bb = biggestIndex

    while bb ~= smallestIndex do
        bb = bb + 2
        if bb > #poly - 1 then
            bb = 1
        end
        table.insert(wrap, poly[bb])
        table.insert(wrap, poly[bb + 1])
    end

    table.insert(wrap, intersection.x)
    table.insert(wrap, intersection.y)

    local back = {}
    local bk = biggestIndex

    while bk ~= smallestIndex do
        table.insert(back, poly[bk])
        table.insert(back, poly[bk + 1])
        bk = bk - 2
    end

    table.insert(back, intersection.x)
    table.insert(back, intersection.y)

    return wrap, back
end

local function get_line_intersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
    local s1_x, s1_y, s2_x, s2_y
    local s1_x = p1_x - p0_x
    local s1_y = p1_y - p0_y
    local s2_x = p3_x - p2_x
    local s2_y = p3_y - p2_y

    local s, t
    s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y)
    t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y)

    if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
        return p0_x + (t * s1_x), p0_y + (t * s1_y)
    end

    return 0
end


local function get_collisions(poly)
    local collisions = {}

    for outeri = 1, #poly, 2 do
        local ax = poly[outeri]
        local ay = poly[outeri + 1]
        local ni = outeri + 2
        if outeri == #poly - 1 then ni = 1 end
        local bx = poly[ni]
        local by = poly[ni + 1]

        for inneri = 1, #poly, 2 do
            local cx = poly[inneri]
            local cy = poly[inneri + 1]
            local ni = inneri + 2
            if inneri == #poly - 1 then ni = 1 end
            local dx = poly[ni]
            local dy = poly[ni + 1]

            if inneri ~= outeri then
                local result, opt = get_line_intersection(ax, ay, bx, by, cx, cy, dx, dy)
                if (ax == cx and ay == cy) or (ax == dx and ay == dy) or
                    (bx == cx and by == cy) or (bx == dx and by == dy) then
                    -- print("share corner")
                else
                    if result ~= 0 then
                        local col = { i1 = outeri, i2 = inneri, x = result, y = opt }
                        local alreadyfound = false

                        for i = 1, #collisions do
                            if (collisions[i].i1 == inneri and collisions[i].i2 == outeri) then
                                alreadyfound = true
                            else
                            end
                        end

                        if not alreadyfound then
                            table.insert(collisions, col)
                        end
                    end
                end
            end
        end
    end
    return collisions
end

local function getTriangleCentroid(triangle)
    local x = (triangle[1] + triangle[3] + triangle[5]) / 3
    local y = (triangle[2] + triangle[4] + triangle[6]) / 3
    return x, y
end

mesh.reTriangulatePolygon = function(poly, result)
    local p = poly
    local triangles = love.math.triangulate(p)
    for j = 1, #triangles do
        local t = triangles[j]
        local cx, cy = getTriangleCentroid(t)
        if hit.pointInPath(cx, cy, p) then
            table.insert(result, t)
        end
    end
end

mesh.decompose_complex_poly = function(poly, result)
    local intersections = get_collisions(poly)
    if #intersections == 0 then
        result = TableConcat(result, { poly })
    end
    if #intersections > 1 then
        local p1, p2 = split_poly(poly, intersections[1])
        local p1c, p2c = get_collisions(p1), get_collisions(p2)
        if (#p1c > 0) then
            result = mesh.decompose_complex_poly(p1, result)
        else
            result = TableConcat(result, { p1 })
        end

        if (#p2c > 0) then
            result = mesh.decompose_complex_poly(p2, result)
        else
            result = TableConcat(result, { p2 })
        end
    end
    if #intersections == 1 then
        local p1, p2 = split_poly(poly, intersections[1])
        result = TableConcat(result, { p1 })
        result = TableConcat(result, { p2 })
    end

    return result
end

mesh.makeVertices = function(shape)
    --local triangles = {}
    if (shape.type == 'meta') then return end
    if (shape.folder) then return end

    local points = shape.points
    local vertices = {}

    if shape.type == nil or shape.type == 'poly' then
        if (points and #points >= 2) then
            local scale = 1
            local coords = {}
            local ps = {}

            for l = 1, #points do
                table.insert(coords, points[l][1])
                table.insert(coords, points[l][2])
            end

            if (shape.color) then
                local polys = mesh.decompose_complex_poly(coords, {})
                local result = {}

                for k = 1, #polys do
                    local p = polys[k]
                    if (#p >= 6) then
                        -- if a import breaks on triangulation errors uncomment this
                        --	       print( #p, inspect(p))

                        mesh.reTriangulatePolygon(p, result)
                    end
                end

                for j = 1, #result do
                    table.insert(vertices, { result[j][1], result[j][2] })
                    table.insert(vertices, { result[j][3], result[j][4] })
                    table.insert(vertices, { result[j][5], result[j][6] })
                end
            end
        end
    else
        -- i re-use this in puppetmaker to get the angle for the feet
        --print(cp1.x, cp1.y, cp2.x, cp2.y)
        -- todo whne the curve is null we make a perfect one for it using lerp



        if (shape.type == 'rubberhose') then
            -- pull the point data from the shape
            local start = {
                x = shape.points[1][1],
                y = shape.points[1][2]
            }
            local eind = {
                x = shape.points[2][1],
                y = shape.points[2][2]
            }

            -- pull more data from the shape
            local scale = shape.data.scale or 1
            local scaleX = (shape.data.scaleX or 1) * scale
            local scaleY = (shape.data.scaleY or 1) * scale
            local cp1, cp2 = geom.positionControlPoints(start, eind, shape.data.length * scaleY, shape.data.flop,
                shape.data.borderRadius)

            local rubberhoseSuccess = true
            if (tostring(cp1.x) == 'nan' or tostring(cp2.x) == 'nan' or tostring(cp1.y) == 'nan' or tostring(cp2.y) == 'nan') then
                rubberhoseSuccess = false
            end

            local curve = nil
            local thickness = nil
            local magicRubberhose = 4.46 -- this value is coming from the way rubberhoses are constructed
            local magicDivider = 3       -- some things need to be divide by 3, don't understand why
            local coords = {}

            -- setting up the data according to if we have succeeded in the rubberhose setup
            if rubberhoseSuccess then
                curve = love.math.newBezierCurve({ start.x, start.y, cp1.x, cp1.y, cp2.x, cp2.y, eind.x, eind.y })
                shape._curve = curve
                local stretchyWidthDivider = 1
                thickness = { scaleX * (shape.data.width / 3) / stretchyWidthDivider }
                local steps = shape.data.steps

                for i = 0, steps do
                    local px, py = curve:evaluate(i / steps)
                    table.insert(coords, { px, py })
                end
            else
                curve = love.math.newBezierCurve({ start.x, start.y, numbers.lerp(start.x, eind.x, .5),
                    numbers.lerp(start.y, eind.y, .5), eind.x, eind.y, })
                shape._curve = curve

                local stretchyWidthDivider = 1
                local d = (geom.distance(start.x, start.y, eind.x, eind.y))
                local m = ((shape.data.length * math.abs(scaleX)) / magicRubberhose)

                -- this does the actual stretchy stuff!!
                local mult = numbers.mapInto(d, m, m * 10, 1, 10 / magicDivider)
                thickness = { scaleX * (shape.data.width / magicDivider) / (stretchyWidthDivider * mult) }
                coords = { shape.points[1], shape.points[2] }
            end



            -- ok we have our coordinates, now we create UV's and vertices
            coords = unloop.unpackNodePoints(coords, false)

            local verts, indices, draw_mode = polyline.render('miter', coords, thickness)
            local h = 1 / (shape.data.steps - 1 or 1)
            local vertsWithUVs = {}

            for i = 1, #verts do
                local u = (i % 2 == 1) and 0 or 1
                local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
            end

            vertices = vertsWithUVs
        elseif (shape.type == 'bezier') then
            local curvedata = unloop.unpackNodePoints(points, false)
            local curve = love.math.newBezierCurve(curvedata)
            local steps = shape.data and shape.data.steps or 10
            local coords = {}
            for i = 0, steps do
                local px, py = curve:evaluate(i / steps)
                table.insert(coords, { px, py })
            end
            coords = unloop.unpackNodePoints(coords, false)
            local width = shape.data and shape.data.width or 10
            local verts, indices, draw_mode = polyline.render('miter', coords, { width })
            local h = 1 / (steps - 1 or 1)
            local vertsWithUVs = {}

            for i = 1, #verts do
                local u = (i % 2 == 1) and 0 or 1
                local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
            end
            vertices = vertsWithUVs
        elseif (shape.type == 'vanillaline') then
            local coords
            --print('vanillaline stuff', shape.data)
            if shape.data and shape.data.tension then
                coords = border.unloosenVanillaline(points, shape.data.tension, shape.data.spacing)
            else
                coords = unloop.unpackNodePoints(points, false)
            end
            local width = shape.data and shape.data.width or 60
            -- print(inspect(coords), inspect(points))
            local verts, indices, draw_mode = polyline.render('miter', coords, width)

            local vertsWithUVs = {}

            for i = 1, #verts do
                local u = (i % 2 == 1) and 0 or 1
                local v = math.floor(((i - 1) / 2)) / (#verts / 2 - 1)
                vertsWithUVs[i] = { verts[i][1], verts[i][2], u, v }
            end
            vertices = vertsWithUVs
        else
            local coords = unloop.unpackNodePoints(points, false)
            local verts, indices, draw_mode = polyline.render('miter', coords, { 10, 40, 20, 100, 10 })
            vertices = verts
        end
    end

    return vertices
end


mesh.makeMeshFromVertices = function(vertices, nodetype, usesTexture)
    --   print('make mesh called, by whom?', nodetype)

    local m = nil

    if nodetype == 'rubberhose' then
        m = love.graphics.newMesh(vertices, "strip")
    elseif nodetype == 'bezier' then
        m = love.graphics.newMesh(vertices, "strip")
    elseif nodetype == 'vanillaline' then
        m = love.graphics.newMesh(vertices, "strip")
    else
        if (vertices and vertices[1] and vertices[1][1]) then
            --local mesh

            if (usesTexture) then
                m = love.graphics.newMesh(vertices, "fan")
            else
                m = love.graphics.newMesh(formats.simple_format, vertices, "triangles")
            end

            --return mesh
        end
    end

    return m
end

mesh.makeSquishableUVsFromPoints = function(points)
    local verts = {}

    --assert(#points == 4)

    local v = points

    if #v == 4 then
        verts[1] = { v[1][1], v[1][2], 0, 0 }
        verts[2] = { v[2][1], v[2][2], 1, 0 }
        verts[3] = { v[3][1], v[3][2], 1, 1 }
        verts[4] = { v[4][1], v[4][2], 0, 1 }
    end
    if #v == 5 then
        verts[1] = { v[1][1], v[1][2], 0.5, 0.5 }
        verts[2] = { v[2][1], v[2][2], 0, 0 }
        verts[3] = { v[3][1], v[3][2], 1, 0 }
        verts[4] = { v[4][1], v[4][2], 1, 1 }
        verts[5] = { v[5][1], v[5][2], 0, 1 }
        verts[6] = { v[2][1], v[2][2], 0, 0 } -- this is an extra one to make it go round
    end

    if #v == 9 then
        verts[1] = { v[1][1], v[1][2], 0.5, 0.5 }
        verts[2] = { v[2][1], v[2][2], 0, 0 }
        verts[3] = { v[3][1], v[3][2], .5, 0 }
        verts[4] = { v[4][1], v[4][2], 1, 0 }
        verts[5] = { v[5][1], v[5][2], 1, .5 }
        verts[6] = { v[6][1], v[6][2], 1, 1 }
        verts[7] = { v[7][1], v[7][2], .5, 1 }
        verts[8] = { v[8][1], v[8][2], 0, 1 }
        verts[9] = { v[9][1], v[9][2], 0, .5 }
        verts[10] = { v[2][1], v[2][2], 0, 0 } -- this is an extra one to make it go round
    end



    return verts
end


mesh.addUVToVerts = function(verts, img, points, settings)
    -- ok this breask if you want to do it with an rubberhose.....
    -- because that doenst have 4 points to it.
    --print('Im tweakibg around ion here atm, check the code for UV stuff')
    local tlx, tly, brx, bry = bbox.getPointsBBox(points)

    local keepAspect = settings.keepAspect ~= nil and settings.keepAspect or true
    local xFactor = 1
    local yFactor = 1
    --print(brx, tlx, bry, tly)
    assert(brx - tlx > 0 and bry - tly > 0)

    local xFactor = img:getWidth() / (brx - tlx)
    local yFactor = img:getHeight() / (bry - tly)

    --   print(xFactor, yFactor)

    local mmin = math.min(xFactor, yFactor)
    local mmax = math.max(xFactor, yFactor)
    local xscale = keepAspect and mmax or xFactor
    local yscale = keepAspect and mmax or yFactor

    --  local ufunc = function(x) return mapInto(x, tlx, brx, 0, 1/xFactor * xscale) end
    --  local vfunc = function(y) return mapInto(y, tly, bry, 0, 1/yFactor * yscale) end

    local ufunc = function(x) return numbers.mapInto(x, tlx, brx, 0, 1) end
    local vfunc = function(y) return numbers.mapInto(y, tly, bry, 0, 1) end

    --print(#verts)
    for i = 1, #verts do
        local v = verts[i]
        verts[i] = { v[1], v[2], ufunc(v[1]), vfunc(v[2]) }
    end

    -- todo should this return instead?
end

local _imageCache = {}

local function addToImageCache(url, settings)
    -- print(url)
    if (url and #url > 0) then
        if not _imageCache[url] then
            --	 print(inspect(settings))
            local wrap = settings and settings.wrap or 'clampzero'
            local filter = settings and settings.filter or 'linear'
            --print('making texture', url)

            --  local imgBefore = love.graphics.newImage(url)
            --   local data = love.image.newImageData( url )
            --local data = imgBefore:getData()
            --   print(inspect(data))


            -- local newData = ''
            -- for x =0, imgBefore:getWidth()-1 do
            --   for y = 0, imgBefore:getHeight()-1 do
            -- local data:getPixel(x,y)
            --   local r, g, b, a = data:getPixel( x, y )
            --    newData = newData .. r
            --  end
            --  end

            --local imageData = love.image.newImageData(imgBefore:getWidth(), imgBefore:getHeight(), 'r8', newData)
            -- local img =  love.graphics.newImage(imageData)





            local img = love.graphics.newImage(url, { dpiscale = 1 })
            img:setWrap(wrap)
            img:setFilter(filter, filter)
            _imageCache[url] = img
        end
    end
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

mesh.getImage = function(url, settings)
    if not _imageCache[url] then
        if love.filesystem.getInfo(url) then
            addToImageCache(url, settings)
        else
            --     print('couldnt find image ', url)
        end
    end
    -- print(inspect(_imageCache))
    --  print(tablelength(_imageCache))
    return _imageCache[url]
end

mesh.recursivelyMakeTextures = function(root)
    if root.texture and root.texture.url and #(root.texture.url) > 0 then
        --print(root.texture.url)
        addToImageCache(root.texture.url, root.texture)
    end

    if root.children then
        for i = 1, #root.children do
            mesh.recursivelyMakeTextures(root.children[i])
        end
    end
end



mesh.remeshNode = function(node)
    --print('remesh node called, lets try and make a textured mesh', node, node.points, #node.points)
    local verts = mesh.makeVertices(node)

    if node.texture and node.texture.canvas then
        return
    end

    if node.texture and (node.texture.url and node.texture.url:len() > 0) and
        (node.type ~= 'rubberhose' and node.type ~= 'bezier' and node.type ~= 'vanillaline') then
        local img = mesh.getImage(node.texture.url)

        if (node.texture.squishable) then
            local v = mesh.makeSquishableUVsFromPoints(node.points)
            node.mesh = love.graphics.newMesh(v, 'fan')
        else
            mesh.addUVToVerts(verts, img, node.points, node.texture)
            if (node.texture.squishable == true) then
                print('need to make this a fan instead of trinagles I think')
            end
            if verts then
                node.mesh = love.graphics.newMesh(verts, 'triangles')
            end
        end

        node.mesh:setTexture(img)
    else
        node.mesh = mesh.makeMeshFromVertices(verts, node.type, node.texture)
        if node.type == 'rubberhose' or node.type == 'bezier' or node.type == 'vanillaline' and node.texture then
            if (node.texture.retexture) then
                node.mesh:setTexture(node.texture.retexture)
                --print('remesh in rubberhose 2')
            else
                local texture = mesh.getImage(node.texture and node.texture.url) --_imageCache[node.texture and node.texture.url]
                --print(inspect(_imageCache))
                --print(node.texture.url)

                --print(texture)
                if texture then
                    --print(texture)
                    node.mesh:setTexture(texture)
                    --print('remesh in rubberhose')
                end
            end
        end
    end

    if node.border then
        node.borderMesh = border.makeBorderMesh(node)
    end
end

mesh.meshAll = function(root) -- this needs to be done recursive
    if root.children then
        for i = 1, #root.children do
            if (root.children[i].points) then
                if root.children[i].type == 'meta' then
                else
                    mesh.remeshNode(root.children[i])
                end
                if root.children[i].border then
                    print('this border should be meshed here')
                end
            else
                mesh.meshAll(root.children[i])
            end
        end
    end
end


local _meshCache = {}
--read  file and addU

mesh.readFileAndAddToCache = function(url)
    -- todo this needs to work with hotrelaoding too,
    -- i suppose its just a matter of overwriting the value in cache?

    if not _meshCache[url] then
        local g2 = parse.parseFile(url)[1]
        parentize.parentize(g2)
        mesh.meshAll(g2)
        mesh.makeOptimizedBatchMesh(g2)

        local bb = bbox.getBBoxRecursive(g2)
        -- ok this is needed cause i do a bit of transforming in the function
        local tlx, tly = g2.transforms._g:inverseTransformPoint(bb[1], bb[2])
        local brx, bry = g2.transforms._g:inverseTransformPoint(bb[3], bb[4])

        g2.bbox = { tlx, tly, brx, bry } --bbox

        --local bbox = getBBoxOfChildren(g2.children)
        --g2.bbox = {bbox.tl.x, bbox.tl.y, bbox.br.x, bbox.br.y}
        _meshCache[url] = g2
    end

    return _meshCache[url]
end


mesh.recursivelyAddOptimizedMesh = function(root)
    if root.folder then
        if root.url then
            root.optimizedBatchMesh = _meshCache[root.url].optimizedBatchMesh
        end
    end

    if root.children then
        for i = 1, #root.children do
            if root.children[i].folder then
                mesh.recursivelyAddOptimizedMesh(root.children[i])
            end
        end
    end
end


mesh.makeOptimizedBatchMesh = function(folder)
    -- this one assumes all children are shapes, still need to think of what todo when
    -- folders are children
    if #folder.children == 0 then
        print("this was empty nothing to optimize")
        return
    end

    for i = 1, #folder.children do
        if (folder.children[i].folder) then
            print("could not optimize shape, it contained a folder!!", folder.name, folder.children[i].name)
            print('havent fetched the metatags either', folder.name, folder.children[i].name)
            return
        end
    end

    --for i=1, #folder.children do
    --   if (folder.children[i].type == 'meta') then
    --      print("could not optimize shape, it contained a meta tag",folder.name,folder.children[i].name)
    --      return
    --  end
    --end

    local lastColor = folder.children[1].color
    local allVerts = {}
    local batchIndex = 1

    local metaTags = {}
    for i = 1, #folder.children do
        if folder.children[i].type == 'meta' then
            local tagData = { name = folder.children[i].name, points = folder.children[i].points }
            table.insert(metaTags, tagData)
            print('skipping meta node in optimize round')
        else
            local thisColor = folder.children[i].color
            if (thisColor[1] ~= lastColor[1]) or
                (thisColor[2] ~= lastColor[2]) or
                (thisColor[3] ~= lastColor[3]) then
                if folder.optimizedBatchMesh == nil then
                    folder.optimizedBatchMesh = {}
                end

                if #allVerts == 0 then
                    -- this is possible since te last node could have been a meta one, then we skip some steps
                    print('the last node was meta and that in itself was the first node')
                else
                    local me = love.graphics.newMesh(formats.simple_format, allVerts, "triangles")
                    folder.optimizedBatchMesh[batchIndex] = { mesh = me, color = lastColor }
                    batchIndex = batchIndex + 1
                end

                lastColor = thisColor
                allVerts = {}
            end

            allVerts = TableConcat(allVerts, mesh.makeVertices(folder.children[i]))
        end
    end

    if #allVerts > 0 then
        if folder.optimizedBatchMesh == nil then
            folder.optimizedBatchMesh = {}
        end
        local m = love.graphics.newMesh(formats.simple_format, allVerts, "triangles")
        folder.optimizedBatchMesh[batchIndex] = { mesh = m, color = lastColor }
        --print('optimized: ', folder.name,)
    end

    if #metaTags > 0 then
        folder.metaTags = metaTags
    end
end

mesh.createTexturedPolygon = function(image, polygon)
    local tlx, tly, brx, bry = bbox.getPointsBBoxFlat(polygon)

    local ufunc = function(x) return numbers.mapInto(x, tlx, brx, 0, 3) end
    local vfunc = function(y) return numbers.mapInto(y, tly, bry, 0, 3) end

    local p = {}
    mesh.reTriangulatePolygon(polygon, p)
    local vertices = {}


    for i = 1, #p do
        local r = p[i]
        table.insert(vertices, { r[1], r[2], ufunc(r[1]), vfunc(r[2]) })
        table.insert(vertices, { r[3], r[4], ufunc(r[3]), vfunc(r[4]) })
        table.insert(vertices, { r[5], r[6], ufunc(r[5]), vfunc(r[6]) })
    end


    local m = love.graphics.newMesh(vertices, "triangles")
    m:setTexture(image)

    return m
end


mesh.createTexturedRectangle = function(image)
    local w, h = image:getDimensions()
    --print(w,h)
    local vertices = {}
    -- x,y,u,v,r,g,b,
    --table.insert(vertices, {0,     0,   0.5, 0.5, 0, 0, 0})

    table.insert(vertices, { 0, 0, 0, 0 })
    table.insert(vertices, { w, 0, 1, 0 })
    table.insert(vertices, { w, h, 1, 1 })
    table.insert(vertices, { 0, h, 0, 1 })

    --table.insert(vertices, {0, 0, 0, 0, 0, 0, 0})


    --simple_format = {
    --   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
    -- }

    local m = love.graphics.newMesh(vertices, "fan")
    m:setTexture(image)

    return m
end



mesh.createTexturedTriangleStrip = function(image)
    -- this assumes an strip that is oriented vertically

    local w, h = image:getDimensions()
    local vertices = {}
    local segments = 15
    local hPart = h / (segments - 1)
    local hv = 1 / (segments - 1)
    local runningHV = 0
    local runningHP = 0
    local index = 0
    for i = 1, segments do
        vertices[index + 1] = { -w / 2, runningHP, 0, runningHV }
        vertices[index + 2] = { w / 2, runningHP, 1, runningHV }

        runningHV = runningHV + hv
        runningHP = runningHP + hPart
        index = index + 2
    end

    local mesh = love.graphics.newMesh(vertices, "strip")
    mesh:setTexture(image)

    return mesh
end


mesh.makeMeshFromSibling = function(sib, imageData)
    local img = love.graphics.newImage(imageData)
    local editing = mesh.makeVertices(sib)

    mesh.addUVToVerts(editing, img, sib.points, sib.texture)
    local result = mesh.makeMeshFromVertices(editing, sib.type, sib.texture)

    result:setTexture(img)
    return result
end

return mesh
