"""Monte Carlo balance check for Chapter 1 fights played by Mira alone.

Mirrors the rules in scripts/battle/ (hit/damage formulas, CTB extra turns, enemy action tables,
stacking debuffs, dagger combos, durability) with simplified grid movement, then plays the
Chapter 1 hub as a route: fights, pickups, drops, potions and level-ups (2 STR + 2 VIT per level).

Run:
    python3 tools/balance_sim.py [data_dir] [runs]

Results and targets are recorded in game-design/combat.md ("Solo balance").
"""

from __future__ import annotations

import json
import random
import sys
from dataclasses import dataclass, field
from pathlib import Path

DATA = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "data")
RUNS = int(sys.argv[2] if len(sys.argv) > 2 else 4000)

BASE_HIT, HIT_FLOOR, HIT_CEIL, LUK_W, VIT_W = 70.0, 10.0, 95.0, 0.5, 0.4
HP_BASE, HP_PER_VIT, EXTRA_AGI = 20, 8, 1.35
GRID = 6


def load(name):
    return json.loads((DATA / f"{name}.json").read_text())


ENEMIES = {e["id"]: e for e in load("enemies")}
ENCOUNTERS = {e["id"]: e for e in load("encounters")}
WEAPONS = {w["id"]: w for w in load("weapons")}
EQUIP = {e["id"]: e for e in load("equipment")}
MIRA = next(c for c in load("characters") if c["id"] == "ally_2")
SETUP = load("setup")


def pct(chance):
    return random.random() * 100.0 <= chance


