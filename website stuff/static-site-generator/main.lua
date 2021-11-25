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
         local path = 'content/posts/'..arg[2]:gsub(' ', '-')..'.md' 
         print('creating '..path)
         writePost(path, frontmatter)
      end
   end
end



local files = scandir('content/posts')
local result = {}
local writtenFileCount =0

local posttemplate = readAll('templates/post.template')
local compiled_posttemplate = liluat.compile(posttemplate)

for _, file in ipairs(files) do
   if ends_with(file, '.md') then
      local source = readAll('content/posts/'..file)
      local html, frontmatter = readSource(source)
      local data = {
         frontmatter=frontmatter,
         html=html,
         path='posts/'..file:gsub('.md', '.html')
      }
      table.insert(result, data)


      local rendered_template = liluat.render(compiled_posttemplate, {content=data.html})

      
      writePost('public/'..data.path, rendered_template)
      writtenFileCount = writtenFileCount+1
   end
end

table.sort(result, function (left, right)
    return left.frontmatter.timestamp < right.frontmatter.timestamp
end)

local indextemplate = readAll('templates/index.template')
local values = {
	title = "A fine selection of posts.",
	posts = {}
}
for _, post in ipairs(result) do
   table.insert(values.posts, {title=post.frontmatter.title, path=post.path})
end

local compiled_template = liluat.compile(indextemplate)
local rendered_template = liluat.render(compiled_template, values)

writePost('public/index.html', rendered_template)


print('Done!, written '..writtenFileCount..' post files and an index file.')


