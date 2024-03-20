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


local patterns = {
    {
        name = "Rock 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x.....x.x.......",
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                    AC = "....x.......x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.x...x.",
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "..x...x...x.xxxx",
                    HT = "...xx..xx..x....",
                    CH = "x...............",
                    AC = "x...........x..x",
                }
            },
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
                    AC = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x......x",
                    SD = "....x.......x.x.",
                    OH = ".......x.......x",
                    CH = "xxxxxxx.xxxxxxx.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..x.x.x.x.",
                    LT = "........xxxx....",
                    SD = "xxxx............",
                    MT = "....xxxx........",
                    CY = "............x.x.",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "..x...x.....x...",
                    OH = "..x...x...x...x.",
                    CH = "x...x...x...x...",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "....x.......x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "xxxxxxxxxxxxxxxx",
                    AC = "x..xx..xx..xx..x",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.......",
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "....x..x..x.x...",
                    CH = "x...............",
                    AC = ".......x..x.x...",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x.......x...",
                    OH = "..............x.",
                    CH = "x.x.x.x.x.x.x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..x...",
                    SD = ".xx.xx.xx.xx..xx",
                    CH = "x..x..x..x..x...",
                    AC = "x..x........x.xx",
                }
            },
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
                    CH = "x.x.xxx......x..",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x.......",
                    SD = "...........x....",
                    CH = "x.xxx.xxx.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x.x....x..",
                    SD = "...x......xxx...",
                    CH = "x...x.x.x....x..",
                    AC = ".............x..",
                }
            },
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
                    AC = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..x..x.......",
                    CH = "xxxxxxxxxxxxxxxx",
                    AC = "x...x...x...x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x......x........",
                    SD = ".xxxxxx..xxxx.x.",
                    CH = "x......x......x.",
                    AC = "...x........x.x.",
                }
            },
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
                    CH = "x.x.xxxx..x.xxx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.......",
                    SD = "....x......x....",
                    CH = "x.x.xxx.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".............x..",
                    SD = "xxxx....xxxxxx..",
                    HT = "....xxxx........",
                }
            },
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
                    AC = ".....x......x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x..x....",
                    SD = "....x..x....x...",
                    CH = "x.x.xxx.x.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..........",
                    SD = "....x.......xxxx",
                    HT = "........xxxx....",
                    CH = "x.x..x..........",
                }
            },
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
                    AC = ".....x......x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x..x....",
                    SD = "....x..x....x...",
                    CH = "x.x.xxx.x.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x..x..........",
                    SD = "....x.......xxxx",
                    HT = "........xxxx....",
                    CH = "x.x..x..........",
                }
            },
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
                    AC = "....xx......xx..",
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
                    AC = "....xx......xx..",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........xx....",
                    SD = "....x........xx.",
                    MT = "......xxx.......",
                }
            },
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
                    CH = "xxx..xx.xxx..xx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x...........",
                    MT = "............x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".x..x.x.........",
                    SD = "x..x.....x.xxxxx",
                    CH = "....x.x.........",
                    AC = "......x........x",
                }
            },
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
                    OH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x....x.xx....",
                    SD = "......x.......xx",
                    OH = "x...x...x...x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "...........xx.x.",
                    SD = "x.x.x..xx.......",
                    MT = ".....x...x......",
                    CH = "............x.x.",
                    AC = ".....x...x..x.x.",
                }
            },
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
                    CH = "....xxx.xxx.xxxx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx.x.x.x.x.x..",
                    SD = "....x.......x...",
                    OH = ".....x.x.x.x....",
                    CH = "x.xxx........x..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x.x...x.x....",
                    SD = ".xx.x..x....x...",
                    CH = "............x...",
                    AC = "....x.......x...",
                }
            },
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
                    CH = "xxxx.xxxxxxx.xxx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x..x..x.......",
                    SD = "....x.......x...",
                    CH = "xxxx.xxxxxxx.xxx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".....x....x.....",
                    SD = "xx.xx..xx...xxxx",
                    CH = ".....x....x.....",
                    AC = ".x...x....x.....",
                }
            },
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
                    AC = "............x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx....x.x..x....",
                    SD = "....x.......x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    AC = "............x...",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "x......x....x...",
                    SD = "..xxx...xxx...xx",
                    HT = ".....xx....x....",
                    AC = "...x...x...x...x",
                }
            },
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
                    CH = "xxx..xx.x.x..xx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x...x...x....",
                    SD = "....x.......x...",
                    OH = "...x...x...x...x",
                    CH = "xxx..xx.xxx..xx.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "............xxxx",
                    SD = ".x.xxxxx........",
                    MT = "........xxxx....",
                    OH = "x.x.............",
                }
            },
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
                    CH = "xxx.xx..xxx.xx..",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x..x....x....",
                    SD = "............x.xx",
                    OH = "......x.......x.",
                    CH = "xxx.xx..xxx.xx..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    SD = "...xx....x.xx...",
                    MT = ".....xx......x.x",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x....xx......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = ".....x.......x..",
                    SD = "x..xx...x.x.xx..",
                    CH = ".............x..",
                    AC = ".............x..",
                }
            },
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
                    CH = "x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.....",
                    SD = "........x..x",
                    CH = "x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.........x.",
                    SD = "..x.x.x.xx..",
                    CH = "x.........x.",
                    AC = "..........x.",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.xx....",
                    SD = "....x..x.x..x..x",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.....x.....",
                    SD = "xx.x.xxx.x.xxxxx",
                    MT = "..x.....x.......",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "...x.xx..x.x.xx.",
                    SD = "x...x...x...x...",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..xx..xx..xx....",
                    LT = "........xx......",
                    SD = "xx..........xxxx",
                    MT = "....xx..........",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx....x..x....",
                    SD = "....x.xx....x...",
                    CH = "x.xxx.xxx.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x...x.......x",
                    LT = ".....x..........",
                    SD = "..x.....x.xx..x.",
                    HT = "............xx..",
                    CH = "x..xx..x........",
                }
            },
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
                    CH = "xxxxxxxxxxxxxxxx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.......x..x",
                    OH = "..x...x...x...x.",
                    CH = "xx.xxx.xxx.xxx.x",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x.....x......",
                    SD = ".xx.x.....x.....",
                    MT = "......xxx...x.xx",
                    CH = "...x......x.....",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx...xx.xx.x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x...x...x....",
                    LT = "........xxx.....",
                    SD = ".xx.........x...",
                    MT = "....xxx.........",
                    CH = "............x...",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x......xx.......",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
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
                    AC = "...............x",
                }
            },
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
                    CH = "x.x.x.x.x.x.xx..",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....xx.x..x..",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
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
                    AC = "....x.......x...",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx....xx........",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...xx..xx..xx..",
                    LT = "..........xx....",
                    SD = "..xx..........xx",
                    HT = "......xx........",
                }
            },
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
                    AC = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.......x...",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "x...x...x...x...",
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
                    AC = ".....x.......x..",
                }
            },
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
                    CH = "xxxxxxx.xxxxxxx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "xx.....x..x..x..",
                    SD = "....x.......x...",
                    CH = "xxxxxxxxxxxxxxxx",
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
                    CH = "xxxxxxx.........",
                }
            },
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
                    AC = "....x.......x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.....x.....",
                    CH = "x.x.x.x.x.x.x.x.",
                    AC = "....x...........",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...............",
                    LT = "..x.x.x.x.......",
                    SD = "..x.x.x.x.xxx...",
                    CH = "x...............",
                    AC = "............x...",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.....x...",
                    SD = "...x......x..x..",
                    CH = "x...x...x...x...",
                    AC = ".............x..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x...x.....",
                    SD = "..xx........xxxx",
                    MT = "........xx......",
                    AC = "...x.....x......",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.xx.x..x.xx.x..",
                    SD = "....x.......x...",
                    CH = "x...x...x...x...",
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
                    AC = "...........x....",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x.....x.xx....",
                    SD = "....x..x....x...",
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.........x.....",
                    SD = "....x.x.x...x.xx",
                    CH = "x...............",
                    AC = "x...........x..x",
                }
            },
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
                    CH = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x......x..",
                    SD = "...x......x.x...",
                    CH = "x...x...x...xx..",
                    AC = ".............x..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = ".xxxx.xxxxx.xxxx",
                    OH = "x...x...x...x...",
                }
            },
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
                    CH = "xxxxxxxxxxxxxxxx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "....x.......x...",
                    RS = "..xx..x...xx..x.",
                    CH = "xxxxxxxxxxxxxxxx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "..............x.",
                    SD = "..x.x.x.....xx..",
                    MT = "........x.x.....",
                    CH = "..............x.",
                    AC = "..............x.",
                }
            },
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
                    CH = "..xx..xx..xx....",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "....x.......x...",
                    RS = "....x.......x...",
                    OH = "..............x.",
                    CH = "..xx..xx..xx....",
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
                    AC = "....x...x...x...",
                }
            },
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
                    CH = "x.xxxxx...x...x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "........x.......",
                    CH = "x.xx.xx...x...x.",
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
                    AC = "..............x.",
                }
            },
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
                    CH = "x.x...x.x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "..x...x.....",
                    RS = "x.....x.....",
                    OH = "...x.....x..",
                    CH = "x.x...x.x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "...x.....x..",
                    SD = "xxx.........",
                    MT = "......xxx...",
                    CH = "...x.....x..",
                }
            },
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
                    CH = "x.xxx.xxx.xxx.xx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    RS = "....x.......x..x",
                    OH = "..xx..xx..xx..xx",
                    CH = "xx..xx..xx..xx..",
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
                    AC = "..............x.",
                }
            },
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
                    AC = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x......xx...",
                    OH = "..x...x..x....x.",
                    CH = "xx.xxx.xx.xxxx.x",
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
                    AC = "....x...x...x...",
                }
            },
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
                    CH = "..x...x...x...x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    CB = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.xx..xx..xx..xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "...xx.x.x.x.xxx.",
                    CH = "xxx.............",
                }
            },
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
                    CH = "..xx..xx..xx..xx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    CH = "x.xxx.xxx.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    CB = "............x.xx",
                    SD = "....x.xx.xx.....",
                    MT = "........x..x....",
                    CH = "xxxx............",
                }
            },
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
                    CH = "xxx..xx.xxx..xx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x..xx...",
                    SD = "....x......xx...",
                    OH = "...x...x.......x",
                    CH = "xxx..xx.xxx..xx.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "...xx..xx..xx..x",
                    OH = "..x...x...x...x.",
                    CH = "xx...x...x...x..",
                }
            },
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
                    CH = "xx...x.xxx...x.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "...x...........x",
                    CH = "xxx..xxxxxxx.xx.",
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
                    CH = "xx..............",
                }
            },
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
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x...x.",
                    RS = "......x.....x...",
                    CH = "x.xxx.x.x.x.x.x.",
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
                    AC = "....x.......x..x",
                }
            },
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
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.....x.",
                    RS = "......x.........",
                    MT = "..........x.x...",
                    CH = "x.xxx.x.x.x.x.x.",
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
                    AC = "............xx..",
                }
            },
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
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    LT = "............x.x.",
                    SD = "...x............",
                    MT = "......x...x.....",
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...x.x...x.x...",
                    SD = ".x...x.x...x.x..",
                    MT = "..xx....xx....xx",
                    CH = "x...x.x...x.x...",
                    AC = "x...x...x...x...",
                }
            },
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
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.......",
                    LT = "..............x.",
                    RS = "......x.........",
                    MT = "..........x.....",
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "........x.x.....",
                    SD = "x..x........x...",
                    HT = "....x.x.........",
                    CH = "............x...",
                    AC = "............x...",
                }
            },
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
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "....x.....x.....",
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..............x.",
                    SD = "x.x...x.........",
                    MT = "..........x.....",
                }
            },
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
                    CH = "xxxxxxxxxxxx",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x.x.",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxxxx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "xxxxxxxxx...",
                    SD = "xxxxxxxxxxxx",
                    CH = "xxxxxxxxx...",
                }
            },
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
                    CH = "x.xx.xx.xx.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x..x",
                    SD = "...x.....x..",
                    CH = "xxxxxxxxxxxx",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..",
                    SD = ".xx.xx.xx.xx",
                    CH = "x..x..x..x..",
                }
            },
        }
    },
    {
        name = "Swing 1",
        sections = {
            {
                name = "Measure A",
                grid = {
                    BD = "x..x..x..x..",
                    CH = "x..x..x..x..",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x..x..x..",
                    SD = "...x.....x..",
                    CH = "x..x..x..x..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x........",
                    SD = "......xxxxxx",
                    CH = "x..x........",
                }
            },
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
                    CH = "x..x.xx..x.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..x.xx..x..",
                    SD = "...x.....x..",
                    CH = "x..x.xx..x.x",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "xxx.xxx.x...",
                    SD = "...x...x.xx.",
                    CH = "..........x.",
                }
            },
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
                    CY = "x..x..x..x.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x..xx.x..x",
                    SD = "...x.....x..",
                    CY = "x..x..x..x..",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x..x..x..",
                    SD = ".xx....xx...",
                    MT = "....xx....xx",
                    OH = "x..x..x..x..",
                }
            },
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
                    CH = "x.xx.xx.xx.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x....xx.x...",
                    SD = "...x.....x..",
                    CH = "x.xx.xx.xx.x",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x...xx.xx.xx",
                    SD = "...x..x..x..",
                    CH = "x...........",
                }
            },
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
                    CH = "x.xx.xx.xx.x",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.x...x.x...",
                    SD = "...x.x...x..",
                    CH = "x.xx.xx.xx.x",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x..x....x..x",
                    SD = ".xx.xxxx.xx.",
                    CH = "x..x........",
                }
            },
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
                    CH = ".xx..xx..xx..xx.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    CB = "x.x.xx.x.xx.xx.x",
                    MT = "...........x....",
                    CH = ".x.x..x.x.....x.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........xxx...",
                    SD = "x.xxx.........x.",
                    MT = "......xxx.......",
                    CH = "..............x.",
                    AC = "..............x.",
                }
            },
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
                    CH = "x.xxx.xxx.xxx.xx",
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
                    CH = "x.xxx.xxx.xxx.xx",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.....x.....",
                    SD = ".xx....xx....xx.",
                    MT = "x..x..x..x..x..x",
                }
            },
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
                    AC = "x...x...x...x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x..xx..xx..xx..x",
                    SD = "x.x.xx.x.xx.xx.x",
                    CH = ".x.x..x.x..x..x.",
                    AC = ".......x...x....",
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
                    CH = "xx....xx..x.x...",
                }
            },
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
                    CH = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "....x.....x.....",
                    CH = "x.x.x.x.x.x.x.x.",
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
                    CY = "....x...........",
                }
            },
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
                    CY = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    RS = "..xx..xx..xx..xx",
                    CH = "....x.......x...",
                    CY = "x.x.x.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "..........x.x...",
                    MT = "..x...x.........",
                    AC = "............x...",
                }
            },
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
                    CH = "....x.......x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    CB = "x...x...x...x...",
                    LT = "......xx......x.",
                    HT = "..xx......xx....",
                    CH = "....x.......x...",
                }
            },
            {
                name = "Break",
                grid = {
                    LT = "....x.x.........",
                    SD = "............x...",
                    HT = "..x.....x.......",
                    CH = "............x...",
                    AC = "............x...",
                }
            },
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
                    AC = "......x.....x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.....x.x.....x.",
                    SD = "....x.x.....x...",
                    CH = "x.xxx.x.x.x.x.x.",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.x.....x.x.....",
                    SD = "............xxxx",
                    MT = "....x.x.........",
                    CH = "x...x...x...x...",
                }
            },
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
                    AC = "......x.....x...",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x.......x.x.....",
                    SD = "....x.x.....x...",
                    CH = "x.xxx.x.x.x.x.x.",
                    AC = "......x.....x...",
                }
            },
            {
                name = "Break",
                grid = {
                    BD = "x.......x.......",
                    SD = "....x.x.....xxxx",
                    MT = "........x.x.....",
                }
            },
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
                    AC = "..x...x...x...x.",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...x...x...x...",
                    SD = "....x.......x...",
                    OH = "..............x.",
                    CH = "x.x.x.x.x.x.x...",
                    AC = "..x...x...x.....",
                }
            },
            {
                name = "Break",
                grid = {
                    SD = "x.xx....x.x.x...",
                    MT = "....x.x.........",
                    CH = "............x...",
                    AC = "............x...",
                }
            },
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
                    AC = "x...............",
                }
            },
            {
                name = "Measure B",
                grid = {
                    BD = "x...............",
                    CH = "x...............",
                    AC = "x...............",
                }
            },
        }
    },

}
function validatePatterns()
    for i = 1, #patterns do
        local p = patterns[i]
        --print(p.name)
        for j = 1, #p.sections do
            local part = p.sections[j]
            -- print(part)
            for k, v in pairs(part.grid) do
                if string.len(v) ~= 16 and string.len(v) ~= 12 then
                    print(p.name, part.name, k, string.len(v))
                end
            end
        end
    end
