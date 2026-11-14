"""Writes tools/rooms.json: the tile layout + gameplay data for every room.
tools/build_scenes.gd turns it into scenes/rooms/*.tscn.  Edit the scenes in Godot afterwards,
or edit this file and re-run both tools.

Legend:  # lab metal (solid)   = one-way slab platform   ~ acid   . empty
         P player spawn  D exit door  g ground spawn  a air spawn  B boss spawn  x training dummy
         decor (no collision): v vent  l lamp  w window  k cabinet  m machine  M monitor(2)  t table(2)
                               b burner  f flask  j green jar  r red tank  T acid tank(3)  p plant  c console
                               ! DANGER sign (lab_tileset_LITE)
"""
import json

H = 23
FLOOR = 19   # top row of the floor


def blank(w):
    g = [["." for _ in range(w)] for _ in range(H)]
    for x in range(w):
        for y in (0, 1, 20, 21, 22, FLOOR):
            g[y][x] = "#"
    for y in range(H):
        g[y][0] = "#"
        g[y][w - 1] = "#"
    return g


def pit(g, x0, x1):
    for x in range(x0, x1 + 1):
        g[FLOOR][x] = "~"
        g[FLOOR + 1][x] = "~"


def plat(g, row, x0, x1):
    for x in range(x0, x1 + 1):
        g[row][x] = "="


def put(g, x, y, ch):
    g[y][x] = ch


def solid(g, x0, x1, y0, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = "#"


def decor_line(g, items):
    for x, y, ch in items:
        put(g, x, y, ch)


rooms = []

# ---------------- Tutorial: Containment Cell (64 wide) ----------------
g = blank(64)
put(g, 3, 18, "P")
plat(g, 17, 7, 10)                       # hop up
pit(g, 15, 18); put(g, 14, 18, "!")      # dash over acid
put(g, 29, 18, "x")                      # slash dummy
plat(g, 13, 41, 44); put(g, 42, 12, "x") # bubble dummy, too high to reach (6 tiles)
put(g, 62, 18, "D")
decor_line(g, [(2, 18, "k"), (5, 18, "c"), (22, 18, "t"), (23, 18, "t"), (22, 17, "b"), (23, 17, "f"),
               (34, 18, "j"), (36, 18, "M"), (37, 18, "M"), (50, 18, "T"), (51, 18, "T"), (52, 18, "T"),
               (57, 18, "m"), (59, 18, "r")])
for x in (6, 20, 34, 48, 58):
    put(g, x, 2, "l")
for x in (12, 27, 40, 55):
    put(g, x, 5, "v")
rooms.append({"file": "Room_Tutorial", "title": "Tutorial: Containment Cell", "tutorial": True, "floor": 0, "map": g,
    "signs": [
        [2, 8, "A / D  —  move\nW / SPACE  —  bounce (2 tiles high)\nHop onto the slab"],
        [12, 8, "SHIFT  —  DASH over the acid\nDashing burns hydrogen (STAMINA)\nAcid pits hurt!"],
        [24, 8, "LEFT CLICK / J  —  SLASH\nDestroy the training skeleton"],
        [36, 6, "RIGHT CLICK / K  —  SLIME BUBBLE (7 HP)\nAim with the mouse. It bounces once off\nwalls (+30%) and ricochets enemy to enemy"],
        [49, 8, "Kills drop LOOT: pick it up to HEAL\nHealing past full = OVERHEAL (gold)"],
        [49, 13, "Room clear?  TAB / I opens the LAB KIT\nDrag the BASE flask into Chemical:\nacid slimes are WEAK to Base!\nThe door opens when the skeletons fall →"],
    ]})

# ---------------- Fight room layouts (40 wide) ----------------
def r1(g):
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 15, 19); put(g, 14, 18, "!")
    plat(g, 17, 6, 10); plat(g, 17, 26, 30); plat(g, 15, 15, 20); plat(g, 13, 8, 11); plat(g, 13, 28, 31)
    for p in [(12, 18, "g"), (24, 18, "g"), (33, 18, "g"), (20, 8, "a"), (30, 7, "a")]:
        put(g, *p)
    decor_line(g, [(3, 18, "k"), (4, 18, "M"), (5, 18, "M"), (22, 18, "j"), (35, 18, "T"), (36, 18, "T"), (37, 18, "T"),
                   (9, 5, "v"), (30, 5, "v"), (18, 6, "w"), (19, 6, "w")])


