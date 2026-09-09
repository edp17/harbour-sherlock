#include "HintSolver.h"

#include <algorithm>
#include <numeric>

namespace SherlockHints {
namespace {

using Permutation = std::vector<int>;

std::uint32_t bit(int item)
{
    return item >= 0 && item < 32 ? (std::uint32_t(1) << item) : 0;
}

bool singleton(std::uint32_t mask)
{
    return mask != 0 && (mask & (mask - 1)) == 0;
}

std::vector<Permutation> domainsForRow(
        int size, int row, const std::vector<std::uint32_t> &masks)
{
    std::vector<Permutation> domains;
    Permutation permutation(static_cast<std::size_t>(size));
    std::iota(permutation.begin(), permutation.end(), 0);
    do {
        bool fits = true;
        for (int col = 0; col < size; ++col) {
            const std::size_t cell = static_cast<std::size_t>(row * size + col);
            if ((masks[cell] & bit(permutation[static_cast<std::size_t>(col)])) == 0) {
                fits = false;
                break;
            }
        }
        if (fits)
            domains.push_back(permutation);
    } while (std::next_permutation(permutation.begin(), permutation.end()));
    return domains;
}

int columnOf(const Permutation &permutation, int item)
{
    const auto found = std::find(permutation.begin(), permutation.end(), item);
    return found == permutation.end() ? -1
                                      : static_cast<int>(found - permutation.begin());
}

bool clueHolds(const SherlockClues::Clue &clue,
               const std::vector<int> &rows,
               const std::vector<const Permutation *> &chosen)
{
    auto endpointColumn = [&](int row, int item) {
        const auto found = std::find(rows.begin(), rows.end(), row);
        if (found == rows.end())
            return -1;
        const std::size_t index = static_cast<std::size_t>(found - rows.begin());
        return columnOf(*chosen[index], item);
    };

    const bool hasC = (clue.flags & 1) != 0 && clue.c >= 0;
    const int a = endpointColumn(clue.aRow, clue.a);
    const int b = endpointColumn(clue.bRow, clue.b);
    const int c = hasC ? endpointColumn(clue.cRow, clue.c) : -1;
    if (a < 0 || b < 0 || (hasC && c < 0))
        return false;

    switch (clue.type) {
    case SherlockClues::SameColumn:
        return a == b && (!hasC || a == c);
    case SherlockClues::NotSameColumn:
        return hasC ? (a == b && c != a) : (a != b);
    case SherlockClues::SameColumnXor:
        return hasC && ((a == b) != (a == c));
    case SherlockClues::LeftOf:
        return a < b;
    case SherlockClues::NextTo:
        return std::abs(a - b) == 1 &&
               (!hasC || (std::abs(b - c) == 1 && std::abs(a - c) == 2));
    case SherlockClues::NotNextTo:
        return hasC ? (std::abs(a - c) == 2 && b != (a + c) / 2)
                    : std::abs(a - b) != 1;
    default:
        return false;
    }
}

void collectAllowed(const SherlockClues::Clue &clue, int size,
                    const std::vector<int> &rows,
                    const std::vector<std::vector<Permutation>> &domains,
                    std::size_t depth,
                    std::vector<const Permutation *> &chosen,
                    std::vector<std::uint32_t> &allowed,
                    bool &found)
{
    if (depth < rows.size()) {
        for (const Permutation &permutation : domains[depth]) {
            chosen[depth] = &permutation;
            collectAllowed(clue, size, rows, domains, depth + 1,
                           chosen, allowed, found);
        }
        return;
    }

    if (!clueHolds(clue, rows, chosen))
        return;

    found = true;
    for (std::size_t r = 0; r < rows.size(); ++r) {
        for (int col = 0; col < size; ++col) {
            const int cell = rows[r] * size + col;
            allowed[static_cast<std::size_t>(cell)] |=
                bit((*chosen[r])[static_cast<std::size_t>(col)]);
        }
    }
}

} // namespace

Hint find(int size, const std::vector<std::uint32_t> &masks,
          const std::vector<std::uint8_t> &fixed,
          const std::vector<int> &solution,
          const std::vector<SherlockClues::Clue> &clues)
{
    const std::size_t cells = static_cast<std::size_t>(size * size);
    if (size < 2 || masks.size() != cells || fixed.size() != cells ||
            solution.size() != cells)
        return {};

    Hint firstElimination;
    for (std::size_t clueIndex = 0; clueIndex < clues.size(); ++clueIndex) {
        const SherlockClues::Clue &clue = clues[clueIndex];
        const bool hasC = (clue.flags & 1) != 0 && clue.c >= 0;

        std::vector<int> rows{clue.aRow, clue.bRow};
        if (hasC)
            rows.push_back(clue.cRow);
        std::sort(rows.begin(), rows.end());
        rows.erase(std::unique(rows.begin(), rows.end()), rows.end());
        if (rows.empty() || rows.size() > 2 || rows.front() < 0 ||
                rows.back() >= size)
            continue;

        std::vector<std::vector<Permutation>> domains;
        bool domainsValid = true;
        for (int row : rows) {
            domains.push_back(domainsForRow(size, row, masks));
            if (domains.back().empty()) {
                domainsValid = false;
                break;
            }
        }
        if (!domainsValid)
            continue;

        std::vector<std::uint32_t> allowed(cells, 0);
        std::vector<std::uint32_t> beforeClue(cells, 0);
        for (std::size_t r = 0; r < rows.size(); ++r) {
            for (const Permutation &permutation : domains[r]) {
                for (int col = 0; col < size; ++col) {
                    const int cell = rows[r] * size + col;
                    beforeClue[static_cast<std::size_t>(cell)] |=
                        bit(permutation[static_cast<std::size_t>(col)]);
                }
            }
        }
        std::vector<const Permutation *> chosen(rows.size(), nullptr);
        bool found = false;
        collectAllowed(clue, size, rows, domains, 0, chosen, allowed, found);
        if (!found)
            continue;

        // Prefer a positive placement: it is the clearest hint to apply.
        for (int row : rows) {
            for (int col = 0; col < size; ++col) {
                const int cell = row * size + col;
                const std::uint32_t current = masks[static_cast<std::size_t>(cell)];
                const std::uint32_t possible = allowed[static_cast<std::size_t>(cell)];
                const std::uint32_t previous = beforeClue[static_cast<std::size_t>(cell)];
                if (fixed[static_cast<std::size_t>(cell)] || singleton(current) ||
                        !singleton(possible) || singleton(previous) ||
                        possible != bit(solution[static_cast<std::size_t>(cell)]))
                    continue;
                int item = 0;
                while ((possible & bit(item)) == 0)
                    ++item;
                return {MakeCertain, cell, item, static_cast<int>(clueIndex)};
            }
        }

        // Otherwise retain the first candidate which this clue rules out.
        if (firstElimination.action == NoAction) {
            for (int row : rows) {
                for (int col = 0; col < size; ++col) {
                    const int cell = row * size + col;
                    if (fixed[static_cast<std::size_t>(cell)] ||
                            singleton(masks[static_cast<std::size_t>(cell)]))
                        continue;
                    std::uint32_t removable =
                        masks[static_cast<std::size_t>(cell)] &
                        beforeClue[static_cast<std::size_t>(cell)] &
                        ~allowed[static_cast<std::size_t>(cell)] &
                        ~bit(solution[static_cast<std::size_t>(cell)]);
                    for (int item = 0; item < size; ++item) {
                        if (removable & bit(item)) {
                            firstElimination = {Eliminate, cell, item,
                                                static_cast<int>(clueIndex)};
                            break;
                        }
                    }
                    if (firstElimination.action != NoAction)
                        break;
                }
                if (firstElimination.action != NoAction)
                    break;
            }
        }
    }
    if (firstElimination.action != NoAction)
        return firstElimination;

    // Some clue eliminations only become a placement after applying the
    // row rule (every item occurs exactly once). That deduction has no single
    // clue card, so return it without a clue index rather than attributing it
    // to an unrelated card.
    Hint rowElimination;
    for (int row = 0; row < size; ++row) {
        const std::vector<Permutation> domains = domainsForRow(size, row, masks);
        if (domains.empty())
            continue;
        std::vector<std::uint32_t> possible(static_cast<std::size_t>(size), 0);
        for (const Permutation &permutation : domains) {
            for (int col = 0; col < size; ++col)
                possible[static_cast<std::size_t>(col)] |=
                    bit(permutation[static_cast<std::size_t>(col)]);
        }
        for (int col = 0; col < size; ++col) {
            const int cell = row * size + col;
            const std::uint32_t current = masks[static_cast<std::size_t>(cell)];
            const std::uint32_t allowed = possible[static_cast<std::size_t>(col)];
            if (fixed[static_cast<std::size_t>(cell)] || singleton(current))
                continue;
            if (singleton(allowed) &&
                    allowed == bit(solution[static_cast<std::size_t>(cell)])) {
                int item = 0;
                while ((allowed & bit(item)) == 0)
                    ++item;
                return {MakeCertain, cell, item, -1};
            }
            if (rowElimination.action == NoAction) {
                const std::uint32_t removable =
                    current & ~allowed & ~bit(solution[static_cast<std::size_t>(cell)]);
                for (int item = 0; item < size; ++item) {
                    if (removable & bit(item)) {
                        rowElimination = {Eliminate, cell, item, -1};
                        break;
                    }
                }
            }
        }
    }
    return rowElimination;
}

} // namespace SherlockHints