end

validatePatterns()
local lib = {}

function lib.pickExistingPattern(drumgrid, drumkit)
    -- clear it
    for x = 1, #drumgrid do
        for y = 1, #drumgrid[1] do
            drumgrid[x][y] = { on = false }
        end
    end

    local patternIndex = math.ceil(love.math.random() * #patterns)
    local pattern = patterns[patternIndex]

    local partIndex = math.ceil(love.math.random() * #pattern.sections)

    local part = patterns[patternIndex].sections[partIndex]
    --print(patternIndex, partIndex, part.grid)
    -- now we verify that the drumkit has all the keys in the pattern too.
    local hasEveryThingNeeded = true
    for k, v in pairs(part.grid) do
        if not drumkit[k] then
            print('failed looking for', k, 'in drumkt')
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
                print('failed: issue with length of drumgrid', string.len(v), #drumgrid, pattern.name)
            end
            gridLength = string.len(v)
            if index == -1 then
                print('failed: I could find the correct key but something wrong with order: ', k)
            end

            for i = 1, string.len(v) do
                local c = v:sub(i, i)
                if (c == 'x') then
                    drumgrid[i][index] = { on = true }
                else
                    drumgrid[i][index] = { on = false }
                end
            end
            --print(k, drumkit.order, index)
        end

        --if (gridLength < #drumgrid[1]) then
        --for i = 1, drumgrid[1]
        --end


        return pattern.name .. ' : ' .. part.name, gridLength
    end
end

function toDotsAndX(array)
    local result = ''
    for i = 1, #array do
        if array[i] == 1 then
            result = result .. 'x'
        else
            result = result .. '.'
        end
    end
    return result
end

function transformData()
    local mapping = {
        ["Bass Drum"] = "BD",
        ["Bass drum"] = "BD",
        ["Snare Drum"] = "SD",
        ["Closed hi-hat"] = "CH",
        ["Open hi-hat"] = "OH",
        ["Rim shot"] = "RS",
        ["High tom"] = "HT",
        ["Medium tom"] = "MT",
        ["Low tom"] = "LT",
        ["Accent"] = "AC",
        ["Cymbal"] = "CY",
        ["Cowbell"] = "CB",
    }
    local js = json.decode(data)

    print("{")
    for x = 61, 67 do
        local thing = js[x]

        print('{ name= "' .. thing.title .. '",')
        --print(inspect(thing.sections))
        print('sections = {')
        for i = 1, #thing.sections do
            print("{")
            print('name="' .. thing.sections[i].name .. '",')
            --print(' ')
            --print(inspect(thing.sections[i]))
            local parts = thing.sections[i].parts
            print("grid={")
            for j = 1, #parts do
                --if (mapping[parts[j].type] == nil) then
                --print(parts[j].type)
                print(mapping[parts[j].type] .. '=' .. '"' .. toDotsAndX(parts[j].beats) .. '",')
                --end
            end
            print("}},")
        end
        print("} },")
    end
    print("}")
end

--transformData()

return lib
