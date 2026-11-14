"""Builds assets/ for Limus Lab by CROPPING tiles out of downloaded packs (no pixels are drawn).

Usage:  python3 tools/build_assets.py <folder with the unzipped packs>
Packs expected in that folder (as downloaded by the user):
  *items/item###.png                         - 16x16 item icons
  *FREE_Mini_Dungeon_Tileset/FREE/...        - Atomic Realm Assets, Mini Dungeon (16x16)
  *Effect_and_Bullet_16x16/Effect and Bullet 16x16/*.png
Limus comes from the user-supplied "Mini Slime" sheets (Mini_Slime_Idle/Walk/Hurt/Death.png). Monster frames are downloaded from 0x72's "16x16 DungeonTileset II" (CC0), mirrored in
https://github.com/lewiji/MagicMissile/tree/master/frames
"""
import glob, io, os, sys, urllib.request
from PIL import Image

SRC = sys.argv[1]
OUT = "assets"
for d in ("tiles", "chars", "fx", "icons", "ui", "decor"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)


def find(pattern):
    hits = glob.glob(os.path.join(SRC, "**", pattern), recursive=True)
    if not hits:
        sys.exit("missing: " + pattern)
    return hits[0]


def save(im, rel):
    im.save(os.path.join(OUT, rel + ".png"))


def tile(sheet, c, r, w=1, h=1):
    return sheet.crop((c * 16, r * 16, (c + w) * 16, (r + h) * 16))


# ---------- Mini Dungeon tiles ----------
md = Image.open(find("1_MiniDungeon_Tileset1_A.png")).convert("RGBA")
for name, (c, r) in {
    "g_tl": (0, 0), "g_t": (1, 0), "g_tr": (2, 0),      # ground surface
    "g_l": (0, 2), "g_m": (1, 2), "g_r": (2, 2),        # ground body
    "ceil": (1, 3),                                     # ceiling
    "gate_top": (3, 0), "gate_mid": (3, 2), "gate_bot": (3, 3),
}.items():
    save(tile(md, c, r), "tiles/" + name)
save(Image.open(find("1_MiniDungeon_Tileset_Background1.png")).convert("RGBA").crop((80, 0, 112, 64)), "tiles/bg")  # solid stone section (2x4 tiles)
save(tile(md, 0, 1, 3, 3), "ui/frame")
# acid: textured water tiles from Stringstar Fields (tinted green in-engine)
ss = Image.open(find("*stringstar_fields/tileset.png")).convert("RGBA")
save(tile(ss, 8, 9), "tiles/acid_top")
save(tile(ss, 8, 10), "tiles/acid")          # 48x48 stone frame used as a 9-patch

# ---------- Effects (one colour pack per chemical) ----------
packs = {0: "Green", 1: "Water", 2: "Fire", 3: "Purple"}
for chem, col in packs.items():
    fx = Image.open(find(f"{col} Effect and Bullet 16x16.png")).convert("RGBA")
    save(tile(fx, 16, 7), f"fx/bubble_{chem}")
    for i, (c, r) in enumerate([(15, 5), (16, 5), (17, 5)]):
        save(tile(fx, c, r), f"fx/boom_{chem}_{i}")
    for i, (c, r) in enumerate([(10, 3), (11, 3), (12, 3)]):
        save(tile(fx, c, r), f"fx/slash_{chem}_{i}")
# super move (Fire pack): converging rings, rising flame pillar (16x32), release burst, spinning aura wheel
fire = Image.open(find("Fire Effect and Bullet 16x16.png")).convert("RGBA")
for i, c in enumerate(range(24, 29)):
    save(tile(fire, c, 8), f"fx/super_ring_{i}")
for i, c in enumerate(range(30, 36)):
    save(tile(fire, c, 11, 1, 2), f"fx/super_pillar_{i}")
    save(tile(fire, c, 0), f"fx/super_burst_{i}")
for i, c in enumerate(range(19, 23)):
    save(tile(fire, c, 0), f"fx/super_aura_{i}")
save(tile(fire, 12, 9), "fx/fire_spark")
green = Image.open(find("Green Effect and Bullet 16x16.png")).convert("RGBA")
save(tile(green, 0, 5), "fx/glob")
save(tile(green, 12, 9), "fx/spark")

