#pragma once

#include <cstdint>
#include <vector>

namespace SherlockCandidates {

// Applies only consequences of the row permutation rule:
// - a certain item is removed from its row peers;
// - an item available in only one cell of a row becomes certain.
// Repeats until stable and never guesses.
bool closeForcedRows(int size, std::vector<std::uint32_t> &masks,
                     const std::vector<std::uint8_t> &fixed);

} // namespace SherlockCandidates
