#include "SherlockEngine.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QPainter>
#include <QFont>
#include <QSettings>
#include <QtGlobal>   // qrand/qsrand
#include <QDateTime>
#include <QFile>
#include <QTextStream>

#include "ShiReader.h"

SherlockEngine::SherlockEngine(QObject *parent)
    : QObject(parent)
{
    loadState();                  // loads m_size + m_iconSource + masks + fixed
    loadSherlockShiFromDataDir(); // may succeed/fail; does not force iconSource

    // If user selected SHI previously but images aren't available, force Generated
    if (m_iconSource == Shi && !m_hasImages) {
        m_iconSource = Generated;
        emit iconSourceChanged();
        ++m_iconEpoch;
        emit imagesChanged();
        saveState();
    }
    rebuildClues();
}

QVector<quint32>& SherlockEngine::bankSeedsForSize(int size)
{
    if (size == 4) return m_bankSeeds4;
    if (size == 5) return m_bankSeeds5;
    return m_bankSeeds6;
}

const QVector<quint32>& SherlockEngine::bankSeedsForSize(int size) const
{
    if (size == 4) return m_bankSeeds4;
    if (size == 5) return m_bankSeeds5;
    return m_bankSeeds6;
}

int SherlockEngine::bankCountForSize(int size)
{
    if (!ensureBankLoaded(size)) return 0;
    return bankSeedsForSize(size).size();
}

bool SherlockEngine::isSeedInBank(int size, quint32 seed) const
{
    const auto& v = bankSeedsForSize(size);
    for (quint32 s : v) {
        if (s == seed) return true;
    }
    return false;
}

static inline quint32 xorshift32(quint32 &state)
{
    if (state == 0) state = 1u;
    quint32 x = state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    state = x;
    return x;
}

static inline int bounded(quint32 &state, int hiExclusive)
{
    return int(xorshift32(state) % quint32(hiExclusive));
}

void SherlockEngine::setLastTouched(int row, int col)
{
    if (m_lastTouchedRow == row && m_lastTouchedCol == col)
        return;
    m_lastTouchedRow = row;
    m_lastTouchedCol = col;
    emit lastTouchedChanged();
}


QVariantList SherlockEngine::clueGroups() const
{
    QVariantList out;
    out.reserve(m_clueGroups.size());

    for (const auto &g : m_clueGroups) {
        QVariantMap gm;
        gm["orient"] = g.orient;
        gm["index"]  = g.index;

        QVariantList list;
        list.reserve(g.clues.size());
        for (const auto &c : g.clues) {
            QVariantMap m;
            m["type"] = c.type;
            m["row"]  = c.row;
            m["col"]  = c.col;
            m["item"] = c.item;
            list.push_back(m);
        }
        gm["clues"] = list;
        out.push_back(gm);
    }
    return out;
}

bool SherlockEngine::ensureBankLoaded(int size)
{
    bool *loaded = nullptr;
    if (size == 4) loaded = &m_bankLoaded4;
    else if (size == 5) loaded = &m_bankLoaded5;
    else loaded = &m_bankLoaded6;

    if (*loaded) return true;

    QVector<quint32>& vec = bankSeedsForSize(size);
    vec.clear();

    auto loadFromFile = [&](const QString& path) -> bool {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            return false;

        QTextStream ts(&f);
        while (!ts.atEnd()) {
            const QString line = ts.readLine().trimmed();
            if (line.isEmpty()) continue;
            bool ok = false;
            const quint32 seed = line.toUInt(&ok, 10);
            if (ok && seed != 0u)
                vec.append(seed);
        }
        return true;
    };

    // 1) Installed filesystem path (what you want on device)
    const QString fsPath = QStringLiteral("/usr/share/harbour-sherlock/qml/assets/puzzles/bank_%1.txt").arg(size);
    bool ok = loadFromFile(fsPath);

    // 2) Fallback: qrc path (if you ever embed assets into resources)
    if (!ok) {
        const QString qrcPath = QStringLiteral(":/qml/assets/puzzles/bank_%1.txt").arg(size);
        ok = loadFromFile(qrcPath);
    }

    // Mark loaded even if missing: empty bank is valid (random still works)
    *loaded = true;
    return true;
}

quint32 SherlockEngine::makeBankSeed(int size, int puzzleId) const
{
    // Stable mapping (size, puzzleId) -> seed. Good enough until real bank data exists.
    // (FNV-1a style mixing)
    quint32 h = 2166136261u;
    auto mix = [&](quint32 v) {
        h ^= v;
        h *= 16777619u;
    };
    mix(quint32(size));
    mix(quint32(puzzleId));
    return h;
}

