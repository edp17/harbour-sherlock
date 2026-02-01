#!/usr/bin/env python3
from pathlib import Path
from typing import List, Set

def xorshift32(state: int) -> int:
    state &= 0xFFFFFFFF
    if state == 0:
        state = 1
    x = state
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= (x >> 17) & 0xFFFFFFFF
    x ^= (x << 5) & 0xFFFFFFFF
    return x & 0xFFFFFFFF

def make_bank(base_seed: int, count: int) -> List[int]:
    out: List[int] = []
    seen: Set[int] = set()
    s = base_seed & 0xFFFFFFFF
    while len(out) < count:
        s = xorshift32(s)
        if s == 0:
            continue
        if s in seen:
            continue
        seen.add(s)
        out.append(s)
    return out

def write_bank(path: Path, seeds: List[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(str(s) for s in seeds) + "\n", encoding="utf-8")

def main() -> None:
    N4, N5, N6 = 1000, 1000, 1000

    bank4 = make_bank(0xA341316C, N4)
    bank5 = make_bank(0xC8013EA4, N5)
    bank6 = make_bank(0xAD90777D, N6)

    root = Path(__file__).resolve().parents[1]
    write_bank(root / "qml/assets/puzzles/bank_4.txt", bank4)
    write_bank(root / "qml/assets/puzzles/bank_5.txt", bank5)
    write_bank(root / "qml/assets/puzzles/bank_6.txt", bank6)

    print("Wrote banks:",
          len(bank4), "to bank_4.txt,",
          len(bank5), "to bank_5.txt,",
          len(bank6), "to bank_6.txt")

if __name__ == "__main__":
    main()