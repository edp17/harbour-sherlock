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

#include "ShiReader.h"

SherlockEngine::SherlockEngine(QObject *parent)
    : QObject(parent)
{
    loadState();                  // loads m_size + m_iconSource + masks + fixed
//    generateSolution();    // Ensure we have a solution vector (even if no puzzle yet)
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
    ++m_iconEpoch;
    emit imagesChanged();
    emit boardChanged();
}

void SherlockEngine::saveState() const
{
    QSettings s;
    s.setValue(QStringLiteral("size"), m_size);
    s.setValue(QStringLiteral("iconSource"), int(m_iconSource));

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

    // Derived data + notifications
    rebuildClues();
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
    m_masks[i] = m;
    emit boardChanged();
    saveState();
}

void SherlockEngine::newGame()
{

    // Ensure arrays sized
    rebuildForSize();
    m_undo.clear();
    m_redo.clear();
    emit undoRedoChanged();

    generateSolution();

    // Seed qrand once
    static bool seeded = false;
    if (!seeded) {
        seeded = true;
        qsrand(uint(QDateTime::currentMSecsSinceEpoch() & 0xffffffff));
    }

    const int cells = m_size * m_size;
    QVector<int> positions;
    positions.reserve(cells);
    for (int i = 0; i < cells; ++i)
        positions.push_back(i);

    // Fisher–Yates shuffle with qrand
    for (int i = positions.size() - 1; i > 0; --i) {
        const int j = qrand() % (i + 1);
        qSwap(positions[i], positions[j]);
    }

    const int givens = qMin(defaultGivenCount(), cells);

    // Mark givens
    for (int k = 0; k < givens; ++k) {
        const int i = positions[k];
        const int v = m_solution[i];           // 0..n-1
        m_masks[i] = bit(v);                   // certain
        m_fixed[i] = 1;                        // locked
    }

    // Others: all candidates, not fixed
    for (int k = givens; k < cells; ++k) {
        const int i = positions[k];
        m_masks[i] = fullMask();
        m_fixed[i] = 0;
    }

    rebuildClues();

    emit boardChanged();
    saveState();
    emit message(QStringLiteral("New game started (%1 givens).").arg(givens));
}

void SherlockEngine::generateSolution()
{
    const int n = m_size;
    const int cells = n * n;

    m_solution.resize(cells);

    QVector<int> base;     base.reserve(n);
    QVector<int> rowShift; rowShift.reserve(n);
    QVector<int> colPerm;  colPerm.reserve(n);

    for (int i = 0; i < n; ++i) {
        base.push_back(i);
        rowShift.push_back(i);
        colPerm.push_back(i);
    }

    // Seed qrand() once per run (cheap + good enough for this puzzle generator)
    static bool seeded = false;
    if (!seeded) {
        seeded = true;
        qsrand(uint(QDateTime::currentMSecsSinceEpoch() & 0xffffffff));
    }

    // Fisher–Yates shuffle using qrand()
    auto shuffleVec = [](QVector<int> &v) {
        for (int i = v.size() - 1; i > 0; --i) {
            const int j = qrand() % (i + 1);
            qSwap(v[i], v[j]);
        }
    };

    shuffleVec(base);
    shuffleVec(rowShift);
    shuffleVec(colPerm);

    // Latin-square-like mapping
    for (int r = 0; r < n; ++r) {
        for (int c = 0; c < n; ++c) {
            const int cc = colPerm[c];
            const int v = base[(cc + rowShift[r]) % n];
            m_solution[r * n + c] = v; // 0..n-1
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

    quint32 m = m_masks[i];

    quint32 newMask = (m ^ bit(item));
    if (newMask == 0)
        return;

    pushUndoSnapshot();
    clearRedo();

    setMask(row, col, newMask);
}

void SherlockEngine::eliminateCandidate(int row, int col, int item)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;
    if (item < 0 || item >= m_size) return;

    const int i = idx(row, col);
    if (isFixedIndex(i)) return;

    quint32 m = m_masks[i];

    quint32 newMask = (m & ~bit(item));
    if (newMask == 0)
        return;

    pushUndoSnapshot();
    clearRedo();

    setMask(row, col, newMask);
}

void SherlockEngine::propagateCertain(int row, int col, int item)
{
    // Remove 'item' from all other cells in the same row and column.
    // Respect your invariant: never reduce a cell to 0 candidates.

    // Row peers
    for (int c = 0; c < m_size; ++c) {
        if (c == col) continue;
        const int ii = idx(row, c);
        quint32 m = m_masks[ii];
        if (m & bit(item)) {
            quint32 nm = (m & ~bit(item));
            if (nm != 0) {
                m_masks[ii] = nm; // direct write: we'll emit/save once at the end
            }
        }
    }

    // Column peers
    for (int r = 0; r < m_size; ++r) {
        if (r == row) continue;
        const int ii = idx(r, col);
        quint32 m = m_masks[ii];
        if (m & bit(item)) {
            quint32 nm = (m & ~bit(item));
            if (nm != 0) {
                m_masks[ii] = nm;
            }
        }
    }

    // Single notification + persistence
    emit boardChanged();
    saveState();
}

void SherlockEngine::setCertain(int row, int col, int item)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;
    if (item < 0 || item >= m_size) return;

    const int i = idx(row, col);
    if (isFixedIndex(i)) return;

    const quint32 b = bit(item);

    // If already certain to this item, undo -> reset cell
    if (m_masks[i] == b) {
        pushUndoSnapshot();
        clearRedo();
        setMask(row, col, fullMask());
        return;
    }

    pushUndoSnapshot();
    clearRedo();
    setMask(row, col, b);
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
