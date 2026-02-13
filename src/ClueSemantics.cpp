#include "ClueSemantics.h"

static inline void swapInts(int &x, int &y) { int t = x; x = y; y = t; }

ClueSemantic normalizeClue(ClueSemantic s)
{
    // flags bits (must match what GamePage expects)
    const int HasC    = 1; // third image present
    const int CIsXbox = 2; // red-X box is on the C image (rendering convention)

    // 1) Make flags and payload consistent
    if ((s.flags & HasC) == 0) {
        // No third image -> force C-related fields off
        s.c = -1;
        s.xMark = -1;
        s.flags &= ~CIsXbox;
    } else {
        // HasC requested, but C missing -> drop HasC
        if (s.c < 0) {
            s.flags &= ~HasC;
            s.flags &= ~CIsXbox;
            s.xMark = -1;
        }
    }

    // 2) If we claim "C is X-boxed", enforce that the X-boxed image IS actually stored in `c`
    //    (because UI paints the red-X on the C slot).
    if ((s.flags & HasC) && (s.flags & CIsXbox)) {
        // xMark tells which of (a,b,c) is the excluded/X one. Normalize to xMark==2 (C).
        if (s.xMark == 0) {
            swapInts(s.a, s.c);
        } else if (s.xMark == 1) {
            swapInts(s.b, s.c);
        }
        s.xMark = 2;
    } else {
        // If not CIsXbox, keep xMark only if it makes sense; otherwise clear it.
        if ((s.flags & HasC) == 0)
            s.xMark = -1;
        else if (s.xMark < -1 || s.xMark > 2)
            s.xMark = -1;
    }

    // 3) Canonical order for symmetric 2-image clue forms:
    //    SameColumn / NotSameColumn / NextTo / NotNextTo:
    //    In the 2-image form, the pair is unordered, so keep (a <= b) to reduce duplicates.
    switch (s.type) {
    case ClueType::SameColumn:
    case ClueType::NotSameColumn:
    case ClueType::NextTo:
    case ClueType::NotNextTo:
        if ((s.flags & HasC) == 0) {
            if (s.a > s.b) swapInts(s.a, s.b);
        }
        break;

    // For XOR with 3 images, B and C are symmetric (either/or set), so normalize b<=c.
    case ClueType::SameColumnXor:
        if ((s.flags & HasC) && s.c >= 0) {
            if (s.b > s.c) swapInts(s.b, s.c);
        }
        break;

    default:
        break;
    }

    return s;
}

QString clueToText(const ClueSemantic &c, const QString &nameA, const QString &nameB)
{
    switch (c.type) {
    case ClueType::SameColumn:
        if (hasC)
            return QString("%1 is in the same column as %2 or %3 (not both)").arg(nameA, nameB, nameC); // only if you use SameColumnXor; see below
        return QString("%1 and %2 are in the same column").arg(nameA, nameB);

    case ClueType::NotSameColumn:
        if (hasC) {
            // cIsXbox means nameC is the excluded one (red-X box), by our normalization
            if (cIsXbox)
                return QString("%1 and %2 are in the same column, but %3 is not").arg(nameA, nameB, nameC);
            // fallback wording if flags inconsistent
            return QString("Two of %1, %2, %3 are in the same column, and one is not").arg(nameA, nameB, nameC);
        }
        return QString("%1 and %2 are not in the same column").arg(nameA, nameB);

    case ClueType::LeftOf:
        return QString("%1 is left of %2").arg(nameA, nameB);

    case ClueType::NextTo:
        if (hasC)
            return QString("%1 is next to %2, and %3 is two columns from %1").arg(nameA, nameB, nameC);
        return QString("%1 is next to %2").arg(nameA, nameB);

    case ClueType::NotNextTo:
        if (hasC) {
            if (cIsXbox)
                return QString("%1 and %3 have exactly one column between them, and %2 is not in that column").arg(nameA, nameB, nameC);
            return QString("%1 and %3 have exactly one column between them, and %2 is not in the middle").arg(nameA, nameB, nameC);
        }
        return QString("%1 is not next to %2").arg(nameA, nameB);

    case ClueType::IsInCol:
        return QString("%1 is in column %2").arg(nameA).arg(c.index + 1);

    case ClueType::NotInCol:
        return QString("%1 is not in column %2").arg(nameA).arg(c.index + 1);

    default:
        break;
    }
}