void SherlockEngine::setBoardSize(int n)
{
    if (n != 4 && n != 5 && n != 6) return;
    if (n == m_size) return;

    // Update size first
    setSize(n);

    // Rebuild puzzle identity deterministically for the new size,
    // then start the puzzle so clues + givens are regenerated.
    if (m_puzzleSource == Bank) {
        if (m_puzzleId < 0) m_puzzleId = 0;
//        m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
        ensureBankLoaded(m_size);
        const auto& bank = bankSeedsForSize(m_size);
        if (bank.isEmpty()) {
            // fallback: use old deterministic mapping so bank still works
            m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
        } else {
            // clamp id
            if (m_puzzleId < 0) m_puzzleId = 0;
            if (m_puzzleId >= bank.size()) m_puzzleId = 0;
            m_puzzleSeed = bank[m_puzzleId];
        }
    } else {
        if (m_puzzleSeed == 0) {
            quint32 s = quint32(QDateTime::currentMSecsSinceEpoch() & 0xffffffffu);
            if (s == 0) s = 1u;
            m_puzzleSeed = s;
        }
        // keep existing seed so size change is deterministic for this generated puzzle
    }

    generateSolutionFromSeed(m_puzzleSeed);
    startPuzzleCommon(true);
}

void SherlockEngine::startPuzzleCommon(bool clearProgress)
{
    clearConflicts();
    clearHint();
    setLastTouched(-1, -1);

    // Fresh solution must already be in m_solution
    rebuildForSize();

    // Clear progress
    const int cells = m_size * m_size;
    for (int i = 0; i < cells; ++i) {
        m_masks[i] = fullMask();
        m_fixed[i] = 0;
    }

    const int givens = defaultGivenCount();

    QVector<int> indices;
    indices.reserve(cells);
    for (int i = 0; i < cells; ++i) indices.push_back(i);

    // Apply givens (locked cells)
    quint32 rng = (m_puzzleSeed == 0) ? 1u : m_puzzleSeed;

    // Deterministic shuffle indices (so givens are stable for a given seed/id)
    for (int i = cells - 1; i > 0; --i) {
        const int j = bounded(rng, i + 1);
        std::swap(indices[i], indices[j]);
    }

    for (int k = 0; k < givens && k < indices.size(); ++k) {
        const int i = indices[k];
        const int sol = m_solution[i];      // 0..n-1
        m_masks[i] = bit(sol);
        m_fixed[i] = 1;
    }

    // Propagate constraints from givens (row/column elimination) — only in assisted mode
    if (m_autoPropagate) {
        for (int k = 0; k < givens && k < indices.size(); ++k) {
            const int i = indices[k];
            const int r = i / m_size;
            const int c = i % m_size;
            const int item = m_solution[i];
            propagateCertain(r, c, item);
        }
    }

    // Reset undo/redo stacks for a new puzzle
    m_undo.clear();
    m_redo.clear();
    emit undoRedoChanged();

    rebuildClues();
    updateSolvedState(false);

    emit puzzleIdentityChanged();
    emit boardChanged();
    saveState();
}

void SherlockEngine::startRandomPuzzle()
{
    m_puzzleSource = GeneratedPuzzle;
    m_puzzleId = -1;

    quint32 seed = quint32(QDateTime::currentMSecsSinceEpoch() & 0xffffffffu);
    if (seed == 0) seed = 1u;

    ensureBankLoaded(m_size);
    int tries = 0;
    while (tries < 20 && isSeedInBank(m_size, seed)) {
        xorshift32(seed);              // xorshift32 takes quint32& so this is correct
        if (seed == 0u) seed = 1u;
        ++tries;
    }

    m_puzzleSeed = seed;
    generateSolutionFromSeed(m_puzzleSeed);
    startPuzzleCommon(true);
    emit message(QStringLiteral("Random puzzle started."));
}

void SherlockEngine::startBankPuzzle(int puzzleId)
{
    if (puzzleId < 0) puzzleId = 0;

    m_puzzleSource = Bank;
    m_puzzleId = puzzleId;
//    m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
    ensureBankLoaded(m_size);
    const auto& bank = bankSeedsForSize(m_size);
    if (bank.isEmpty()) {
        // fallback: use old deterministic mapping so bank still works
        m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
    } else {
        // clamp id
        if (m_puzzleId < 0) m_puzzleId = 0;
        if (m_puzzleId >= bank.size()) m_puzzleId = 0;
        m_puzzleSeed = bank[m_puzzleId];
    }

    generateSolutionFromSeed(m_puzzleSeed);
    startPuzzleCommon(/*clearProgress*/ true);

    emit message(QStringLiteral("Bank puzzle #%1 started.").arg(m_puzzleId));
}

int SherlockEngine::bankCount()
{
    ensureBankLoaded(m_size);
    return bankSeedsForSize(m_size).size();
}

