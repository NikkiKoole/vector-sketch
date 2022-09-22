local formats = {}

formats.simple_format = {
   { "VertexPosition", "float", 2 }, -- The x,y position of each vertex.
}

formats.simple_format_colors = {
   { "VertexPosition", "float", 2 }, -- The x,y position of each vertex.
   { "VertexColor", "float", 4 }, -- The x,y position of each vertex.
}
formats.other_format_colors = {
   { "VertexPosition", "float", 2 }, -- The x,y position of each vertex.
   { "VertexColor", "byte", 4 } -- The r,g,b,a color of each vertex.
}
return formats
