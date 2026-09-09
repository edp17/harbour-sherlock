#pragma once

#include <cstdint>
#include <vector>

namespace SherlockClues {

// Values intentionally match ClueType in ClueSemantics.h.
enum Type {
    LeftOf = 1,
    SameColumn = 2,
    NotSameColumn = 3,
    SameColumnXor = 4,
    NextTo = 5,
    NotNextTo = 6
};

enum Orient {
    Vertical = 0,
    Horizontal = 1
};

enum Difficulty {
    Easy = 0,
    Medium = 1,
    Hard = 2
};

struct Clue {
    int type = SameColumn;
    int orient = Vertical;
    int index = 0;

    int a = -1;
    int b = -1;
    int c = -1;
    int aRow = -1;
    int bRow = -1;
    int cRow = -1;
    int aCol = -1;
    int bCol = -1;
    int cCol = -1;

    int xMark = -1;
    int flags = 0;
};

struct Group {
    int orient = Vertical;
    int index = 0;
    std::vector<Clue> clues;
};

struct Result {
    std::vector<Group> groups;
    bool valid = false;
};

// solution and fixed are row-major. Every solution row must be a permutation
// of 0..size-1; non-zero fixed entries identify the given board cells.
// The returned clues plus those givens have exactly one solution.
Result generate(int size, const std::vector<int> &solution,
                const std::vector<std::uint8_t> &fixed,
                std::uint32_t seed, int difficulty);

bool holds(const Clue &clue, int size, const std::vector<int> &solution);

} // namespace SherlockClues