void SherlockEngine::nextBankPuzzle()
{
    ensureBankLoaded(m_size);
    const int count = bankSeedsForSize(m_size).size();

    if (m_puzzleSource != Bank || m_puzzleId < 0) {
        m_puzzleId = 0;
    } else if (count > 0) {
        m_puzzleId = (m_puzzleId + 1) % count;
    } else {
        m_puzzleId = m_puzzleId + 1; // fallback if bank files missing
    }

    startBankPuzzle(m_puzzleId);
}

int SherlockEngine::defaultGivenCount() const
{
    // Feel free to tweak. These give a playable start without making it trivial.
    if (m_size == 4) return 6;
    if (m_size == 5) return 8;
    return 10; // 6x6
}

void SherlockEngine::setSize(int n)
{
    if (n != 4 && n != 5 && n != 6)
        return;

    if (m_size == n)
        return;

    m_size = n;

    rebuildForSize();
    rebuildClues();

    emit sizeChanged();
    emit boardChanged();   // board dimensions changed, QML should re-render
    emit message(QStringLiteral("Board size set to %1x%1.").arg(m_size));
}

void SherlockEngine::resetCell(int row, int col)
{
    const int i = idx(row, col);
    if (isFixedIndex(i))
        return;

    if (m_masks[i] == fullMask())
        return;

    pushUndoSnapshot();
    clearRedo();
    setMask(row, col, fullMask());
}

void SherlockEngine::setIconSource(int v)
{
    const IconSource ns = (v == int(Shi)) ? Shi : Generated;
    if (m_iconSource == ns)
        return;
    m_iconSource = ns;
    m_iconEpoch++;
    emit iconSourceChanged();
    emit imagesChanged();
    saveState();
}

void SherlockEngine::rebuildForSize()
{
    const int cells = m_size * m_size;

    m_masks.resize(cells);
    m_fixed.resize(cells);

    for (int i = 0; i < cells; ++i) {
        m_masks[i] = quint32(fullMask());
        m_fixed[i] = 0;
    }

    buildPlaceholderIcons();
}

QString SherlockEngine::dataDir() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir;
}

void SherlockEngine::loadState()
{
    QSettings s;

    // 1) Size
    const int sz = s.value(QStringLiteral("size"), 6).toInt();
    m_size = (sz == 4 || sz == 5 || sz == 6) ? sz : 6;

    // Ensure arrays exist for this size
    rebuildForSize();

    const int ps = s.value(QStringLiteral("puzzleSource"), int(GeneratedPuzzle)).toInt();
    m_puzzleSource = (ps == int(Bank)) ? Bank : GeneratedPuzzle;

    m_puzzleId = s.value(QStringLiteral("puzzleId"), -1).toInt();
    m_puzzleSeed = quint32(s.value(QStringLiteral("puzzleSeed"), 0u).toUInt());

    if (m_puzzleSource == Bank) {
        if (m_puzzleId < 0) m_puzzleId = 0;
//        m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
        ensureBankLoaded(m_size);
        const auto& bank = bankSeedsForSize(m_size);
        if (bank.isEmpty()) {
            // fallback: use old deterministic mapping so bank still works
            m_puzzleSeed = makeBankSeed(m_size, m_puzzleId);
        } else {
            // clamp id
            if (m_puzzleId < 0) m_puzzleId = 0;
            if (m_puzzleId >= bank.size()) m_puzzleId = 0;
            m_puzzleSeed = bank[m_puzzleId];
        }
    } else {
        if (m_puzzleSeed == 0) m_puzzleSeed = 1;
    }
    generateSolutionFromSeed(m_puzzleSeed);

    // 2) Icon source (no setter here; avoid saveState recursion during load)
    const int src = s.value(QStringLiteral("iconSource"), int(Generated)).toInt();
    const IconSource loadedSource = (src == int(Shi)) ? Shi : Generated;
    m_iconSource = loadedSource;

    // 3) Masks
    const QVariantList savedMasks = s.value(QStringLiteral("masks")).toList();
    const int cellCount = m_size * m_size;

    if (savedMasks.size() == cellCount) {
        for (int i = 0; i < cellCount; ++i) {
            const quint32 v = quint32(savedMasks[i].toUInt());
            quint32 m = (v & fullMask());
            if (m == 0) m = fullMask();
            m_masks[i] = m;
        }
    }

    // 4) Fixed (givens)
    const QVariantList savedFixed = s.value(QStringLiteral("fixed")).toList();
    if (savedFixed.size() == cellCount) {
        for (int i = 0; i < cellCount; ++i) {
            const int v = savedFixed[i].toInt();
            m_fixed[i] = (v != 0) ? 1 : 0;
        }
    } else {
        // Default: no givens if not present
        for (int i = 0; i < cellCount; ++i)
            m_fixed[i] = 0;
    }
    rebuildClues();
    emit iconSourceChanged();
    updateSolvedState(false);
    emit puzzleIdentityChanged();
    ++m_iconEpoch;
    emit imagesChanged();
    emit boardChanged();
}

