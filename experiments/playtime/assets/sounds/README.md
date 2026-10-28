# Sounds

| Folder / files | Source | License / note |
|---|---|---|
| `rubber-plonk1-3.ogg`, `winegum-kiss1-5.ogg` | puppet-maker2 `assets/sounds/fx` | own recordings (Mipo Puppetmaker) |
| `casio-mt70/` | melody-paint `instruments/casiomt70`, originally Legowelt (http://legowelt.org/samples/) | free sample pack, check terms before shipping |
| `korg-minipops/` | melody-paint `instruments/Korg_Minipops` | source unknown, find out before shipping |
| `cr78/` (conga-low, bongo-low/high, tamb1, guiro1) | puppet-maker2 `instruments/cr78`, originally Boxed Ear's free Roland CR-78 pack | free sample pack, check terms before shipping |
| `triangles/`, `babirhodes/`, `mp7-quijada.ogg` | puppet-maker2 `instruments/` (the band in `mipo4.melodypaint.txt`) | source unknown, find out before shipping |
| `bd-perc.ogg` | puppet-maker2 `sounds/fx/BD-perc.wav` (UI scroll tick), Elka Solist 505 pack (bleepbit.com) | free sample pack, check terms |
| `rubber-stretch1-2.ogg` | puppet-maker2 `assets/sounds/fx` (loaded there, never played) | own recordings |

All converted from wav with `ffmpeg -c:a libvorbis -q:a 5`. Voices are in `../voices/` (mipomi-lang repo; `puppetmaker/` = the
Puppetmaker 2 mi/po takes). Puppetmaker's music loops are in `../music/`. What each one was used for: `docs/PUPPETMAKER-SOUND.md`.
