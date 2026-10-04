"""뽑기키우기 밸런스 시뮬레이터.

scripts/autoload/balance.gd 와 같은 공식을 사용한다.
플레이어가 골드는 전부 레벨업에, 코인은 전부 뽑기에 쓴다고 가정하고
활동 시간 대비 도달 스테이지와 환생 타이밍을 출력한다.

사용법: python tools/balance_sim.py [시뮬레이션_시간(h)=24] [시드=1]
"""
import random
import sys

RARITIES = ["N", "R", "SR", "SSR", "UR"]
BASE_ATK = {"N": 10, "R": 14, "SR": 21, "SSR": 32, "UR": 50}
POOL = {"N": 5, "R": 5, "SR": 4, "SSR": 4, "UR": 2}
STAR_MULT = [1.0, 1.5, 2.2, 3.2, 4.6, 6.5]
STAR_COST = [2, 4, 8, 15, 30]
RATES = [0.60, 0.28, 0.09, 0.027, 0.003]  # 기계 Lv1 (시뮬레이션은 단순화를 위해 고정)
TEAM_FACTOR = 1.2   # 치명타 + 스킬 평균 기여
WAVE_GAP = 3.0      # 적 등장까지 걸리는 시간(초)


def enemy_hp(s): return 40 * 1.21 ** s
def kill_gold(s): return 5 * 1.19 ** s
def level_cost(lv): return 15 * 1.10 ** (lv - 1)
def level_mult(lv): return 1.07 ** (lv - 1)
def party_slots(s): return 1 + (s >= 2) + (s >= 5) + (s >= 10) + (s >= 20)
def scales_for(max_s): return 0 if max_s < 30 else int(((max_s - 20) / 10) ** 1.5 * 2)
def scale_mult(scales): return 1 + 0.05 * scales


class Dragon:
    def __init__(self, rarity):
        self.rarity, self.level, self.star, self.shards = rarity, 1, 0, 0

    def atk(self):
        return BASE_ATK[self.rarity] * level_mult(self.level) * STAR_MULT[self.star]


def run(hours=24.0, seed=1):
    rng = random.Random(seed)
    owned = {("R", 0): Dragon("R")}
    pity_sr = pity_ssr = 0
    coins, gold, s, t, scales, max_s = 10, 0.0, 0, 0.0, 0, 0
    cleared, marks, prestiges, last_progress = set(), {}, [], 0.0
    while t < hours * 3600:
        while coins >= 1:
            coins -= 1
            x, acc, k = rng.random(), 0.0, 0
            for k, r in enumerate(RATES):
                acc += r
                if x < acc:
                    break
            if pity_sr >= 9 and k < 2: k = 2
            if pity_ssr >= 89 and k < 3: k = 3
            pity_sr = 0 if k >= 2 else pity_sr + 1
            pity_ssr = 0 if k >= 3 else pity_ssr + 1
            key = (RARITIES[k], rng.randrange(POOL[RARITIES[k]]))
            if key in owned:
                d = owned[key]
                d.shards += 1
                if d.star < 5 and d.shards >= STAR_COST[d.star]:
                    d.shards -= STAR_COST[d.star]
                    d.star += 1
            else:
                owned[key] = Dragon(RARITIES[k])
        party = sorted(owned.values(), key=lambda d: -d.atk())[:party_slots(s)]
        while True:
            d = min(party, key=lambda d: level_cost(d.level))
            if gold < level_cost(d.level):
                break
            gold -= level_cost(d.level)
            d.level += 1
        dps = sum(d.atk() for d in party) * TEAM_FACTOR * scale_mult(scales)
        hp = enemy_hp(s)
        t += 4 * (3 * hp / dps + WAVE_GAP)
        gold += 12 * kill_gold(s) * scale_mult(scales)
        boss_mult, timer = (25, 30) if s % 10 == 9 else (6, 20)
        boss_time = boss_mult * hp / dps
        if boss_time <= timer:
            t += boss_time + 3
            gold += kill_gold(s) * 8 * scale_mult(scales)
            coins += 1 + (2 if s not in cleared else 0) + (20 if s % 10 == 9 and s not in cleared else 0)
            cleared.add(s)
            s += 1
            last_progress = t
            if s > max_s:
                max_s = s
                if s % 10 == 0:
                    marks[s] = t
        else:
            t += timer + 3
            gain = scales_for(s)
            if s >= 30 and t - last_progress > 15 * 60 and gain >= max(2, scales // 2):
                prestiges.append((t, s, gain))
                scales += gain
                s, gold, last_progress = 0, 0.0, t
                for d in owned.values():
                    d.level = 1
    return marks, prestiges, max_s, scales


if __name__ == "__main__":
    hours = float(sys.argv[1]) if len(sys.argv) > 1 else 24
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    marks, prestiges, max_s, scales = run(hours, seed)
    print(f"[{hours}시간 시뮬레이션, 시드 {seed}]")
    for s, t in sorted(marks.items()):
        print(f"  {s // 10 + 1}-1 첫 도달: {t / 60:7.1f}분")
    for t, s, gain in prestiges[:10]:
        print(f"  둥지 이사: {t / 60:7.1f}분, 최고 {s // 10 + 1}-{s % 10 + 1}, 비늘 +{gain}")
    print(f"  최종 최고 스테이지 s={max_s}, 누적 비늘 {scales}")