void SherlockEngine::saveState() const
{
    QSettings s;
    s.setValue(QStringLiteral("size"), m_size);
    s.setValue(QStringLiteral("iconSource"), int(m_iconSource));

    s.setValue(QStringLiteral("puzzleSource"), int(m_puzzleSource));
    s.setValue(QStringLiteral("puzzleId"), m_puzzleId);
    s.setValue(QStringLiteral("puzzleSeed"), uint(m_puzzleSeed));

    QVariantList outMasks;
    outMasks.reserve(m_masks.size());
    for (quint32 m : m_masks)
        outMasks.push_back(uint(m));
    s.setValue(QStringLiteral("masks"), outMasks);

    QVariantList outFixed;
    outFixed.reserve(m_fixed.size());
    for (quint8 f : m_fixed)
        outFixed.push_back(int(f ? 1 : 0));
    s.setValue(QStringLiteral("fixed"), outFixed);
}

QVariantList SherlockEngine::boardMasks() const
{
    QVariantList out;
    out.reserve(m_size * m_size);
    for (quint32 m : m_masks)
        out.push_back(int(m));
    return out;
}

QVariantList SherlockEngine::conflictCells() const
{
    QVariantList out;
    out.reserve(m_conflictCells.size());
    for (int i : m_conflictCells) out.push_back(i);
    return out;
}

void SherlockEngine::clearConflicts()
{
    if (m_conflictCells.isEmpty()) return;
    m_conflictCells.clear();
    emit conflictCellsChanged();
}

void SherlockEngine::setConflicts(const QVector<int> &cells)
{
    // Normalize: unique + sorted (stable for QML bindings)
    QVector<int> tmp = cells;
    std::sort(tmp.begin(), tmp.end());
    tmp.erase(std::unique(tmp.begin(), tmp.end()), tmp.end());

    if (tmp == m_conflictCells) return;
    m_conflictCells = tmp;
    emit conflictCellsChanged();
}

static inline bool isCertainMask(quint32 m)
{
    return m != 0 && ((m & (m - 1)) == 0);
}

static inline int maskToItem(quint32 m)
{
    // m has exactly 1 bit set
    for (int k = 0; k < 32; ++k)
        if (m & (1u << k)) return k;
    return -1;
}

bool SherlockEngine::isSolvedNow() const
{
    const int n = m_size;
    const int cells = n * n;

    // All cells must be certain (single-bit)
    for (int i = 0; i < cells; ++i) {
        const quint32 m = m_masks[i];
        if (m == 0 || (m & (m - 1)) != 0) return false;
    }

    // No duplicates in any row/column
    auto maskToItemLocal = [](quint32 m) -> int {
        for (int k = 0; k < 32; ++k) if (m & (1u << k)) return k;
        return -1;
    };

    // Rows
    for (int r = 0; r < n; ++r) {
        QVector<int> seen(n, 0);
        for (int c = 0; c < n; ++c) {
            const int i = r * n + c;
            const int item = maskToItemLocal(m_masks[i]);
            if (item < 0 || item >= n) return false;
            if (seen[item]) return false;
            seen[item] = 1;
        }
    }

    // Cols
    for (int c = 0; c < n; ++c) {
        QVector<int> seen(n, 0);
        for (int r = 0; r < n; ++r) {
            const int i = r * n + c;
            const int item = maskToItemLocal(m_masks[i]);
            if (item < 0 || item >= n) return false;
            if (seen[item]) return false;
            seen[item] = 1;
        }
    }

    return true;
}

void SherlockEngine::updateSolvedState(bool announce)
{
    const bool now = isSolvedNow();
    if (now == m_solved) return;

    m_solved = now;
    emit solvedChanged();

    if (announce && m_solved) {
        emit message(QStringLiteral("Solved!"));
    }
}

void SherlockEngine::setHint(int cell, int item)
{
    if (m_hintCell == cell && m_hintItem == item) return;
    m_hintCell = cell;
    m_hintItem = item;
    emit hintChanged();
}

void SherlockEngine::clearHint()
{
    if (m_hintCell < 0 && m_hintItem < 0) return;
    m_hintCell = -1;
    m_hintItem = -1;
    emit hintChanged();
}

