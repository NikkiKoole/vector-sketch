function hex2rgb(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

miffy = {
   name='miffy',
   colors={
      {name="green", rgb={48,112,47}},
      {name="blue", rgb={27,84,154}},
      {name="yellow", rgb={250,199,0}},
      {name="orange1", rgb={233,100,14}},
      {name="orange2", rgb={237,76,6}},
      {name="orange3", rgb={221,61,14}},
      {name="black1", rgb={34,30,30}},
      {name="black2", rgb={24,26,23}},
      {name="black2", rgb={24,26,23}},
      {name="brown1", rgb={145,77,35}},
      {name="brown2", rgb={114,65,11}},
      {name="brown3", rgb={136,95,62}},
      {name="grey1", rgb={147,142,114}},
      {name="grey2", rgb={149,164,151}},
   }
}
lego = {
   name='lego-classic',
   colors={
      -- {name="bright red", rgb={196,40,27}},
      -- {name="bright blue", rgb={13,105,171}},
      -- {name="bright yellow", rgb={245,205,47}},
      -- {name="dark green", rgb={40,127,70}},
     {name="white", rgb={242,243,242}},
      -- {name="grey", rgb={161,165,162}},
      -- {name="dark grey", rgb={109,110,108}},
      -- {name="black", rgb={27,42,52}},
   }
}
fabuland = {
   name='fabuland',
   colors={
      {name="fabuland red", rgb={255, 128, 20}},
      {name="fabuland green", rgb={120,252,120}},
      {name="brick yellow", rgb={215,197,153}},
      {name="nougat", rgb={204,142,104}},
      {name="sky blue", rgb={137,181,196}},
      {name="sky blue 2", rgb={183,215,213}},
      {name="light orange brown", rgb={203,132,60}},
      {name="fabuland orange", rgb={207, 138, 71}},
      {name="fabuland brown", rgb={242, 112, 94}},
      {name="earth orange", rgb={98, 71, 50}},
   }
}



local jamesGulliverHancock = {
   'd44553','e36f73','d2797b','cd8aa4','cc6b8f','df5a91','ec71a5','e595ab','dca9ac','ecbcc7','b5abac','a89ea1','996164','797073','796870','7f968c',
   '39875e','2388a2','2599ab','205667','5b6b73','539693','5d9398','76a3ae','a4c6cd','aaaeaa','9fc84b','869048','676766','757066','937f64','947a60',
   '9f7956','a98343','c0ab4e','af9d50','af9f5e','9e9c79','abaf85','a5a4a2','c1b6ac','cab39d','cdae9a','d9ad76','cfab60','cdbb6e','d9c054','dfc54b',
   'e3ca57','ded869','d4d29d','c7c66f','bcc092','bdba94','bebcb2','b6af9b','baaf8d','b99b75','b99974','cb9370','bc7d5e','bd7151','c6735d','e17b55',
   'e58f61','ed8b60','f0b364','f7d0b2','f2e3d9','dfdcd9','e6e5e2','ede8d5','e0dcbd','e9d22b','e1e1c0','d0cccc','c19490','995555','a19e9c','e5e3df',
   'cb5f63','dfcaa7','ca3135','9a5e61','ad898a','454546',
}

james = {
   name="james",
   colors = {}
}

for i = 1, #jamesGulliverHancock do
   local r,g,b = hex2rgb(jamesGulliverHancock[i])
   table.insert(james.colors, {name='unknown', rgb={r,g,b}})
end

picoColors = {
   '000000','1D2B53','7E2553','008751','AB5236','5F574F','C2C3C7','FFF1E8',
   'FF004D','FFA300','FFEC27','00E436','29ADFF','83769C','FF77A8','FFCCAA',
}

pico = {
   name='pico',
   colors = {}
}
for i = 1, #picoColors do
   local r,g,b = hex2rgb(picoColors[i])
   table.insert(pico.colors, {name='unknown', rgb={r,g,b}})
end

childCraftColors = {

   '4D391F',
   '4B6868',
   '9F7344',
   '9D7630',
   'D3C281',
   'CB433A',
   'EBE9D6',
   'AE934D',
   'B09764',
   '8F4839',
   '8A934E',
   '69445D',
   '4F4C91',
   'BDA971',
   'E2DAA5',
   'BEA762',
   'AAAC73',
   'EEC488',
   'BAB87F'
}



childCraft = {
   name='childCraft',
   colors = {}
}

for i = 1, #childCraftColors do
   local r,g,b = hex2rgb(childCraftColors[i])
   table.insert(childCraft.colors, {name='unknown', rgb={r,g,b}})
end


gruvBoxColors = {
'1D2021',
'282828',
'32302F',
'3C3836',
'504945',
'665C54',
'7C6F64',
'7C6F64',
'928374',
'928374',
'F9F5D7',
'FBF1C7',
'F2E5BC',
'EBDBB2',
'D5C4A1',
'BDAE93',
'A89984',
'A89984',
'FB4934',
'B8BB26',
'FABD2F',
'83a598',
'd3869b',
'8ec07c',
'FE8019',
'CC241D',
'98971A',
'D79921',
'458588',
'B16286',
'689d6a',
'D65D0E',
'9D0006',
'79740E',
'B57614',
'076678',
'8F3F71',
'427B58',
'AF3A03',
}
gruvBox = {
   name='gruvBox',
   colors = {}
}

for i = 1, #gruvBoxColors do
   local r,g,b = hex2rgb(gruvBoxColors[i])
   table.insert(gruvBox.colors, {name='unknown', rgb={r,g,b}})
end
