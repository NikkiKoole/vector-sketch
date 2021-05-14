-- written by groverbuger for g3d
-- february 2021
-- MIT license

local vectors = require(G3D_PATH .. "/vectors")
local vectorCrossProduct = vectors.crossProduct
local vectorDotProduct = vectors.dotProduct
local vectorNormalize = vectors.normalize

----------------------------------------------------------------------------------------------------
-- matrix class
----------------------------------------------------------------------------------------------------
-- matrices are 16 numbers in table, representing a 4x4 matrix

local matrix = {}
matrix.__index = matrix

local function newMatrix()
    local self = setmetatable({}, matrix)
    self:identity()
    return self
end

function matrix:identity()
    self[1],  self[2],  self[3],  self[4]  = 1, 0, 0, 0
    self[5],  self[6],  self[7],  self[8]  = 0, 1, 0, 0
    self[9],  self[10], self[11], self[12] = 0, 0, 1, 0
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
end

function matrix:getValueAt(x,y)
    return self[x + (y-1)*4]
end

-- multiply this matrix and another matrix together
-- this matrix becomes the result of the multiplication operation
local orig = newMatrix()
function matrix:multiply(other)
    -- hold the values of the original matrix
    -- because the matrix is changing while it is used
    for i=1, 16 do
        orig[i] = self[i]
    end

    local i = 1
    for y=1, 4 do
        for x=1, 4 do
            self[i] = orig:getValueAt(1,y)*other:getValueAt(x,1)
            self[i] = self[i] + orig:getValueAt(2,y)*other:getValueAt(x,2)
            self[i] = self[i] + orig:getValueAt(3,y)*other:getValueAt(x,3)
            self[i] = self[i] + orig:getValueAt(4,y)*other:getValueAt(x,4)
            i = i + 1
        end
    end
end

function matrix:__tostring()
    local str = ""

    for i=1, 16 do
        str = str .. self[i]

        if i%4 == 0 and i > 1 then
            str = str .. "\n"
        else
            str = str .. ", "
        end
    end

    return str
end

----------------------------------------------------------------------------------------------------
-- transformation, projection, and rotation matrices
----------------------------------------------------------------------------------------------------
-- the three most important matrices for 3d graphics
-- these three matrices are all you need to write a simple 3d shader

-- returns a transformation matrix
-- translation and rotation are 3d vectors
local temp = newMatrix()
function matrix:setTransformationMatrix(translation, rotation, scale)
    self:identity()

    -- translations
    self[4] = translation[1]
    self[8] = translation[2]
    self[12] = translation[3]

    -- rotations
    if #rotation == 3 then
        -- use 3D rotation vector as euler angles
        -- x
        temp:identity()
        temp[6] = math.cos(rotation[1])
        temp[7] = -1*math.sin(rotation[1])
        temp[10] = math.sin(rotation[1])
        temp[11] = math.cos(rotation[1])
        self:multiply(temp)

        -- y
        temp:identity()
        temp[1] = math.cos(rotation[2])
        temp[3] = math.sin(rotation[2])
        temp[9] = -1*math.sin(rotation[2])
        temp[11] = math.cos(rotation[2])
        self:multiply(temp)

        -- z
        temp:identity()
        temp[1] = math.cos(rotation[3])
        temp[2] = -1*math.sin(rotation[3])
        temp[5] = math.sin(rotation[3])
        temp[6] = math.cos(rotation[3])
        self:multiply(temp)
    else
        -- use 4D rotation vector as quaternion
        temp:identity()

        local qx,qy,qz,qw = rotation[1], rotation[2], rotation[3], rotation[4]
        temp[1], temp[2],  temp[3]  = 1 - 2*qy^2 - 2*qz^2, 2*qx*qy - 2*qz*qw,   2*qx*qz + 2*qy*qw
        temp[5], temp[6],  temp[7]  = 2*qx*qy + 2*qz*qw,   1 - 2*qx^2 - 2*qz^2, 2*qy*qz - 2*qx*qw
        temp[9], temp[10], temp[11] = 2*qx*qz - 2*qy*qw,   2*qy*qz + 2*qx*qw,   1 - 2*qx^2 - 2*qy^2

        self:multiply(temp)
    end

    -- scale
    temp:identity()
    temp[1] = scale[1]
    temp[6] = scale[2]
    temp[11] = scale[3]
    self:multiply(temp)

    return self
end

-- returns a perspective projection matrix
-- (things farther away appear smaller)
-- all arguments are scalars aka normal numbers
-- aspectRatio is defined as window width divided by window height
function matrix:setProjectionMatrix(fov, near, far, aspectRatio)
    local top = near * math.tan(fov/2)
    local bottom = -1*top
    local right = top * aspectRatio
    local left = -1*right

    self[1],  self[2],  self[3],  self[4]  = 2*near/(right-left), 0, (right+left)/(right-left), 0
    self[5],  self[6],  self[7],  self[8]  = 0, 2*near/(top-bottom), (top+bottom)/(top-bottom), 0
    self[9],  self[10], self[11], self[12] = 0, 0, -1*(far+near)/(far-near), -2*far*near/(far-near)
    self[13], self[14], self[15], self[16] = 0, 0, -1, 0
end

-- returns an orthographic projection matrix
-- (things farther away are the same size as things closer)
-- all arguments are scalars aka normal numbers
-- aspectRatio is defined as window width divided by window height
function matrix:setOrthographicMatrix(fov, size, near, far, aspectRatio)
    local top = size * math.tan(fov/2)
    local bottom = -1*top
    local right = top * aspectRatio
    local left = -1*right

    self[1],  self[2],  self[3],  self[4]  = 2/(right-left), 0, 0, -1*(right+left)/(right-left)
    self[5],  self[6],  self[7],  self[8]  = 0, 2/(top-bottom), 0, -1*(top+bottom)/(top-bottom)
    self[9],  self[10], self[11], self[12] = 0, 0, -2/(far-near), -(far+near)/(far-near)
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
end

-- returns a view matrix
-- eye, target, and down are all 3d vectors
function matrix:setViewMatrix(eye, target, down)
    local z_1, z_2, z_3 = vectorNormalize(eye[1] - target[1], eye[2] - target[2], eye[3] - target[3])
    local x_1, x_2, x_3 = vectorNormalize(vectorCrossProduct(down[1], down[2], down[3], z_1, z_2, z_3))
    local y_1, y_2, y_3 = vectorCrossProduct(z_1, z_2, z_3, x_1, x_2, x_3)

    self[1],  self[2],  self[3],  self[4]  = x_1, x_2, x_3, -1*vectorDotProduct(x_1, x_2, x_3, eye[1], eye[2], eye[3])
    self[5],  self[6],  self[7],  self[8]  = y_1, y_2, y_3, -1*vectorDotProduct(y_1, y_2, y_3, eye[1], eye[2], eye[3])
    self[9],  self[10], self[11], self[12] = z_1, z_2, z_3, -1*vectorDotProduct(z_1, z_2, z_3, eye[1], eye[2], eye[3])
    self[13], self[14], self[15], self[16] = 0, 0, 0, 1
end

return newMatrix
