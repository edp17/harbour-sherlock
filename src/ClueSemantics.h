#pragma once
#include <QString>

enum class ClueType {
    GivenCell = 0,          // current behavior (fixed/given)
    // Future DOS-authentic types (Phase B2+):
    LeftOf,
    Above,
    SameRow,
    SameCol,
    NotSameRow,
    NotSameCol,
    IsInRow,
    IsInCol,
    NotInRow,
    NotInCol
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