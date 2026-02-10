#pragma once
#include <QString>

enum class ClueType {
    GivenCell   = 0,

    // Positional (current)
    LeftOf      = 1,
    Above       = 2,

    // Same/Not-same (future)
    SameRow     = 3,
    SameCol     = 4,
    NotSameRow  = 5,
    NotSameCol  = 6,

    // Direct placement (we’ll use IsInCol now)
    IsInRow     = 7,
    IsInCol     = 8,
    NotInRow    = 9,
    NotInCol    = 10
};

struct ClueSemantic {
    ClueType type{ClueType::GivenCell};
    int a = -1;
    int b = -1;
    int index = -1;
    bool given = true;
};

// Canonicalization (keeps representation stable)
ClueSemantic normalizeClue(ClueSemantic c);

// Optional: deterministic text rendering (Phase B2/3 can wire this to UI if needed)
QString clueToText(const ClueSemantic &c, const QString &nameA, const QString &nameB);