void SherlockEngine::verify()
{
    const int n = m_size;
    const int cells = n * n;

    QVector<int> conflicts;
    conflicts.reserve(cells);

    // 1) Any zero-mask cell is an immediate contradiction (should not happen, but verify it)
    for (int i = 0; i < cells; ++i) {
        if (m_masks[i] == 0) conflicts.push_back(i);
    }

    // 2) Row duplicates among certain cells
    for (int r = 0; r < n; ++r) {
        QVector<int> seen(n, -1); // item -> cellIndex
        for (int c = 0; c < n; ++c) {
            const int i = r * n + c;
            const quint32 m = m_masks[i];
            if (!isCertainMask(m)) continue;

            const int item = maskToItem(m);
            if (item < 0 || item >= n) continue;

            if (seen[item] >= 0) {
                conflicts.push_back(i);
                conflicts.push_back(seen[item]);
            } else {
                seen[item] = i;
            }
        }
    }

    // 3) Column duplicates among certain cells
    for (int c = 0; c < n; ++c) {
        QVector<int> seen(n, -1);
        for (int r = 0; r < n; ++r) {
            const int i = r * n + c;
            const quint32 m = m_masks[i];
            if (!isCertainMask(m)) continue;

            const int item = maskToItem(m);
            if (item < 0 || item >= n) continue;

            if (seen[item] >= 0) {
                conflicts.push_back(i);
                conflicts.push_back(seen[item]);
            } else {
                seen[item] = i;
            }
        }
    }

    setConflicts(conflicts);

    if (m_conflictCells.isEmpty()) {
        emit message(QStringLiteral("No contradictions found."));
    } else {
        emit message(QStringLiteral("Contradictions found: %1 cell(s).").arg(m_conflictCells.size()));
    }
}

void SherlockEngine::hint()
{
    clearHint();

    if (m_solved) {
        emit message(QStringLiteral("Already solved."));
        return;
    }

    const int n = m_size;
    const int cells = n * n;

    // 1) Naked single: any non-fixed cell with exactly one candidate
    for (int i = 0; i < cells; ++i) {
        if (isFixedIndex(i)) continue;
        const quint32 m = m_masks[i];
        if (m != 0 && ((m & (m - 1)) == 0)) {
            // find item
            for (int k = 0; k < n; ++k) {
                if (m & bit(k)) {
                    setHint(i, k);
                    emit message(QStringLiteral("Hint: single candidate."));
                    return;
                }
            }
        }
    }

    // 2) Hidden single in rows
    for (int r = 0; r < n; ++r) {
        for (int item = 0; item < n; ++item) {
            int where = -1;
            int count = 0;
            const quint32 b = bit(item);

            for (int c = 0; c < n; ++c) {
                const int i = r * n + c;
                if (isFixedIndex(i)) continue;
                if (m_masks[i] & b) {
                    where = i;
                    if (++count > 1) break;
                }
            }
            if (count == 1 && where >= 0) {
                setHint(where, item);
                emit message(QStringLiteral("Hint: only place in row."));
                return;
            }
        }
    }

    // 3) Hidden single in columns
    for (int c = 0; c < n; ++c) {
        for (int item = 0; item < n; ++item) {
            int where = -1;
            int count = 0;
            const quint32 b = bit(item);

            for (int r = 0; r < n; ++r) {
                const int i = r * n + c;
                if (isFixedIndex(i)) continue;
                if (m_masks[i] & b) {
                    where = i;
                    if (++count > 1) break;
                }
            }
            if (count == 1 && where >= 0) {
                setHint(where, item);
                emit message(QStringLiteral("Hint: only place in column."));
                return;
            }
        }
    }

    emit message(QStringLiteral("No forced move found."));
}

void SherlockEngine::applyHint()
{
    if (!hasHint()) {
        emit message(QStringLiteral("No hint to apply."));
        return;
    }

    const int n = m_size;
    const int i = m_hintCell;
    const int row = i / n;
    const int col = i % n;

    // Apply as a certain move (includes propagation + undo step in your current implementation)
    setCertain(row, col, m_hintItem);

    // Clear hint after applying
    clearHint();
}

void SherlockEngine::pushUndoSnapshot()
{
    m_undo.push_back(captureSnapshot());

    // Cap memory
    if (m_undo.size() > m_undoLimit) {
        const int drop = m_undo.size() - m_undoLimit;
        m_undo.erase(m_undo.begin(), m_undo.begin() + drop);
    }

    emit undoRedoChanged();
}

void SherlockEngine::clearRedo()
{
    if (m_redo.isEmpty())
        return;
    m_redo.clear();
    emit undoRedoChanged();
}

void SherlockEngine::undo()
{
    if (m_undo.isEmpty())
        return;

    // Move current to redo
    m_redo.push_back(captureSnapshot());

    // Restore previous
    const Snapshot s = m_undo.takeLast();
    applySnapshot(s, /*persist*/ true);

    emit undoRedoChanged();
}