# ---------- Item icons ----------
ITEMS = {
    # materials (dropped by monsters)
    "acid_gel": 1122, "etch_wing": 1187, "vitriol_gland": 1190, "slime_core": 1195, "corrosion_heart": 1134,
    # catalysts (ores, ingots, crystals)
    "accelerant": 1132, "stabilizer": 566, "enricher": 567, "aerator": 598,
    "concentrate": 531, "edge": 543, "lobber": 1129,
    # base chemicals (flasks)
    "chem_0": 919, "chem_1": 901, "chem_2": 902, "chem_3": 903,
    # abilities
    "slash": 4, "dash": 1243, "heal": 688,
}
for name, n in ITEMS.items():
    save(Image.open(find(f"item{n}.png")).convert("RGBA"), "icons/" + name)
save(tile(green, 16, 7), "icons/bubble")
for name, n in {"flask_a": 901, "flask_b": 919, "flask_c": 902, "station": 917}.items():
    save(Image.open(find(f"item{n}.png")).convert("RGBA"), "decor/" + name)

# ---------- 0x72 monsters (CC0) ----------
BASE = "https://raw.githubusercontent.com/lewiji/MagicMissile/master/frames/"
MONSTERS = ["muddy", "imp", "orc_shaman", "skelet", "big_demon", "swampy", "necromancer", "orc_warrior", "ogre"]
for name in MONSTERS:
    for anim in ("idle", "run"):
        for i in range(4):
            data = urllib.request.urlopen(f"{BASE}{name}_{anim}_anim_f{i}.png", timeout=30).read()
            im = Image.open(io.BytesIO(data)).convert("RGBA")
            if im.size == (16, 20):          # 0x72 tall sprites: trim to the 16x16 cell
                im = im.crop((0, 4, 16, 20))
            save(im, f"chars/{name}_{anim}_{i}")
# big zombie (0x72, CC0) mirrored in iTzTalha/Dino-Run; only idle frames exist, reused for "run"
ZB = "https://raw.githubusercontent.com/iTzTalha/Dino-Run/master/Dino/Assets/Sprites/DungeonTileset/Big%20Zombie/"
for i in range(4):
    im = Image.open(io.BytesIO(urllib.request.urlopen(f"{ZB}big_zombie_idle_anim_f{i}.png", timeout=30).read())).convert("RGBA")
    save(im, f"chars/big_zombie_idle_{i}")
    save(im, f"chars/big_zombie_run_{i}")
print("assets built in", OUT)

# ---------- Limus: the user's "Mini Slime" sheets (32x32 frames), palette-swapped ----------
# Green body -> light blue, yellow eyes -> white, red hurt-flash -> faint red. Black outline/pupils untouched.
PALETTE = {
    (0, 199, 22): (150, 206, 246),   # body -> light blue
    (46, 246, 68): (208, 238, 255),  # highlight
    (0, 117, 13): (86, 140, 198),    # shadow
    (0, 130, 14): (100, 156, 212),   # shadow 2
    (188, 255, 102): (255, 255, 255),  # eyes -> white
    (138, 186, 77): (196, 210, 228),   # eye shade -> light grey
    (255, 0, 0): (238, 150, 162),    # hurt flash -> faint red
    (130, 0, 0): (176, 104, 122),
    (255, 105, 105): (255, 196, 202),
}
for anim in ("Idle", "Walk", "Hurt", "Death"):
    sheet = Image.open(find(f"Mini_Slime_{anim}.png")).convert("RGBA")
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in PALETTE:
                px[x, y] = PALETTE[(r, g, b)] + (a,)
    for i in range(sheet.width // 32):
        save(sheet.crop((i * 32, 0, i * 32 + 32, 32)), f"chars/limus_{anim.lower()}_{i}")
    print("limus", anim, sheet.width // 32, "frames")

# ---------- whole sheets used directly by the TileSet / scenes ----------
import shutil
os.makedirs(os.path.join(OUT, "lab"), exist_ok=True)
os.makedirs(os.path.join(OUT, "nature"), exist_ok=True)
for name in ("Laboratory.png", "hospital2.png", "LabIcons.png", "lab_tileset_LITE.png"):
    shutil.copy(find(name), os.path.join(OUT, "lab", name))
shutil.copy(find("*stringstar_fields/tileset.png"), os.path.join(OUT, "nature", "tileset.png"))
shutil.copy(find("*stringstar_fields/background_0.png"), os.path.join(OUT, "nature", "background_0.png"))
print("copied lab + nature sheets")
