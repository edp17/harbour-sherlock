#include "ClueGenerator.h"

#include <algorithm>
#include <cstdlib>
#include <limits>
#include <numeric>
#include <set>
#include <string>

namespace SherlockClues {
namespace {

constexpr int HasC = 1;

std::uint32_t nextRandom(std::uint32_t &state)
{
    if (state == 0)
        state = 1;
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

template<typename T>
void shuffle(std::vector<T> &values, std::uint32_t &state)
{
    for (std::size_t i = values.size(); i > 1; --i) {
        const std::size_t other = nextRandom(state) % i;
        std::swap(values[i - 1], values[other]);
    }
}

int columnOf(int size, const std::vector<int> &solution, int row, int item)
{
    if (row < 0 || row >= size || item < 0 || item >= size)
        return -1;

    for (int col = 0; col < size; ++col) {
        if (solution[static_cast<std::size_t>(row * size + col)] == item)
            return col;
    }
    return -1;
}

bool validInput(int size, const std::vector<int> &solution,
                const std::vector<std::uint8_t> &fixed)
{
    const std::size_t cells = static_cast<std::size_t>(size * size);
    if (size < 2 || solution.size() != cells || fixed.size() != cells)
        return false;

    for (int row = 0; row < size; ++row) {
        std::vector<bool> seen(static_cast<std::size_t>(size), false);
        for (int col = 0; col < size; ++col) {
            const int item = solution[static_cast<std::size_t>(row * size + col)];
            if (item < 0 || item >= size || seen[static_cast<std::size_t>(item)])
                return false;
            seen[static_cast<std::size_t>(item)] = true;
        }
    }
    return true;
}

std::string signature(const Clue &clue)
{
    return std::to_string(clue.type) + ":" +
           std::to_string(clue.aRow) + ":" + std::to_string(clue.a) + ":" +
           std::to_string(clue.bRow) + ":" + std::to_string(clue.b) + ":" +
           std::to_string(clue.cRow) + ":" + std::to_string(clue.c);
}

Group *groupAt(Result &result, int orient, int index)
{
    for (Group &group : result.groups) {
        if (group.orient == orient && group.index == index)
            return &group;
    }
    return nullptr;
}

void appendUnique(Result &result, const Clue &clue, std::set<std::string> &seen)
{
    if (!seen.insert(signature(clue)).second)
        return;
    Group *group = groupAt(result, clue.orient, clue.index);
    if (group)
        group->clues.push_back(clue);
}

int clueCount(const Result &result, int orient)
{
    int count = 0;
    for (const Group &group : result.groups) {
        if (group.orient == orient)
            count += static_cast<int>(group.clues.size());
    }
    return count;
}

using Permutation = std::vector<int>;

std::vector<Permutation> rowDomains(int size, int row,
                                    const std::vector<int> &solution,
                                    const std::vector<std::uint8_t> &fixed)
{
    std::vector<Permutation> domains;
    Permutation permutation(static_cast<std::size_t>(size));
    std::iota(permutation.begin(), permutation.end(), 0);
    do {
        bool fits = true;
        for (int col = 0; col < size; ++col) {
            const std::size_t cell = static_cast<std::size_t>(row * size + col);
            if (fixed[cell] && permutation[static_cast<std::size_t>(col)] != solution[cell]) {
                fits = false;
                break;
            }
        }
        if (fits)
            domains.push_back(permutation);
    } while (std::next_permutation(permutation.begin(), permutation.end()));
    return domains;
}

int columnInPermutation(const Permutation &permutation, int item)
{
    const auto found = std::find(permutation.begin(), permutation.end(), item);
    return found == permutation.end() ? -1
                                      : static_cast<int>(found - permutation.begin());
}

bool holdsForRow(const Clue &clue, int size, int row,
                 const Permutation &permutation,
                 const std::vector<int> &solution)
{
    auto endpointColumn = [&](int endpointRow, int item) {
        return endpointRow == row
             ? columnInPermutation(permutation, item)
             : columnOf(size, solution, endpointRow, item);
    };

    const int a = endpointColumn(clue.aRow, clue.a);
    const int b = endpointColumn(clue.bRow, clue.b);
    const bool hasC = (clue.flags & HasC) != 0 && clue.c >= 0;
    const int c = hasC ? endpointColumn(clue.cRow, clue.c) : -1;
    if (a < 0 || b < 0 || (hasC && c < 0))
        return false;

    switch (clue.type) {
    case SameColumn:
        return a == b && (!hasC || a == c);
    case NotSameColumn:
        return hasC ? (a == b && c != a) : (a != b);
    case SameColumnXor:
        return hasC && ((a == b) != (a == c));
    case LeftOf:
        return a < b;
    case NextTo:
        return std::abs(a - b) == 1 &&
               (!hasC || (std::abs(b - c) == 1 && std::abs(a - c) == 2));
    case NotNextTo:
        return hasC ? (std::abs(a - c) == 2 && b != (a + c) / 2)
                    : std::abs(a - b) != 1;
    default:
        return false;
    }
}

std::vector<Clue> horizontalCandidates(int size, int row,
                                       const std::vector<int> &solution)
{
    auto itemAt = [&](int col) {
        return solution[static_cast<std::size_t>(row * size + col)];
    };
    std::vector<Clue> candidates;

    for (int left = 0; left < size; ++left) {
        for (int right = left + 1; right < size; ++right) {
            Clue clue;
            clue.type = LeftOf;
            clue.orient = Horizontal;
            clue.index = row;
            clue.aRow = clue.bRow = row;
            clue.aCol = left;
            clue.bCol = right;
            clue.a = itemAt(left);
            clue.b = itemAt(right);
            candidates.push_back(clue);
        }
    }

    for (int left = 0; left + 1 < size; ++left) {
        Clue clue;
        clue.type = NextTo;
        clue.orient = Horizontal;
        clue.index = row;
        clue.aRow = clue.bRow = row;
        clue.aCol = left;
        clue.bCol = left + 1;
        clue.a = itemAt(left);
        clue.b = itemAt(left + 1);
        candidates.push_back(clue);
    }

    for (int left = 0; left + 2 < size; ++left) {
        Clue clue;
        clue.type = NextTo;
        clue.orient = Horizontal;
        clue.index = row;
        clue.aRow = clue.bRow = clue.cRow = row;
        clue.aCol = left;
        clue.bCol = left + 1;
        clue.cCol = left + 2;
        clue.a = itemAt(left);
        clue.b = itemAt(left + 1);
        clue.c = itemAt(left + 2);
        clue.flags = HasC;
        candidates.push_back(clue);
    }

    for (int aCol = 0; aCol < size; ++aCol) {
        for (int bCol = aCol + 2; bCol < size; ++bCol) {
            Clue clue;
            clue.type = NotNextTo;
            clue.orient = Horizontal;
            clue.index = row;
            clue.aRow = clue.bRow = row;
            clue.aCol = aCol;
            clue.bCol = bCol;
            clue.a = itemAt(aCol);
            clue.b = itemAt(bCol);
            clue.xMark = 1;
            candidates.push_back(clue);
        }
    }

    // The outer icons are two columns apart; the crossed icon is not between
    // them. This is the classic three-picture "not between" card.
    for (int left = 0; left + 2 < size; ++left) {
        for (int excluded = 0; excluded < size; ++excluded) {
            if (excluded >= left && excluded <= left + 2)
                continue;
            Clue clue;
            clue.type = NotNextTo;
            clue.orient = Horizontal;
            clue.index = row;
            clue.aRow = clue.bRow = clue.cRow = row;
            clue.aCol = left;
            clue.bCol = excluded;
            clue.cCol = left + 2;
            clue.a = itemAt(left);
            clue.b = itemAt(excluded);
            clue.c = itemAt(left + 2);
            clue.xMark = 1;
            clue.flags = HasC;
            candidates.push_back(clue);
        }
    }
    return candidates;
}

std::vector<Clue> verticalCandidates(int size, int referenceRow, int row,
                                     const std::vector<int> &solution)
{
    auto itemAt = [&](int sourceRow, int col) {
        return solution[static_cast<std::size_t>(sourceRow * size + col)];
    };
    std::vector<Clue> candidates;

    for (int col = 0; col < size; ++col) {
        Clue same;
        same.type = SameColumn;
        same.orient = Vertical;
        same.index = col;
        same.aRow = referenceRow;
        same.bRow = row;
        same.aCol = same.bCol = col;
        same.a = itemAt(referenceRow, col);
        same.b = itemAt(row, col);
        candidates.push_back(same);

        for (int other = 0; other < size; ++other) {
            if (other == col)
                continue;

            Clue notSame;
            notSame.type = NotSameColumn;
            notSame.orient = Vertical;
            notSame.index = col;
            notSame.aRow = referenceRow;
            notSame.bRow = row;
            notSame.aCol = col;
            notSame.bCol = other;
            notSame.a = itemAt(referenceRow, col);
            notSame.b = itemAt(row, other);
            notSame.xMark = 1;
            candidates.push_back(notSame);

            Clue eitherOr;
            eitherOr.type = SameColumnXor;
            eitherOr.orient = Vertical;
            eitherOr.index = col;
            eitherOr.aRow = referenceRow;
            eitherOr.bRow = eitherOr.cRow = row;
            eitherOr.aCol = eitherOr.bCol = col;
            eitherOr.cCol = other;
            eitherOr.a = itemAt(referenceRow, col);
            eitherOr.b = itemAt(row, col);
            eitherOr.c = itemAt(row, other);
            eitherOr.flags = HasC;
            candidates.push_back(eitherOr);

            Clue excludedFromColumn = same;
            excludedFromColumn.type = NotSameColumn;
            excludedFromColumn.cRow = row;
            excludedFromColumn.cCol = other;
            excludedFromColumn.c = itemAt(row, other);
            excludedFromColumn.xMark = 2;
            excludedFromColumn.flags = HasC;
            candidates.push_back(excludedFromColumn);
        }
    }
    return candidates;
}

int survivingCount(const Clue &clue, int size, int row,
                   const std::vector<Permutation> &domains,
                   const std::vector<int> &active,
                   const std::vector<int> &solution)
{
    int count = 0;
    for (int index : active) {
        if (holdsForRow(clue, size, row,
                        domains[static_cast<std::size_t>(index)], solution))
            ++count;
    }
    return count;
}

void applyClueToDomains(const Clue &clue, int size, int row,
                        const std::vector<Permutation> &domains,
                        std::vector<int> &active,
                        const std::vector<int> &solution)
{
    active.erase(std::remove_if(active.begin(), active.end(), [&](int index) {
        return !holdsForRow(clue, size, row,
                            domains[static_cast<std::size_t>(index)], solution);
    }), active.end());
}

struct SelectedClue {
    Clue clue;
};

std::vector<SelectedClue> selectRowClues(
        int size, int row, const std::vector<int> &solution,
        const std::vector<std::uint8_t> &fixed,
        const std::vector<Clue> &candidates,
        const std::vector<int> &requiredTypes,
        int verticalBias,
        std::uint32_t &randomState)
{
    const std::vector<Permutation> domains = rowDomains(size, row, solution, fixed);
    std::vector<int> active(domains.size());
    std::iota(active.begin(), active.end(), 0);
    std::vector<SelectedClue> selected;
    std::set<std::string> used;

    auto addBestOfType = [&](int type, bool preferThreeIcon) {
        int best = -1;
        int bestScore = -1;
        for (std::size_t i = 0; i < candidates.size(); ++i) {
            const Clue &candidate = candidates[i];
            if (candidate.type != type || used.count(signature(candidate)))
                continue;
            const bool threeIcon = (candidate.flags & HasC) != 0;
            const int survivors = survivingCount(candidate, size, row, domains,
                                                  active, solution);
            if (survivors <= 0 || survivors >= static_cast<int>(active.size()))
                continue;

            // Prefer a useful middle-sized deduction. This avoids both direct
            // giveaways and very weak cards that merely inflate the panel.
            const int target = std::max(1, static_cast<int>(active.size()) * 45 / 100);
            int score = -std::abs(survivors - target) * 32;
            if (threeIcon == preferThreeIcon)
                score += 8;
            score += static_cast<int>(nextRandom(randomState) & 7u);
            if (score > bestScore) {
                bestScore = score;
                best = static_cast<int>(i);
            }
        }
        if (best >= 0) {
            const Clue clue = candidates[static_cast<std::size_t>(best)];
            selected.push_back(SelectedClue{clue});
            used.insert(signature(clue));
            applyClueToDomains(clue, size, row, domains, active, solution);
        }
    };

    for (std::size_t i = 0; i < requiredTypes.size() && active.size() > 1; ++i) {
        const bool preferThreeIcon = ((nextRandom(randomState) + i) % 3u) == 0u;
        addBestOfType(requiredTypes[i], preferThreeIcon);
    }

    while (active.size() > 1) {
        int best = -1;
        int bestScore = std::numeric_limits<int>::min();
        for (std::size_t i = 0; i < candidates.size(); ++i) {
            const Clue &candidate = candidates[i];
            if (used.count(signature(candidate)))
                continue;
            const int survivors = survivingCount(candidate, size, row, domains,
                                                  active, solution);
            if (survivors <= 0 || survivors >= static_cast<int>(active.size()))
                continue;
            const int eliminated = static_cast<int>(active.size()) - survivors;
            int score = eliminated * 1000 / static_cast<int>(active.size());
            if (candidate.orient == Vertical)
                score += verticalBias;
            if (candidate.type == SameColumn)
                score -= 80;
            if (candidate.type == NotSameColumn && (candidate.flags & HasC))
                score -= 110;
            score += static_cast<int>(nextRandom(randomState) & 31u);
            if (score > bestScore) {
                bestScore = score;
                best = static_cast<int>(i);
            }
        }
        if (best < 0)
            break;
        const Clue clue = candidates[static_cast<std::size_t>(best)];
        selected.push_back(SelectedClue{clue});
        used.insert(signature(clue));
        applyClueToDomains(clue, size, row, domains, active, solution);
    }

    // Remove accidental redundancy, including a featured-family card when
    // the remaining cards already prove this row. Global family variety is
    // restored below only where the complete puzzle still needs it.
    for (std::size_t remove = selected.size(); remove > 0; --remove) {
        const std::size_t index = remove - 1;
        std::vector<int> trial(domains.size());
        std::iota(trial.begin(), trial.end(), 0);
        for (std::size_t i = 0; i < selected.size(); ++i) {
            if (i != index)
                applyClueToDomains(selected[i].clue, size, row, domains, trial, solution);
        }
        if (trial.size() == 1)
            selected.erase(selected.begin() + static_cast<std::ptrdiff_t>(index));
    }
    return selected;
}

bool clueAffectsRow(const Clue &clue, int row, int referenceRow)
{
    if (row == referenceRow)
        return clue.orient == Horizontal && clue.aRow == row;

    const bool hasC = (clue.flags & HasC) != 0 && clue.c >= 0;
    return clue.aRow == row || clue.bRow == row ||
           (hasC && clue.cRow == row);
}

void minimizeHardResult(Result &result, int size, int referenceRow,
                        const std::vector<int> &solution,
                        const std::vector<std::uint8_t> &fixed)
{
    int typeCounts[NotNextTo + 1] = {};
    int orientationCounts[2] = {};
    int distinctTypes = 0;
    for (const Group &group : result.groups) {
        for (const Clue &clue : group.clues) {
            ++orientationCounts[clue.orient];
            if (clue.type >= LeftOf && clue.type <= NotNextTo) {
                if (typeCounts[clue.type]++ == 0)
                    ++distinctTypes;
            }
        }
    }

    const int minimumTypes = size >= 5 ? 5 : 0;
    for (std::size_t groupPos = result.groups.size(); groupPos > 0; --groupPos) {
        Group &group = result.groups[groupPos - 1];
        for (std::size_t cluePos = group.clues.size(); cluePos > 0; --cluePos) {
            const std::size_t removeIndex = cluePos - 1;
            const Clue candidate = group.clues[removeIndex];
            if (orientationCounts[candidate.orient] <= 1)
                continue;
            if (candidate.type >= LeftOf && candidate.type <= NotNextTo &&
                    typeCounts[candidate.type] == 1 &&
                    distinctTypes <= minimumTypes) {
                continue;
            }

            const int targetRow = candidate.orient == Horizontal
                                ? candidate.aRow
                                : (candidate.aRow == referenceRow
                                   ? candidate.bRow : candidate.aRow);
            if (targetRow < 0 || targetRow >= size)
                continue;

            const std::vector<Permutation> domains =
                rowDomains(size, targetRow, solution, fixed);
            std::vector<int> active(domains.size());
            std::iota(active.begin(), active.end(), 0);

            for (std::size_t otherGroupPos = 0;
                 otherGroupPos < result.groups.size(); ++otherGroupPos) {
                const Group &otherGroup = result.groups[otherGroupPos];
                for (std::size_t otherCluePos = 0;
                     otherCluePos < otherGroup.clues.size(); ++otherCluePos) {
                    if (otherGroupPos == groupPos - 1 &&
                            otherCluePos == removeIndex) {
                        continue;
                    }
                    const Clue &other = otherGroup.clues[otherCluePos];
                    if (clueAffectsRow(other, targetRow, referenceRow)) {
                        applyClueToDomains(other, size, targetRow, domains,
                                           active, solution);
                    }
                }
            }

            if (active.size() == 1) {
                group.clues.erase(group.clues.begin() +
                                  static_cast<std::ptrdiff_t>(removeIndex));
                --orientationCounts[candidate.orient];
                if (candidate.type >= LeftOf && candidate.type <= NotNextTo &&
                        --typeCounts[candidate.type] == 0) {
                    --distinctTypes;
                }
            }
        }
    }
}

} // namespace

bool holds(const Clue &clue, int size, const std::vector<int> &solution)
{
    const std::vector<std::uint8_t> noFixed(solution.size(), 0);
    if (!validInput(size, solution, noFixed))
        return false;

    const int aCol = columnOf(size, solution, clue.aRow, clue.a);
    const int bCol = columnOf(size, solution, clue.bRow, clue.b);
    const bool hasC = (clue.flags & HasC) != 0 && clue.c >= 0;
    const int cCol = hasC ? columnOf(size, solution, clue.cRow, clue.c) : -1;
    if (aCol < 0 || bCol < 0 || (hasC && cCol < 0))
        return false;

    switch (clue.type) {
    case SameColumn:
        return aCol == bCol && (!hasC || aCol == cCol);
    case NotSameColumn:
        return hasC ? (aCol == bCol && cCol != aCol) : (aCol != bCol);
    case SameColumnXor:
        return hasC && ((aCol == bCol) != (aCol == cCol));
    case LeftOf:
        return aCol < bCol;
    case NextTo:
        return std::abs(aCol - bCol) == 1 &&
               (!hasC || (std::abs(bCol - cCol) == 1 &&
                          std::abs(aCol - cCol) == 2));
    case NotNextTo:
        if (!hasC)
            return std::abs(aCol - bCol) != 1;
        return std::abs(aCol - cCol) == 2 && bCol != (aCol + cCol) / 2;
    default:
        return false;
    }
}

Result generate(int size, const std::vector<int> &solution,
                const std::vector<std::uint8_t> &fixed,
                std::uint32_t seed, int difficulty)
{
    Result result;
    if (!validInput(size, solution, fixed))
        return result;

    difficulty = std::max(int(Easy), std::min(int(Hard), difficulty));
    result.groups.reserve(static_cast<std::size_t>(size * 2));
    for (int index = 0; index < size; ++index) {
        result.groups.push_back(Group{Vertical, index, {}});
        result.groups.push_back(Group{Horizontal, index, {}});
    }

    auto isFixed = [&](int row, int col) {
        return fixed[static_cast<std::size_t>(row * size + col)] != 0;
    };

    // The most-constrained row is cheapest to establish as the reference.
    // Seeded tie-breaking prevents every puzzle from using the same category.
    int referenceRow = static_cast<int>(seed % static_cast<std::uint32_t>(size));
    int mostGivens = -1;
    for (int offset = 0; offset < size; ++offset) {
        const int row = (referenceRow + offset) % size;
        int count = 0;
        for (int col = 0; col < size; ++col)
            count += isFixed(row, col) ? 1 : 0;
        if (count > mostGivens) {
            mostGivens = count;
            referenceRow = row;
        }
    }

    std::set<std::string> seen;
    std::uint32_t randomState = seed ^ 0x9e3779b9u;

    // Establish one category from genuine ordering/neighbour clues. Once this
    // reference row is known, vertical cards can relate every other category
    // to it without resorting to direct placement-number clues.
    const std::vector<Clue> referenceCandidates =
        horizontalCandidates(size, referenceRow, solution);
    std::vector<int> referenceRequired{LeftOf};
    const std::vector<SelectedClue> referenceClues = selectRowClues(
        size, referenceRow, solution, fixed, referenceCandidates,
        referenceRequired, 0, randomState);
    for (const SelectedClue &selected : referenceClues)
        appendUnique(result, selected.clue, seen);

    std::vector<int> targetRows;
    for (int offset = 1; offset < size; ++offset)
        targetRows.push_back((referenceRow + offset) % size);
    shuffle(targetRows, randomState);
    auto givenCountForRow = [&](int row) {
        int count = 0;
        for (int col = 0; col < size; ++col)
            count += isFixed(row, col) ? 1 : 0;
        return count;
    };
    std::stable_sort(targetRows.begin(), targetRows.end(), [&](int a, int b) {
        return givenCountForRow(a) < givenCountForRow(b);
    });

    const int palette[] = {SameColumn, NotSameColumn, SameColumnXor,
                           NextTo, NotNextTo};
    const int paletteSize = static_cast<int>(sizeof(palette) / sizeof(palette[0]));
    const int paletteOffset = static_cast<int>((seed >> 8) % paletteSize);

    for (std::size_t rowIndex = 0; rowIndex < targetRows.size(); ++rowIndex) {
        const int row = targetRows[rowIndex];
        const std::vector<Clue> vertical = verticalCandidates(
            size, referenceRow, row, solution);
        const std::vector<Clue> horizontal = horizontalCandidates(size, row, solution);
        std::vector<Clue> candidates;
        std::vector<int> requiredTypes;

        if (rowIndex == 0) {
            // The least-constrained target row is vertical-only. This makes
            // the vertical panel essential and showcases all three column
            // clue families on larger boards.
            candidates = vertical;
            requiredTypes.push_back(NotSameColumn);
        } else if (rowIndex == 1) {
            // Keep horizontal relations essential, but do not leave a
            // low-given row dependent on an abstract permutation chain alone.
            // Vertical cards become concrete as soon as the reference row is
            // known and give the player candidate-by-candidate progress.
            if (size >= 6 && givenCountForRow(row) == 0) {
                candidates = horizontal;
                for (const Clue &candidate : vertical) {
                    if (candidate.type == SameColumn)
                        candidates.push_back(candidate);
                }
            } else {
                candidates = horizontal;
            }
            requiredTypes.push_back((seed & 2u) ? NextTo : NotNextTo);
            if (size >= 5)
                requiredTypes.push_back((seed & 2u) ? NotNextTo : NextTo);
        } else {
            candidates = vertical;
            candidates.insert(candidates.end(), horizontal.begin(), horizontal.end());
            int featuredType;
            if (rowIndex == 2)
                featuredType = SameColumnXor;
            else if (rowIndex == 3)
                featuredType = SameColumn;
            else
                featuredType = palette[(paletteOffset + static_cast<int>(rowIndex)) % paletteSize];
            if (featuredType == NextTo || featuredType == NotNextTo) {
                // A horizontal relation supplies variety while an indirect
                // vertical card keeps categories genuinely interdependent.
                requiredTypes.push_back(featuredType);
                requiredTypes.push_back(((rowIndex + seed) & 1u)
                                        ? NotSameColumn : SameColumnXor);
            } else {
                requiredTypes.push_back(featuredType);
            }
        }

        const std::vector<SelectedClue> rowClues = selectRowClues(
            size, row, solution, fixed, candidates, requiredTypes,
            (rowIndex < 2 || givenCountForRow(row) == 0) ? 220 : 150,
            randomState);
        for (const SelectedClue &selected : rowClues)
            appendUnique(result, selected.clue, seen);
    }

    // A large puzzle should never look as though it only understands two
    // relations. Preserve a compact set, but ensure at least five of the six
    // classic clue families are visible on every 5x5/6x6 Hard proof.
    if (size >= 5) {
        bool present[7] = {false, false, false, false, false, false, false};
        int distinct = 0;
        for (const Group &group : result.groups) {
            for (const Clue &clue : group.clues) {
                if (clue.type >= LeftOf && clue.type <= NotNextTo &&
                    !present[clue.type]) {
                    present[clue.type] = true;
                    ++distinct;
                }
            }
        }

        for (int missing = LeftOf; missing <= NotNextTo && distinct < 5; ++missing) {
            if (present[missing])
                continue;
            bool added = false;
            for (int row = 0; row < size && !added; ++row) {
                std::vector<Clue> candidates;
                if (missing == LeftOf || missing == NextTo || missing == NotNextTo) {
                    candidates = horizontalCandidates(size, row, solution);
                } else if (row != referenceRow) {
                    candidates = verticalCandidates(size, referenceRow, row, solution);
                }
                shuffle(candidates, randomState);
                for (const Clue &clue : candidates) {
                    if (clue.type != missing)
                        continue;
                    const int before = clueCount(result, clue.orient);
                    appendUnique(result, clue, seen);
                    if (clueCount(result, clue.orient) > before) {
                        present[missing] = true;
                        ++distinct;
                        added = true;
                        break;
                    }
                }
            }
        }
    }

    // Easier levels receive a few redundant, true relationship cards. The
    // compact Hard set is the one that demands the longest deduction chain.
    int bonus = difficulty == Easy ? std::max(3, size - 1)
                                   : (difficulty == Medium ? 2 : 0);
    std::vector<int> rows(static_cast<std::size_t>(size));
    std::iota(rows.begin(), rows.end(), 0);
    shuffle(rows, randomState);
    for (int row : rows) {
        std::vector<Clue> extras = horizontalCandidates(size, row, solution);
        if (row != referenceRow) {
            std::vector<Clue> vertical = verticalCandidates(
                size, referenceRow, row, solution);
            extras.insert(extras.end(), vertical.begin(), vertical.end());
        }
        shuffle(extras, randomState);
        for (const Clue &clue : extras) {
            if (bonus == 0)
                break;
            if ((clue.orient == Horizontal && clueCount(result, Horizontal) >= 12) ||
                (clue.orient == Vertical && clueCount(result, Vertical) >= 18))
                continue;
            const int before = clueCount(result, Horizontal);
            const int beforeVertical = clueCount(result, Vertical);
            appendUnique(result, clue, seen);
            if (clueCount(result, Horizontal) > before ||
                clueCount(result, Vertical) > beforeVertical)
                --bonus;
        }
        if (bonus == 0)
            break;
    }

    // Hard uses the smallest proof we can retain without losing orientation
    // coverage or the five-family visual variety promised by the UI.
    if (difficulty == Hard)
        minimizeHardResult(result, size, referenceRow, solution, fixed);

    result.valid = clueCount(result, Vertical) <= 18 &&
                   clueCount(result, Horizontal) <= 12;
    if (result.valid) {
        for (const Group &group : result.groups) {
            for (const Clue &clue : group.clues) {
                if (!holds(clue, size, solution)) {
                    result.valid = false;
                    break;
                }
            }
            if (!result.valid)
                break;
        }
    }
    return result;
}

} // namespace SherlockClues