def r2(g):
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 9, 12); pit(g, 27, 30); put(g, 8, 18, "!"); put(g, 26, 18, "!")
    plat(g, 17, 3, 6); plat(g, 17, 33, 36); plat(g, 15, 15, 24); plat(g, 13, 6, 9); plat(g, 13, 30, 33)
    for p in [(18, 18, "g"), (22, 18, "g"), (34, 18, "g"), (12, 7, "a"), (28, 7, "a")]:
        put(g, *p)
    decor_line(g, [(14, 18, "t"), (15, 18, "t"), (14, 17, "f"), (15, 17, "b"), (20, 18, "m"), (24, 18, "c"),
                   (36, 18, "r"), (7, 5, "v"), (32, 5, "v"), (19, 9, "w"), (20, 9, "w")])


def r3(g):
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 18, 22); put(g, 17, 18, "!")
    solid(g, 7, 10, 17, 18); solid(g, 29, 32, 17, 18)          # raised benches (2 tiles)
    plat(g, 15, 12, 16); plat(g, 15, 23, 27); plat(g, 13, 17, 22); plat(g, 11, 5, 8); plat(g, 11, 31, 34)
    for p in [(9, 16, "g"), (30, 16, "g"), (14, 18, "g"), (25, 18, "g"), (20, 6, "a")]:
        put(g, *p)
    decor_line(g, [(3, 18, "k"), (4, 18, "c"), (12, 18, "j"), (26, 18, "j"), (34, 18, "M"), (35, 18, "M"),
                   (8, 16, "f"), (31, 16, "b"), (15, 5, "v"), (24, 5, "v")])


def r4(g):
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 8, 10); pit(g, 18, 21); pit(g, 29, 31)
    for x in (7, 17, 28):
        put(g, x, 18, "!")
    plat(g, 17, 12, 16); plat(g, 17, 23, 27); plat(g, 15, 18, 21); plat(g, 13, 5, 8); plat(g, 13, 31, 34)
    for p in [(5, 18, "g"), (14, 18, "g"), (25, 18, "g"), (34, 18, "g"), (19, 8, "a")]:
        put(g, *p)
    decor_line(g, [(3, 18, "m"), (12, 18, "c"), (24, 18, "r"), (33, 18, "k"), (36, 18, "T"), (37, 18, "T"),
                   (35, 18, "j"), (10, 5, "v"), (20, 4, "v"), (29, 5, "v")])


def r5(g):
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 6, 9); pit(g, 30, 33); put(g, 5, 18, "!"); put(g, 34, 18, "!")
    plat(g, 17, 14, 25); plat(g, 15, 10, 13); plat(g, 15, 26, 29); plat(g, 13, 17, 22)
    for p in [(12, 18, "g"), (20, 16, "g"), (27, 18, "g"), (8, 8, "a"), (31, 8, "a")]:
        put(g, *p)
    decor_line(g, [(3, 18, "k"), (11, 18, "j"), (13, 18, "t"), (14, 18, "t"), (13, 17, "b"), (26, 18, "M"), (27, 18, "M"),
                   (36, 18, "r"), (15, 5, "v"), (24, 5, "v"), (19, 9, "w"), (20, 9, "w")])


LAYOUTS = [r1, r2, r3, r4, r5]
BASE_WAVES = [
    ([["tank", "tank"], ["tank", "annoying", "annoying"]], "tank"),
    ([["annoying", "annoying", "ranged"], ["ranged", "annoying", "tank"]], "annoying"),
    ([["ranged", "ranged", "tank"], ["ranged", "tank", "tank", "annoying"]], "ranged"),
    ([["tank", "annoying", "ranged", "annoying"], ["tank", "tank", "ranged", "ranged"]], "tank"),
    ([["annoying", "annoying", "annoying", "ranged"], ["tank", "ranged", "ranged", "annoying", "tank"]], "ranged"),
]
FLOORS = [   # 1 Acid -> 2 Base -> 3 Fuel, then the Prime Reactor
    ("Floor 1", ["Intake Vats", "Etching Hall", "Spitter Gallery", "Overflow Pipes", "Neutralizer Chamber"], "The Corrosion Core", {}),
    ("Floor 2", ["Lye Intake", "Caustic Hall", "Alkali Gallery", "Brine Pipes", "pH Chamber"], "The Alkaline Tyrant", {"j": "r", "k": "m"}),
    ("Floor 3", ["Boiler Intake", "Flare Stacks", "Cinder Gallery", "Pressure Lines", "Ignition Chamber"], "The Furnace Ogre", {"j": "r", "T": "r"}),
]