void SherlockEngine::redo()
{
    if (m_redo.isEmpty())
        return;

    // Move current to undo
    m_undo.push_back(captureSnapshot());
    if (m_undo.size() > m_undoLimit) {
        const int drop = m_undo.size() - m_undoLimit;
        m_undo.erase(m_undo.begin(), m_undo.begin() + drop);
    }

    // Restore next
    const Snapshot s = m_redo.takeLast();
    applySnapshot(s, /*persist*/ true);

    emit undoRedoChanged();
}

SherlockEngine::Snapshot SherlockEngine::captureSnapshot() const
{
    Snapshot s;
    s.size = m_size;
    s.masks = m_masks;
    s.fixed = m_fixed;
    s.solution = m_solution;
    return s;
}

bool SherlockEngine::applySnapshot(const Snapshot &s, bool persist)
{
    if (s.size != m_size) {
        // Option B: undo/redo is within the current game/size.
        return false;
    }

    const int cells = m_size * m_size;
    if (s.masks.size() != cells || s.fixed.size() != cells) {
        return false;
    }

    // Restore authoritative state
    m_masks = s.masks;
    m_fixed = s.fixed;
    m_solution = s.solution;
    clearHint();

    // Derived data + notifications
    rebuildClues();
    updateSolvedState(false);
    emit boardChanged();

    if (persist) {
        saveState();
    }
    return true;
}

QVariantList SherlockEngine::clues() const
{
    QVariantList out;
    out.reserve(m_clues.size());
    for (const auto &c : m_clues) {
        QVariantMap m;
        m["type"] = c.type;
        m["row"]  = c.row;
        m["col"]  = c.col;
        m["item"] = c.item;
        out.push_back(m);
    }
    return out;
}

void SherlockEngine::rebuildClues()
{
    const int n = m_size;
    const int cells = n * n;

    // Collect givens by column/row
    QVector<QVector<Clue>> byCol(n);
    QVector<QVector<Clue>> byRow(n);

    auto maskToItem = [](quint32 m) -> int {
        // expects m has exactly 1 bit set
        for (int k = 0; k < 32; ++k) {
            if (m & (1u << k)) return k;
        }
        return 0;
    };

    for (int i = 0; i < cells; ++i) {
        if (i >= m_fixed.size() || i >= m_masks.size())
            break;

        if (!m_fixed[i])
            continue;

        const int r = i / n;
        const int c = i % n;

        Clue cl;
        cl.type = 0;               // "Given" for now (matches your current usage)
        cl.row  = r;               // board row (A..)
        cl.col  = c;               // board col (1..)
        cl.item = maskToItem(m_masks[i]); // icon item (0..n-1)

        byCol[c].push_back(cl);
        byRow[r].push_back(cl);
    }

    QVector<ClueGroup> groups;
    groups.reserve(2 * n);

    // Vertical: ALWAYS one group per column (orient = 0)
    for (int c = 0; c < n; ++c) {
        ClueGroup g;
        g.orient = 0;          // vertical
        g.index  = c;
        g.clues = byCol[c];    // may be empty
        groups.push_back(g);
    }

    // Horizontal: ALWAYS one group per row (orient = 1)
    for (int r = 0; r < n; ++r) {
        ClueGroup g;
        g.orient = 1;          // horizontal
        g.index  = r;
        g.clues = byRow[r];    // may be empty
        groups.push_back(g);
    }

    m_clueGroups = groups;
    emit clueGroupsChanged();
}

bool SherlockEngine::fixedAt(int row, int col) const
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size)
        return false;
    return isFixedIndex(idx(row, col));
}

int SherlockEngine::maskAt(int row, int col) const
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size)
        return int(fullMask());
    return int(m_masks[idx(row, col)]);
}

void SherlockEngine::setMask(int row, int col, quint32 m)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size)
        return;
    const int i = idx(row, col);
    if (m_masks[i] == m)
        return;
    clearConflicts();
    clearHint();
    m_masks[i] = m;
    updateSolvedState(true);
    emit boardChanged();
    saveState();
}

void SherlockEngine::newGame()
{
    startRandomPuzzle();
    //nextBankPuzzle(); //if prefer bank by default
}

