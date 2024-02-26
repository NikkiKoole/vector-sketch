package.path = package.path .. ";../../?.lua"



local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("vendor.json") -- You might need a JSON library, like lua-cjson or similar

local discordToken =
"MTIxMTY3MDU1NDU1NDI2OTczNg.GVT3yb.n-OPNWdkTJU8YFQKtn3l91YQM1IYTAptjO0-x4" --"YOUR_DISCORD_BOT_TOKEN"
local channelId =
"1211638953841786943"                                                      --"YOUR_DISCORD_CHANNEL_ID"
local messageContent = "Hello, Discord!"

local url = "https://discord.com/api/v10/channels/" .. channelId .. "/messages"
local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bot " .. discordToken
}

local payload = {
    content = messageContent,

}

local requestBody = json.encode(payload)
print(requestBody)
local response = {}
local result, status = http.request {
    url = url,
    method = "POST",
    headers = headers,
    source = ltn12.source.string(requestBody),
    --sink = ltn12.sink.table(response),
    --redirect = true
}
--print(url)
--print(headers["Content-Type"])
--print(headers["Authorization"])
print(result, status)
if status == 200 then
    print("Message sent successfully!")
else
    print("Failed to send message. Status code:", status)
    print("Response:", table.concat(response))
end
