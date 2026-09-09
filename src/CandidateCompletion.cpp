#include "CandidateCompletion.h"

namespace SherlockCandidates {
namespace {

bool isSingleton(std::uint32_t mask)
{
    return mask != 0 && (mask & (mask - 1)) == 0;
}

} // namespace

bool closeForcedRows(int size, std::vector<std::uint32_t> &masks,
                     const std::vector<std::uint8_t> &fixed)
{
    if (size < 2 || size >= 32 ||
            masks.size() != static_cast<std::size_t>(size * size) ||
            fixed.size() != masks.size()) {
        return false;
    }

    const std::uint32_t fullMask = (std::uint32_t(1) << size) - 1u;
    bool anyChange = false;

    for (int pass = 0; pass < size * size; ++pass) {
        bool passChanged = false;

        for (int row = 0; row < size; ++row) {
            // Propagate every already-certain item through its row.
            for (int col = 0; col < size; ++col) {
                const std::size_t cell = static_cast<std::size_t>(row * size + col);
                const std::uint32_t certain = masks[cell] & fullMask;
                if (!isSingleton(certain))
                    continue;

                for (int peerCol = 0; peerCol < size; ++peerCol) {
                    if (peerCol == col)
                        continue;
                    const std::size_t peer =
                        static_cast<std::size_t>(row * size + peerCol);
                    if (fixed[peer])
                        continue;
                    const std::uint32_t before = masks[peer] & fullMask;
                    const std::uint32_t after = before & ~certain;
                    // Preserve a contradictory singleton for Verify rather
                    // than replacing it with an invalid empty candidate set.
                    if (after != 0 && after != before) {
                        masks[peer] = after;
                        passChanged = true;
                    }
                }
            }

            // If an item occurs in only one cell, that cell is forced even
            // when it still displays several candidate pictures.
            for (int item = 0; item < size; ++item) {
                const std::uint32_t itemBit = std::uint32_t(1) << item;
                int onlyColumn = -1;
                int occurrences = 0;
                for (int col = 0; col < size; ++col) {
                    const std::size_t cell =
                        static_cast<std::size_t>(row * size + col);
                    if ((masks[cell] & fullMask & itemBit) != 0) {
                        onlyColumn = col;
                        if (++occurrences > 1)
                            break;
                    }
                }
                if (occurrences == 1) {
                    const std::size_t cell =
                        static_cast<std::size_t>(row * size + onlyColumn);
                    if (masks[cell] != itemBit) {
                        masks[cell] = itemBit;
                        passChanged = true;
                    }
                }
            }
        }

        if (!passChanged)
            break;
        anyChange = true;
    }

    return anyChange;
}

} // namespace SherlockCandidates