void SherlockEngine::generateSolutionFromSeed(quint32 seed)
{
    quint32 rng = (seed == 0) ? 1u : seed;

    const int n = m_size;
    const int cells = n * n;
    m_solution.resize(cells);

    // Base Latin square: value = (r + c) % n
    QVector<int> base(cells);
    for (int r = 0; r < n; ++r)
        for (int c = 0; c < n; ++c)
            base[r * n + c] = (r + c) % n;

    QVector<int> permSym(n), permRow(n), permCol(n);
    for (int i = 0; i < n; ++i) { permSym[i] = i; permRow[i] = i; permCol[i] = i; }

    auto shuffle = [&](QVector<int> &v) {
        for (int i = v.size() - 1; i > 0; --i) {
            const int j = bounded(rng, i + 1);
            std::swap(v[i], v[j]);
        }
    };

    shuffle(permSym);
    shuffle(permRow);
    shuffle(permCol);

    for (int r = 0; r < n; ++r) {
        for (int c = 0; c < n; ++c) {
            const int rr = permRow[r];
            const int cc = permCol[c];
            const int v = base[rr * n + cc];
            m_solution[r * n + c] = permSym[v];
        }
    }
}

void SherlockEngine::revealSolution()
{
    const int n = m_size;
    const int cells = n * n;

    if (m_solution.size() != cells) {
        emit message(QStringLiteral("No solution available to reveal."));
        return;
    }

    // Check first (before mutating) so undo/redo + “no-op” detection is correct.
    bool any = false;
    for (int i = 0; i < cells; ++i) {
        const quint32 want = bit(m_solution[i]);
        if (m_masks[i] != want) { any = true; break; }
    }
    if (!any) return;

    pushUndoSnapshot();
    clearRedo();

    // Apply all at once (avoid saving 36 times)
    for (int i = 0; i < cells; ++i) {
        m_masks[i] = bit(m_solution[i]);
    }

    rebuildClues();
    updateSolvedState(true);
    emit boardChanged();
    saveState();
    emit message(QStringLiteral("Solution revealed (debug)."));
}

void SherlockEngine::resetMarks()
{
    bool any = false;
    const int cells = m_size * m_size;
    const quint32 fm = fullMask();

    for (int i = 0; i < cells; ++i) {
        if (m_fixed[i]) continue;
        if (m_masks[i] != fm) { any = true; break; }
    }
    if (!any) return;

    pushUndoSnapshot();
    clearRedo();
    clearHint();

    for (int i = 0; i < cells; ++i) {
        if (m_fixed[i]) continue;
        m_masks[i] = fm;
    }

    rebuildClues();
    emit boardChanged();
    saveState();
}

void SherlockEngine::toggleCandidate(int row, int col, int item)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;
    if (item < 0 || item >= m_size) return;

    const int i = idx(row, col);
    if (isFixedIndex(i)) return;
    setLastTouched(row, col);


    const quint32 m = m_masks[i];

    const quint32 b = bit(item);
    quint32 newMask = (m ^ b);

    // Never allow empty candidate set
    if (newMask == 0) return;

    // If no change (should not happen with XOR, but keep it safe)
    if (newMask == m) return;

    pushUndoSnapshot();
    clearRedo();
    clearConflicts();
    clearHint();

    m_masks[i] = newMask;

    // If this toggle leaves exactly one candidate, propagate it.
    if ((newMask & (newMask - 1)) == 0) {
        int chosen = -1;
        for (int k = 0; k < m_size; ++k) {
            if (newMask & bit(k)) { chosen = k; break; }
        }
        if (chosen >= 0) {
            if (m_autoPropagate) propagateCertain(row, col, chosen);
        }
    }

    updateSolvedState(true);
    emit boardChanged();
    saveState();
}

void SherlockEngine::eliminateCandidate(int row, int col, int item)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;
    if (item < 0 || item >= m_size) return;

    const int i = idx(row, col);
    if (isFixedIndex(i)) return;
    setLastTouched(row, col);

    const quint32 m = m_masks[i];
    const quint32 newMask = (m & ~bit(item));
    if (newMask == 0) return;
    if (newMask == m) return;

    pushUndoSnapshot();
    clearRedo();

    clearConflicts();
    clearHint();

    m_masks[i] = newMask;

    if ((newMask & (newMask - 1)) == 0) {
        // single bit left -> propagate
        int chosen = -1;
        for (int k = 0; k < m_size; ++k) {
            if (newMask & bit(k)) { chosen = k; break; }
        }
        if (chosen >= 0) {
            if (m_autoPropagate) propagateCertain(row, col, chosen);
        }
    }

    updateSolvedState(true);
    emit boardChanged();
    saveState();
}

void SherlockEngine::propagateCertain(int row, int col, int item)
{
    clearConflicts();

    // Remove 'item' from all other cells in the same row and column.

    // Row peers
    for (int c = 0; c < m_size; ++c) {
        if (c == col) continue;
        const int ii = idx(row, c);
        if (isFixedIndex(ii)) continue;

        quint32 m = m_masks[ii];
        if (m & bit(item)) {
            const quint32 nm = (m & ~bit(item));
            if (nm != 0) {
                m_masks[ii] = nm;   // direct write; batch notify happens in caller
            }
        }
    }

    // Column peers
    for (int r = 0; r < m_size; ++r) {
        if (r == row) continue;
        const int ii = idx(r, col);
        if (isFixedIndex(ii)) continue;

        quint32 m = m_masks[ii];
        if (m & bit(item)) {
            const quint32 nm = (m & ~bit(item));
            if (nm != 0) {
                m_masks[ii] = nm;
            }
        }
    }
}

