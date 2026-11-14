# Art credits

Every image in `assets/` is cropped out of the packs below by `tools/build_assets.py`. Nothing was drawn or generated.
All sprites/tiles are 16x16 cells (the boss is a 2x2-tile 0x72 sprite), drawn in-game at 2x.

| Used for | Pack | Author / license |
|---|---|---|
| Lab Kit / slot stone frame | FREE Mini Dungeon Tileset | Atomic Realm Assets: free for commercial/non-commercial games, assets may be edited, **may not be repackaged or redistributed on their own** |
| Acid pools (water tiles, tinted) | Stringstar Fields tileset | as supplied by the user (see the pack's readme) |
| Bubbles, acid globs, explosions, slash, sparks | Effect and Bullet 16x16 (Green / Water / Fire / Purple) | as supplied by the user |
| Material, catalyst, chemical, ability icons; lab flasks; Lab Kit chest | 16x16 item icon pack (items.zip, "Item_sheet") | as supplied by the user |
| Limus (the player slime) | "Mini Slime" Idle / Walk / Hurt / Death sheets (32x32 frames), palette-swapped to light blue with white eyes and a faint-red hurt flash | as supplied by the user |
| Room floors, walls, ceilings, slabs, background panels | Laboratory SciFi Tileset (`Laboratory.png`, 16x16) | as supplied by the user |
| Lab props: vents, lamps, cabinets, machines, monitors, tables, jars, tanks, acid tank, exit door | `hospital2.png` (16x16) | as supplied by the user |
| Burners and flasks on tables | `LabIcons.png` (16x16) | as supplied by the user |
| DANGER signs | Laboratory Tileset Revamped LITE by ExceptRea | **CC BY-NC 4.0**: non-commercial only, credit "ExceptRea" (linktr.ee/ExceptRea) |
| Lab Kit screen: sky, trees, ground, vines | Stringstar Fields `background_0.png` + `tileset.png` | as supplied by the user |
| Muddy & swampy slimes, imp, orc shaman, orc warrior, necromancer, skeleton, ogre, big demon, big zombie | 0x72 "16x16 DungeonTileset II" | 0x72, **CC0**, https://0x72.itch.io/dungeontileset-ii (frames fetched from github.com/lewiji/MagicMissile; big zombie from github.com/iTzTalha/Dino-Run) |

Rebuild: `python3 tools/build_assets.py <folder with the unzipped packs>` (needs Pillow + internet for the 0x72 frames).

Not used: TileSetLaboratoryv2 by Oleteras (its sheet is not on a 16 px grid).

**Licence note:** `lab_tileset_LITE` is non-commercial (CC BY-NC 4.0). Before selling the game, remove the two DANGER-sign props (`Props` in each room) or buy the PRO version.
