#include "ClueSemantics.h"

static inline void swapInts(int &x, int &y) { int t = x; x = y; y = t; }

ClueSemantic normalizeClue(ClueSemantic c)
{
    // For symmetric relations, keep operands ordered
    switch (c.type) {
    case ClueType::SameRow:
    case ClueType::SameCol:
    case ClueType::NotSameRow:
    case ClueType::NotSameCol:
        if (c.a > c.b) swapInts(c.a, c.b);
        break;
    default:
        break;
    }
    return c;
}

QString clueToText(const ClueSemantic &c, const QString &nameA, const QString &nameB)
{
    switch (c.type) {
    case ClueType::GivenCell:  return QString("%1 is given").arg(nameA);
    case ClueType::LeftOf:     return QString("%1 is left of %2").arg(nameA, nameB);
    case ClueType::Above:      return QString("%1 is above %2").arg(nameA, nameB);
    case ClueType::SameRow:    return QString("%1 is in the same row as %2").arg(nameA, nameB);
    case ClueType::SameCol:    return QString("%1 is in the same column as %2").arg(nameA, nameB);
    case ClueType::NotSameRow: return QString("%1 is not in the same row as %2").arg(nameA, nameB);
    case ClueType::NotSameCol: return QString("%1 is not in the same column as %2").arg(nameA, nameB);
    case ClueType::IsInRow:    return QString("%1 is in row %2").arg(nameA).arg(c.index + 1);
    case ClueType::IsInCol:    return QString("%1 is in column %2").arg(nameA).arg(c.index + 1);
    case ClueType::NotInRow:   return QString("%1 is not in row %2").arg(nameA).arg(c.index + 1);
    case ClueType::NotInCol:   return QString("%1 is not in column %2").arg(nameA).arg(c.index + 1);
    default:                   return QString("?");
    }
}
