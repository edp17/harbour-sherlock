#include "ClueSemantics.h"

static inline void swapInts(int &x, int &y) { int t = x; x = y; y = t; }

ClueSemantic normalizeClue(ClueSemantic c)
{
    // 1) Keep flags and payload consistent
    const bool hasC = (c.flags & ClueSemantic::HasC) != 0;

    if (!hasC) {
        c.c = -1;
        c.xMark = -1;
        c.flags &= ~ClueSemantic::CIsXbox;
    } else {
        // HasC set but c missing => drop HasC
        if (c.c < 0) {
            c.flags &= ~ClueSemantic::HasC;
            c.flags &= ~ClueSemantic::CIsXbox;
            c.xMark = -1;
            c.c = -1;
        }
    }

    // 2) Sanity rule: if we claim "C is X-boxed", ensure the X-boxed image is stored in `c`
    const bool hasCAfter = (c.flags & ClueSemantic::HasC) != 0;
    const bool cIsXbox   = (c.flags & ClueSemantic::CIsXbox) != 0;

    if (hasCAfter && cIsXbox) {
        // xMark tells which of (a,b,c) is excluded; normalize so excluded is always `c` (xMark==2)
        if (c.xMark == 0) {
            swapInts(c.a, c.c);
        } else if (c.xMark == 1) {
            swapInts(c.b, c.c);
        }
        c.xMark = 2;
    } else {
        // If not using the C-is-xbox convention, keep xMark only if it is in range
        if (!hasCAfter) {
            c.xMark = -1;
        } else {
            if (c.xMark < -1 || c.xMark > 2) c.xMark = -1;
        }
    }

    // 3) Canonical ordering to reduce duplicates for symmetric 2-image forms
    switch (c.type) {
    case ClueType::SameColumn:
    case ClueType::NotSameColumn:
    case ClueType::NextTo:
    case ClueType::NotNextTo:
        // Only canonicalize the 2-image form
        if ((c.flags & ClueSemantic::HasC) == 0) {
            if (c.a > c.b) swapInts(c.a, c.b);
        }
        break;

    case ClueType::SameColumnXor:
        // In XOR, B and C are symmetric: keep b <= c
        if ((c.flags & ClueSemantic::HasC) != 0 && c.c >= 0) {
            if (c.b > c.c) swapInts(c.b, c.c);
        }
        break;

    default:
        break;
    }

    return c;
}

// NOTE: This helper is optional. Your UI does not rely on this text for rendering.
// It only accepts (nameA, nameB) in the header right now, so for 3-image clues
// we fall back to printing c.c as a number.
QString clueToText(const ClueSemantic &c, const QString &nameA, const QString &nameB)
{
    const bool hasC = (c.flags & ClueSemantic::HasC) != 0;
    const bool cIsXbox = (c.flags & ClueSemantic::CIsXbox) != 0;

    const QString nameC = hasC ? QString::fromLatin1("#%1").arg(c.c) : QString();

    switch (c.type) {
    case ClueType::GivenCell:
        return QString("%1 is given").arg(nameA);

    case ClueType::LeftOf:
        return QString("%1 is left of %2").arg(nameA, nameB);

    case ClueType::SameColumn:
        if (hasC) {
            return QString("%1 is in the same column as %2 and %3").arg(nameA, nameB, nameC);
        }
        return QString("%1 and %2 are in the same column").arg(nameA, nameB);

    case ClueType::NotSameColumn:
        if (hasC) {
            if (cIsXbox)
                return QString("%1 and %2 are in the same column, but %3 is not").arg(nameA, nameB, nameC);
            return QString("Two of %1, %2, %3 are in the same column, and one is not").arg(nameA, nameB, nameC);
        }
        return QString("%1 and %2 are not in the same column").arg(nameA, nameB);

    case ClueType::SameColumnXor:
        // A is same column as either B or C, but not both
        return QString("%1 is in the same column as %2 XOR %3").arg(nameA, nameB, nameC);

    case ClueType::NextTo:
        if (hasC)
            return QString("%1 is next to %2, and %3 is two columns from %1").arg(nameA, nameB, nameC);
        return QString("%1 is next to %2").arg(nameA, nameB);

    case ClueType::NotNextTo:
        if (hasC) {
            if (cIsXbox)
                return QString("%1 and %3 have one column between them, and %2 is not in that column").arg(nameA, nameB, nameC);
            return QString("%1 and %3 have one column between them, and %2 is not in the middle").arg(nameA, nameB, nameC);
        }
        return QString("%1 is not next to %2").arg(nameA, nameB);

    case ClueType::IsInCol:
        return QString("%1 is in column %2").arg(nameA).arg(c.index + 1);

    case ClueType::NotInCol:
        return QString("%1 is not in column %2").arg(nameA).arg(c.index + 1);

    default:
        return QString("?");
    }
}