@dataclass
class Mira:
    level: int = 1
    xp: int = 0
    alloc: dict = field(default_factory=lambda: {"str": 0, "vit": 0, "dex": 0, "agi": 0, "luk": 0})
    weapon: str | None = "rusty_dagger"
    durability: int = 30
    armor: str | None = None
    helmet: str | None = None
    hp: int = 0
    potions: int = 2
    mastery_uses: int = 0
    spares: list = field(default_factory=list)

    def stats(self):
        s = {k: MIRA["stats"][k] for k in MIRA["stats"]}
        for k, v in MIRA["level_growth"].items():
            s[k] += v * (self.level - 1)
        for k, v in self.alloc.items():
            s[k] += v
        for item in (WEAPONS.get(self.weapon), EQUIP.get(self.armor), EQUIP.get(self.helmet)):
            if item:
                for k, v in item["stat_bonuses"].items():
                    s[k] += v
        return s

    def max_hp(self):
        return HP_BASE + self.stats()["vit"] * HP_PER_VIT

    def mastery(self):
        return min(3, 1 + self.mastery_uses // 25)


@dataclass
class Unit:
    name: str
    hp: int
    pos: list
    ally: bool
    data: dict | None = None
    str_debuff: int = 0


def chebyshev(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def manhattan(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def can_attack(src, dst, rng, blockers):
    if rng <= 1:
        return chebyshev(src, dst) == 1
    dx, dy = dst[0] - src[0], dst[1] - src[1]
    if not (dx == 0 or dy == 0 or abs(dx) == abs(dy)):
        return False
    steps = max(abs(dx), abs(dy))
    if steps > rng or steps == 0:
        return False
    sx, sy = (dx > 0) - (dx < 0), (dy > 0) - (dy < 0)
    for i in range(1, steps):
        if [src[0] + sx * i, src[1] + sy * i] in blockers:
            return False
    return True


def reachable(start, move, occupied, row_min, row_max):
    seen = {tuple(start): 0}
    frontier = [tuple(start)]
    while frontier:
        nxt = []
        for c in frontier:
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + d[0], c[1] + d[1])
                if not (0 <= n[0] < GRID and row_min <= n[1] <= row_max):
                    continue
                if n in seen or list(n) in occupied:
                    continue
                if seen[c] + 1 > move:
                    continue
                seen[n] = seen[c] + 1
                nxt.append(n)
        frontier = nxt
    return [list(c) for c in seen]


def battle(m: Mira, encounter_id: str):
    enc = ENCOUNTERS[encounter_id]
    st = m.stats()
    mira = Unit("Mira", m.hp, [2, 1], True)
    foes = [Unit(e["enemy_id"], ENEMIES[e["enemy_id"]]["stats"]["hp"], list(e["position"]), False,
                 ENEMIES[e["enemy_id"]]) for e in enc["enemies"]]
    # Turn queue as TurnQueue.build_queue: weight = agi, extra entry when agi >= avg * 1.35.
    units = [mira] + foes
    agis = [st["agi"]] + [f.data["stats"]["agi"] for f in foes]
    avg = sum(agis) / len(agis)
    queue = []
    for u, a in zip(units, agis):
        queue.append((a, u))
        if a >= avg * EXTRA_AGI:
            queue.append((a - 1, u))
    queue.sort(key=lambda e: -e[0])
    order = [u for _, u in queue]
    attacks = 0
    damage_taken = 0
    turns = 0
    potions_used = 0
    while turns < 400:
        for u in order:
            living = [f for f in foes if f.hp > 0]
            if not living:
                m.hp = mira.hp
                return "win", attacks, damage_taken, potions_used, turns
            if mira.hp <= 0:
                return "loss", attacks, damage_taken, potions_used, turns
            if u.hp <= 0:
                continue
            turns += 1
            occupied = [x.pos for x in [mira] + living]
            if u.ally:
                st = m.stats()
                eff_str = max(st["str"] + mira.str_debuff, 1)
                front = min(f.pos[1] for f in living)
                bounds = (0, front - 1)
                # Heal when low.
                if mira.hp <= 0.4 * m.max_hp() and m.potions > 0:
                    m.potions -= 1
                    potions_used += 1
                    mira.hp = min(m.max_hp(), mira.hp + 50)
                    continue
                rng = WEAPONS[m.weapon]["attack_range"] if m.weapon else 1

                def attackable(pos):
                    return [f for f in living if can_attack(pos, f.pos, rng, occupied)]

                targets = attackable(mira.pos)
                if not targets:
                    cells = reachable(mira.pos, MIRA["move_range"], [o for o in occupied if o is not mira.pos],
                                      *bounds)
                    best = None
                    for c in cells:
                        t = attackable(c)
                        if t:
                            best = c
                            break
                    if best is None:
                        nearest = min(living, key=lambda f: manhattan(mira.pos, f.pos))
                        best = min(cells, key=lambda c: manhattan(c, nearest.pos))
                    mira.pos = best
                    targets = attackable(mira.pos)
                if targets:
                    t = min(targets, key=lambda f: f.hp)
                    attacks += 1
                    if m.weapon:
                        m.durability -= 1
                        m.mastery_uses += 1
                        if m.durability <= 0:
                            m.weapon = None
                            if m.spares:
                                nxt = m.spares.pop(0)
                                m.weapon, m.durability = nxt, WEAPONS[nxt]["durability_max"]
                    hit = max(HIT_FLOOR, min(HIT_CEIL, BASE_HIT + st["dex"]))
                    if pct(hit):
                        hits = 1
                        combo = max(HIT_FLOOR, min(HIT_CEIL, st["dex"] + st["luk"]))
                        lvl = m.mastery()
                        if lvl >= 2 and pct(combo):
                            hits = 2
                            if lvl >= 3 and pct(combo):
                                hits = 3
                        dmg = max(eff_str - t.data["stats"]["vit"], 1)
                        t.hp -= dmg * hits
            else:
                actions = u.data["actions"]
                roll = random.randint(1, 100)
                cum = 0
                act = actions[-1]
                for a in actions:
                    cum += a["chance"]
                    if roll <= cum:
                        act = a
                        break
                bounds = (mira.pos[1] + 1, GRID - 1)
                rng = act.get("range", 1)

                def step():
                    cells = reachable(u.pos, u.data["move_range"], [o for o in occupied if o is not u.pos], *bounds)
                    best = min(cells, key=lambda c: manhattan(c, mira.pos))
                    if manhattan(best, mira.pos) < manhattan(u.pos, mira.pos):
                        u.pos = best

                if act["type"] == "debuff":
                    if manhattan(u.pos, mira.pos) > rng:
                        step()
                    if manhattan(u.pos, mira.pos) <= rng:
                        mira.str_debuff += act["amount"]
                    continue
                blockers = [x.pos for x in [mira] + living if x is not u]
                if not can_attack(u.pos, mira.pos, rng, blockers):
                    step()
                    blockers = [x.pos for x in [mira] + living if x is not u]
                if can_attack(u.pos, mira.pos, rng, blockers):
                    dex = u.data["stats"]["dex"]
                    st = m.stats()
                    hit = max(HIT_FLOOR, min(HIT_CEIL, BASE_HIT + dex - (st["dex"] + st["luk"] * LUK_W)))
                    if pct(hit):
                        mitig = int(st["vit"] * VIT_W)
                        dmg = max(random.randint(act["damage_min"], act["damage_max"]) - mitig, 1)
                        mira.hp -= dmg
                        damage_taken += dmg
    return "timeout", attacks, damage_taken, potions_used, turns


def award(m: Mira, encounter_id: str):
    enc = ENCOUNTERS[encounter_id]
    for e in enc["enemies"]:
        data = ENEMIES[e["enemy_id"]]
        m.xp += data["xp_reward"]
        for drop in data.get("drops", []):
            if pct(drop["chance"]):
                take(m, drop["item_id"])
    while m.xp >= m.level * 100:
        m.xp -= m.level * 100
        m.level += 1
        # Player allocation guess for a solo knife-fighter: 2 STR, 2 VIT per level.
        m.alloc["str"] += 2
        m.alloc["vit"] += 2
        m.hp = m.max_hp()


def take(m: Mira, item):
    if item == "heal_potion":
        m.potions += 1
    elif item in EQUIP:
        slot = EQUIP[item]["slot"]
        cur = getattr(m, slot, None) if slot in ("armor", "helmet") else None
        if slot in ("armor", "helmet"):
            if cur is None or sum(EQUIP[item]["stat_bonuses"].values()) > sum(EQUIP[cur]["stat_bonuses"].values()):
                setattr(m, slot, item)
    elif item in WEAPONS and WEAPONS[item]["weapon_class"] == "dagger":
        if m.weapon is None:
            m.weapon, m.durability = item, WEAPONS[item]["durability_max"]
        else:
            m.spares.append(item)


def patch_up(m: Mira, threshold: float = 0.6):
    while m.hp < threshold * m.max_hp() and m.potions > 0:
        m.potions -= 1
        m.hp = min(m.max_hp(), m.hp + 50)


def route(steps):
    """steps: list of ("fight", encounter_id) / ("pickup", item_id)."""
    m = Mira()
    m.potions = int(SETUP["inventory"].get("heal_potion", 0))
    m.hp = m.max_hp()
    log = []
    for kind, ref in steps:
        if kind == "pickup":
            take(m, ref)
            continue
        patch_up(m)
        lvl, hp0 = m.level, m.hp
        res, attacks, dmg, pots, turns = battle(m, ref)
        log.append((ref, res, lvl, hp0, dmg, pots, attacks, m.weapon))
        if res != "win":
            return False, log, m
        award(m, ref)
    return True, log, m


def summarize(name, steps, runs=RUNS):
    stats = {}
    wins = 0
    broke = 0
    levels = []
    for _ in range(runs):
        ok, log, m = route(steps)
        wins += ok
        levels.append(m.level)
        if m.weapon is None:
            broke += 1
        for ref, res, lvl, hp0, dmg, pots, attacks, weapon in log:
            s = stats.setdefault(ref, {"n": 0, "win": 0, "dmg": 0, "pots": 0, "attacks": 0, "lvl": 0, "hp0": 0})
            s["n"] += 1
            s["win"] += res == "win"
            s["dmg"] += dmg
            s["pots"] += pots
            s["attacks"] += attacks
            s["lvl"] += lvl
            s["hp0"] += hp0
    print(f"\n== {name}: route clear {wins / runs:.1%}, weapon broken by end {broke / runs:.1%}, "
          f"final level avg {sum(levels) / runs:.2f}")
    for ref, s in stats.items():
        n = s["n"]
        print(f"  {ref:24s} reached {n / runs:6.1%}  win {s['win'] / n:6.1%}  lvl {s['lvl'] / n:4.2f}  "
              f"hp_in {s['hp0'] / n:5.1f}  dmg_taken {s['dmg'] / n:5.1f}  potions {s['pots'] / n:4.2f}  "
              f"attacks {s['attacks'] / n:5.1f}")


if __name__ == "__main__":
    random.seed(1)
    intended = [("fight", "village_square_scuffle"), ("pickup", "heal_potion"),
                ("pickup", "heal_potion"), ("fight", "cottage_closet_ambush"),
                ("pickup", "leather_vest"), ("pickup", "heal_potion"), ("pickup", "skinning_knife"),
                ("fight", "granary_patrol"), ("fight", "granary_loft"),
                ("fight", "cellar_guard"), ("pickup", "chain_mail"),
                ("pickup", "iron_helm"), ("fight", "chapel_warden")]
    summarize("intended route", intended)
    summarize("chapel first (fresh Mira)", [("fight", "village_square_scuffle"), ("fight", "chapel_warden")])
    for enc in ("village_square_scuffle", "cottage_closet_ambush", "granary_patrol", "granary_loft",
                "cellar_guard", "chapel_warden"):
        summarize(f"{enc} at level 1, full HP", [("fight", enc)], runs=RUNS // 2)
