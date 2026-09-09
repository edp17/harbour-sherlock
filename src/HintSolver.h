#pragma once

#include "ClueGenerator.h"

#include <cstdint>
#include <vector>

namespace SherlockHints {

enum Action {
    NoAction = 0,
    MakeCertain = 1,
    Eliminate = 2
};

struct Hint {
    Action action = NoAction;
    int cell = -1;
    int item = -1;
    int clueIndex = -1;
};

// Finds one deduction which follows from a displayed clue and the candidates
// currently left on the board. clueIndex refers to the flattened clue list.
Hint find(int size, const std::vector<std::uint32_t> &masks,
          const std::vector<std::uint8_t> &fixed,
          const std::vector<int> &solution,
          const std::vector<SherlockClues::Clue> &clues);

} // namespace SherlockHints
