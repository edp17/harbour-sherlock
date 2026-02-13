#pragma once
#include <QString>

enum class ClueType {
    GivenCell = 0,

    // Horizontal ordering (DOS rule #4)
    LeftOf = 1,

    // Column alignment (DOS rules #1–#3)
    SameColumn = 2,          // 2–3 images are in the same column
    NotSameColumn = 3,       // 2 images NOT same col; OR 3 images where "x" image is NOT in that column
    SameColumnXor = 4,       // A is same column as (B xor C)

    // Column adjacency (DOS rules #5–#6)
    NextTo = 5,              // |col(A)-col(B)| = 1 (2-image form), optional 3-image form later
    NotNextTo = 6,           // 2-image: not adjacent; 3-image: A and C have one gap, B is NOT in the gap

    // Keep your direct placement (you already use these)
    IsInCol = 7,
    NotInCol = 8
};

struct ClueSemantic {
    ClueType type{ClueType::GivenCell};

    // Image payload: up to 3 images (a,b,c) as "item indices" in their respective rows
    int a = -1;
    int b = -1;
    int c = -1;          // optional (=-1 if unused)

    // Extra parameter meaning depends on type:
    // - LeftOf: unused (keep -1)
    // - IsInCol/NotInCol: index = column number
    int index = -1;

    // For 3-image variants where one image is "red X boxed"
    // - NotSameColumn: xMark says which of (a,b,c) is the excluded one
    // - NotNextTo (3-image): xMark indicates which image is excluded from the middle column (DOS shows X on the middle one)
    // Values: 0=a, 1=b, 2=c, -1 = none
    int xMark = -1;

    bool given = true;
};

// Canonicalization (keeps representation stable)
ClueSemantic normalizeClue(ClueSemantic c);

// Optional: deterministic text rendering (Phase B2/3 can wire this to UI if needed)
QString clueToText(const ClueSemantic &c, const QString &nameA, const QString &nameB);