void SherlockEngine::setCertain(int row, int col, int item)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;
    if (item < 0 || item >= m_size) return;

    const int i = idx(row, col);
    if (isFixedIndex(i)) return;
    setLastTouched(row, col);

    const quint32 b = bit(item);

    // If already certain to this item, undo -> reset cell
    if (m_masks[i] == b) {
        pushUndoSnapshot();
        clearRedo();
        setMask(row, col, fullMask());   // setMask() already emits/saves
        return;
    }

    pushUndoSnapshot();
    clearRedo();

    clearConflicts();
    clearHint();

    // Batch update: write directly to avoid emit/save twice
    m_masks[i] = b;

    // Propagate constraints
    if (m_autoPropagate) propagateCertain(row, col, item);

    // Single notification + persistence
    emit boardChanged();
    saveState();
}

bool SherlockEngine::importSherlockShi(const QString &sourcePath)
{
    QFileInfo fi(sourcePath);
    if (!fi.exists() || !fi.isFile()) {
        emit message(QStringLiteral("Import failed: source file not found."));
        return false;
    }

    const QString destPath = QDir(dataDir()).filePath(QStringLiteral("sherlock.shi"));

    if (QFile::exists(destPath))
        QFile::remove(destPath);

    if (!QFile::copy(sourcePath, destPath)) {
        emit message(QStringLiteral("Import failed: could not copy file into app data directory."));
        return false;
    }

    // Ensure readable
    QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser);

    const bool ok = loadSherlockShiFromDataDir();
    if (ok) emit message(QStringLiteral("Imported sherlock.shi successfully."));
    return ok;
}

bool SherlockEngine::loadSherlockShiFromDataDir()
{
    const QString path = QDir(dataDir()).filePath(QStringLiteral("sherlock.shi"));
    if (!QFileInfo::exists(path)) {
        m_hasImages = false;
        emit imagesChanged();
        return false;
    }

    ShiReader reader;
    ShiReader::Result r = reader.tryLoad(path);

    // Always emit the diagnostic dump to console to guide parser work.
//    qInfo().noquote() << r.diagnostic;

    if (!r.ok) {
        m_hasImages = false;
        emit imagesChanged();
        emit message(QStringLiteral("sherlock.shi present, but could not decode (see logs). Using placeholder icons."));
        return false;
    }

    m_fullShi = r.full;
    m_halfShi = r.half;

    m_hasImages = true;
    emit imagesChanged();
    return true;

}

void SherlockEngine::buildPlaceholderIcons()
{
    m_placeholders.clear();
    m_placeholders.reserve(m_size * m_size);

    // Category labels (A..F) + item numbers (1..6) -> deterministic placeholders
    for (int row = 0; row < m_size; ++row) {
        for (int item = 0; item < m_size; ++item) {
            QImage img(64, 64, QImage::Format_ARGB32_Premultiplied);
            img.fill(QColor(0, 0, 0, 0));

            QPainter p(&img);
            p.setRenderHint(QPainter::Antialiasing, true);

            // light card-like tile
            p.setPen(QPen(QColor(180, 180, 180), 2));
            p.setBrush(QColor(245, 245, 245));
            p.drawRoundedRect(QRectF(2, 2, 60, 60), 10, 10);

            QFont f;
            f.setBold(true);
            f.setPointSize(18);
            p.setFont(f);
            p.setPen(QColor(20, 20, 20));

            const QString text = QString("%1%2").arg(QChar('A' + row)).arg(item + 1);
            p.drawText(QRect(0, 0, 64, 64), Qt::AlignCenter, text);

            p.end();

            m_placeholders.push_back(img);
        }
    }
}

QImage SherlockEngine::iconFor(int row, int item, int pixelSize) const
{
    if (row < 0 || row >= m_size || item < 0 || item >= m_size)
        return QImage();

    // sherlock.shi typically includes image 0 = empty, then 36 images (row-major)
    const int shiIndex = 1 + row * m_size + item;

    QImage base;

    if (m_iconSource == Shi && m_hasImages && shiIndex >= 0 && shiIndex < m_fullShi.size()) {
        base = m_fullShi[shiIndex];
    } else {
        base = m_placeholders[row * m_size + item];
    }

    if (pixelSize <= 0 || base.width() == pixelSize)
        return base;

    return base.scaled(pixelSize, pixelSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}