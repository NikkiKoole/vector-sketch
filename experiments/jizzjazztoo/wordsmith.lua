local verbs = {
    "Jive", "Twirl", "Stumble", "Wobble", "Shuffle",
    "Bounce", "Wiggle", "Skitter", "Tumble", "Fumble",
    "Drift", "Sway", "Doodle", "Spin", "Lurch",
    "Swagger", "Tangle", "Clatter", "Slur", "Meander",
    "Saunter", "Trudge", "Flicker", "Flutter", "Flick",
    "Twitch", "Jitter", "Bumble", "Clunk", "Limp",
    "Stagger", "Linger", "Ramble", "Totter", "Slink",
    "Flounder", "Writhe", "Tiptoe", "Stomp", "Bop",
    "Strum", "Croon", "Whisper", "Lounge", "Wander",
    "Sway", "Float", "Drift", "Chill", "Daydream",
    "Melt", "Sigh", "Doodle", "Noodle", "Coast",
    "Twinkle", "Serenade", "Jive", "Reverberate", "Echo"
}


local random_words = {
    "Banana", "Rainbow", "Telescope", "Bubblegum", "Thunderstorm",
    "Firefly", "Marshmallow", "Tornado", "Pancake", "Moonlight",
    "Waterfall", "Bubblewrap", "Pineapple", "Jellyfish", "Galaxy",
    "Umbrella", "Dragonfly", "Coconut", "Bubble bath", "Seashell",
    "Lighthouse", "Popsicle", "Whirlwind", "Cactus", "Starlight",
    "Hammock", "Butterflies", "Iceberg", "Snowflake", "Campfire",
    "Lemonade", "Beachball", "Stardust", "Sunflower", "Bubble tea",
    "Hot air balloon", "Beach towel", "Flip-flops", "Ocean breeze",
    "Sunbeam", "Sandcastle", "Pinecone", "Gummy bears", "Shooting star",
    "Ice cream cone", "Campfire", "Compass", "Backpack", "Sunglasses",
    "Compass", "Dream", "Beach", "Sunset", "Breeze", "Cloud",
    "Memory", "Reflection", "Voyage", "Fantasy", "Whisper",
    "Echo", "Melody", "Harmony", "Glimmer", "Serenade",
    "Sunshine", "Moonbeam", "Twilight", "Lullaby", "Raindrop"
}

local adjectives = {
    "Wonky", "Bizarre", "Quirky", "Eccentric", "Whimsical",
    "Offbeat", "Funky", "Surreal", "Zany", "Oddball",
    "Wacky", "Kooky", "Absurd", "Peculiar", "Funky",
    "Trippy", "Groovy", "Lopsided", "Melancholic", "Dizzy",
    "Fuzzy", "Jittery", "Hazy", "Dreamy", "Gloomy",
    "Silly", "Goofy", "Frenzied", "Spooky", "Bleary",
    "Drunken", "Haphazard", "Wobbly", "Shaky", "Cranky",
    "Mellow", "Clumsy", "Messy", "Ragged", "Rustic",
    "Whimsical", "Chaotic", "Disorderly", "Messy", "Haphazard",
    "Lucky", "Sunny", "Hazy", "Dreamy", "Whimsical", "Laid-back",
    "Luminous", "Mellow", "Gentle", "Serene", "Nostalgic",
    "Soothing", "Surreal", "Enchanted", "Fleeting", "Tender",
    "Melancholic", "Echoing", "Tranquil", "Drowsy", "Blissful"
}

local function pickRandom(container)
    return container[math.ceil(love.math.random() * #container)]
end

function getRandomName()
    return pickRandom(adjectives) .. ' ' .. pickRandom(random_words) .. ' ' .. pickRandom(verbs)
end