def mirror(g):
    """Flip a room left-right (keeps the player spawn on the left and the door on the right)."""
    w = len(g[0])
    for row in g:
        row[1:w - 1] = row[1:w - 1][::-1]
    for y in range(len(g)):
        for x in range(w):
            if g[y][x] in "PD":
                g[y][x] = "."
    for x in (1, 2, 3, w - 4, w - 3, w - 2):
        if g[18][x] not in "#=~":
            g[18][x] = "."
    g[18][2] = "P"
    g[18][w - 2] = "D"


def theme(g, swaps):
    for row in g:
        for x, ch in enumerate(row):
            if ch in swaps:
                row[x] = swaps[ch]


def lamps(g):
    for x in (5, 14, 25, 34):
        if g[2][x] == ".":
            g[2][x] = "l"


def boss_arena(floor_i):
    g = blank(40)
    put(g, 2, 18, "P"); put(g, 38, 18, "D")
    pit(g, 4, 6); pit(g, 33, 35)
    plat(g, 17, 8, 12); plat(g, 17, 27, 31); plat(g, 15, 15, 24); plat(g, 13, 9, 12); plat(g, 13, 27, 30)
    put(g, 20, 6, "B")
    decor_line(g, [(14, 18, "T"), (15, 18, "T"), (16, 18, "T"), (23, 18, "T"), (24, 18, "T"), (25, 18, "T"),
                   (3, 18, "k"), (37, 18, "k"), (8, 5, "v"), (31, 5, "v")])
    for x in (6, 14, 26, 34):
        put(g, x, 2, "l")
    return g


for fi, (fname, titles, boss_name, swaps) in enumerate(FLOORS):
    for ri in range(5):
        g = blank(40)
        LAYOUTS[ri](g)
        if fi % 2 == 1:
            mirror(g)
        theme(g, swaps)
        lamps(g)
        waves = [list(w) for w in BASE_WAVES[ri][0]]
        if fi >= 2:                       # deeper floors: one extra enemy per wave
            for w in waves:
                w.append(["tank", "annoying", "ranged"][(ri + len(w)) % 3])
        file = "Room_%d" % (ri + 1) if fi == 0 else "F%d_Room_%d" % (fi + 1, ri + 1)
        rooms.append({"file": file, "title": "Room %d: %s" % (ri + 1, titles[ri]), "floor": fi,
                      "waves": waves, "sub": BASE_WAVES[ri][1], "map": g})
    g = boss_arena(fi)
    theme(g, swaps)
    rooms.append({"file": "Room_Boss" if fi == 0 else "F%d_Boss" % (fi + 1), "title": "BOSS: " + boss_name,
                  "floor": fi, "boss": True, "floor_end": True, "map": g})

# ---------------- Final: the Prime Reactor ----------------
g = blank(40)
put(g, 2, 18, "P"); put(g, 38, 18, "D")
pit(g, 5, 7); pit(g, 18, 21); pit(g, 32, 34)
plat(g, 17, 9, 15); plat(g, 17, 24, 30); plat(g, 15, 17, 22); plat(g, 13, 5, 9); plat(g, 13, 30, 34); plat(g, 11, 14, 25)
put(g, 20, 5, "B")
decor_line(g, [(3, 18, "k"), (11, 18, "T"), (12, 18, "T"), (13, 18, "T"), (26, 18, "T"), (27, 18, "T"), (28, 18, "T"),
               (36, 18, "m"), (10, 5, "v"), (29, 5, "v"), (19, 8, "w"), (20, 8, "w")])
for x in (6, 14, 26, 34):
    put(g, x, 2, "l")
rooms.append({"file": "Final_Boss", "title": "FINAL: The Prime Catalyst", "floor": 3, "boss": True, "floor_end": True, "map": g})

for r in rooms:
    r["map"] = ["".join(row) for row in r["map"]]
    assert all(len(row) == len(r["map"][0]) for row in r["map"]), r["file"]
json.dump(rooms, open("tools/rooms.json", "w"), indent=1)
print("\n".join(rooms[8]["map"][15:20]))
print(len(rooms), "rooms")
