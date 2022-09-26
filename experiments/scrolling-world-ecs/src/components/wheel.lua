Concord.component(
   'wheelCircumference',
   function(c, value)
      c.value = value
   end
)

Concord.component(
   'rotatingPart',
   function(c, value)
      c.value = value
   end
)


-- maybe just calculate values using bbox

local function getRadiusAndCircumForBBox(bbox)
   local width = bbox[3] - bbox[1]
   local height = bbox[4] - bbox[2]
   local radius = math.min(width, height) / 2
   local circum = 2 * math.pi * radius
   return radius, circum
end

Concord.component(
   'vehicle',
   function(c, body, wheel1, wheel2)
      c.body = body

      c.wheel1 = wheel1

      local radius, circum = getRadiusAndCircumForBBox(wheel1.bbox)
      c.circum1 = circum
      c.radius1 = radius

      c.wheel2 = wheel2

      radius, circum = getRadiusAndCircumForBBox(wheel2.bbox)
      c.circum2 = circum
      c.radius2 = radius

   end
)
