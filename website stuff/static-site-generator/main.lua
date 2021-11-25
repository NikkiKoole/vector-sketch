#!/usr/bin/env lua

local markdown = require 'libs.markdown'
local toml = require 'libs.toml'
local inspect = require 'libs.inspect'
local liluat = require 'libs.liluat'

function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"') -- no joy on windows
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

function readSource(source)
   local firstIndex = (string.find(source, '---\n', 1))
   local secondIndex = (string.find(source, '---\n', 4))
   local frontmatter = nil

   if firstIndex and secondIndex  then
      frontmatter = string.sub(source,firstIndex,secondIndex+3)
      frontmatter = string.gsub(frontmatter, '---\n', '')
      frontmatter = toml.parse(frontmatter)
      source = string.sub(source, secondIndex+4)
   end

   return markdown(source), frontmatter
end

function writePost(path, data)
   local file = io.open(path, "w")
   file:write(data)
   file:close()
end

if arg then
   if arg[1] == 'post' then
      if not arg[2] then
         print('you forgot to write a new name')
      else
         local frontmatter =
            "---\n"..
            "timestamp="..os.time().."\n"..
            "title='"..arg[2].."'\n"..
            "---\n"
         local path = 'content/apps/'..arg[2]:gsub(' ', '-')..'.md'
         print('creating '..path)
         writePost(path, frontmatter)
      end
   end
end


local writtenFileCount =0

function doSimple(template, content, values, valueStorage)

   local t = readAll('templates/'..template..'.template')
   local source = readAll('content/'..content..'.md')
   local html, frontmatter = readSource(source)
   values.frontmatter = frontmatter
   values.html = html
   if (frontmatter and frontmatter.title) then
      values.title = frontmatter.title
   end

   if (valueStorage) then
      table.insert(valueStorage, values)
   end

   local compiled_template = liluat.compile(t)
--   print(type(t), type(compiled_template))
   local rendered_template = liluat.render(compiled_template, values)
   writePost('public/'..content..'.html', rendered_template)
   writtenFileCount = writtenFileCount + 1
end

local files = scandir('content/apps')
local result = {}

for _, file in ipairs(files) do
   if (file ~= 'index.md') then
      if ends_with(file, '.md') then
	 local content = file:gsub('.md', '')
	 doSimple('general', 'apps/'..content, {path=content..'.html'}, result)
      end
   end
end


table.sort(result, function (left, right)
    return left.frontmatter.timestamp < right.frontmatter.timestamp
end)

local appsList = {}
for _, post in ipairs(result) do
   table.insert(appsList, {title=post.frontmatter.title, path=post.path, frontmatter=post.frontmatter})
end


doSimple('apps-index', 'apps/index', {title="Apps", apps=appsList})
doSimple('general', 'about/index', {title="About"})
doSimple('general', 'index', {title='Happy apps for young children'})



print('Done!, written '..writtenFileCount..' files.')
