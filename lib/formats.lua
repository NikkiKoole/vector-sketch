local formats = {}

formats.simple_format = {
   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
}

formats.simple_format_colors = {
   {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
   {"VertexColor", "float", 4}, -- The x,y position of each vertex.
}
return formats
