--[[
https://ia800700.us.archive.org/2/items/260DrumMachinePatterns/Drum%20Machine%20-%20260%20Patterns_text.pdf

AC: Accent
BD: Bass Drum
SD: Snare Drum
LT: Low Tom
MT: Medium Tom
HT: High Tom
CH: Closed Hi-Hat
OH: Open Hi-Hat
CY: Cymbal
RS: Rim Shot
CPS: Claps
CB: Cowbell
]]


--[[
{
    name='',
    sections={}
},
--]]

local patterns = {
    {
        name = "CR78",
        sections = {
            {
                grid = {
                    CY = "x...........x...",
                    BD = "x...............",
                    AC = "............x...",
                    SD = "....x.......x..."
                },
                name = "Waltz1"
            },
            {
                grid = {
                    CY = "x.........x.x...",
                    BD = "x...............",
                    AC = "............x...",
                    SD = "....x.......x..."
                },
                name = "Waltz2"
            },
            {
                grid = {
                    CY = "....x.......x...",
                    CB = "x.......x.......",
                    BD = "x.......x.......",
                    AC = "x.......x...x...",
                    SD = "....x.......x..."
                },
                name = "Foxtrot A"
            },
            {
                grid = {
                    CY = "x.....x......x..",
                    CH = "xxxxxxxxxxxxxxxx",
                    RS = "x..x..x...x..x..",
                    BD = "x..xx..xx..xx..x",
                    AC = "....x.......x...",

                },
                name = "BOSSANOVA A"
            },
        }
    },
    {
        name = "BoomBAP",
        sections = {
            {
                grid = {
                    BD = "x.....x.x.x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "Boombap1"
            },
        }
    },
    {
        name = "EDM",
        sections = {
            {
                grid = {
                    BD = "x...x...x...x.x.",
                    CH = ".........x......",
                    OH = "..x...x...x...x.",
                    SD = "....x.......x..."
                },
                name = "TECHNO"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CH = ".xx...x....x..x.",
                    OH = "....x........x..",
                    SD = "........x......."
                },
                name = "DUBSTEP - A"
            },
            {
                grid = {
                    BD = "x..x..x...x.....",
                    CH = ".xx...x....x..x.",
                    OH = "....x........x..",
                    SD = "........x......."
                },
                name = "DUBSTEP - B"
            },
            {
                grid = {
                    BD = "x..x....x..x....",
                    CH = "xx...xxxxx.xxx.x",
                    OH = "......x.........",
                    SD = "....x.......x..x"
                },
                name = "DUBSTEP - RATCHETED"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CH = "..xx..x...x...xx",
                    CPS = "....x.......x...",
                    MT = ".....x.....x....",
                    RS = ".x.....x.....x.."
                },
                name = "UK GARAGE - A"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CH = "..x...x...x...x.",
                    CPS = "....x.......x...",
                    MT = ".....x.....x....",
                    RS = ".......x.....x.."
                },
                name = "UK GARAGE - B"
            },
            {
                grid = {
                    BD = "x.......x.......",
                    CH = "xxxxxxxxxxxxxxxx",
                    OH = ".............x..",
                    SD = "....x.......x..."
                },
                name = "SYNTH WAVE"
            }
        }
    },
    {
        name = "Afro-Cuban",
        sections = {
            {
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CY = "xxxxxxxxxxxxxxxx",
                    RS = "x..x..x...x.x..."
                },
                name = "SON CLAVE"
            },
            {
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CY = "xxxxxxxxxxxxxxxx",
                    RS = "x..x...x..x.x..."
                },
                name = "RUMBA"
            },
            {
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CY = "xxxxxxxxxxxxxxxx",
                    RS = "x..x..x...x..x.."
                },
                name = "BOSSA NOVA"
            },
            {
                grid = {
                    BD = "x.......x.x...x.",
                    CH = "x.xxx.x.x.x.x.x.",
                    RS = "...x..x.....x..."
                },
                name = "BOUTON"
            },
            {
                grid = {
                    BD = "x...x...x...x.x.",
                    CB = "x..x..x...x...x.",
                    RS = "..xx..xx..xx..xx"
                },
                name = "GAHU"
            },
            {
                grid = {
                    BD = "x...x.x.x...x.x.",
                    CB = "x...x.x...x.x...",
                    RS = "..xx..xx..xx..xx"
                },
                name = "SHIKO"
            },
            {
                grid = {
                    BD = "x...x...x...x.x.",
                    CB = "x..x..x..xx.....",
                    RS = "x..x..x.x..x..x."
                },
                name = "SOUKOUS"
            }
        }
    },
    {
        name = "Basic Patterns",
        sections = {
            {
                grid = {
                    BD = "x.....x.........",
                    SD = "....x.......x..."
                },
                name = "ONE AND SEVEN & FIVE AND THIRTEEN"
            },
            {
                grid = {
                    BD = "x.......x.......",
                    CH = "x.x.x.x.x.x.xx..",
                    SD = "....x.......x..."
                },
                name = "BOOTS N’ CATS"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    OH = "..x...x...x...x."
                },
                name = "TINY HOUSE"
            },
            {
                grid = {
                    BD = "x..x..x...x.....",
                    SD = "....x.......x..."
                },
                name = "GOOD TO GO"
            },
            {
                grid = {
                    BD = "x.x...xx......x.",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "HIP HOP"
            }
        }
    },
    {
        name = "Miami Bass",
        sections = {
            {
                grid = {
                    BD = "x.....x.........",
                    CH = "x.xxx.xxx.xxx.xx",
                    SD = "....x.......x..."
                },
                name = "MIAMI BASS - A"
            },
            {
                grid = {
                    BD = "x.....x...x..x..",
                    CH = "x.xxx.xxx.xxx.xx",
                    SD = "....x.......x..."
                },
                name = "MIAMI BASS - B"
            },
            {
                grid = {
                    BD = "x.....x...x...x.",
                    SD = "....x.......x..."
                },
                name = "SALLY"
            },
            {
                grid = {
                    CH = "x.x.x.x.x.x.x.x.",
                    LT = "x.....x...x...x."
                },
                name = "unnamed"
            },
            {
                grid = {
                    BD = "x..x..x.........",
                    CH = "x.xxx.xxx.xxxxxx",
                    SD = "....x.......x..."
                },
                name = "ROCK THE PLANET"
            }
        }
    },
    {
        name = "Dub",
        sections = {
            {
                grid = {
                    BD = "x...............",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "........x......."
                },
                name = "HALF DROP"
            },
            {
                grid = {
                    BD = "........x.......",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "........x......."
                },
                name = "ONE DROP"
            },
            {
                grid = {
                    BD = "x.......x.......",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "........x......."
                },
                name = "TWO DROP"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "........x......."
                },
                name = "STEPPERS"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "...x..x....x..x."
                },
                name = "REGGAETON"
            }
        }
    },
    {
        name = "Rock",
        sections = {
            {
                grid = {
                    BD = "x......xx.x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    CY = "x...............",
                    SD = "....x.......x..."
                },
                name = "ROCK 1"
            },
            {
                grid = {
                    BD = "x......xx.x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "ROCK 2"
            },
            {
                grid = {
                    BD = "x......xx.x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    OH = "..............x.",
                    SD = "....x.......x..."
                },
                name = "ROCK 3"
            },
            {
                grid = {
                    BD = "x......xx.x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    OH = "..............x.",
                    SD = "....x.......x.xx"
                },
                name = "ROCK 4"
            }
        }
    },
    {

        name = "Drum and Bass",
        sections = {
            {
                grid = {
                    BD = "x..x...x.xx....x",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 1 - A"
            },
            {
                grid = {
                    BD = "x.x....xxxx.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 1 - B"
            },
            {
                grid = {
                    BD = "x......x.x.x...x",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 2 - A"
            },
            {
                grid = {
                    BD = "x..........x....",
                    CH = "x.x.x.x.x.x.x.xx",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 2 - B"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CH = "xxxxxxxxxxxxxxxx",
                    OH = "......xxxx......",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 3"
            },
            {
                grid = {
                    BD = "x.....x.........",
                    CH = "x.x.x.x.x.x.x.x.",
                    OH = "x...............",
                    SD = "....x.....x.x..."
                },
                name = "DRUM AND BASS 4 - A"
            },
            {
                grid = {
                    BD = "....x.....x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "DRUM AND BASS 4 - B"
            },
            {
                grid = {
                    BD = "x.x.......x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    OH = "x...............",
                    SD = "....x..x.x....x."
                },
                name = "JUNGLE - A"
            },
            {
                grid = {
                    BD = ".xx.......x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = ".x..x..x.x....x."
                },
                name = "JUNGLE - B"
            }
        }
    },
    {
        name = "Electro",
        sections = {
            {
                grid = {
                    BD = "x.....x.........",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 1 - A"
            },
            {
                grid = {
                    BD = "x.....x...x...x.",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 1 - B"
            },
            {
                grid = {
                    BD = "x.....x.........",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 2 - A"
            },
            {
                grid = {
                    BD = "x.........x..x..",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 2 - B"
            },
            {
                grid = {
                    BD = "x.....x....x....",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 3 - A"
            },
            {
                grid = {
                    BD = "x.....x....x.x..",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 3 - B"
            },
            {
                grid = {
                    BD = "x.....x...x..x..",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 4"
            },
            {
                grid = {
                    BD = "x.....x.........",
                    CH = "x.xxx.xxx.xxx.xx",
                    SD = "....x.......x..."
                },
                name = "SIBERIAN NIGHTS"
            },
            {
                grid = {
                    BD = "x.....x.xx......",
                    CH = "xxxxxxxxxxxxxxxx",
                    OH = "..x.............",
                    SD = "....x.......x...",
                    TB = "....x.......x..."
                },
                name = "NEW WAVE"
            },
            {
                grid = {
                    BD = "x.....x....x.x..",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 3 - B"
            },
            {
                grid = {
                    BD = "x.....x...x..x..",
                    SD = "....x.......x..."
                },
                name = "ELECTRO 4"
            },
            {
                grid = {
                    BD = "x.....x.........",
                    CH = "x.xxx.xxx.xxx.xx",
                    SD = "....x.......x..."
                },
                name = "SIBERIAN NIGHTS"
            },
            {
                grid = {
                    BD = "x.....x.xx......",
                    CH = "xxxxxxxxxxxxxxxx",
                    OH = "..x.............",
                    SD = "....x.......x...",
                    TB = "....x.......x..."
                },
                name = "NEW WAVE"
            }
        }
    },
    {
        name = "Standard Breaks",
        sections = {
            {
                grid = {
                    BD = "x.........x.....",
                    CH = "x.x.x.x.xxx.x.x.",
                    SD = "....x.......x..."
                },
                name = "STANDARD BREAK 1"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CH = "x.x.x.xxx.x...x.",
                    SD = "....x.......x..."
                },
                name = "STANDARD BREAK 2"
            },
            {
                grid = {
                    BD = "x......x..x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "ROLLING BREAK"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x..x..x...x.....",
                    CH = ".xx.xx.x.....x..",
                    OH = "........x.....x.",
                    SD = ".x..x..x....x..."
                },
                name = "THE UNKNOWN DRUMMER"
            }
        }
    },
    {
        name = "House",
        sections = {
            {
                grid = {
                    BD = "x...x...x...x...",
                    CY = "x...............",
                    OH = "..x...x...x...x.",
                    SD = "....x.......x..."
                },
                name = "HOUSE"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "xxxxxxxxxxxxxxxx",
                    OH = "..x..x....x..x..",
                    SD = "....x.......x..."
                },
                name = "HOUSE 2"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "xx.xxx.xxx.xxx.x",
                    CPS = "....x.......x...",
                    CY = "..x...x...x...x.",
                    OH = "..x...x...x...x."
                },
                name = "BRIT HOUSE"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "xxxxxxxxxxxxxxxx",
                    CPS = "....x.......x...",
                    OH = ".x.x.x.x.x.x.x.x",
                    TB = "xxx.x.xxxxx.x.xx"
                },
                name = "FRENCH HOUSE"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x.x...x.x.x..x",
                    CH = "..........x....x",
                    CPS = "..x.x...x.x.x...",
                    OH = "..x.......x...x.",
                    SD = "....x.......x..."
                },
                name = "DIRTY HOUSE"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = ".x.....x.x......",
                    CPS = "....x.......x...",
                    OH = "..x...x...x...x."
                },
                name = "DEEP HOUSE"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CPS = ".x.......x......",
                    MT = "..x....x..x.....",
                    OH = "..x...x...xx..x.",
                    TB = "...x....x......."
                },
                name = "DEEPER HOUSE"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "x...x...x...x...",
                    CPS = "....x.......x...",
                    OH = "..xx..xx.xx.x...",
                    TB = "xxxxxxxxxxxxxxxx"
                },
                name = "SLOW DEEP HOUSE"
            },
            {
                grid = {
                    BD = "x..x..x.x..x..x.",
                    CH = "..x.......x.....",
                    CPS = "............x...",
                    RS = "xxxxxxxxxxxxxxxx"
                },
                name = "FOOTWORK - A"
            },
            {
                grid = {
                    BD = "x..x..x.x..x..x.",
                    CH = "..x...xx..x...x.",
                    CPS = "............x...",
                    RS = "xxxxxxxxxxxxxxxx"
                },
                name = "FOOTWORK - B"
            }
        }
    },
    {
        name = "Funk and Soul",
        sections = {
            {
                grid = {
                    BD = "x.x.......xx....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x..x.x..x..x"
                },
                name = "AMEN BREAK - A"
            },
            {
                grid = {
                    BD = "x.x.......xx....",
                    CH = "x.x.x.x.x.x.x.x.",
                    RS = "....x...........",
                    SD = ".......x.x..x..x"
                },
                name = "AMEN BREAK - B"
            },
            {
                grid = {
                    BD = "x.x.......x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    RS = "..............x.",
                    SD = ".......x.x..x..x"
                },
                name = "AMEN BREAK - C"
            },
            {
                grid = {
                    BD = "x.x.......x.....",
                    CH = "x.x.x.x.x...x.x.",
                    CY = "..........x.....",
                    SD = ".x..x..x.x....x."
                },
                name = "AMEN BREAK - D"
            },
            {
                grid = {
                    BD = "x.x...x...x..x..",
                    CH = "xxxxxxx.xxxxx.xx",
                    OH = ".......x.....x..",
                    SD = "....x..x.x.xx..x"
                },
                name = "THE FUNKY DRUMMER"
            },
            {
                grid = {
                    BD = "x......xx.....x.",
                    CH = "x.x.x.xxx...x.x.",
                    OH = "..........x.....",
                    SD = "....x.......x..."
                },
                name = "IMPEACH THE PRESIDENT"
            },
            {
                grid = {
                    BD = "xx.....x..xx....",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "WHEN THE LEVEE BREAKS"
            },
            {
                grid = {
                    BD = "x.x.......xx...x",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "IT’S A NEW DAY"
            },
            {
                grid = {
                    BD = "x..x..x.x.......",
                    HT = "....x.......x...",
                    SD = "....x.......x..."
                },
                name = "THE BIG BEAT"
            },
            {
                grid = {
                    BD = "x.x...x.xx......",
                    CB = "x.x.x.x.x.x.x.x.",
                    CH = "x.x.x.x.x...x.x.",
                    OH = "..........x.....",
                    SD = "....x.......x..."
                },
                name = "ASHLEY’S ROACHCLIP"
            },
            {
                grid = {
                    BD = "x......xx.x....x",
                    CH = "....x...x.x.x.xx",
                    CY = "....x...........",
                    SD = "....x.......x..."
                },
                name = "PAPA WAS TOO"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CH = "x.x.x.xxxxx.x.xx",
                    SD = "....x.......x..."
                },
                name = "SUPERSTITION"
            },
            {
                grid = {
                    BD = "x..x.x...x.xx.x.",
                    CY = "............x.x.",
                    SD = "....x...x.xx...."
                },
                name = "CISSY STRUT (B-SECTION) - A"
            },
            {
                grid = {
                    BD = "x..x...x.x.xx.x.",
                    SD = "..x..xx.xx......"
                },
                name = "CISSY STRUT (B-SECTION) - B"
            },
            {
                grid = {
                    BD = "x...x..x.x.xx.x.",
                    CY = "............x.x.",
                    SD = "..x.xxx..x......"
                },
                name = "CISSY STRUT (B-SECTION) - C"
            },
            {
                grid = {
                    BD = "x...x..x.x.xx.x.",
                    CY = "............x.x.",
                    SD = "x.x..x..xx......"
                },
                name = "CISSY STRUT (B-SECTION) - D"
            },
            {
                grid = {
                    BD = "x.x......x...xx.",
                    CY = "x.xx.x..xx.x..x.",
                    SD = "....x.xx..x.x..."
                },
                name = "HOOK AND SLING - A"
            },
            {
                grid = {
                    BD = "..............x.",
                    CY = "xx.x..x.xx..x.x.",
                    SD = "x...xx.x..xx..xx"
                },
                name = "HOOK AND SLING - B"
            },
            {
                grid = {
                    BD = "xx..........xx.x",
                    CY = "x.x.xx.x.x..xx..",
                    SD = "..x.x.xx..xx..x."
                },
                name = "HOOK AND SLING - C"
            },
            {
                grid = {
                    BD = "x.x..x.....x.xx.",
                    CY = "x.x.xx.x........",
                    SD = "....x..x..x....x"
                },
                name = "HOOK AND SLING - D"
            },
            {
                grid = {
                    BD = "xx.x.......x..x.",
                    CY = "xxxxxxxxxxxxxxx.",
                    SD = "....x..x.x..x..."
                },
                name = "KISSING MY LOVE - A"
            },
            {
                grid = {
                    BD = "xx.x.......x.x..",
                    CY = "xxxxxxxxxxxxxxxx",
                    SD = "....x..x.x..x..x"
                },
                name = "KISSING MY LOVE - B"
            },
            {
                grid = {
                    BD = "xx.x......x.xx..",
                    CY = "xxxxxxxxxxxxxxxx",
                    SD = "....x..x.x.....x"
                },
                name = "KISSING MY LOVE - C"
            },
            {
                grid = {
                    BD = "x..x.......x..x.",
                    CY = "xxxxxxxxxxxxxxx.",
                    SD = "....x....x..x..."
                },
                name = "KISSING MY LOVE - D"
            },
            {
                grid = {
                    BD = "x..........x.x..",
                    CY = "xxxxxxxxxxxxxxx.",
                    SD = "....x..x.x..x..."
                },
                name = "KISSING MY LOVE - E"
            },
            {
                grid = {
                    BD = "x.......x..x..x.",
                    CY = "..x...x.........",
                    SD = "....xx.........."
                },
                name = "LADY - A"
            },
            {
                grid = {
                    BD = "x..........x..x.",
                    CY = "..x...x.........",
                    SD = "....xx..x......."
                },
                name = "LADY - B"
            },
            {
                grid = {
                    BD = "x.x.x..xx.x.x..x",
                    CY = "x.x...xx.xx...x.",
                    SD = "....x.......x..."
                },
                name = "KNOCKS ME OFF MY FEET - A"
            },
            {
                grid = {
                    BD = "x.x.x..xx.x.x..x",
                    CY = "x.x...xx.xx...x.",
                    SD = "....x.......x..."
                },
                name = "KNOCKS ME OFF MY FEET - B"
            },
            {
                grid = {
                    BD = ".......xxx......",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "x...x...x...x..."
                },
                name = "THE THRILL IS GONE"
            },
            {
                grid = {
                    BD = "x...............",
                    CY = "x.......x.......",
                    SD = "....x.......x..."
                },
                name = "POP TECH - A"
            },
            {
                grid = {
                    BD = ".x...........xxx",
                    CY = "x.......x.......",
                    SD = "....x.......x..."
                },
                name = "POP TECH - B"
            },
            {
                grid = {
                    BD = "x.......x.......",
                    CY = "....x.......x..."
                },
                name = "YA MAMA - A"
            },
            {
                grid = {
                    BD = "x......xx.......",
                    CY = "....x.......x..."
                },
                name = "YA MAMA - B"
            },
            {
                grid = {
                    BD = "x.......x.x.....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x..x......x."
                },
                name = "COLD SWEAT - A"
            },
            {
                grid = {
                    BD = "..x.....x.x...x.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".x..x..x.x..x..."
                },
                name = "COLD SWEAT - B"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "I GOT YOU (I FEEL GOOD) - A"
            },
            {
                grid = {
                    BD = "..x...x...x...x.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "I GOT YOU (I FEEL GOOD) - B"
            },
            {
                grid = {
                    BD = "xx......xx......",
                    CY = "x.x.x.xxx.xxx.xx",
                    SD = "...x.xx.....xxx."
                },
                name = "THE SAME BLOOD"
            },
            {
                grid = {
                    BD = "x..xx..xxx.x.x.x",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "GROOVE ME"
            },
            {
                grid = {
                    BD = "x..x.x....x..xx.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".x..x..xx.x...x."
                },
                name = "LOOK-KA PY PY - A"
            },
            {
                grid = {
                    BD = "x..x.x.xx.x..xx.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".x..xx.xx.x...x."
                },
                name = "LOOK-KA PY PY - B"
            },
            {
                grid = {
                    BD = "x...x.......x...",
                    CY = "x.x.xxxxxxx.xxxx",
                    SD = "..x.x.xx.xx.x.xx"
                },
                name = "USE ME - A"
            },
            {
                grid = {
                    BD = "....x..x..x.x...",
                    CY = "xxx.xxxxxxx.xxxx",
                    SD = ".xx.x.xx.xx.x.xx"
                },
                name = "USE ME - B"
            },
            {
                grid = {
                    BD = "x.x..x.xx.xx.x.x",
                    CY = "xxxxxxxxxxxxxxxx",
                    SD = "....x..x.x..x..x"
                },
                name = "USE ME - C"
            },
            {
                grid = {
                    BD = "x.x..x..xx.x.x.x",
                    CY = "xxxxxxxxxx.x.x.x",
                    SD = "....x..x.......x"
                },
                name = "USE ME - D"
            },
            {
                grid = {
                    BD = "x..x...x.xx.....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "FUNKY PRESIDENT"
            },
            {
                grid = {
                    BD = "x.........x...x.",
                    CY = "x.x.x.xxx.x.x.xx",
                    SD = "....x.xx.x..x..x"
                },
                name = "GET UP - A"
            },
            {
                grid = {
                    BD = "x.........x...x.",
                    CY = "x.x.x.xxx.x.x.x.",
                    SD = "....x.xx.x..x..x"
                },
                name = "GET UP - B"
            },
            {
                grid = {
                    BD = "...x..x.......x.",
                    CY = "x.xxx.xxx.xxx.xx",
                    SD = "xx.x.x..xx..xx.."
                },
                name = "EXPENSIVE SHIT"
            },
            {
                grid = {
                    BD = "x..x.x.x.x.x..x.",
                    CY = "x.x.xxx.xxx.x.x.",
                    SD = ".xx.x..x.xx.x..."
                },
                name = "CHUG CHUG CHUG-A-LUG"
            },
            {
                grid = {
                    BD = "x.......x.......",
                    CY = "..x...x...x...x.",
                    SD = ".x.xxx.x.x.xxx.x"
                },
                name = "THE FEZ - A"
            },
            {
                grid = {
                    BD = "x.......x..x..x.",
                    CY = "..x...x...x...x.",
                    SD = ".x.xxx.x.x.xxx.x"
                },
                name = "THE FEZ - B"
            },
            {
                grid = {
                    BD = "..x.x..x..x.x...",
                    CY = "x.x.x.xxx.x.x.xx",
                    SD = ".x..xx.x.x..xx.x"
                },
                name = "ROCK STEADY"
            },
            {
                grid = {
                    BD = "x.x....x.xxx...x",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x...x......."
                },
                name = "SYNTHETIC SUBSTITUTION - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x....x.xxx...x",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x...x......."
                },
                name = "SYNTHETIC SUBSTITUTION - B"
            },
            {
                grid = {
                    BD = "x..x..xx..xx.x.x",
                    CB = "x.xxx.xxx.xxx.xx",
                    SD = ".x.xxx.x.x.xxx.x"
                },
                name = "COW’D BELL - A"
            },
            {
                grid = {
                    BD = "x.xx...xx.xx.x.x",
                    CB = "x.xxx.xxx.xxx.xx",
                    SD = ".x.xxx.x.x.xxx.x"
                },
                name = "COW’D BELL - B"
            },
            {
                grid = {
                    BD = "x.......x......x",
                    CY = "xxxx.xx.x.xx.xx.",
                    SD = "....x..x.x..x..x"
                },
                name = "PALM GREASE - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "..x.............",
                    CY = "x.x.......x.....",
                    SD = ".x....x.......x."
                },
                name = "PALM GREASE - B"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x.....x.xx....",
                    CY = "xxx.xxx.xxx.xxx.",
                    SD = ".x.xx.xx.x.xxx.x"
                },
                name = "O-O-H CHILD - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x.....x.xx....",
                    CY = "xxx.xxx.xxx.xxx.",
                    SD = ".x.xx.xx.x..x.x."
                },
                name = "O-O-H CHILD - B"
            },
            {
                grid = {
                    BD = "x.x...x.x.....x.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "LADY MARMALADE - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "............x...",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x...x......."
                },
                name = "LADY MARMALADE - B"
            },
            {
                grid = {
                    BD = "x.........x.....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x..xxx..x.xx"
                },
                name = "HOT SWEAT - A"
            },
            {
                grid = {
                    BD = "..xx......xx..x.",
                    CY = "x.xxx.x.x.xxx.x.",
                    SD = ".x.xxx.x.x.xxx.."
                },
                name = "HOT SWEAT - B"
            },
            {
                grid = {
                    AC = "................",
                    BD = "..x.x.....x.x...",
                    CY = "xxx.xxxxxxx.xxxx",
                    SD = ".x..x.xx.x..x.xx"
                },
                name = "HAITIAN DIVORCE"
            },
            {
                grid = {
                    BD = "x.......xx.....x",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".xx.xxx..xx.xxx."
                },
                name = "COME DANCING - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x..x.xx......x",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".x..xx...x..xxx."
                },
                name = "COME DANCING - B"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.....x.x..."
                },
                name = "RESPECT YOURSELF - A"
            },
            {
                grid = {
                    BD = "x...x...x...x...",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x...x.x.x..."
                },
                name = "RESPECT YOURSELF - B"
            },
            {
                grid = {
                    BD = "x..x....x..x..x.",
                    CY = "xxxxxxxxxxxxxxxx",
                    SD = "....x..x.x.x.x.x"
                },
                name = "EXPRESS YOURSELF - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x..x....x..x..x.",
                    CY = "xxxxxxxxxxxxxxxx",
                    SD = "....x..x.x.xx..."
                },
                name = "EXPRESS YOURSELF - B"
            },
            {
                grid = {
                    AC = "................",
                    BD = "..x.....x.xx.xx.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x..x.xx.xx.."
                },
                name = "LET A WOMAN BE A WOMAN"
            },
            {
                grid = {
                    AC = "................",
                    BD = "..x.......x...x.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x..x.x.xx..."
                },
                name = "LET A MAN BE A MAN"
            },
            {
                grid = {
                    BD = "x...x...x..x....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "BOOKS OF MOSES - A"
            },
            {
                grid = {
                    BD = "x...x...x.......",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "BOOKS OF MOSES - B"
            },
            {
                grid = {
                    BD = "x.x.......x.....",
                    CY = "x...x...x...x...",
                    SD = "....x..x.x....x."
                },
                name = "MOTHER POPCORN - A"
            },
            {
                grid = {
                    BD = "..x...x...x...x.",
                    CY = "x...x...x...x...",
                    SD = ".x.xxx.x.x.xxx.x"
                },
                name = "MOTHER POPCORN - B"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x..x..x...x.....",
                    CY = ".xx.xx.xx....xx.",
                    SD = ".x..x..x...xx..."
                },
                name = "STRT BTS - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x..x..x...x.....",
                    CY = ".xx.xx.xx....xx.",
                    SD = ".x..x..x....x..."
                },
                name = "STRT BTS - B"
            },
            {
                grid = {
                    AC = "................",
                    BD = "x.x.......x.....",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "......x..x....x."
                },
                name = "I GOT THE FEELIN’ - A"
            },
            {
                grid = {
                    AC = "................",
                    BD = "..x.....x...x.x.",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = ".x..xx.x.xxx.xxx"
                },
                name = "I GOT THE FEELIN’ - B"
            },
            {
                grid = {
                    BD = "x.......xx......",
                    CH = "..x.x.x.x.x.x.x.",
                    HT = "....x.......x...",
                    OH = "x...............",
                    SD = "....x.......x..."
                },
                name = "MORE BOUNCE TO THE OUNCE"
            }
        }
    },
    {
        name = "Hip Hop",
        sections = {
            {
                grid = {
                    BD = "x.....xx...x..x.",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 1 - A"
            },
            {
                grid = {
                    BD = "x......x...x....",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 1 - B"
            },
            {
                grid = {
                    BD = "x......xxx...x.x",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 2 - A"
            },
            {
                grid = {
                    BD = "x......xx..x....",
                    SD = "....x....x..x..."
                },
                name = "HIP HOP 2 - B"
            },
            {
                grid = {
                    BD = "x.x.....x.x.....",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 3 - A"
            },
            {
                grid = {
                    BD = "x.x.....xx.x....",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 3 - B"
            },
            {
                grid = {
                    BD = "x..x...x.xx....x",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 4 - A"
            },
            {
                grid = {
                    BD = "x.x....xxxx.....",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 4 - B"
            },
            {
                grid = {
                    BD = "x.x....xx.x....x",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 5"
            },
            {
                grid = {
                    BD = "x.x.......xx...x",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 6"
            },
            {
                grid = {
                    BD = "x......x..x..x.x",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 7"
            },
            {
                grid = {
                    BD = "x..x....x.xx....",
                    CH = "xx.xx.xxxx.xx.xx",
                    OH = ".....x.......x..",
                    SD = "....x.......x..."
                },
                name = "HIP HOP 8"
            },
            {
                grid = {
                    BD = "x.....x.....x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    SD = "........x......."
                },
                name = "TRAP - A"
            },
            {
                grid = {
                    BD = "..x.x...........",
                    CH = "..x.x.x.x.x...x.",
                    SD = "........x......."
                },
                name = "TRAP - B"
            }
        }
    },
    ---
    {
        name = "Rock 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.......",
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                    AC = "....x.......x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.x...x.",
                    SD = "....x.......x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "..x...x...x.xxxx",
                    HT = "...xx..xx..x....",
                    CH = "x...............",
                    AC = "x...........x..x"
                }
            }
        }
    },
    {
        name = "Rock 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x..x..x......x",
                    SD = "....x.......x...",
                    OH = "...............x",
                    CH = "xxxxxxxxxxxxxxx.",
                    AC = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x......x",
                    SD = "....x.......x.x.",
                    OH = ".......x.......x",
                    CH = "xxxxxxx.xxxxxxx."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..x.x.x.x.",
                    LT = "........xxxx....",
                    SD = "xxxx............",
                    MT = "....xxxx........",
                    CY = "............x.x."
                }
            }
        }
    },
    {
        name = "Rock 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.........x...x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "..x...x.....x...",
                    OH = "..x...x...x...x.",
                    CH = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Rock 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "....x.......x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "xxxxxxxxxxxxxxxx",
                    AC = "x..xx..xx..xx..x"
                }
            }
        }
    },
    {
        name = "Rock 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x.......x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.......",
                    SD = "....x.......x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "....x..x..x.x...",
                    CH = "x...............",
                    AC = ".......x..x.x..."
                }
            }
        }
    },
    {
        name = "Funk 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x......x..x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x.......x...",
                    OH = "..............x.",
                    CH = "x.x.x.x.x.x.x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..x...",
                    SD = ".xx.xx.xx.xx..xx",
                    CH = "x..x..x..x..x...",
                    AC = "x..x........x.xx"
                }
            }
        }
    },
    {
        name = "Funk 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x......x.x.x.x..",
                    SD = "....x.......x...",
                    OH = ".......x.x.x....",
                    CH = "x.x.xxx......x.."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x.......",
                    SD = "...........x....",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x.x....x..",
                    SD = "...x......xxx...",
                    CH = "x...x.x.x....x..",
                    AC = ".............x.."
                }
            }
        }
    },
    {
        name = "Funk 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x......xx.......",
                    CH = "xxxxxxxxxxxxxxxx",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x.......",
                    CH = "xxxxxxxxxxxxxxxx",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x......x........",
                    SD = ".xxxxxx..xxxx.x.",
                    CH = "x......x......x.",
                    AC = "...x........x.x."
                }
            }
        }
    },
    {
        name = "Funk 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x....x..x.....",
                    SD = "....x.......x...",
                    CH = "x.x.xxxx..x.xxx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.......",
                    SD = "....x......x....",
                    CH = "x.x.xxx.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".............x..",
                    SD = "xxxx....xxxxxx..",
                    HT = "....xxxx........"
                }
            }
        }
    },
    {
        name = "Funk 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x.....x.......",
                    SD = "....xx.....xx...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = ".....x......x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x..x....",
                    SD = "....x..x....x...",
                    CH = "x.x.xxx.x.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..........",
                    SD = "....x.......xxxx",
                    HT = "........xxxx....",
                    CH = "x.x..x.........."
                }
            }
        }
    },
    {
        name = "Funk 5b",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x.....x.......",
                    SD = "....xx.....xx...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = ".....x......x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x..x....",
                    SD = "....x..x....x...",
                    CH = "x.x.xxx.x.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..........",
                    SD = "....x.......xxxx",
                    HT = "........xxxx....",
                    CH = "x.x..x.........."
                }
            }
        }
    },
    {
        name = "Funk 6",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x.x..x..x.",
                    SD = "..x.xx.x..x.xx.x",
                    CH = "xx.x..x.xx.x..x.",
                    AC = "....xx......xx.."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x..x.x..x..x.",
                    LT = ".......x.......x",
                    SD = "....xx......xx..",
                    HT = "..x.......x.....",
                    CH = "xx.x..x.xx.x..x.",
                    AC = "....xx......xx.."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........xx....",
                    SD = "....x........xx.",
                    MT = "......xxx......."
                }
            }
        }
    },
    {
        name = "Funk 7",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x...x.......x",
                    SD = "....x.......x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x...........",
                    MT = "............x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".x..x.x.........",
                    SD = "x..x.....x.xxxxx",
                    CH = "....x.x.........",
                    AC = "......x........x"
                }
            }
        }
    },
    {
        name = "Funk 8",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x....x.xx....",
                    SD = "......x.......x.",
                    OH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x....x.xx....",
                    SD = "......x.......xx",
                    OH = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "...........xx.x.",
                    SD = "x.x.x..xx.......",
                    MT = ".....x...x......",
                    CH = "............x.x.",
                    AC = ".....x...x..x.x."
                }
            }
        }
    },
    {
        name = "Funk 9",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.x....x",
                    SD = "....x.......x...",
                    OH = "..x.............",
                    CH = "....xxx.xxx.xxxx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx.x.x.x.x.x..",
                    SD = "....x.......x...",
                    OH = ".....x.x.x.x....",
                    CH = "x.xxx........x.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x.x...x.x....",
                    SD = ".xx.x..x....x...",
                    CH = "............x...",
                    AC = "....x.......x..."
                }
            }
        }
    },
    {
        name = "Funk 10",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x....x........",
                    SD = "....x.......x...",
                    CH = "xxxx.xxxxxxx.xxx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x.......",
                    SD = "....x.......x...",
                    CH = "xxxx.xxxxxxx.xxx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".....x....x.....",
                    SD = "xx.xx..xx...xxxx",
                    CH = ".....x....x.....",
                    AC = ".x...x....x....."
                }
            }
        }
    },
    {
        name = "Funk 11",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x.x..x....",
                    SD = "....x.......x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    AC = "............x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx....x.x..x....",
                    SD = "....x.......x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    AC = "............x..."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "x......x....x...",
                    SD = "..xxx...xxx...xx",
                    HT = ".....xx....x....",
                    AC = "...x...x...x...x"
                }
            }
        }
    },
    {
        name = "Funk 12",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x...x.x.x...x",
                    SD = "....x.......x...",
                    OH = "...x...x.x.x...x",
                    CH = "xxx..xx.x.x..xx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x...x...x....",
                    SD = "....x.......x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "............xxxx",
                    SD = ".x.xxxxx........",
                    MT = "........xxxx....",
                    OH = "x.x............."
                }
            }
        }
    },
    {
        name = "Funk 13",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x....x....",
                    SD = "............x.x.",
                    OH = "......x.......x.",
                    CH = "xxx.xx..xxx.xx.."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x..x....x....",
                    SD = "............x.xx",
                    OH = "......x.......x.",
                    CH = "xxx.xx..xxx.xx.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "...xx....x.xx...",
                    MT = ".....xx......x.x"
                }
            }
        }
    },
    {
        name = "Funk 14",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "xx....xx..x..x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x....xx......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".....x.......x..",
                    SD = "x..xx...x.x.xx..",
                    CH = ".............x..",
                    AC = ".............x.."
                }
            }
        }
    },
    {
        name = "Funk 15",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.....",
                    SD = "........x...",
                    CH = "x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.....",
                    SD = "........x..x",
                    CH = "x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.........x.",
                    SD = "..x.x.x.xx..",
                    CH = "x.........x.",
                    AC = "..........x."
                }
            }
        }
    },
    {
        name = "Rhythm & Blues 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x...x...x.....",
                    SD = "....x.......x..x",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.xx....",
                    SD = "....x..x.x..x..x",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.....x.....",
                    SD = "xx.x.xxx.x.xxxxx",
                    MT = "..x.....x......."
                }
            }
        }
    },
    {
        name = "Rhythm & Blues 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x..x.x..xx.x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "...x.xx..x.x.xx.",
                    SD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..xx..xx..xx....",
                    LT = "........xx......",
                    SD = "xx..........xxxx",
                    MT = "....xx.........."
                }
            }
        }
    },
    {
        name = "Rhythm & Blues 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x...x.x.x.x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx....x..x....",
                    SD = "....x.xx....x...",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x...x.......x",
                    LT = ".....x..........",
                    SD = "..x.....x.xx..x.",
                    HT = "............xx..",
                    CH = "x..xx..x........"
                }
            }
        }
    },
    {
        name = "Rhythm & Blues 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x.....x.xx....",
                    SD = "....x..x.x..x..x",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.......x..x",
                    OH = "..x...x...x...x.",
                    CH = "xx.xxx.xxx.xxx.x"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x.....x......",
                    SD = ".xx.x.....x.....",
                    MT = "......xxx...x.xx",
                    CH = "...x......x....."
                }
            }
        }
    },
    {
        name = "Rhythm & Blues 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...xx.xx.x.xx.x",
                    SD = "..x...x....x..x.",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx...xx.xx.x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x...x...x....",
                    LT = "........xxx.....",
                    SD = ".xx.........x...",
                    MT = "....xxx.........",
                    CH = "............x..."
                }
            }
        }
    },
    {
        name = "Ballad 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x......xx.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    LT = "............xxxx",
                    SD = "....x.xx........",
                    MT = "........xxx.....",
                    CH = "x.x.............",
                    AC = "...............x"
                }
            }
        }
    },
    {
        name = "Ballad 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x......xx.x.....",
                    SD = "....x.......x...",
                    OH = "..............x.",
                    CH = "x.x.x.x.x.x.xx.."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....xx.x..x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.......x.......",
                    LT = "............xxxx",
                    SD = "..xxx.x.........",
                    MT = "........x.x.....",
                    CH = "x...............",
                    AC = "....x.......x..."
                }
            }
        }
    },
    {
        name = "Ballad 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.........",
                    SD = "........x.....xx",
                    OH = "..x...x...x..x..",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx....xx........",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...xx..xx..xx..",
                    LT = "..........xx....",
                    SD = "..xx..........xx",
                    HT = "......xx........"
                }
            }
        }
    },
    {
        name = "Ballad 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.x...x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x....x..x.......",
                    LT = "................",
                    SD = "...xx...........",
                    MT = ".xx.......x.xx..",
                    CH = ".....x..x.......",
                    AC = ".....x.......x.."
                }
            }
        }
    },
    {
        name = "Ballad 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.........x....x",
                    SD = "....x.......x...",
                    OH = ".......x.......x",
                    CH = "xxxxxxx.xxxxxxx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    LT = "..............xx",
                    SD = "....x...xx......",
                    MT = "..........xx....",
                    HT = "............xx..",
                    OH = ".......x........",
                    CH = "xxxxxxx........."
                }
            }
        }
    },
    {
        name = "Pop 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.....x.",
                    SD = "....x.x.....x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "....x.......x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.....x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "....x..........."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    LT = "..x.x.x.x.......",
                    SD = "..x.x.x.x.xxx...",
                    CH = "x...............",
                    AC = "............x..."
                }
            }
        }
    },
    {
        name = "Pop 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x...x..x..",
                    SD = "...x....x...x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.....x...",
                    SD = "...x......x..x..",
                    CH = "x...x...x...x...",
                    AC = ".............x.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x...x.....",
                    SD = "..xx........xxxx",
                    MT = "........xx......",
                    AC = "...x.....x......"
                }
            }
        }
    },
    {
        name = "Pop 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "....x.xx.x..x...",
                    SD = "x..x....x..x....",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx.x..x.xx.x..",
                    SD = "....x.......x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "............x...",
                    LT = "................",
                    SD = "x.........xx....",
                    MT = "...x............",
                    CH = "............x...",
                    AC = "...........x...."
                }
            }
        }
    },
    {
        name = "Pop 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x..x....x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.xx....",
                    SD = "....x..x....x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.........x.....",
                    SD = "....x.x.x...x.xx",
                    CH = "x...............",
                    AC = "x...........x..x"
                }
            }
        }
    },
    {
        name = "Pop 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x...x..x..",
                    SD = "...xx.......x...",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x......x..",
                    SD = "...x......x.x...",
                    CH = "x...x...x...xx..",
                    AC = ".............x.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = ".xxxx.xxxxx.xxxx",
                    OH = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Reggae 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "....x.......x...",
                    RS = "....x..x.x..x..x",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "....x.......x...",
                    RS = "..xx..x...xx..x.",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..............x.",
                    SD = "..x.x.x.....xx..",
                    MT = "........x.x.....",
                    CH = "..............x.",
                    AC = "..............x."
                }
            }
        }
    },
    {
        name = "Reggae 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "....x.......x...",
                    RS = "........x.......",
                    OH = "..............x.",
                    CH = "..xx..xx..xx...."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "....x.......x...",
                    RS = "....x.......x...",
                    OH = "..............x.",
                    CH = "..xx..xx..xx...."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..............x.",
                    LT = "..........xxx...",
                    SD = "..xxx...........",
                    MT = "......xxx.......",
                    CH = "..............x.",
                    AC = "....x...x...x..."
                }
            }
        }
    },
    {
        name = "Reggae 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x....x...x...",
                    SD = "........x.......",
                    CH = "x.xxxxx...x...x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "........x.......",
                    CH = "x.xx.xx...x...x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..............x.",
                    LT = "..........x.x...",
                    SD = "x.x.............",
                    MT = "......x.........",
                    OH = "..............x.",
                    AC = "..............x."
                }
            }
        }
    },
    {
        name = "Reggae 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "......x..x..",
                    RS = "x.....x.....",
                    OH = "...x.....x..",
                    CH = "x.x...x.x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x...x.....",
                    RS = "x.....x.....",
                    OH = "...x.....x..",
                    CH = "x.x...x.x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "...x.....x..",
                    SD = "xxx.........",
                    MT = "......xxx...",
                    CH = "...x.....x.."
                }
            }
        }
    },
    {
        name = "Reggae 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    RS = "..x...x...x...xx",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    RS = "....x.......x..x",
                    OH = "..xx..xx..xx..xx",
                    CH = "xx..xx..xx..xx.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..............x.",
                    LT = ".........x.x....",
                    SD = "x...........x...",
                    MT = "...x.xx.........",
                    CH = "..............x.",
                    AC = "..............x."
                }
            }
        }
    },
    {
        name = "Disco 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x......xx...",
                    OH = "..x...x..x....x.",
                    CH = "xx.xxx.xx.xxxx.x"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    LT = "........x.......",
                    SD = "....xx.x.xxxxx..",
                    MT = "......x.........",
                    OH = "..x.............",
                    CH = "xx.x............",
                    AC = "....x...x...x..."
                }
            }
        }
    },
    {
        name = "Disco 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    CB = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    CB = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.xx..xx..xx..xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "...xx.x.x.x.xxx.",
                    CH = "xxx............."
                }
            }
        }
    },
    {
        name = "Disco 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "..xx..xx..xx..xx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    CB = "............x.xx",
                    SD = "....x.xx.xx.....",
                    MT = "........x..x....",
                    CH = "xxxx............"
                }
            }
        }
    },
    {
        name = "Disco 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x..xx...",
                    SD = "....x......xx...",
                    OH = "...x...x.......x",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "...xx..xx..xx..x",
                    OH = "..x...x...x...x.",
                    CH = "xx...x...x...x.."
                }
            }
        }
    },
    {
        name = "Disco 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "..xx..x...xx..x.",
                    CH = "xx...x.xxx...x.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "...x...........x",
                    CH = "xxx..xxxxxxx.xx."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    LT = "............xxxx",
                    SD = "....xxxx........",
                    MT = "........xxxx....",
                    OH = "..xx............",
                    CH = "xx.............."
                }
            }
        }
    },
    {
        name = "Afro-Cuban 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    RS = "......x...x...x.",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x...x.",
                    RS = "......x.....x...",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    LT = "............xxxx",
                    SD = ".xxxx...........",
                    MT = "......xxxxx.....",
                    CH = "x...............",
                    AC = "....x.......x..x"
                }
            }
        }
    },
    {
        name = "Afro-Cuban 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    LT = "............x.x.",
                    RS = "...x..x.........",
                    MT = "..........x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.....x.",
                    RS = "......x.........",
                    MT = "..........x.x...",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".............x..",
                    LT = "......x.x.x.....",
                    SD = "xx..........x...",
                    MT = "....x...........",
                    CH = ".............x..",
                    AC = "............xx.."
                }
            }
        }
    },
    {
        name = "Afro-Cuban 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.....x.",
                    LT = "..............x.",
                    RS = "...x............",
                    MT = "......x...x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    LT = "............x.x.",
                    SD = "...x............",
                    MT = "......x...x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x...x.x...",
                    SD = ".x...x.x...x.x..",
                    MT = "..xx....xx....xx",
                    CH = "x...x.x...x.x...",
                    AC = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Afro-Cuban 4",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.x...x.",
                    RS = "......x.....x...",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    LT = "..............x.",
                    RS = "......x.........",
                    MT = "..........x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "........x.x.....",
                    SD = "x..x........x...",
                    HT = "....x.x.........",
                    CH = "............x...",
                    AC = "............x..."
                }
            }
        }
    },
    {
        name = "Afro-Cuban 5",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    LT = "..............x.",
                    RS = "......x.........",
                    HT = "..........x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "....x.....x.....",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..............x.",
                    SD = "x.x...x.........",
                    MT = "..........x....."
                }
            }
        }
    },
    {
        name = "Blues 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x..xx.x.xx",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxxxx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x.x.",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxxxx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "xxxxxxxxx...",
                    SD = "xxxxxxxxxxxx",
                    CH = "xxxxxxxxx..."
                }
            }
        }
    },
    {
        name = "Blues 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x.x.x.x.x.",
                    SD = "...x.....x..",
                    CH = "x.xx.xx.xx.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x..x",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxxxx"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..",
                    SD = ".xx.xx.xx.xx",
                    CH = "x..x..x..x.."
                }
            }
        }
    },
    {
        name = "Swing 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x..x..",
                    CH = "x..x..x..x.."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x..x..x..",
                    SD = "...x.....x..",
                    CH = "x..x..x..x.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x........",
                    SD = "......xxxxxx",
                    CH = "x..x........"
                }
            }
        }
    },
    {
        name = "Swing 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x..x..",
                    SD = "...x.....x..",
                    CH = "x..x.xx..x.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x.xx..x..",
                    SD = "...x.....x..",
                    CH = "x..x.xx..x.x"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "xxx.xxx.x...",
                    SD = "...x...x.xx.",
                    CH = "..........x."
                }
            }
        }
    },
    {
        name = "Swing 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x....xx.x..x",
                    SD = "...x.....x..",
                    CY = "x..x..x..x.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x..x",
                    SD = "...x.....x..",
                    CY = "x..x..x..x.."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..",
                    SD = ".xx....xx...",
                    MT = "....xx....xx",
                    OH = "x..x..x..x.."
                }
            }
        }
    },
    {
        name = "Shuffle 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x....xx.....",
                    SD = "...x.....x..",
                    CH = "x.xx.xx.xx.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x....xx.x...",
                    SD = "...x.....x..",
                    CH = "x.xx.xx.xx.x"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...xx.xx.xx",
                    SD = "...x..x..x..",
                    CH = "x..........."
                }
            }
        }
    },
    {
        name = "Shuffle 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.x...x.x...",
                    SD = "...x.....x..",
                    CH = "x.xx.xx.xx.x"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x...x.x...",
                    SD = "...x.x...x..",
                    CH = "x.xx.xx.xx.x"
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x....x..x",
                    SD = ".xx.xxxx.xx.",
                    CH = "x..x........"
                }
            }
        }
    },
    {
        name = "Samba 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CB = "x...x...x...x...",
                    LT = ".......x.......x",
                    SD = "...........x....",
                    MT = "...x............",
                    CH = ".xx..xx..xx..xx."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CB = "x.x.xx.x.xx.xx.x",
                    MT = "...........x....",
                    CH = ".x.x..x.x.....x."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........xxx...",
                    SD = "x.xxx.........x.",
                    MT = "......xxx.......",
                    CH = "..............x.",
                    AC = "..............x."
                }
            }
        }
    },
    {
        name = "Samba 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    LT = "..............xx",
                    RS = "..x..x..x.......",
                    SD = "...........x....",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    LT = "...............x",
                    RS = ".x...x...x...x..",
                    SD = "...x.......x....",
                    MT = ".......x........",
                    CH = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.....x.....",
                    SD = ".xx....xx....xx.",
                    MT = "x..x..x..x..x..x"
                }
            }
        }
    },
    {
        name = "Samba 3",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx",
                    AC = "x...x...x...x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    SD = "x.x.xx.x.xx.xx.x",
                    CH = ".x.x..x.x..x..x.",
                    AC = ".......x...x...."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    LT = "...........x..x.",
                    SD = "..x.x...x..x..x.",
                    MT = "........x.......",
                    HT = "..x.x...........",
                    OH = "...............x",
                    CH = "xx....xx..x.x..."
                }
            }
        }
    },
    {
        name = "Bossa Nova 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "x.....x.....x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "....x.....x.....",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..x.x.........x.",
                    LT = "............x...",
                    RS = "x...............",
                    MT = "........x.x.....",
                    CH = "..x.............",
                    CY = "....x..........."
                }
            }
        }
    },
    {
        name = "Bossa Nova 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "..x..x..x..x....",
                    CH = "....x.......x...",
                    CY = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "..xx..xx..xx..xx",
                    CH = "....x.......x...",
                    CY = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........x.x...",
                    MT = "..x...x.........",
                    AC = "............x..."
                }
            }
        }
    },
    {
        name = "Cha-Cha",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.....x.",
                    CB = "x...x...x...x...",
                    LT = "............x.x.",
                    HT = "..x...x.........",
                    CH = "....x.......x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    CB = "x...x...x...x...",
                    LT = "......xx......x.",
                    HT = "..xx......xx....",
                    CH = "....x.......x..."
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.x.........",
                    SD = "............x...",
                    HT = "..x.....x.......",
                    CH = "............x...",
                    AC = "............x..."
                }
            }
        }
    },
    {
        name = "Twist 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.x.....x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "......x.....x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.x.....x...",
                    CH = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x.....x.x.....",
                    SD = "............xxxx",
                    MT = "....x.x.........",
                    CH = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Twist 2",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.x.....x...",
                    CH = "x...x.x.x...x...",
                    AC = "......x.....x..."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x.x.....x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    AC = "......x.....x..."
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.x.....xxxx",
                    MT = "........x.x....."
                }
            }
        }
    },
    {
        name = "Ska",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "..x...x...x...x."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "..............x.",
                    CH = "x.x.x.x.x.x.x...",
                    AC = "..x...x...x....."
                }
            },
            {
                name = "Break",
                grid = {
                    SD = "x.xx....x.x.x...",
                    MT = "....x.x.........",
                    CH = "............x...",
                    AC = "............x..."
                }
            }
        }
    },
    {
        name = "Endings",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x...............",
                    CY = "x...............",
                    AC = "x..............."
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...............",
                    CH = "x...............",
                    AC = "x..............."
                }
            }
        }
    },
    ------ end of book 200 pattersns start with 260 new pattersn

    {
        name = "Ending",
        sections = {
            {
                name = "Ending1",
                grid = {
                    CH = "x...............",
                    BD = "x..............."
                }
            },
            {
                name = "Ending2",
                grid = {
                    BD = "........x.......",
                    CY = "........x.......",
                    MT = "....f...........",
                    SD = "f..............."
                }
            },
            {
                name = "Ending3",
                grid = {
                    BD = "........x.......",
                    SD = "xx..............",
                    CY = "........x.......",
                    MT = "...xx...........",
                    LT = "......x........."
                }
            }
        }
    },
    {
        name = "Waltz",
        sections = {
            {
                name = "Waltz1",
                grid = {
                    CH = "....x...x...",
                    SD = "....x...x...",
                    BD = "x...........",
                    CY = "x...x..xx..."
                }
            },
            {
                name = "Waltz2",
                grid = {
                    CH = "....x...x...",
                    SD = "....x...x...",
                    BD = "x...........",
                    CY = "x..........."
                }
            },
            {
                name = "Waltz3",
                grid = {
                    CH = "....x...x...",
                    SD = "....x...x..x",
                    BD = "x...........",
                    CY = "x...x...x..x"
                }
            },
            {
                name = "WaltzBreak1",
                grid = {
                    CH = "....x...x...",
                    SD = "....x.x.x.x.",
                    BD = "x...........",
                    CY = "x..........."
                }
            },
            {
                name = "WaltzBreak2",
                grid = {
                    MT = "....f.......",
                    LT = "........f...",
                    BD = "x...........",
                    SD = "f...........",
                    CH = "....x...x..."
                }
            },
            {
                name = "WaltzBreak3",
                grid = {
                    CH = "....x...x...",
                    LT = "........x.x.",
                    MT = "....x.x.....",
                    SD = "f..........."
                }
            }
        }
    },
    {
        name = "Twist",
        sections = {
            {
                name = "Twist1",
                grid = {
                    AC = "......x.....x...",
                    SD = "....x.x.....x...",
                    BD = "x.......x.x.....",
                    CY = "x.xxx.x.x.x.x.x.",
                    CH = "x...x...x...x..."
                }
            },
            {
                name = "Twist2",
                grid = {
                    AC = "......x.....x...",
                    BD = "x.......x.......",
                    CY = "x.x.x.x.x.x.x.x.",
                    SD = "..x.x.x.....x..."
                }
            },
            {
                name = "Twist3",
                grid = {
                    AC = "......x.........",
                    SD = "....x.x.....x...",
                    BD = "x.......x.......",
                    CY = "x...x.x.x...x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "TwistBreak1",
                grid = {
                    AC = "............x.x.",
                    LT = "........x.x.....",
                    SD = "x.x.x.x.....f.f.",
                    MT = "x.x.x.x.x.x....."
                }
            },
            {
                name = "TwistBreak2",
                grid = {
                    AC = "x...........x.x.",
                    LT = "........x.x.....",
                    SD = "f.x.x.x.x.x.xxxx",
                    MT = "..x.x.x........."
                }
            },
            {
                name = "TwistBreak3",
                grid = {
                    SD = "xx.x.xxx......x.",
                    MT = "........xx.x.x..",
                    CY = "..............x.",
                    CH = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Swing",
        sections = {
            {
                name = "Swing1",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x....xx....x",
                    SD = "...x.....x.."
                }
            },
            {
                name = "Swing2",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x....xx.....",
                    SD = "...x.....x.x"
                }
            },
            {
                name = "Swing3",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x..x..x..x..",
                    SD = "...x.....x.x"
                }
            },
            {
                name = "Swing4",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x.....x....x",
                    SD = "...x.x...x.."
                }
            },
            {
                name = "Swing5",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x.....x.x..x",
                    SD = "...x.....x.."
                }
            },
            {
                name = "Swing6",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    BD = "x.x...x.x...",
                    SD = "...x.x...x.."
                }
            },
            {
                name = "SwingBreak1",
                grid = {
                    BD = ".x.x.x.x.x.x",
                    SD = "f.f.f.f.f.f."
                }
            },
            {
                name = "SwingBreak2",
                grid = {
                    AC = ".x..x..x..x.",
                    HT = "......xx....",
                    MT = "...xx.......",
                    LT = ".........xx.",
                    BD = "..x..x..x..x",
                    SD = "xx.........."
                }
            },
            {
                name = "SwingBreak3",
                grid = {
                    MT = "..........xx",
                    SD = "...x...xx...",
                    BD = "x.x...x..x..",
                    CY = "x.xx........"
                }
            }
        }
    },
    {
        name = "Slow",
        sections = {
            {
                name = "Slow1",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.x....xx.x..x.."
                }
            },
            {
                name = "Slow2",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "xx....xx..x..x.."
                }
            },
            {
                name = "Slow3",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.xxx.x.x.x.xxx.",
                    BD = "x.....x.x.x....."
                }
            },
            {
                name = "Slow4",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.x.xxx...x.x...",
                    OH = ".......x......x.",
                    BD = "x......x........"
                }
            },
            {
                name = "Slow5",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.....xx........"
                }
            },
            {
                name = "Slow6",
                grid = {
                    SD = "........x.......",
                    CH = "x.x.x.x.xx..xx..",
                    OH = "..........x...x.",
                    BD = "x.....x...x...x."
                }
            },
            {
                name = "Slow7",
                grid = {
                    SD = "........x.......",
                    CH = "xx..xx..xx..xx..",
                    OH = "..x...x...x...x.",
                    BD = "x.....x.......x."
                }
            },
            {
                name = "Slow8",
                grid = {
                    SD = "........x.......",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x...x.x.......x."
                }
            },
            {
                name = "Slow9",
                grid = {
                    SD = "........x.......",
                    CH = "x.xx..x.x.x.x.x.",
                    OH = "....x...........",
                    BD = "x.....x...x...x."
                }
            },
            {
                name = "Slow10",
                grid = {
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                    OH = "..x.......x.....",
                    BD = "x......xx....x.x"
                }
            },
            {
                name = "Slow11",
                grid = {
                    SD = "....x.......x...",
                    CH = "xxxxxxx.xxxxxxx.",
                    OH = ".......x.......x",
                    BD = "x.xx...xx.x....."
                }
            },
            {
                name = "Slow12",
                grid = {
                    SD = "....x.......x...",
                    CH = "xxxxxx.xxxxxxx.x",
                    OH = "......x.......x.",
                    BD = "x......xx.x..x.."
                }
            },
            {
                name = "SlowBreak1",
                grid = {
                    SD = "....x.......xxxx",
                    CH = "x.x.x.x.x.x.x...",
                    BD = "x......xx......."
                }
            },
            {
                name = "SlowBreak2",
                grid = {
                    MT = "........x.xx....",
                    LT = "............x.xx",
                    BD = "x......xx.......",
                    SD = "....x...........",
                    CH = "x.x.x.x........."
                }
            },
            {
                name = "SlowBreak3",
                grid = {
                    AC = "............xx..",
                    MT = "...f............",
                    LT = ".....f..........",
                    BD = ".x..x..x..x...x.",
                    SD = "f........f..xx..",
                    OH = "..............x."
                }
            },
            {
                name = "SlowBreak4",
                grid = {
                    AC = "....x...........",
                    HT = "..........xx....",
                    MT = "........x.......",
                    LT = "............x.x.",
                    BD = "x............x.x",
                    SD = "...xx.x.........",
                    CH = "x.x.............",
                    OH = "..............x."
                }
            },
            {
                name = "SlowBreak5",
                grid = {
                    AC = "...........xx...",
                    MT = "....f........xx.",
                    BD = "..x...x.........",
                    SD = "f........x.xx...",
                    CH = "..x.............",
                    OH = "......x........."
                }
            },
            {
                name = "SlowBreak6",
                grid = {
                    HT = "..............f.",
                    MT = "......xx........",
                    BD = "xx......x.......",
                    CY = "xx..............",
                    OH = "........x.......",
                    SD = "....f.......f..."
                }
            }
        }
    },
    {
        name = "Ska",
        sections = {
            {
                name = "Ska1",
                grid = {
                    SD = "....x.......x...",
                    CH = "..x...x...x.....",
                    OH = "..............x.",
                    BD = "x.......x......."
                }
            },
            {
                name = "Ska2",
                grid = {
                    AC = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.......x......."
                }
            },
            {
                name = "Ska3",
                grid = {
                    AC = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x...",
                    OH = "..............x.",
                    BD = "x...x...x...x..."
                }
            },
            {
                name = "SkaBreak1",
                grid = {
                    AC = "x...x...x...x.x.",
                    SD = "x.xxx.x.x.xxxxxx"
                }
            },
            {
                name = "SkaBreak2",
                grid = {
                    AC = "x...x...x...x...",
                    SD = "..xxx.x...xxxxxx",
                    OH = "x.......x.......",
                    BD = "x.......x......."
                }
            },
            {
                name = "SkaBreak3",
                grid = {
                    AC = "..x...x...x...x.",
                    SD = "..x.............",
                    CH = "x...x...x...x...",
                    OH = "..x...x...x...x.",
                    HT = "..........x.....",
                    MT = "......x.........",
                    LT = "..............x.",
                    BD = "x...x...x...x..."
                }
            }
        }
    },
    {
        name = "Shuffle",
        sections = {
            {
                name = "Shuffle1",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "...x.....x..",
                    BD = "x.x..xx....."
                }
            },
            {
                name = "Shuffle2",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "...x.x...x..",
                    BD = "x.....x.x..."
                }
            },
            {
                name = "Shuffle3",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "...x.x.xxx..",
                    BD = "x.x...x....x"
                }
            },
            {
                name = "Shuffle4",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "...x.....x..",
                    BD = "x.x..x..x..."
                }
            },
            {
                name = "Shuffle5",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "...x...xxx..",
                    BD = "x....xx....x"
                }
            },
            {
                name = "Shuffle6",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.xx.x",
                    SD = "x.xx.xx.xx.x",
                    BD = "x.xx.xx.xx.x"
                }
            },
            {
                name = "ShuffleBreak1",
                grid = {
                    AC = "x.xx.xx.xx.x",
                    SD = "xxxxxx......",
                    HT = ".........x..",
                    MT = "......xxx...",
                    LT = "..........xx",
                    BD = "x....xx....."
                }
            },
            {
                name = "ShuffleBreak2",
                grid = {
                    AC = "x.xx.xx.xx.x",
                    HT = ".......x.x.x",
                    MT = "......x.x.x.",
                    SD = ".xxxxx......",
                    BD = "x.....x....."
                }
            },
            {
                name = "ShuffleBreak3",
                grid = {
                    AC = "x.xx.xx.xx.x",
                    SD = ".x.xxx.x....",
                    MT = ".........xxx",
                    BD = "x.x...x.x..."
                }
            }
        }
    },
    {
        name = "Samba",
        sections = {
            {
                name = "Samba1",
                grid = {
                    AC = "..x...x...x...x.",
                    MT = "x.x....x.x......",
                    LT = ".....x.....x.xx.",
                    BD = "x..xx..xx..xx..x",
                    CY = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Samba2",
                grid = {
                    AC = "..x...x...x...x.",
                    MT = "x.x.....x.......",
                    LT = ".....x.....x.x..",
                    BD = "x..xx..xx..xx..x",
                    CY = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Samba3",
                grid = {
                    AC = "..x...x...x...x.",
                    MT = "x.x.....x.......",
                    LT = ".....x.....x.x..",
                    BD = "x..xx..xx..xx..x",
                    CY = "x.xxx.xxx.xxx.xx"
                }
            },
            {
                name = "Samba4",
                grid = {
                    AC = ".......x...x....",
                    CH = ".x.x..x.x..x..x.",
                    HT = "x.x.............",
                    MT = "....xx.x........",
                    LT = "............xx.x",
                    BD = "x..xx..xx..xx..x",
                    SD = ".........xx....."
                }
            },
            {
                name = "Samba5",
                grid = {
                    CH = "..x...x...x...x.",
                    RS = "..x.....x..x....",
                    MT = ".....x........xx",
                    BD = "x..xx..xx..xx..x",
                    CY = "x..xx.xx.xx.xx.."
                }
            },
            {
                name = "Samba6",
                grid = {
                    CH = "..x...x...x...x.",
                    RS = "x.x....x.x.x....",
                    MT = "..............xx",
                    BD = "x..xx..xx..xx..x",
                    CY = "x.x.xxxx.x.xx.x."
                }
            },
            {
                name = "SambaBreak1",
                grid = {
                    AC = "..x.x...x.x...x.",
                    HT = "........x.x.....",
                    MT = "....x.xx........",
                    LT = "............xxx.",
                    BD = "x..xx..xx..xx..x",
                    SD = "xxx............."
                }
            },
            {
                name = "SambaBreak2",
                grid = {
                    AC = "x...........x.x.",
                    MT = "........x.x.....",
                    LT = "....x.x.........",
                    SD = "xxx.........x.x."
                }
            },
            {
                name = "SambaBreak3",
                grid = {
                    AC = "..x.....x...x...",
                    CH = "............x...",
                    MT = "x.x.............",
                    LT = "......x.x.......",
                    BD = "............x...",
                    SD = "x.x...x.x...x..."
                }
            }
        }
    },
    {
        name = "RnB",
        sections = {
            {
                name = "Rnb1",
                grid = {
                    SD = "....x..xxx..x..x",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.x.......x..xx."
                }
            },
            {
                name = "Rnb2",
                grid = {
                    SD = "....x....x....x.",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.xx.x.x...x.x.x"
                }
            },
            {
                name = "Rnb3",
                grid = {
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.x....x.x.x.x.x"
                }
            },
            {
                name = "Rnb4",
                grid = {
                    SD = "....x..x....x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.x.....xx.x.xx."
                }
            },
            {
                name = "Rnb5",
                grid = {
                    AC = "....x.......x...",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x..x.xx..xx....."
                }
            },
            {
                name = "Rnb6",
                grid = {
                    AC = "....x.......x...",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "..x......x.x.xx."
                }
            },
            {
                name = "Rnb7",
                grid = {
                    SD = "....x..x....x...",
                    CH = "x.x.x...x.x.x...",
                    OH = "......x.......x.",
                    BD = "x.xx....x.xx...."
                }
            },
            {
                name = "Rnb8",
                grid = {
                    CY = "..x...x...x...x.",
                    SD = "....x.......x...",
                    BD = "x.x....x..x..x.."
                }
            },
            {
                name = "Rnb9",
                grid = {
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                    OH = "..x...x...x...x.",
                    BD = "xx.x...xx.x....."
                }
            },
            {
                name = "Rnb10",
                grid = {
                    AC = "....x.......x...",
                    SD = "....x..x.x..x...",
                    OH = "..x...x...x...x.",
                    BD = "x.x.....x.xx...."
                }
            },
            {
                name = "Rnb11",
                grid = {
                    SD = "...x.........x..",
                    CH = "xxxxxxx.xxxxxxx.",
                    OH = ".......x.......x",
                    BD = "xx.....xx.x....."
                }
            },
            {
                name = "Rnb12",
                grid = {
                    AC = "....x...x...x...",
                    SD = "....x.......x...",
                    CH = "xx.xxx.xxx.xxx.x",
                    OH = "..x...x...x...x.",
                    BD = "x.x....xx.x..xx."
                }
            },
            {
                name = "RnbBreak1",
                grid = {
                    AC = "....x.......x...",
                    MT = "..........x.....",
                    LT = "..............x.",
                    BD = "x.x.............",
                    CY = "x.x.............",
                    SD = "....xx.x.x..xx.."
                }
            },
            {
                name = "RnbBreak2",
                grid = {
                    AC = "....x.......x...",
                    SD = "....x.xx.xxx..xx",
                    CH = "x.x.x...........",
                    BD = "x.......x...xx.."
                }
            },
            {
                name = "RnbBreak3",
                grid = {
                    AC = "....x.......x...",
                    HT = "............x...",
                    MT = "..........x...xx",
                    BD = "x............x..",
                    CY = "x...............",
                    SD = "..xxxx.x.x......"
                }
            },
            {
                name = "RnbBreak4",
                grid = {
                    CY = "............x...",
                    SD = "..f..f..f..f..f.",
                    BD = "xx.xx.xx.xx.x..."
                }
            },
            {
                name = "RnbBreak5",
                grid = {
                    AC = "....x...x.......",
                    CY = "x...........x.x.",
                    MT = ".......xx.......",
                    SD = "....xx....xx....",
                    BD = "x...........x.x."
                }
            },
            {
                name = "RnbBreak6",
                grid = {
                    AC = "..............x.",
                    CY = "..............x.",
                    MT = "......f.........",
                    SD = "f...........f...",
                    BD = ".x..x..x..x...x."
                }
            }
        }
    },
    {
        name = "Rock",
        sections = {
            {
                name = "Rock1",
                grid = {
                    AC = "x...x.......x...",
                    BD = "x.x...x.x.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock2",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x...x.x.x...x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock3",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.....x.x.......",
                    SD = "....x.......x.x.",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock4",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.....x...x...x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock5",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x...x...x...x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock6",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x...x...x.....",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock7",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.....x.x.x...x.",
                    SD = "....x..x.x..x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock8",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x.....x.x.....",
                    SD = "....x..x.x..x..x",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock9",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.......x.....x.",
                    SD = "....x..x..x....x",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock10",
                grid = {
                    AC = "............x...",
                    BD = "x.xx.x..x.xx.x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock11",
                grid = {
                    AC = "............x...",
                    BD = "x.....x.x.......",
                    SD = "..x.........x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock12",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x...x...x.....",
                    SD = "....x....x..x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Rock13",
                grid = {
                    AC = "x...x...x...x...",
                    BD = "x......xx.......",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Rock14",
                grid = {
                    AC = "x...x...x...x...",
                    BD = "x..x..x.x......x",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx"
                }
            },
            {
                name = "Rock15",
                grid = {
                    AC = "....x.......x...",
                    BD = "x..x.xx.x.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x...",
                    OH = "..............x."
                }
            },
            {
                name = "RockBreak1",
                grid = {
                    AC = "....x...x...x...",
                    BD = "x.....x.x.......",
                    SD = "..x.x...........",
                    CH = "x...............",
                    HT = "............xxx.",
                    MT = "..........x....."
                }
            },
            {
                name = "RockBreak2",
                grid = {
                    AC = "......x........x",
                    BD = "x.......x.......",
                    SD = "x.x.xxx.........",
                    CY = "...............x",
                    HT = "...........x....",
                    MT = "........xx......",
                    LT = "............xxxx"
                }
            },
            {
                name = "RockBreak3",
                grid = {
                    AC = "............x...",
                    LT = "x.x.x.x.x.x.....",
                    SD = "x.x.x.x.x.x.f..."
                }
            },
            {
                name = "RockBreak4",
                grid = {
                    AC = "....x...x.....x.",
                    BD = "x.........x...x.",
                    SD = "....f...f.......",
                    CY = "..............x."
                }
            },
            {
                name = "RockBreak5",
                grid = {
                    AC = "....x.....x.x.x.",
                    BD = "x.x.....x.......",
                    SD = "....x.xx........",
                    CH = "x.x.x...........",
                    OH = "............x...",
                    HT = "............xxx.",
                    MT = "........x.x....."
                }
            },
            {
                name = "RockBreak6",
                grid = {
                    AC = "....x.....x.x..x",
                    BD = "x.......x......x",
                    SD = "x.x.xxx..xxx....",
                    CY = "...............x",
                    HT = ".............x..",
                    MT = "............x...",
                    LT = "..............x."
                }
            },
            {
                name = "RockBreak7",
                grid = {
                    AC = "............x...",
                    BD = "x...............",
                    SD = "..f.........f...",
                    CY = "x...............",
                    MT = "......x.........",
                    LT = "..........x....."
                }
            },
            {
                name = "RockBreak8",
                grid = {
                    AC = "....x.x...x.x...",
                    BD = "x...x...x...x...",
                    SD = "....x.x...x.x...",
                    LT = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "RockBreak9",
                grid = {
                    AC = "x.x.x.x..x.x..x.",
                    BD = "x.......x.......",
                    SD = "....x.x.........",
                    CH = "x...............",
                    OH = "..x.............",
                    HT = "............xxx.",
                    MT = "........xx.x...."
                }
            },
            {
                name = "RockBreak10",
                grid = {
                    AC = "x...x...x.x...x.",
                    BD = "x.x.....x.......",
                    SD = "....x...x.x...xx",
                    CH = "x.x.x.x.........",
                    OH = "..............x.",
                    MT = "............xx.."
                }
            },
            {
                name = "RockBreak11",
                grid = {
                    AC = "....x.x.........",
                    BD = "x.....x.........",
                    CY = "......x.........",
                    CH = "x.x.x...........",
                    SD = "....x..........."
                }
            },
            {
                name = "RockBreak12",
                grid = {
                    BD = "x.......x.......",
                    SD = "xx.x............",
                    HT = "........xx.x....",
                    MT = "....xx.x........",
                    LT = ".............xx."
                }
            }
        }
    },
    {
        name = "Reggae",
        sections = {
            {
                name = "Reggae1",
                grid = {
                    AC = "........x.......",
                    OH = "....x...........",
                    BD = "x...x...x...x...",
                    SD = "........x.......",
                    CH = "xx.x....x.x.x.x."
                }
            },
            {
                name = "Reggae2",
                grid = {
                    AC = "....x.......x...",
                    RS = "....x.......x.x.",
                    BD = "x.x...x.x.x.....",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "Reggae3",
                grid = {
                    AC = "....x.......x...",
                    RS = "....x....x..x...",
                    BD = "x..x....x..x....",
                    CH = "..x...xx..x...xx"
                }
            },
            {
                name = "Reggae4",
                grid = {
                    RS = "....x.......x...",
                    BD = "....x.....x.x...",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "Reggae5",
                grid = {
                    RS = "...x..x...x.x...",
                    BD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Reggae6",
                grid = {
                    AC = "........x.......",
                    RS = "....x.x.....x.x.",
                    BD = "........x.......",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Reggae7",
                grid = {
                    AC = "...x.....x..",
                    RS = "x....x...x..",
                    BD = "......x.....",
                    CH = "x.xx.xx.xx.."
                }
            },
            {
                name = "Reggae8",
                grid = {
                    OH = "...x.....x..",
                    RS = "x.....x.....",
                    BD = "..x...x.....",
                    CH = "x.x...x.x..."
                }
            },
            {
                name = "Reggae9",
                grid = {
                    RS = "...x.....x.x",
                    BD = "x.....x.....",
                    CH = "x..x.xx..x.x"
                }
            },
            {
                name = "Reggae10",
                grid = {
                    BD = "x...x...x...x...",
                    RS = "..xx..xx........",
                    SD = "...........x..x.",
                    CH = "x.xxx.xxx.x.x.x."
                }
            },
            {
                name = "Reggae11",
                grid = {
                    OH = ".x..x.........x.",
                    RS = "........x.......",
                    BD = "........x.......",
                    CH = "x..x..x.x.xxx..."
                }
            },
            {
                name = "Reggae12",
                grid = {
                    RS = "........x.......",
                    BD = "x.....x..x.xx...",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "ReggaeBreak1",
                grid = {
                    AC = "x...........x...",
                    OH = "x...............",
                    HT = "....xx..........",
                    MT = "......xx........",
                    LT = "........x.x.....",
                    BD = "x...........x...",
                    SD = "x...............",
                    CH = "............x..."
                }
            },
            {
                name = "ReggaeBreak2",
                grid = {
                    AC = "....x.......xx..",
                    OH = "......x...x...x.",
                    HT = "........x.......",
                    MT = "............xx..",
                    BD = "......x...x...x.",
                    SD = "....x..........."
                }
            },
            {
                name = "ReggaeBreak3",
                grid = {
                    AC = "............xxx.",
                    OH = "..............x.",
                    HT = "........xx......",
                    MT = "..xx............",
                    LT = "....x.....x.....",
                    BD = "..............x.",
                    SD = "xx....xx....xx.."
                }
            },
            {
                name = "ReggaeBreak4",
                grid = {
                    AC = "x.......x.x.x...",
                    OH = "............x...",
                    BD = "............x...",
                    SD = "f.x...x.x.x.x...",
                    CH = "....x..........."
                }
            },
            {
                name = "ReggaeBreak5",
                grid = {
                    OH = "....x.....x.....",
                    BD = "..x.x...x.x.....",
                    SD = "f.....f.....f...",
                    CH = "..x.....x......."
                }
            },
            {
                name = "ReggaeBreak6",
                grid = {
                    AC = "x...........x...",
                    OH = "............x...",
                    HT = "........xx......",
                    MT = "......xx........",
                    LT = "..........x.x...",
                    BD = "x...............",
                    SD = "x..............."
                }
            },
            {
                name = "ReggaeBreak7",
                grid = {
                    AC = "...x.....x..",
                    OH = ".........x..",
                    MT = "......xxx...",
                    LT = ".........x..",
                    BD = "x..x..x..x..",
                    SD = "fxxx........"
                }
            },
            {
                name = "ReggaeBreak8",
                grid = {
                    OH = "..........x.",
                    HT = "...xxx......",
                    MT = "......x.x...",
                    LT = ".........xxx",
                    BD = "x...........",
                    SD = "x.x.........",
                    CH = "...........x"
                }
            },
            {
                name = "ReggaeBreak9",
                grid = {
                    AC = "x.x.x.x.x.x.",
                    OH = "x...........",
                    HT = "..........xx",
                    MT = "..xx..xx....",
                    BD = "x...........",
                    SD = "....xx..xx.."
                }
            }
        }
    },
    {
        name = "Pop",
        sections = {
            {
                name = "Pop1",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "xx.x.x.xxx.x.x.x",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop2",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "x.x..xxxx.x..xxx",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop3",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x..xx.x.x..x",
                    OH = "......x.......x.",
                    BD = "xx.x.x..xx.x....",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop4",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    OH = ".......x.......x",
                    BD = "x.xx.x.x.x.x.x.x",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop5",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "xx.x....xx.x..xx",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop6",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    BD = "xx.x....xx.x....",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop7",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x...x.x.x...x.",
                    OH = "....x.......x...",
                    BD = "x.xx..x...xx..x."
                }
            },
            {
                name = "Pop8",
                grid = {
                    AC = "....x.......x...",
                    CH = "x...x...x...x...",
                    OH = "..x...x...x...x.",
                    BD = "x.x...x...x...x.",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Pop9",
                grid = {
                    AC = "......x.....x...",
                    CH = "x.x.x.x.x...x...",
                    OH = "..........x...x.",
                    BD = "x.x.......x.....",
                    SD = "......x.....x.x."
                }
            },
            {
                name = "Pop10",
                grid = {
                    AC = "....x.......x...",
                    CH = "xxxxxxxxxxxx....",
                    OH = ".............x.x",
                    BD = "x.x.....xx.x.x.x",
                    SD = "....x..x....x..."
                }
            },
            {
                name = "Pop11",
                grid = {
                    AC = "....x.......x...",
                    CH = ".xxx.xxx.xxx.xxx",
                    BD = "..x..x.x..x..x.x",
                    SD = "x...x...x...x..."
                }
            },
            {
                name = "Pop12",
                grid = {
                    AC = "....x.......x...",
                    CH = "xxxx.x.xxxxx.x.x",
                    OH = "......x.......x.",
                    BD = "x.x....xx.x....x",
                    SD = "....x.......x..."
                }
            },
            {
                name = "PopBreak1",
                grid = {
                    HT = "........xx.x....",
                    MT = "....x..x........",
                    LT = "............xxx.",
                    BD = "xx......x.......",
                    SD = "xxxx............"
                }
            },
            {
                name = "PopBreak2",
                grid = {
                    AC = "x..x..x..x..x...",
                    HT = "......f.........",
                    MT = "...f............",
                    LT = ".........f......",
                    BD = ".xx.xx.xx.xx.xxx",
                    SD = "f...........f..."
                }
            },
            {
                name = "PopBreak3",
                grid = {
                    HT = ".............xxx",
                    MT = "........xx.x....",
                    CY = "x...............",
                    BD = "x.......x.......",
                    SD = "..f...f........."
                }
            },
            {
                name = "PopBreak4",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.x..x.x...x....",
                    SD = "....f....xx.f..."
                }
            },
            {
                name = "PopBreak5",
                grid = {
                    CY = "............xx..",
                    MT = "...f............",
                    LT = "......f.........",
                    BD = "............xx..",
                    SD = "f........f......"
                }
            },
            {
                name = "PopBreak6",
                grid = {
                    AC = "x..xx..x......x.",
                    CH = ".......x........",
                    OH = "..............x.",
                    MT = "....xxx.........",
                    LT = "...........xxxx.",
                    SD = "x......x........",
                    CY = "x..............."
                }
            }
        }
    },
    {
        name = "Charleston",
        sections = {
            {
                name = "Charleston1",
                grid = {
                    SD = "....x.......x...",
                    BD = "x.......x.......",
                    CY = "x...x..xx...x..x",
                    CH = "....x.......x..."
                }
            },
            {
                name = "CharlestonBreak1",
                grid = {
                    BD = "x.......x.......",
                    SD = "..x...x.x...x...",
                    CH = "....x.......x..."
                }
            }
        }
    },
    {
        name = "Paso",
        sections = {
            {
                name = "Paso1",
                grid = {
                    SD = "..x...x...xx..x.",
                    BD = "x...x...x...x...",
                    CY = "x.x.x.x.x.xxx.x.",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "Paso2",
                grid = {
                    SD = "..x...x.x.x.x.x.",
                    BD = "x...x...x...x...",
                    CY = "x.x.x.x.x.x.x.x.",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "PasoBreak1",
                grid = {
                    SD = "xx.x.xx.xx.xx.x.",
                    BD = "x...x...x...x..."
                }
            },
            {
                name = "PasoBreak2",
                grid = {
                    LT = ".........x.x....",
                    BD = "x...x...x...x...",
                    SD = ".x.x........x.f.",
                    CH = "x...x...x...x...",
                    MT = ".....xx........."
                }
            }
        }
    },
    {
        name = "Tango",
        sections = {
            {
                name = "Tango1",
                grid = {
                    AC = "..............x.",
                    SD = "x...x...x...x.x.",
                    CH = "....x.......x...",
                    BD = "x...x...x...x..."
                }
            },
            {
                name = "TangoBreak1",
                grid = {
                    AC = "......x.........",
                    SD = "..x...x.x.x.x.x.",
                    CH = "x...............",
                    BD = "x.......x.x.x.x."
                }
            }
        }
    },
    {
        name = "March",
        sections = {
            {
                name = "March1",
                grid = {
                    AC = "x...x...x...x...",
                    BD = "x...x...x...x...",
                    SD = "x.x.xx.xx.x.xxxx",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "March2",
                grid = {
                    AC = "x...x...x...x...",
                    BD = "x...x...x...x...",
                    SD = "x.xxx.xxx.xxxxxx",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "MarchBreak1",
                grid = {
                    AC = "..............x.",
                    HT = "........f.......",
                    MT = "....f...........",
                    LT = "............f...",
                    BD = "..x...x...x...x.",
                    SD = "f...............",
                    CY = "..........x...x."
                }
            },
            {
                name = "MarchBreak2",
                grid = {
                    AC = "......x....x....",
                    BD = "x...x...x...x...",
                    SD = "x.xx..x.xxxx..x.",
                    CH = "..x...x...x....."
                }
            }
        }
    },
    {
        name = "ChaCha",
        sections = {
            {
                name = "ChaCha1",
                grid = {
                    SD = "......x.........",
                    CH = "....x.......x...",
                    RS = "..x.......x.....",
                    MT = "............x.x.",
                    CB = "x...x...x...x...",
                    BD = "x.....x.x.....x."
                }
            },
            {
                name = "ChaCha2",
                grid = {
                    SD = "......x.........",
                    CH = "....x.x.....x.x.",
                    OH = "x.......x.......",
                    CB = "x...x...x...x...",
                    MT = "............x...",
                    LT = "..............x.",
                    BD = "x.....x.x.....x."
                }
            },
            {
                name = "ChaCha3",
                grid = {
                    SD = "......x.........",
                    CH = "x.x.x.x.x.x.x.x.",
                    CB = "x...x...x...x...",
                    LT = "............x.x.",
                    BD = "x.....x.......x."
                }
            },
            {
                name = "ChaChaBreak1",
                grid = {
                    SD = "f...........f...",
                    CB = "..............x.",
                    MT = "......f.......x.",
                    LT = "..x.....f.......",
                    BD = "..............x."
                }
            },
            {
                name = "ChaChaBreak2",
                grid = {
                    AC = "....x..x..x..x..",
                    MT = "....xx....xx....",
                    LT = ".......xx....xx.",
                    CB = "x..............."
                }
            },
            {
                name = "ChaChaBreak3",
                grid = {
                    AC = "......x.....x...",
                    SD = "....f...........",
                    MT = "..f...xx........",
                    LT = "..........x.xx.x"
                }
            }
        }
    },
    {
        name = "Jazz",
        sections = {
            {
                name = "Jazz1",
                grid = {
                    CY = "x..x.xx..x.x",
                    SD = "...x.......x",
                    BD = "x....x......"
                }
            },
            {
                name = "Jazz2",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    SD = "..x......x.x",
                    BD = "x.....x....."
                }
            },
            {
                name = "Jazz3",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    SD = "...x.x...x..",
                    BD = "......x....x"
                }
            },
            {
                name = "Jazz4",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    SD = "..x.....x..x",
                    BD = "x....x......"
                }
            },
            {
                name = "Jazz5",
                grid = {
                    CY = "x..x.xx..x.x",
                    SD = "...x.....x..",
                    BD = "x.x...x.x..."
                }
            },
            {
                name = "Jazz6",
                grid = {
                    AC = "...x.....x..",
                    CY = "x..x.xx..x.x",
                    SD = ".....x..x...",
                    BD = "x.x........."
                }
            },
            {
                name = "JazzBreak1",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.x......",
                    MT = ".........xxx",
                    SD = "...x..xxx...",
                    BD = "x....x......"
                }
            },
            {
                name = "JazzBreak2",
                grid = {
                    AC = "...x.....x..",
                    CY = "x...........",
                    MT = "........xxxx",
                    SD = "..xxxxx.....",
                    BD = "x..........."
                }
            },
            {
                name = "JazzBreak3",
                grid = {
                    AC = "...x.....x..",
                    CY = "x.xx.xx.....",
                    SD = "...x....xxxx",
                    BD = "x.x..xx....."
                }
            }
        }
    },
    {
        name = "Funk",
        sections = {
            {
                name = "Funk1",
                grid = {
                    AC = "..x......x..x...",
                    CH = "x...x...x...x...",
                    OH = "...............x",
                    BD = "x.....x..x......",
                    SD = "..x.........x..."
                }
            },
            {
                name = "Funk2",
                grid = {
                    AC = "......x......x..",
                    CH = "x...x...x...x...",
                    OH = "..x.............",
                    HT = "..........x.....",
                    LT = "..............x.",
                    BD = "x.x...xx.....x..",
                    SD = ".....x.........."
                }
            },
            {
                name = "Funk3",
                grid = {
                    AC = "............x...",
                    CH = "x...x...x...x...",
                    OH = "..............x.",
                    HT = "......x.........",
                    BD = "x..xx..xx...x...",
                    SD = ".x........x....."
                }
            },
            {
                name = "Funk4",
                grid = {
                    AC = "......x......x..",
                    CH = "x...x...x...x...",
                    OH = "..............x.",
                    MT = ".........xx.....",
                    BD = "xx....xx...x....",
                    SD = "...x.........x.."
                }
            },
            {
                name = "Funk5",
                grid = {
                    AC = ".x....x.....x.x.",
                    CH = "x...x...x...x...",
                    OH = ".x..............",
                    MT = "...............x",
                    BD = "xx....xx.xx...x.",
                    SD = "...x........xx.."
                }
            },
            {
                name = "Funk6",
                grid = {
                    AC = "x...x.........x.",
                    CH = "x...x...x...x...",
                    OH = ".....x....x.....",
                    BD = "..x...x...x...xx",
                    SD = ".......x....x..."
                }
            },
            {
                name = "Funk7",
                grid = {
                    AC = ".........x..x...",
                    CH = "xx.xx..xx.xx.xx.",
                    BD = "x..xx..xx.......",
                    SD = "..x..xx..x..x..x"
                }
            },
            {
                name = "Funk8",
                grid = {
                    CH = "xxx.x.xxx...x...",
                    OH = "..........x...x.",
                    BD = "x..xx.x.x...x...",
                    SD = ".....x...x..x..."
                }
            },
            {
                name = "Funk9",
                grid = {
                    AC = "...x.........xx.",
                    CH = "x.x.xx..x..xx...",
                    SD = "...x..xx.xx..x.x",
                    BD = "x...x...x..x....",
                    HT = "..............x."
                }
            },
            {
                name = "Funk10",
                grid = {
                    AC = "....x........x..",
                    CH = "......x....xx.xx",
                    OH = "x..x...x.x......",
                    BD = "x..x...x.x.xx..x",
                    SD = ".xx.x...x.x..x.."
                }
            },
            {
                name = "Funk11",
                grid = {
                    AC = "..x........x..x.",
                    CH = "x...x....xx.x...",
                    OH = ".....x.x........",
                    BD = "x....x.x.x......",
                    SD = "..x...x.x..x.x.."
                }
            },
            {
                name = "Funk12",
                grid = {
                    AC = "....x........x..",
                    CH = "x..x.xx..x.xx...",
                    OH = "..............x.",
                    BD = "x..x.....x.xx...",
                    SD = "....x..xx.x..x.."
                }
            },
            {
                name = "Funk13",
                grid = {
                    AC = ".......x.x....x.",
                    CH = "x.x..xx.x.x.....",
                    OH = "...x........x...",
                    BD = "....x......xx...",
                    SD = ".......x.x....x."
                }
            },
            {
                name = "Funk14",
                grid = {
                    AC = ".......x.x....x.",
                    CH = "x.x..xx.x.x.....",
                    OH = "...x........x...",
                    BD = "....x......xx...",
                    SD = ".......x.x....x."
                }
            },
            {
                name = "Funk15",
                grid = {
                    AC = "....x.......x...",
                    CH = "x.x.x...x.xxx...",
                    OH = "......x.......x.",
                    BD = "xx......x.x.x...",
                    SD = "...x.x.x.x...x.."
                }
            },
            {
                name = "FunkBreak1",
                grid = {
                    CH = "x..x............",
                    HT = "...........x....",
                    MT = "........x.......",
                    LT = "............x...",
                    BD = "x..x.......x....",
                    SD = ".xx.xxxx.xx..xxx"
                }
            },
            {
                name = "FunkBreak2",
                grid = {
                    CH = "x.x.............",
                    OH = "..............x.",
                    HT = "............xx.x",
                    MT = "........x.......",
                    BD = "x..x.......x....",
                    SD = "....x.xx........"
                }
            },
            {
                name = "FunkBreak3",
                grid = {
                    CH = "x.x.............",
                    OH = ".x.x............",
                    HT = "...........x....",
                    MT = "........xx......",
                    LT = ".............xx.",
                    BD = "xx.x....x.......",
                    SD = "....x.x........."
                }
            },
            {
                name = "FunkBreak4",
                grid = {
                    BD = "x.x..x.x...x....",
                    SD = "....f....xx.f..."
                }
            },
            {
                name = "FunkBreak5",
                grid = {
                    AC = ".x..x..x..x...xx",
                    MT = "...fx...........",
                    LT = ".........fx.....",
                    SD = "fx..........f.xx",
                    HT = "......fx........"
                }
            },
            {
                name = "FunkBreak6",
                grid = {
                    AC = "x....x.x..x...xx",
                    CH = "x...............",
                    BD = "x........x......",
                    SD = "....xx.x..f...xx"
                }
            },
            {
                name = "FunkBreak7",
                grid = {
                    AC = "..........x..xx.",
                    HT = ".............xx.",
                    BD = "x....x...x......",
                    SD = ".xxxx.xxx.f....."
                }
            },
            {
                name = "FunkBreak8",
                grid = {
                    AC = "...xx.......x...",
                    HT = ".........x......",
                    LT = "..........x.....",
                    BD = ".....x.....x....",
                    SD = "x..xx...x...f..."
                }
            },
            {
                name = "FunkBreak9",
                grid = {
                    AC = "...x...x.x...x..",
                    MT = "......xx........",
                    LT = "............xx..",
                    SD = "xxxx............",
                    HT = "........xx......"
                }
            },
            {
                name = "FunkBreak10",
                grid = {
                    AC = "...........x....",
                    CY = "............x...",
                    MT = "...f............",
                    LT = "......f.........",
                    BD = "............x...",
                    SD = "f.........xx...."
                }
            },
            {
                name = "FunkBreak11",
                grid = {
                    AC = "......x.xx.x.xx.",
                    HT = "........xx.x....",
                    MT = ".............x..",
                    LT = "..............x.",
                    BD = "x...x..xx.x.x...",
                    SD = "......x........."
                }
            },
            {
                name = "FunkBreak12",
                grid = {
                    CH = "x..x....x..x....",
                    MT = "............xx..",
                    LT = "..............xx",
                    BD = "x..x....x..x....",
                    SD = ".xx.xxxx.xx....."
                }
            },
            {
                name = "FunkBreak13",
                grid = {
                    CH = "x.x.x...........",
                    HT = "............xx..",
                    MT = "........xxx.....",
                    LT = "..............xx",
                    BD = "x..x.......x....",
                    SD = "....xxxx........"
                }
            },
            {
                name = "FunkBreak14",
                grid = {
                    CH = "x.x.x.x.x.x.....",
                    BD = "x..x.......x.x.x",
                    SD = "....x..x.x..f.f."
                }
            },
            {
                name = "FunkBreak15",
                grid = {
                    CH = "x.x.x.x.x.x.....",
                    BD = "x..x.......x....",
                    SD = "....x..x.x..x..f"
                }
            }
        }
    },
    {
        name = "Disco",
        sections = {
            {
                name = "Disco1",
                grid = {
                    OH = "....x.......x...",
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.x...x.x.x...x."
                }
            },
            {
                name = "Disco1",
                grid = {
                    OH = "....x.......x...",
                    BD = "x...x...x...x...",
                    CPS = "..x...x...x.x...",
                    CH = "x.xx..xxxxxx..xx"
                }
            },
            {
                name = "Disco2",
                grid = {
                    OH = "....x.......x...",
                    BD = "x...x...x...x...",
                    CPS = "..x...x...x.x...",
                    CH = "x.xx..xxxxxx..xx"
                }
            },
            {
                name = "Disco3",
                grid = {
                    OH = "..x.......x.....",
                    BD = "x...x..xx...x...",
                    CPS = "..x.x.......x.x.",
                    CH = "xx..xxxxxx..xxxx"
                }
            },
            {
                name = "Disco4",
                grid = {
                    CPS = "....x.......x...",
                    TB = "x.xxx.xxx.xxx.xx",
                    BD = "x...x...x...x...",
                    SD = "x...x...x.x.x...",
                    CH = ".xxx.xxx.x.x.xxx"
                }
            },
            {
                name = "Disco5",
                grid = {
                    OH = "..........x...x.",
                    CPS = "....x.....x.x...",
                    BD = "x...x...x...x...",
                    SD = "....x...........",
                    CH = "xxxx.xxxx...x..."
                }
            },
            {
                name = "Disco6",
                grid = {
                    OH = "..........x...x.",
                    TB = "x.x.x.x.x.x.x.x.",
                    BD = "x...x.x.x...x...",
                    SD = "xxx.x...........",
                    CH = "....x...x...x..."
                }
            },
            {
                name = "Disco7",
                grid = {
                    CPS = "....x...x...xx..",
                    CH = ".xxx.xxx...x.xxx",
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CB = "x...x...xxx.x..."
                }
            },
            {
                name = "Disco8",
                grid = {
                    OH = "...x...x.......x",
                    CPS = "x.x.x.......x...",
                    BD = "x...x...x...x...",
                    SD = "....x......xx...",
                    CH = "xxx..xx.xxx..xx."
                }
            },
            {
                name = "Disco9",
                grid = {
                    CPS = "..x.x...x.x.x.x.",
                    CH = "..xx..x...xx..x.",
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CB = "x...x...x...x..."
                }
            },
            {
                name = "Disco10",
                grid = {
                    OH = "............x...",
                    CPS = "..x.x.....x.x...",
                    BD = "x...x...x...x...",
                    SD = "....x...........",
                    CH = "xxxx.xx.x.x....."
                }
            },
            {
                name = "Disco11",
                grid = {
                    OH = ".x.......x......",
                    CPS = ".x..x.......x...",
                    BD = "x...x..xx...x..x",
                    SD = "....x.......x...",
                    CH = "x.x.....x.x....."
                }
            },
            {
                name = "Disco12",
                grid = {
                    BD = "x.x.x...x...xx..",
                    TB = "x.xxx.xxx.xxx.xx",
                    SD = "....x..x..x.x..x",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "DiscoBreak1",
                grid = {
                    OH = "......x...x.....",
                    CPS = "..x.x.....x.x...",
                    BD = "x..xx...x..xx...",
                    SD = "......x.........",
                    CH = "........x...x..."
                }
            },
            {
                name = "DiscoBreak2",
                grid = {
                    OH = "......x.........",
                    MT = "..............xx",
                    LT = "............xx..",
                    BD = "........x.x.....",
                    SD = ".........x.x....",
                    CH = "..x.x..........."
                }
            },
            {
                name = "DiscoBreak3",
                grid = {
                    TB = "..x.x...........",
                    HT = "..........x.....",
                    MT = "..x.............",
                    BD = "....x.......x...",
                    SD = "xx......xx......"
                }
            },
            {
                name = "DiscoBreak4",
                grid = {
                    SD = "..x.....xxxx....",
                    HT = "....x.x.........",
                    MT = "............xxxx"
                }
            },
            {
                name = "DiscoBreak5",
                grid = {
                    OH = "x...............",
                    MT = "...........xx...",
                    LT = ".............xxx",
                    BD = "....x...........",
                    SD = "........xxx....."
                }
            },
            {
                name = "DiscoBreak6",
                grid = {
                    SD = "x.x.x.x.x.x.x.x.",
                    CH = ".x.x.x.x.x.x.x.x"
                }
            },
            {
                name = "DiscoBreak7",
                grid = {
                    TB = "x.xxx.xxx.xxx.xx",
                    HT = "........x.......",
                    MT = "..x...........x.",
                    BD = "....x.....x.....",
                    SD = "x.....x.....x..."
                }
            },
            {
                name = "DiscoBreak8",
                grid = {
                    SD = "xx.xxx.xxx.xxx.x",
                    CH = "..x...x...x...x."
                }
            },
            {
                name = "DiscoBreak9",
                grid = {
                    MT = "............xx..",
                    LT = "........xx......",
                    BD = "..x.x...........",
                    SD = "..x.......xx....",
                    CH = "....x.........x."
                }
            }
        }
    },
    {
        name = "Bossa",
        sections = {
            {
                name = "Bossa1",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.....x.x.....x.",
                    RS = "x.....x.....x...",
                    CY = "x.x.x.x.x.x.x.x.",
                    MT = "..x.....x.....x."
                }
            },
            {
                name = "Bossa2",
                grid = {
                    AC = "....x.......x...",
                    RS = "..x.x...x.x...x.",
                    BD = "x.....x.x.....x.",
                    CH = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "Bossa3",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "x.x...x...x...x.",
                    CY = "..x...x...x...x.",
                    CH = "....x.......x..."
                }
            },
            {
                name = "Bossa4",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "x.x...x...x...x.",
                    CY = "..x...x...x...x.",
                    CH = "....x.......x..."
                }
            },
            {
                name = "Bossa5",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "x.x...x.x.......",
                    CY = "x...x...x...x...",
                    CH = "....x.......x..."
                }
            },
            {
                name = "Bossa6",
                grid = {
                    AC = "....x.......x...",
                    BD = "x.....x.x.....x.",
                    MT = "......x.........",
                    LT = "............x...",
                    RS = "....x.....x.....",
                    CY = "x.x.x.x.x.x.x.x."
                }
            },
            {
                name = "BossaBreak1",
                grid = {
                    AC = "..x........x....",
                    CH = "...........x....",
                    LT = "..x...x.x.......",
                    SD = "x.x...x.x..x....",
                    MT = "x..............."
                }
            },
            {
                name = "BossaBreak2",
                grid = {
                    AC = "x...x...x...x...",
                    BD = "x....x.x......x.",
                    SD = "x...x.......x...",
                    LT = "........x.......",
                    HT = "......x.........",
                    MT = "..x...........x."
                }
            },
            {
                name = "BossaBreak3",
                grid = {
                    AC = "............x...",
                    SD = "f...........f...",
                    CH = "............x...",
                    LT = "......f.........",
                    HT = "..f.............",
                    MT = "..........f....."
                }
            }
        }
    },
    {
        name = "Boogie",
        sections = {
            {
                name = "Boogie1",
                grid = {
                    CY = "x...x...x...x...",
                    BD = "x..x...xx..x...x",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Boogie2",
                grid = {
                    CY = "x..xx..xx..xx..x",
                    BD = "x.......x..x....",
                    SD = "....x.......x..."
                }
            },
            {
                name = "Boogie3",
                grid = {
                    CY = "x..xx..xx..xx..x",
                    BD = "x..x....x..x....",
                    SD = "....x..x....x..x"
                }
            },
            {
                name = "BoogieBreak1",
                grid = {
                    MT = "....xx......",
                    LT = "..........xx",
                    BD = "x..x..x..x..",
                    SD = ".xx....xx...",
                    CY = "x..x..x..x.."
                }
            },
            {
                name = "BoogieBreak2",
                grid = {
                    MT = "...xxx......",
                    LT = ".........xxx",
                    SD = "xxx...xxx..."
                }
            },
            {
                name = "BoogieBreak3",
                grid = {
                    MT = "...x.....x..",
                    LT = "x.....x.....",
                    SD = ".xx.xx.xx.xx"
                }
            }
        }
    },
    {
        name = "Blues",
        sections = {
            {
                name = "Blues1",
                grid = {
                    BD = "x.x..xx.x.x.",
                    SD = "...x.....x.x",
                    CH = "x.xx.xx.xxxx"
                }
            },
            {
                name = "Blues2",
                grid = {
                    BD = "x.x...x.x..x",
                    SD = "...x.x...x..",
                    CH = "xxxxxxxxxxxx"
                }
            },
            {
                name = "Blues3",
                grid = {
                    AC = ".x..x..x..x.",
                    OH = "..........x.",
                    BD = "x.x..xx.x.x.",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxx.x"
                }
            },
            {
                name = "Blues4",
                grid = {
                    BD = "x.x..xx.x.xx",
                    SD = "...x.....x..",
                    CH = "x..x..x..x.x",
                    OH = "..........x.",
                    CY = "x.xx.xx.xx.."
                }
            },
            {
                name = "Blues5",
                grid = {
                    CY = "x..x.xx..x.x",
                    CH = "...x........"
                }
            },
            {
                name = "Blues6",
                grid = {
                    SD = "...x.....x..",
                    BD = "..........xx",
                    CY = "x.xx.xx.xxxx",
                    CH = "...x.....x.."
                }
            },
            {
                name = "BluesBreak1",
                grid = {
                    AC = "...x.x.x.x..",
                    LT = ".......f....",
                    BD = "x...x.x.x.xx",
                    SD = "...f.....f..",
                    CY = "x...........",
                    MT = ".....f......"
                }
            },
            {
                name = "BluesBreak2",
                grid = {
                    AC = "...x.....x..",
                    SD = ".xxx...x.f..",
                    BD = "x...xxx.x.xx",
                    CY = "...........x",
                    CH = "x.....x.x..."
                }
            },
            {
                name = "BluesBreak3",
                grid = {
                    AC = "...x..x..x..",
                    SD = ".xxxxxxxxf..",
                    BD = "x.........xx",
                    CY = "x...........",
                    CH = "...x..x....."
                }
            }
        }
    },
    {
        name = "Afro Cuban",
        sections = {
            {
                name = "AfroCub1",
                grid = {
                    RS = "...x..x.....x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    BD = "x.......x.x...x."
                }
            },
            {
                name = "AfroCub2",
                grid = {
                    BD = "x.......x.....x.",
                    CH = "x.xxx.x.x.x.x.x.",
                    RS = "...x........x...",
                    HT = "......x.........",
                    MT = "..........x.....",
                    LT = "..............x."
                }
            },
            {
                name = "AfroCub3",
                grid = {
                    BD = "x.......x.......",
                    CH = "x.x.x.x.x.x.x.x.",
                    RS = "......x.........",
                    LT = "..............x.",
                    MT = "..........x.....",
                    CY = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "AfroCub4",
                grid = {
                    RS = "...x..x...x...x.",
                    BD = "x.......x.......",
                    CH = "x.x.x.x.x.x.x.x.",
                    CY = "x.xxx.x.x.x.x.x."
                }
            },
            {
                name = "AfroCub5",
                signature = "4/4",
                grid = {
                    AC = "x.......x.x.xxxx",
                    BD = "x...x...x...x...",
                    SD = "..xx.xx.........",
                    CH = "..x...x...x...x.",
                    MT = "x.......x.x.....",
                    LT = "............xxxx"
                }
            },
            {
                name = "AfroCub6",
                grid = {
                    RS = "x.xx.x.xx.x.xx.x",
                    BD = "x...x...x...x...",
                    CH = "..x...x...x...x.",
                    CB = "x.xx.x.xx.x.xx.x"
                }
            },
            {
                name = "AfroCub7",
                grid = {
                    BD = "x.......x.x...x.",
                    CH = "x.x.x.x.x.x.x.x.",
                    RS = "....x...........",
                    LT = "..............x.",
                    MT = "........x.x.....",
                    CY = "x.xxx.x.x.xxx.x."
                }
            },
            {
                name = "AfroCub8",
                signature = "4/4",
                grid = {
                    AC = "x.........x...x.",
                    BD = "x...x...x...x...",
                    SD = "..xx.xx.........",
                    CH = "..x...x...x...x.",
                    HT = "........xxx.....",
                    MT = "x...........xxx."
                }
            },
            {
                name = "AfroCub9",
                signature = "4/4",
                grid = {
                    AC = "...x...x...x...x",
                    CB = "x...x...x...x...",
                    SD = ".xx..xx..xx..xx.",
                    CH = "..x...x...x...x.",
                    BD = "x...x...x...x...",
                    HT = ".......x........",
                    MT = "...x.......x....",
                    LT = "...............x"
                }
            },
            {
                name = "AfroCubBreak1",
                grid = {
                    CB = "x.xxx.x.........",
                    SD = "...x..x.f.......",
                    BD = "x...............",
                    HT = "............f...",
                    MT = "..........x.....",
                    LT = "..............x."
                }
            },
            {
                name = "AfroCubBreak2",
                grid = {
                    AC = "....x...x...x...",
                    BD = "x...............",
                    SD = "..x.x..x..x.x..x",
                    CY = "x...............",
                    MT = "...x.......x....",
                    LT = "......x.x.....x."
                }
            },
            {
                name = "AfroCubBreak3",
                grid = {
                    AC = "x..xx.x...x.x...",
                    SD = "xx.xx...........",
                    HT = ".........xx.....",
                    MT = "......xx........",
                    LT = "............xx.x"
                }
            },
            {
                name = "AfroCubBreak4",
                grid = {
                    CB = "x.xx......xx....",
                    HT = "............x.xx",
                    MT = "....xx.x........",
                    LT = "........x......."
                }
            },
            {
                name = "AfroCubBreak5",
                grid = {
                    CB = "........x.x.x.x.",
                    SD = "f.xx............",
                    CH = "x...x...x...x...",
                    MT = "....f.xx........"
                }
            },
            {
                name = "AfroCubBreak6",
                grid = {
                    SD = "........xx.x....",
                    HT = "....x.x.........",
                    MT = "xx.x............",
                    LT = "............x.xx"
                }
            }
        }
    }
}

function validatePatterns()
    for i = 1, #patterns do
        local p = patterns[i]

        for j = 1, #p.sections do
            local part = p.sections[j]

            for k, v in pairs(part.grid) do
                if string.len(v) ~= 16 and string.len(v) ~= 12 then
                    -- print(p.name, part.name, k, string.len(v))
                end
            end
        end
    end
end

--validatePatterns()
local lib = {}
lib.patterns = patterns

local function clear()
    for x = 1, #drumgrid do
        for y = 1, #drumgrid[1] do
            drumgrid[x][y] = { on = false }
        end
    end

    local totalSections = 0
    for i = 1, #patterns do
        --   print(patterns[i].name)
        totalSections = totalSections + #patterns[i].sections
    end
end

local function fill(pattern, part)
    local hasEveryThingNeeded = true
    for k, v in pairs(part.grid) do
        if not drumkit[k] then
            print("failed looking for", k, "in drumkt")
            hasEveryThingNeeded = false
        end
    end

    if (hasEveryThingNeeded) then
        local gridLength = 0
        for k, v in pairs(part.grid) do
            -- find the correct row in the grid.
            local index = -1
            for i = 1, #drumkit.order do
                if drumkit.order[i] == k then
                    index = i
                end
            end

            if string.len(v) ~= #drumgrid then
                print("failed: issue with length of drumgrid", string.len(v), #drumgrid, pattern.name)
            end
            gridLength = string.len(v)
            if index == -1 then
                print("failed: I could find the correct key but something wrong with order: ", k)
            end

            for i = 1, string.len(v) do
                local c = v:sub(i, i)
                if (c == "x") then
                    drumgrid[i][index] = { on = true }
                elseif (c == "f") then
                    drumgrid[i][index] = { on = true, flam = true }
                else
                    drumgrid[i][index] = { on = false }
                end
            end
        end

        return pattern.name .. " : " .. part.name, gridLength
    end
end

function lib.pickPatternByIndex(index1, index2)
    -- clear it
    clear()
    local patternIndex = index1 --math.ceil(love.math.random() * #patterns)
    local pattern = patterns[patternIndex]

    local partIndex = index2

    local part = patterns[patternIndex].sections[partIndex]

    return fill(pattern, part)
end

function lib.pickExistingPattern(drumgrid, drumkit)
    -- clear it
    clear()
    -- print(#patterns, totalSections)

    local index = -1
    --  print('**')
    for i = 1, #patterns do
        --   print(patterns[i].name)
        --if patterns[i].name == 'Rock' then
        if patterns[i].name == "Funk and Soul" then
            -- if patterns[i].name == 'Standard Breaks' then
            --if patterns[i].name == 'ChaCha' then
            --if patterns[i].name == 'Funk and Soul' then
            --if patterns[i].name == 'Electro' then
            --if patterns[i].name == 'Drum and Bass' then
            --if patterns[i].name == 'House' then
            --if patterns[i].name == 'Miami Bass' then
            --if patterns[i].name == 'Slow' then
            --if patterns[i].name == 'Basic Patterns' then
            -- if patterns[i].name == 'Ballad 1' then
            --if patterns[i].name == 'Pop' then
            --if patterns[i].name == 'Disco' then
            --if patterns[i].name == 'EDM' then
            --if patterns[i].name == 'Afro-Cuban' then
            --if patterns[i].name == 'Hip Hop' then
            index = i
        end
    end
    local patternIndex = index --math.ceil(love.math.random() * #patterns)
    local pattern = patterns[patternIndex]

    local partIndex = math.ceil(love.math.random() * #pattern.sections)

    local part = patterns[patternIndex].sections[partIndex]
    drummPatternPickData.pickedCategoryIndex = patternIndex
    drummPatternPickData.pickedItemIndex = partIndex

    return fill(pattern, part)
end

--transformData()

return lib
