#include "SherlockEngine.h"
#include "ClueSemantics.h"

#include <sailfishapp.h>
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
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStandardPaths>
#include <QDir>
#include <QDataStream>
#include <QIODevice>

#include "ShiReader.h"

static QByteArray packSnapshots(const QVector<SherlockEngine::Snapshot> &v)
{
    QByteArray ba;
    QDataStream ds(&ba, QIODevice::WriteOnly);
    ds.setVersion(QDataStream::Qt_5_6);

    ds << quint32(v.size());
    for (const auto &s : v) {
        ds << qint32(s.size);
        ds << s.masks;
        ds << s.fixed;
        ds << s.solution;
    }
    return ba;
}

static bool unpackSnapshots(const QByteArray &ba, QVector<SherlockEngine::Snapshot> &out)
{
    out.clear();
    if (ba.isEmpty())
        return true;

    QDataStream ds(ba);
    ds.setVersion(QDataStream::Qt_5_6);

    quint32 count = 0;
    ds >> count;
    if (ds.status() != QDataStream::Ok)
        return false;

    out.reserve(int(count));
    for (quint32 i = 0; i < count; ++i) {
        SherlockEngine::Snapshot s;
        qint32 sz = 0;
        ds >> sz;
        s.size = int(sz);
        ds >> s.masks;
        ds >> s.fixed;
        ds >> s.solution;

        if (ds.status() != QDataStream::Ok)
            return false;

        out.push_back(std::move(s));
    }
    return true;
}

// Constructor
SherlockEngine::SherlockEngine(QObject *parent)
    : QObject(parent)
{
    connect(&m_gameTimer, &QTimer::timeout, this, [this]() {
        ++m_elapsedSeconds;
        emit elapsedSecondsChanged();

        // Persist periodically so restart resumes correctly even if the user made no moves.
        if ((m_elapsedSeconds % 5) == 0) {
            saveState();
        }
    });
    m_gameTimer.setInterval(1000);
    m_gameTimer.setSingleShot(false);

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
//    rebuildClues();
    QTimer::singleShot(0, this, [this]() {
        rebuildClues();
        emit dosClueGroupsChanged();
    });
    loadScoresFromDisk();
    loadSolvedBankFromDisk(m_size);
}

QVariantList SherlockEngine::boardFixed() const
{
    QVariantList out;
    const int cells = m_size * m_size;
    out.reserve(cells);

    for (int i = 0; i < cells; ++i) {
        const bool f = (i < m_fixed.size() && m_fixed[i] != 0);
        out.push_back(f ? 1 : 0);
    }
    return out;
}

QVariantList SherlockEngine::boardFixedItems() const
{
    QVariantList out;
    const int cells = m_size * m_size;
    out.reserve(cells);

    for (int i = 0; i < cells; ++i) {
        const bool f = (i < m_fixed.size() && m_fixed[i] != 0);
        if (!f) {
            out.push_back(-1);
            continue;
        }
        const int item = (i < m_solution.size()) ? m_solution[i] : -1;
        out.push_back(item);
    }
    return out;
}

QString SherlockEngine::solvedBankFilePath(int size) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/solved_bank_%1.json").arg(size);
}

int SherlockEngine::currentBankPuzzleId() const
{
    if (m_puzzleSource != Bank) return -1;
    return m_puzzleId;
}

void SherlockEngine::nextPuzzleAccordingToMode()
{
    if (m_puzzleSource == Bank) {
        nextBankPuzzle();
    } else {
        startRandomPuzzle();
    }
}

void SherlockEngine::setDifficulty(int d)
{
    if (d < int(Easy) || d > int(Hard)) d = int(Medium);
    if (m_difficulty == d) return;

    m_difficulty = d;
    emit difficultyChanged();

    // Difficulty affects the clue set only (not the puzzle).
    rebuildDosClues();
    emit dosClueGroupsChanged();
}

void SherlockEngine::loadSolvedBankFromDisk(int size)
{
    m_solvedBankIds.clear();

    QFile f(solvedBankFilePath(size));
    if (!f.open(QIODevice::ReadOnly)) {
        emit solvedBankChanged();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray()) {
        emit solvedBankChanged();
        return;
    }

    const QJsonArray arr = doc.array();
    for (const QJsonValue &v : arr) {
        if (!v.isDouble()) continue;
        const int id = v.toInt(-1);
        if (id >= 0) m_solvedBankIds.insert(id);
    }

    emit solvedBankChanged();
}

void SherlockEngine::saveSolvedBankToDisk(int size) const
{
    QJsonArray arr;
    for (int id : m_solvedBankIds) {
        arr.append(id);
    }

    QFile f(solvedBankFilePath(size));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

bool SherlockEngine::bankPuzzleSolved(int puzzleId) const
{
    return m_solvedBankIds.contains(puzzleId);
}

QVariantList SherlockEngine::bankPuzzleEntries() const
{
    QVariantList out;

    const int count = const_cast<SherlockEngine*>(this)->bankCount(); // ensures bank is loaded
    out.reserve(count);

    for (int id = 0; id < count; ++id) {
        QVariantMap m;
        m["id"] = id;
        m["solved"] = m_solvedBankIds.contains(id);
        out.push_back(m);
    }
    return out;
}

void SherlockEngine::clearSolvedBankPuzzles()
{
    m_solvedBankIds.clear();
    saveSolvedBankToDisk(m_size);
    emit solvedBankChanged();
}

void SherlockEngine::markCurrentBankPuzzleSolved()
{
    if (m_puzzleSource != Bank) return;
    if (m_puzzleId < 0) return;

    if (m_solvedBankIds.contains(m_puzzleId)) return;
    m_solvedBankIds.insert(m_puzzleId);
    saveSolvedBankToDisk(m_size);
    emit solvedBankChanged();
}

QString SherlockEngine::scoresFilePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/scores.json");
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

void SherlockEngine::setPlayerName(const QString &name)
{
    m_playerName = name.left(32);
}

void SherlockEngine::loadScoresFromDisk()
{
    m_scores.clear();

    QFile f(scoresFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        emit scoresChanged();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray()) {
        emit scoresChanged();
        return;
    }

    const QJsonArray arr = doc.array();
    for (const QJsonValue &v : arr) {
        if (v.isObject())
            m_scores.append(v.toObject().toVariantMap());
    }

    emit scoresChanged();
}

void SherlockEngine::saveScoresToDisk() const
{
    QJsonArray arr;

    for (const QVariant &v : m_scores) {
        const QVariantMap m = v.toMap();
        arr.append(QJsonObject::fromVariantMap(m));
    }

    QFile f(scoresFilePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;

    f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void SherlockEngine::clearScores()
{
    m_scores.clear();
    saveScoresToDisk();
    emit scoresChanged();
}

void SherlockEngine::reloadScores()
{
    loadScoresFromDisk();
}

void SherlockEngine::appendScoreIfSolved()
{
    // Only record if we truly finished a puzzle.
    // Use your existing "solved" condition here.
    if (!m_solved)   // replace with your actual solved flag/property
        return;

    QVariantMap rec;
    rec["size"] = m_size;
    rec["elapsedSeconds"] = m_elapsedSeconds;
    rec["timestamp"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    if (m_activePuzzleSource == int(Bank)) {
        rec["source"] = "bank";
        rec["puzzleId"] = m_activePuzzleId;
        rec["seed"] = 0;
    } else {
        rec["source"] = "random";
        rec["puzzleId"] = -1;
        rec["seed"] = int(m_activePuzzleSeed);
    }

    // player name comes from QML setting; we’ll pass it in (next section)
    rec["playerName"] = m_playerName; // if you store it in engine; or set via invokable.

    m_scores.append(rec);

    // Keep file from growing unbounded: keep last 200 entries
    while (m_scores.size() > 200)
        m_scores.removeFirst();

    saveScoresToDisk();
    emit scoresChanged();
}

void SherlockEngine::timerReset()
{
    m_gameTimer.stop();
    m_elapsedSeconds = 0;

    m_timerRunning = false;
    m_timerArmed = true;     // allow start on first action

    emit elapsedSecondsChanged();
    emit timerRunningChanged();

    saveState();             // <<< IMPORTANT: persist reset immediately
}

void SherlockEngine::timerStart()
{
    if (m_timerRunning)
        return;
    m_timerRunning = true;
    m_gameTimer.start();
    emit timerRunningChanged();
    saveState();
}

void SherlockEngine::timerStop()
{
    if (!m_timerRunning)
        return;
    m_timerRunning = false;
    m_gameTimer.stop();
    emit timerRunningChanged();
    saveState();
}

void SherlockEngine::timerOnUserAction()
{
    if (!m_timerArmed)
        return;
    m_timerArmed = false;
    timerStart();
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


QVariantList SherlockEngine::dosClueGroups() const
{
    QVariantList out;
    out.reserve(m_dosClueGroups.size());

    for (const auto &g : m_dosClueGroups) {
        QVariantMap gm;
        gm["orient"] = g.orient;
        gm["index"] = g.index;

        QVariantList list;
        list.reserve(g.clues.size());
        for (const auto &c : g.clues) {
            QVariantMap m;
            m["type"]  = int(c.sem.type);
            m["a"]     = c.sem.a;
            m["b"]     = c.sem.b;
            m["c"]     = c.sem.c;
            m["index"] = c.sem.index;
            m["xMark"] = c.sem.xMark;
            m["given"] = c.sem.given;
            m["flags"] = c.sem.flags;
            m["aRow"]  = c.aRow;
            m["aCol"]  = c.aCol;
            m["bRow"]  = c.bRow;
            m["bCol"]  = c.bCol;
            m["cRow"]  = c.cRow;
            m["cCol"]  = c.cCol;
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
    timerReset();
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

    // Build initial candidate masks by removing given items from ROW peers only.
    const quint32 fm = fullMask();

    // Precompute given item(s) in each row as bitmasks
    QVector<quint32> rowTaken(m_size, 0);

    for (int i = 0; i < cells; ++i) {
        if (!m_fixed[i]) continue;
        const int r = i / m_size;
        const quint32 b = (m_masks[i] & fm);  // singleton bit
        rowTaken[r] |= b;
    }

    // Apply to non-fixed cells (row-only elimination)
    for (int i = 0; i < cells; ++i) {
        if (m_fixed[i]) continue;

        const int r = i / m_size;

        quint32 m = (m_masks[i] & fm);
        m &= ~rowTaken[r];

        if (m == 0) m = fm;     // defensive
        m_masks[i] = m;
    }

    // ---- SANITIZE: never allow 0-mask cells after (re)starting a puzzle ----
    // Ensure vectors are at least the right size (defensive)
    if (m_masks.size() != cells) m_masks.resize(cells);
    if (m_fixed.size() != cells) m_fixed.resize(cells);

    for (int i = 0; i < cells; ++i) {
        if (m_fixed[i]) {
            // Fixed/given must always display a single icon
            if (i >= 0 && i < m_solution.size()) {
                const int sol = m_solution[i];
                m_masks[i] = bit(sol);
            } else {
                // fallback: still keep non-zero
                m_masks[i] = fm;
            }
        } else {
            quint32 m = (m_masks[i] & fm);
            if (m == 0) m = fm;
            m_masks[i] = m;
        }
    }

    // Reset undo/redo stacks for a new puzzle
    m_undo.clear();
    m_redo.clear();
    emit undoRedoChanged();

    rebuildClues();
    updateSolvedState(false);

    m_activePuzzleSource = int(m_puzzleSource);
    m_activePuzzleId = m_puzzleId;
    m_activePuzzleSeed = m_puzzleSeed;

    emit puzzleIdentityChanged();
    emit boardChanged();
    saveState();
}

void SherlockEngine::startRandomPuzzle()
{
    m_puzzleSource = GeneratedPuzzle;
    m_puzzleId = -1;

    m_solved = false;
    emit solvedChanged();

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
    timerReset();
    emit message(QStringLiteral("Random puzzle started."));
}

void SherlockEngine::startBankPuzzle(int puzzleId)
{
    if (puzzleId < 0) puzzleId = 0;

    m_solved = false;
    emit solvedChanged();

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
    timerReset();

    emit message(QStringLiteral("Bank puzzle #%1 started.").arg(m_puzzleId));
}

int SherlockEngine::bankCount()
{
    ensureBankLoaded(m_size);
    return bankSeedsForSize(m_size).size();
}

void SherlockEngine::nextBankPuzzle()
{
    m_solved = false;
    emit solvedChanged();

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

void SherlockEngine::previousBankPuzzle()
{
    if (m_puzzleSource != Bank)
        return;

    m_solved = false;
    emit solvedChanged();

    ensureBankLoaded(m_size);
    const int count = bankSeedsForSize(m_size).size();

    if (m_puzzleId < 0)
        m_puzzleId = 0;

    if (count > 0) {
        // wrap backwards
        m_puzzleId = (m_puzzleId - 1 + count) % count;
    } else {
        // fallback when bank files missing: just decrement but clamp at 0
        m_puzzleId = qMax(0, m_puzzleId - 1);
    }

    startBankPuzzle(m_puzzleId);
}

void SherlockEngine::restartCurrentPuzzle()
{
    // Re-run the same puzzle identity but clear progress
    if (m_puzzleSource == Bank) {
        if (m_puzzleId < 0) m_puzzleId = 0;
        startBankPuzzle(m_puzzleId);
    } else {
        // GeneratedPuzzle: keep the same seed
        if (m_puzzleSeed == 0u) {
            quint32 seed = quint32(QDateTime::currentMSecsSinceEpoch() & 0xffffffffu);
            if (seed == 0u) seed = 1u;
            m_puzzleSeed = seed;
        }
        m_puzzleSource = GeneratedPuzzle;
        m_puzzleId = -1;
        generateSolutionFromSeed(m_puzzleSeed);
        startPuzzleCommon(true);
        timerReset();
        emit message(QStringLiteral("Puzzle restarted."));
    }
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
    loadSolvedBankFromDisk(m_size);
    emit message(QStringLiteral("Board size set to %1x%1.").arg(m_size));
}

void SherlockEngine::resetCell(int row, int col)
{
    const int i = idx(row, col);
    if (isFixedIndex(i))
        return;

    pushUndoSnapshot();
    clearRedo();
    clearConflicts();
    clearHint();

    // Clear this cell
    m_masks[i] = fullMask();

    // Recompute the whole row baseline (adds back removed candidates in peers,
    // but keeps removed candidates that are taken by other certainties in the row)
    recomputeRowCandidates(row);

    updateSolvedState(true);
    emit boardChanged();
    saveState();
}

void SherlockEngine::setAutoCompleteEnabled(bool on)
{
    if (m_autoCompleteEnabled == on) return;
    m_autoCompleteEnabled = on;
    emit autoCompleteEnabledChanged();
    saveState();
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

    m_activePuzzleSource = int(m_puzzleSource);
    m_activePuzzleId = m_puzzleId;
    m_activePuzzleSeed = m_puzzleSeed;

    // 2) Icon source (no setter here; avoid saveState recursion during load)
    const int src = s.value(QStringLiteral("iconSource"), int(Generated)).toInt();
    const IconSource loadedSource = (src == int(Shi)) ? Shi : Generated;
    m_iconSource = loadedSource;

    // Autocomplete
    m_autoCompleteEnabled = s.value(QStringLiteral("autoCompleteEnabled"), false).toBool();
    emit autoCompleteEnabledChanged();

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

    // 5) Timer
    m_elapsedSeconds = s.value(QStringLiteral("elapsedSeconds"), 0).toInt();
    emit elapsedSecondsChanged();

    const bool timerRunning = s.value(QStringLiteral("timerRunning"), false).toBool();

    // 6) Undo/Redo stacks
    m_undo.clear();
    m_redo.clear();
    {
        QVector<Snapshot> tmpUndo;
        QVector<Snapshot> tmpRedo;

        const QByteArray undoBytes = s.value(QStringLiteral("undoStack")).toByteArray();
        const QByteArray redoBytes = s.value(QStringLiteral("redoStack")).toByteArray();

        const bool okUndo = unpackSnapshots(undoBytes, tmpUndo);
        const bool okRedo = unpackSnapshots(redoBytes, tmpRedo);

        if (okUndo && okRedo) {
            // Keep only snapshots matching current size (avoid cross-size corruption)
            auto sizeFilter = [this](const Snapshot &sn) { return sn.size == m_size; };

            for (const auto &sn : tmpUndo)
                if (sizeFilter(sn)) m_undo.push_back(sn);

            for (const auto &sn : tmpRedo)
                if (sizeFilter(sn)) m_redo.push_back(sn);
        }
    }
    emit undoRedoChanged();

    rebuildClues();
    emit iconSourceChanged();
    updateSolvedState(false);
    emit puzzleIdentityChanged();
    ++m_iconEpoch;
    emit imagesChanged();
    emit boardChanged();

    const bool shouldRun = (timerRunning && !m_solved);

    m_timerRunning = shouldRun;
    m_timerArmed   = !shouldRun;    // if not running, arm so first user action starts it

    emit timerRunningChanged();

    if (shouldRun) {
        m_gameTimer.start();
    } else {
        m_gameTimer.stop();
    }
}

void SherlockEngine::saveState() const
{
    QSettings s;
    s.setValue(QStringLiteral("size"), m_size);
    s.setValue(QStringLiteral("iconSource"), int(m_iconSource));
    s.setValue(QStringLiteral("autoCompleteEnabled"), m_autoCompleteEnabled);
    s.setValue(QStringLiteral("puzzleSource"), int(m_puzzleSource));
    s.setValue(QStringLiteral("puzzleId"), m_puzzleId);
    s.setValue(QStringLiteral("puzzleSeed"), uint(m_puzzleSeed));
    s.setValue(QStringLiteral("elapsedSeconds"), m_elapsedSeconds);
    s.setValue(QStringLiteral("timerRunning"), m_gameTimer.isActive());
    s.setValue(QStringLiteral("undoStack"), packSnapshots(m_undo));
    s.setValue(QStringLiteral("redoStack"), packSnapshots(m_redo));

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
    const int cells = m_size * m_size;
    out.reserve(cells);

    const quint32 fm = fullMask();

    for (int i = 0; i < cells; ++i) {
        quint32 m = (i < m_masks.size()) ? (m_masks[i] & fm) : fm;

        // If the cell is a given/fixed, force it to the solution bit so QML
        // will show the large icon and never hide everything.
        if (isFixedIndex(i)) {
            const int sol = (i < m_solution.size()) ? m_solution[i] : 0;
            m = bit(sol);
        }

        if (m == 0) m = fm;     // never return 0 to QML
        out.push_back(uint(m)); // use uint to avoid negative ints
    }

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

int SherlockEngine::ambiguousCellCount() const
{
    const int cells = m_size * m_size;
    int amb = 0;
    for (int i = 0; i < cells; ++i) {
        const quint32 m = m_masks[i];
        if (m == 0) return cells; // treat as non-trivial
        if ((m & (m - 1)) != 0) ++amb; // not a singleton
    }
    return amb;
}

bool SherlockEngine::applyHiddenSinglesPass(bool &anyChange)
{
    anyChange = false;
    const int n = m_size;
    const quint32 fm = fullMask();
    bool changed = false;

    // Sherlock rule: uniqueness is ROW-only.
    // Hidden single in a row: an item can only fit in one column of that row.

    for (int r = 0; r < n; ++r) {
        for (int item = 0; item < n; ++item) {
            const quint32 b = bit(item);
            int whereC = -1;
            int count = 0;

            for (int c = 0; c < n; ++c) {
                const int i = r * n + c;
                const quint32 m = (m_masks[i] & fm);
                if (m & b) {
                    whereC = c;
                    if (++count > 1) break;
                }
            }

            if (count == 1 && whereC >= 0) {
                const int i = r * n + whereC;
                if (m_masks[i] != b) {
                    m_masks[i] = b;
                    // Propagate row-only constraint immediately
                    propagateCertain(r, whereC, item);
                    changed = true;
                }
            }
        }
    }

    anyChange = changed;
    return true;
}

bool SherlockEngine::tryAutoCompleteTrivialFinish()
{
    const int amb = ambiguousCellCount();
    if (amb == 0) return false;
//    if (amb > m_size) return false; // Conservative/trivial gate (tweak later: amb > 2*m_size is looser

    // More permissive, still conservative: allow up to 3*n ambiguous cells.
    if (amb > 3 * m_size) return false;

    m_inAutoComplete = true;

    // One undo step for the whole auto-finish.
    pushUndoSnapshot();
    clearRedo();
    clearConflicts();
    clearHint();

    bool anyOverallChange = false;

    auto propagateAllCurrentSingles = [&]() -> bool {
        const int n = m_size;
        const quint32 fm = fullMask();
        bool any = false;

        for (int r = 0; r < n; ++r) {
            for (int c = 0; c < n; ++c) {
                const int i = r * n + c;
                const quint32 m = (m_masks[i] & fm);
                if (m != 0 && ((m & (m - 1)) == 0)) {
                    // singleton => propagate row-only
                    const int item = maskToItem(m);
                    if (item >= 0 && item < n) {
                        // propagateCertain only reduces peers; mark change if it actually changes something
                        // We'll detect change by checking peers before/after.
                        const QVector<quint32> beforeRow = [&]{
                            QVector<quint32> v(n);
                            for (int cc = 0; cc < n; ++cc) v[cc] = m_masks[r*n + cc] & fm;
                            return v;
                        }();

                        propagateCertain(r, c, item);

                        for (int cc = 0; cc < n; ++cc) {
                            if ((m_masks[r*n + cc] & fm) != beforeRow[cc]) { any = true; break; }
                        }
                    }
                }
            }
        }
        return any;
    };

    // Repeat forced-only passes until stable.
    // Bound iterations to avoid pathological loops.
    for (int it = 0; it < m_size * m_size; ++it) {
        bool passChanged = false;

        // First, propagate existing singletons
        if (propagateAllCurrentSingles()) passChanged = true;

        // Then, create new singletons via hidden singles and propagate them
        bool hiddenChanged = false;
        applyHiddenSinglesPass(hiddenChanged);
        if (hiddenChanged) passChanged = true;

        if (!passChanged) break;
        anyOverallChange = true;
    }

    if (anyOverallChange) {
        emit boardChanged();
        saveState();
    }

    m_inAutoComplete = false;
    return anyOverallChange;
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
    const bool nowSolved = isSolvedNow();
    if (nowSolved != m_solved) {
        m_solved = nowSolved;
        emit solvedChanged();
        if (announce && m_solved) {
            emit message(QStringLiteral("Solved!"));
            appendScoreIfSolved();
            markCurrentBankPuzzleSolved();
            timerStop();
        }
    }

    // Autocomplete "trivial finish" (optional, forced-only, no guessing)
    // Only run on announced/user-triggered updates (not on load).
    if (announce && m_autoCompleteEnabled && !m_solved && !m_inAutoComplete) {
        if (tryAutoCompleteTrivialFinish()) {
            // After applying, re-check solved state and announce if solved.
            const bool solvedAfter = isSolvedNow();
            if (solvedAfter != m_solved) {
                m_solved = solvedAfter;
                emit solvedChanged();
            }
            if (m_solved) {
                emit message(QStringLiteral("Solved!"));
                appendScoreIfSolved();
                markCurrentBankPuzzleSolved();
                timerStop();
            }
        }
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
    // Defensive resize
    m_masks = s.masks;
    m_fixed = s.fixed;
    m_solution = s.solution;

    const quint32 fm = fullMask();

    // Fix sizes
    if (m_masks.size() != cells) {
        const int old = m_masks.size();
        m_masks.resize(cells);
        for (int i = old; i < cells; ++i) m_masks[i] = fm;
    }
    if (m_fixed.size() != cells) {
        const int old = m_fixed.size();
        m_fixed.resize(cells);
        for (int i = old; i < cells; ++i) m_fixed[i] = 0;
    }
    if (m_solution.size() != cells) {
        // keep your existing logic here; don't invent new generation
        // (if you already rebuild solution elsewhere, you can leave this alone)
    }

    // Clamp masks: no zeros, no bits outside fullMask
    for (int i = 0; i < cells; ++i) {
        quint32 m = (m_masks[i] & fm);
        if (m == 0) m = fm;
        m_masks[i] = m;
    }

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

        cl.sem.type = ClueType::GivenCell;
        cl.sem.given = true;
        cl.sem = normalizeClue(cl.sem);

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

    rebuildDosClues();

    emit clueGroupsChanged();
}

void SherlockEngine::rebuildDosClues()
{
//    qDebug() << "[rebuildDosClues] start n=" << m_size << " diff=" << m_difficulty;
    QElapsedTimer t;
    t.start();
    const qint64 TIME_BUDGET_MS = 50; // keep UI responsive

    m_dosClueGroups.clear();

    const int n = m_size;
    const int cells = n * n;
    if (m_solution.size() != cells)
        return;

    auto rngSeed = [&](quint32 salt) -> quint32 {
        quint32 s = (m_puzzleSeed == 0u) ? 1u : m_puzzleSeed;
        s ^= salt;
        s ^= quint32(m_difficulty) * 2654435761u;
        if (s == 0u) s = 1u;
        return s;
    };

    auto nextRand = [&](quint32 &state) -> quint32 {
        // LCG (deterministic)
        state = state * 1664525u + 1013904223u;
        return state;
    };

    auto shuffleVec = [&](QVector<int> &v, quint32 seed) {
        quint32 st = seed;
        for (int i = v.size() - 1; i > 0; --i) {
            int j = int(nextRand(st) % quint32(i + 1));
            qSwap(v[i], v[j]);
        }
    };

    auto colOf = [&](int row, int item) -> int {
        // In row 'row', find which column has 'item' in the solution
        const int base = row * n;
        for (int c = 0; c < n; ++c) {
            if (m_solution[base + c] == item)
                return c;
        }
        return -1;
    };

    auto itemAt = [&](int row, int col) -> int {
        return m_solution[row * n + col]; // 0..n-1
    };

    // --- DOS clue helpers (place inside rebuildDosClues(), after colOf/itemAt) ---

    auto semHasC = [&](const SemClue& s) -> bool {
        return (s.sem.flags & ClueSemantic::HasC) && (s.sem.c >= 0);
    };

    auto rowsDistinctRequired = [&](const SemClue& s) -> bool {
        // For ALL of our DOS clue types, A and B must come from different rows.
        if (s.aRow < 0 || s.bRow < 0) return false;
        if (s.aRow == s.bRow) return false;

        if (semHasC(s)) {
            if (s.cRow < 0) return false;
            // For 3-icon variants in our supported DOS set, C is always a third row too.
            // (This also prevents illegal "two items from same category" displays.)
            if (s.cRow == s.aRow) return false;
            if (s.cRow == s.bRow) return false;
        }
        return true;
    };

    auto recalcColsFromSolution = [&](SemClue& s) {
        s.aCol = colOf(s.aRow, s.sem.a);
        s.bCol = colOf(s.bRow, s.sem.b);
        if (semHasC(s)) s.cCol = colOf(s.cRow, s.sem.c);
        else s.cCol = -1;
    };

    auto clueHoldsInSolution = [&](const SemClue& s) -> bool {
        const int ca = colOf(s.aRow, s.sem.a);
        const int cb = colOf(s.bRow, s.sem.b);
        if (ca < 0 || cb < 0) return false;

        const bool hasC = semHasC(s);
        const int cc = hasC ? colOf(s.cRow, s.sem.c) : -1;
        if (hasC && cc < 0) return false;

        switch (s.sem.type) {
        case ClueType::SameColumn:
            if (ca != cb) return false;
            if (hasC && ca != cc) return false;
            return true;

        case ClueType::NotSameColumn:
            if (!hasC) {
                return (ca != cb);
            } else {
                // Rule 2 (3 icons): A and B are in same column, boxed item (C) is NOT in that column.
            if (ca != cb) return false;
                return (cc != ca);
            }

        case ClueType::SameColumnXor:
            // Rule 3: A is in same column as either B or C but NOT BOTH.
            if (!hasC) return false; // XOR is always 3-icon
            return ((ca == cb) ^ (ca == cc));

        case ClueType::LeftOf:
            // Rule 4: A is left of B
            return (ca < cb);

        case ClueType::NextTo:
            // Rule 5:
            // 2 icons: A next to B
            // 3 icons: C next to B AND two columns away from A
            if (!hasC) {
                return (qAbs(ca - cb) == 1);
            } else {
                if (qAbs(ca - cb) != 1) return false;
                if (qAbs(cc - cb) != 1) return false;
                if (qAbs(cc - ca) != 2) return false;
                return true;
            }

        case ClueType::NotNextTo:
            // Rule 6:
            // 2 icons: A NOT next to B
            // 3 icons: A and C have exactly one column between them, B is NOT in that between-column
            if (!hasC) {
                return (qAbs(ca - cb) != 1);
            } else {
                if (qAbs(ca - cc) != 2) return false;
                const int between = (ca + cc) / 2; // safe because diff is 2
                return (cb != between);
            }

        default:
            return false;
        }

    };

    QSet<QString> emitted; // across all groups for this rebuild

    auto clueSignature = [&](const SemClue &s) -> QString {
        // Use semantic items + rows (and xMark/flags) as identity. Keep it stable.
        // For symmetric 2-icon types (SameColumn, NotSameColumn, NextTo, NotNextTo), sort A/B by (row,item).
        auto keyPair = [&](int r, int item) -> QString { return QString::number(r) + ":" + QString::number(item); };

        const bool hasC = (s.sem.flags & ClueSemantic::HasC) && (s.sem.c >= 0);

        QString A = keyPair(s.aRow, s.sem.a);
        QString B = keyPair(s.bRow, s.sem.b);
        QString C = hasC ? keyPair(s.cRow, s.sem.c) : QString("-");

        const bool symmetricAB =
            (s.sem.type == ClueType::SameColumn) ||
            (s.sem.type == ClueType::NotSameColumn) ||
            (s.sem.type == ClueType::NextTo) ||
            (s.sem.type == ClueType::NotNextTo);

        if (symmetricAB && A > B) qSwap(A, B);

        // XOR is *not* symmetric: A is special. LeftOf is directional too.
        return QString("%1|o%2|i%3|t%4|f%5|x%6|%7|%8|%9")
            .arg(int(s.sem.given))
            .arg(int(s.orient))
            .arg(int(s.index))
            .arg(int(s.sem.type))
            .arg(int(s.sem.flags))
            .arg(int(s.sem.xMark))
            .arg(A).arg(B).arg(C);
    };

    auto normPair = [&](int &r1, int &i1, int &c1,
                        int &r2, int &i2, int &c2)
    {
        if (r1 > r2 || (r1 == r2 && i1 > i2)) {
            qSwap(r1, r2);
            qSwap(i1, i2);
            qSwap(c1, c2);
        }
    };

    // DOS-only normalization that NEVER loses row association.
    // We only swap whole (row,item,col) tuples.
    auto normalizeDosSemClue = [&](SemClue &sc)
    {
        const bool hasC = semHasC(sc);

        switch (sc.sem.type) {
        case ClueType::SameColumn:
        case ClueType::NotSameColumn:
        case ClueType::NextTo:
        case ClueType::NotNextTo:
            if (!hasC) {
                // symmetric A/B: order by (row,item)
                normPair(sc.aRow, sc.sem.a, sc.aCol,
                         sc.bRow, sc.sem.b, sc.bCol);
            } else if (sc.sem.type == ClueType::NotSameColumn) {
                // Rule 2 (3 icons): C is the boxed item -> keep C fixed, normalize only A/B
                normPair(sc.aRow, sc.sem.a, sc.aCol,
                         sc.bRow, sc.sem.b, sc.bCol);
            }
            // For NextTo/NotNextTo 3-icon variants: keep A,B,C as generated (B is "middle").
            break;

        case ClueType::SameColumnXor:
            // XOR: A is special, but (B,C) can be ordered stably
            if (hasC) {
                normPair(sc.bRow, sc.sem.b, sc.bCol,
                     sc.cRow, sc.sem.c, sc.cCol);
        }
        break;

        case ClueType::LeftOf:
            // directional -> keep order
            break;

        default:
            break;
        }
    };

    // Prevent contradictory SameColumn duplicates ---
    // Tracks forced column for each (row,item) implied by emitted SameColumn clues.
    QHash<int, int> forcedSameCol; // key=(row<<8)|item, value=solution column

    auto scKey = [&](int row, int item) -> int {
        return (row << 8) | (item & 0xFF);
    };

    QHash<int,int> forcedRowCol; // key(row,col) -> item
    auto rcKey = [&](int row, int col) -> int {
        // n is 6, but keep it generic
        return row * n + col;
    };

    // Local-only flags to encode which slot is X-boxed for NotSameColumn(3)
    constexpr int XBOX_A = 1 << 20;
    constexpr int XBOX_B = 1 << 21;
    constexpr int XBOX_C = 1 << 22;

    auto xIndex = [&](const SemClue& s) -> int {
        if (s.sem.flags & XBOX_A) return 0;
        if (s.sem.flags & XBOX_B) return 1;
        if (s.sem.flags & XBOX_C) return 2;
        return -1;
    };

    auto acceptAndRecordSameColumn = [&](const SemClue& s) -> bool {
        // We record "forced column" constraints for:
        //  (A) SameColumn clues (Rule 1)
        //  (B) The *pair* that is same-column inside NotSameColumn with 3 icons (Rule 2 variant)

        auto checkOne = [&](int row, int item, int col) -> bool {
            // Forward constraint: this item can't be forced to two different columns
            {
                const int k = scKey(row, item);
                auto it = forcedSameCol.find(k);
                if (it != forcedSameCol.end() && it.value() != col)
                    return false;
            }

            // Inverse constraint: this row+column can't be occupied by two different items
            {
                const int rk = rcKey(row, col);
                auto it2 = forcedRowCol.find(rk);
                if (it2 != forcedRowCol.end() && it2.value() != item)
                    return false;
            }

            return true;
        };

        // --- (A) Rule 1: SameColumn ---
        if (s.sem.type == ClueType::SameColumn) {
            // After recalcColsFromSolution(), aCol/bCol/cCol are solution columns
            const int col = s.aCol;
            if (col < 0) return false;

            if (!checkOne(s.aRow, s.sem.a, col)) return false;
            if (!checkOne(s.bRow, s.sem.b, col)) return false;

            const bool hasC = (s.cRow >= 0 && s.sem.c >= 0);
            if (hasC) {
                if (!checkOne(s.cRow, s.sem.c, col)) return false;
            }
            return true;
        }

        // --- (B) Rule 2 (3 icons): NotSameColumn where TWO are same-column and the X-box one is NOT ---
        // Only applies when the clue actually has C and we can identify which icon is boxed.
        if (s.sem.type == ClueType::NotSameColumn && semHasC(s)) {
            const int xi = xIndex(s);     // 0=a, 1=b, 2=c ; -1 if unknown
            if (xi < 0) return true;      // if we can't identify the boxed one, don't block generation

            // Determine the "same-column pair" (the two *not* boxed)
            // If A is boxed -> B and C are same-column
            // If B is boxed -> A and C are same-column
            // If C is boxed -> A and B are same-column
            int row1=-1, item1=-1, col1=-1;
            int row2=-1, item2=-1, col2=-1;

            if (xi == 0) { // A boxed => B & C same column
                row1 = s.bRow; item1 = s.sem.b; col1 = s.bCol;
                row2 = s.cRow; item2 = s.sem.c; col2 = s.cCol;
            } else if (xi == 1) { // B boxed => A & C same column
                row1 = s.aRow; item1 = s.sem.a; col1 = s.aCol;
                row2 = s.cRow; item2 = s.sem.c; col2 = s.cCol;
            } else { // xi == 2 ; C boxed => A & B same column
                row1 = s.aRow; item1 = s.sem.a; col1 = s.aCol;
                row2 = s.bRow; item2 = s.sem.b; col2 = s.bCol;
            }

            // Sanity: in a valid clue that holds in solution these two cols must match anyway,
            // but we rely on recalcColsFromSolution() already having run.
            if (col1 < 0 || col2 < 0) return false;
            if (col1 != col2) return false;

            if (!checkOne(row1, item1, col1)) return false;
            if (!checkOne(row2, item2, col2)) return false;

            return true;
        }

        // Other clue types: no forced-col tracking here
        return true;
    };

    // Helper: does this SemClue have a C item?
    auto hasC = [&](const SemClue& s) -> bool {
        return (s.sem.flags & ClueSemantic::HasC) && (s.sem.c >= 0);
    };

    // Extract fixed column for (row,item) from current givens (fixed cells).
    // Returns -1 if that item is not fixed in that row.
    auto fixedColForItem = [&](int row, int item) -> int {
        if (row < 0 || row >= n || item < 0 || item >= n) return -1;

        for (int col = 0; col < n; ++col) {
            const int i = row * n + col;
            if (i < 0 || i >= m_fixed.size() || i >= m_masks.size()) continue;
            if (!m_fixed[i]) continue;

            // fixed cell: mask should be singleton; decode which item it is
            quint32 m = m_masks[i] & fullMask();
            if (m == 0) continue;

            int fixedItem = -1;
            for (int k = 0; k < 32; ++k) {
                if (m & (1u << k)) { fixedItem = k; break; }
            }
            if (fixedItem == item) return col;
        }
        return -1;
    };

    // Redundancy filter: if the clue is already fully implied by givens (fixed cells), skip it.
    auto clueIsRedundantWithGivens = [&](const SemClue& s) -> bool {
        const int ca = fixedColForItem(s.aRow, s.sem.a);
        const int cb = fixedColForItem(s.bRow, s.sem.b);
        const int cc = hasC(s) ? fixedColForItem(s.cRow, s.sem.c) : -1;

        // If we don't know the columns from givens, we can't call it redundant.
        if (ca < 0 || cb < 0) return false;
        if (hasC(s) && cc < 0) return false;

        // Evaluate using the same logic as the solution validator but with known fixed columns
        switch (s.sem.type) {
        case ClueType::SameColumn:
            if (!hasC(s)) return (ca == cb);
            return (ca == cb && ca == cc);

        case ClueType::NotSameColumn:
            if (!hasC(s)) return (ca != cb);
            {
                const int xi = xIndex(s);
                if (xi == 0) return (cb == cc) && (ca != cb);
                if (xi == 1) return (ca == cc) && (cb != ca);
                return (ca == cb) && (cc != ca);
            }

        case ClueType::SameColumnXor:
            if (!hasC(s)) return false;
            return ((ca == cb) ^ (ca == cc));

        case ClueType::LeftOf:
            return (ca < cb);

        case ClueType::NextTo:
            if (!hasC(s)) return (qAbs(ca - cb) == 1);
            return (qAbs(ca - cb) == 1) && (qAbs(cb - cc) == 1) && (qAbs(ca - cc) == 2);

        case ClueType::NotNextTo:
            if (!hasC(s)) return (qAbs(ca - cb) != 1);
            if (qAbs(ca - cc) != 2) return false;
            return (cb != (ca + cc) / 2);

        default:
            return false;
        }
    };

    // --- helpers: pick distinct rows, and a simple retry loop ---
    auto pickRowExcluding = [&](quint32 &st, int ex0, int ex1, int ex2) -> int {
        // tries up to 32 times (more than enough for n<=6)
        for (int tries = 0; tries < 32; ++tries) {
            int r = int(nextRand(st) % quint32(n));
            if (r != ex0 && r != ex1 && r != ex2) return r;
        }
        // fallback: first allowed
        for (int r = 0; r < n; ++r) {
            if (r != ex0 && r != ex1 && r != ex2) return r;
        }
        return 0;
    };

    auto pickDistinctRows2 = [&](quint32 &st, int &r0, int &r1) {
        r0 = int(nextRand(st) % quint32(n));
        r1 = pickRowExcluding(st, r0, -1, -1);
    };

    auto pickDistinctRows3 = [&](quint32 &st, int &r0, int &r1, int &r2) {
        r0 = int(nextRand(st) % quint32(n));
        r1 = pickRowExcluding(st, r0, -1, -1);
        r2 = pickRowExcluding(st, r0, r1, -1);
    };

    auto fixedAt = [&](int row, int col) -> bool {
        const int idx = row * n + col;
        return (idx >= 0 && idx < m_fixed.size() && m_fixed[idx] != 0);
    };

    // For redundancy checks: if a row has a fixed value at a given column,
    // return the item, else -1.
    auto fixedItemAt = [&](int row, int col) -> int {
        const int idx = row * n + col;
        if (idx < 0 || idx >= m_fixed.size() || idx >= m_masks.size()) return -1;
        if (m_fixed[idx] == 0) return -1;
        // m_solution is authoritative, but if you prefer: decode from mask here
        if (idx >= 0 && idx < m_solution.size()) return m_solution[idx];
        return -1;
    };

    // Core: check semantics against solution
    auto clueHolds = [&](const SemClue &s) -> bool {
        const bool hasC = (s.sem.flags & ClueSemantic::HasC);
        const bool isVerticalFamily =
                (s.sem.type == ClueType::SameColumn) ||
                (s.sem.type == ClueType::NotSameColumn) ||
                (s.sem.type == ClueType::SameColumnXor);

        if (isVerticalFamily) {
            if (s.aRow < 0 || s.bRow < 0) return false;
            if (s.aRow == s.bRow) return false;
            if (hasC) {
                if (s.cRow < 0) return false;
                if (s.cRow == s.aRow || s.cRow == s.bRow) return false;
            }
        }

        auto colA = [&]() -> int { return colOf(s.aRow, s.sem.a); };
        auto colB = [&]() -> int { return colOf(s.bRow, s.sem.b); };
        auto colC = [&]() -> int { return colOf(s.cRow, s.sem.c); };

        switch (s.sem.type) {
        case ClueType::SameColumn:        // rule 1
            return (colA() >= 0 && colA() == colB());

        case ClueType::NotSameColumn:     // rule 2 (2 or 3 icons)
            if (s.sem.flags & ClueSemantic::HasC) {
                // A and B same column, C NOT in that column
                return (colA() >= 0 && colA() == colB() && colC() >= 0 && colC() != colA());
            } else {
                return (colA() >= 0 && colB() >= 0 && colA() != colB());
            }

        case ClueType::SameColumnXor:     // rule 3
            // A is in same column as exactly ONE of (B,C)
            {
                int a = colA(), b = colB(), c = colC();
                if (a < 0 || b < 0 || c < 0) return false;
                bool ab = (a == b);
                bool ac = (a == c);
                return (ab != ac);
            }

        case ClueType::LeftOf:            // rule 4
            // A left of B (distance unknown)
            {
                int a = colA(), b = colB();
                if (a < 0 || b < 0) return false;
                return a < b;
            }

        case ClueType::NextTo:            // rule 5 (2 or 3 icons)
            {
                int a = colA(), b = colB();
                if (a < 0 || b < 0) return false;
                if (!(std::abs(a - b) == 1)) return false;
                if (s.sem.flags & ClueSemantic::HasC) {
                    int c = colC();
                    if (c < 0) return false;
                    // C is next to B and two away from A (i.e. A-B-C in a line)
                    return (std::abs(b - c) == 1) && (std::abs(a - c) == 2);
                }
                return true;
            }

        case ClueType::NotNextTo:         // rule 6 (2 or 3 icons)
            {
                int a = colA(), b = colB();
                if (a < 0 || b < 0) return false;

                if (s.sem.flags & ClueSemantic::HasC) {
                    // A and C have exactly one column between them,
                    // and B is NOT in that middle column.
                    int c = colC();
                    if (c < 0) return false;
                    if (std::abs(a - c) != 2) return false;
                    int mid = (a + c) / 2;
                    return b != mid;
                } else {
                    return std::abs(a - b) != 1;
                }
            }

        default:
            return true; // unknown types: don't block here
        }
    };

    // --- Difficulty knobs (tune later) ---
    auto vCluesPerStrip = [&]() -> int {
        if (m_difficulty == int(Easy))   return (n >= 6 ? 3 : 2);
        if (m_difficulty == int(Medium)) return 2;
        return 1; // Hard
    };

    auto hCluesPerStrip = [&]() -> int {
        if (m_difficulty == int(Easy))   return (n >= 6 ? 3 : 2);
        if (m_difficulty == int(Medium)) return 2;
        return 1; // Hard
    };

    const int vPer = vCluesPerStrip();
    const int hPer = hCluesPerStrip();

    // One group per "stripe" as your UI expects: n vertical + n horizontal
    m_dosClueGroups.reserve(2 * n);
    for (int idx = 0; idx < n; ++idx) {
        SemClueGroup vg; vg.orient = int(Vertical);   vg.index = idx;
        SemClueGroup hg; hg.orient = int(Horizontal); hg.index = idx;
        m_dosClueGroups.push_back(vg);
        m_dosClueGroups.push_back(hg);
    }

    auto vGroupAt = [&](int stripe) -> SemClueGroup* {
        for (auto &g : m_dosClueGroups)
            if (g.orient == int(Vertical) && g.index == stripe) return &g;
        return nullptr;
    };
    auto hGroupAt = [&](int stripe) -> SemClueGroup* {
        for (auto &g : m_dosClueGroups)
            if (g.orient == int(Horizontal) && g.index == stripe) return &g;
        return nullptr;
    };

    // ==========================================================
    // VERTICAL CLUES (column-relations, DOS types 1..3)
    // We build each vertical stripe from a REAL column in solution.
    // Stripe index == column index (0..n-1)
    // ==========================================================
    for (int col = 0; col < n; ++col) {
        SemClueGroup *g = vGroupAt(col);
        if (!g) continue;

        // Collect icons that are in this solution column: (row, item)
        QVector<QPair<int,int>> inThisCol;
        inThisCol.reserve(n);
        for (int r = 0; r < n; ++r) {
            inThisCol.push_back(qMakePair(r, itemAt(r, col)));
        }

        // Deterministic shuffle for variety
        {
            QVector<int> order;
            order.reserve(inThisCol.size());
            for (int i = 0; i < inThisCol.size(); ++i) order.push_back(i);
            shuffleVec(order, rngSeed(0x11110000u + quint32(col)));

            QVector<QPair<int,int>> tmp;
            tmp.reserve(inThisCol.size());
            for (int k : order) tmp.push_back(inThisCol[k]);
            inThisCol = tmp;
        }

        int made = 0;
        quint32 st = rngSeed(0x22220000u + quint32(col));

        int attempts = 0;
        const int maxAttempts = 2000; // bump as needed; cheap, this is small n

        while (made < vPer && attempts < maxAttempts) {
            ++attempts;
            const int pick = int(nextRand(st) % 3u); // 0..2 choose type family

            if (pick == 0) {
                // (1) Same Column: 2 or 3 images all in same column
                // Easy: prefer 2; Medium/Hard: sometimes 3
                const bool want3 = (m_difficulty != int(Easy)) && ((nextRand(st) & 1u) == 0u);

                SemClue sc;
                sc.orient = int(Vertical);
                sc.index  = col;
                sc.sem.given = true;

                sc.sem.type = ClueType::SameColumn;

                // a and b always
                sc.aRow = inThisCol[0].first; sc.aCol = col; sc.sem.a = inThisCol[0].second;
                sc.bRow = inThisCol[1].first; sc.bCol = col; sc.sem.b = inThisCol[1].second;

                // optional c
                if (want3 && inThisCol.size() >= 3) {
                    sc.cRow = inThisCol[2].first; sc.cCol = col; sc.sem.c = inThisCol[2].second;
                    sc.sem.flags = 1; // HAS_C
                } else {
                    sc.cRow = -1; sc.cCol = -1; sc.sem.c = -1;
                    sc.sem.flags = 0;
                }

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }
                if (!acceptAndRecordSameColumn(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }

            if (pick == 1) {
                // (2) Not In Same Column:
                // 2 icons: not same column
                // or 3 icons: two are same column, third (X-box) is NOT in that column.
                const bool want3 = (m_difficulty != int(Easy)) && ((nextRand(st) & 1u) == 0u);

                SemClue sc;
                sc.orient = int(Vertical);
                sc.index  = col;
                sc.sem.given = true;
                sc.sem.type = ClueType::NotSameColumn;

                // choose (a,b) from this column (so they ARE same column)
                sc.aRow = inThisCol[0].first; sc.aCol = col; sc.sem.a = inThisCol[0].second;

                if (!want3) {
                    // 2 icons: A and B are NOT in the same column.
                    // IMPORTANT: For DOS-style vertical clues, A and B must be from DIFFERENT rows/categories.
                    // Pick A from (aRow, col) and B from (bRow != aRow, bCol != col).

                    const int aRow = inThisCol[0].first;
                    const int bRow = inThisCol[1].first; // different row

                    int bCol = int(nextRand(st) % quint32(n));
                    if (bCol == col) bCol = (bCol + 1) % n; // ensure different column than A's column

                    SemClue sc2;
                    sc.orient = int(Vertical);
                    sc.index = col;
                    sc.sem.type = ClueType::NotSameColumn;
                    sc.sem.given = true;

                    // A in this column
                    sc.aRow = aRow;
                    sc.aCol = col;
                    sc.sem.a = itemAt(aRow, col);

                    // B in a different row AND different column
                    sc.bRow = bRow;
                    sc.bCol = bCol;
                    sc.sem.b = itemAt(bRow, bCol);

                    sc.cRow = -1;
                    sc.cCol = -1;
                    sc.sem.c = -1;
                    sc.sem.flags |= XBOX_C;

                    // 1) normalize by swapping full tuples only (row-safe)
                    normalizeDosSemClue(sc); 

                    // 2) recompute columns from solution AFTER normalization
                    recalcColsFromSolution(sc);

                    // 3) validate against solution
                    if (!rowsDistinctRequired(sc)) {
                        continue;
                    }
                    if (!clueHoldsInSolution(sc)) {
                        continue;
                    }
                    if (!acceptAndRecordSameColumn(sc)) {
                        continue;
                    }

                    const QString sig = clueSignature(sc);
                    if (emitted.contains(sig)) continue;
                    emitted.insert(sig);

                    if (t.elapsed() > TIME_BUDGET_MS) {
                        break; // stop generating more clues this pass
                    }
                    g->clues.push_back(sc);
                    ++made;
                    continue;
                } else {
                    // b is also in same column (col)
                    sc.bRow = inThisCol[1].first; sc.bCol = col; sc.sem.b = inThisCol[1].second;

                    // c is the "red-X boxed" one: must NOT be in this column
                    int r = inThisCol[2].first; // any row
                    int otherCol = int(nextRand(st) % quint32(n));
                    if (otherCol == col) otherCol = (otherCol + 1) % n;

                    sc.cRow = r; sc.cCol = otherCol; sc.sem.c = itemAt(r, otherCol);

                    // flags: HAS_C + C_IS_XBOX
                    sc.sem.flags = ClueSemantic::HasC | XBOX_C;
                }

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }
                if (!acceptAndRecordSameColumn(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }

            {
                // (3) Same Column As This OR This (XOR):
                // a shares column with exactly one of b/c.
                SemClue sc;
                sc.orient = int(Vertical);
                sc.index  = col;
                sc.sem.given = true;
                sc.sem.type = ClueType::SameColumnXor;

                // a comes from this column
                sc.aRow = inThisCol[0].first; sc.aCol = col; sc.sem.a = inThisCol[0].second;

                // b is in SAME column (col)
                sc.bRow = inThisCol[1].first; sc.bCol = col; sc.sem.b = inThisCol[1].second;

                // c is NOT in this column (col)
                int r = inThisCol[2].first;
                int otherCol = int(nextRand(st) % quint32(n));
                if (otherCol == col) otherCol = (otherCol + 1) % n;

                sc.cRow = r; sc.cCol = otherCol; sc.sem.c = itemAt(r, otherCol);

                // flags: HAS_C
                sc.sem.flags = 1;

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }
                if (!acceptAndRecordSameColumn(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }
        }
    }

    // ==========================================================
    // HORIZONTAL CLUES (DOS types 4..6)
    // Stripe index == row index (0..n-1)
    // ==========================================================
    for (int row = 0; row < n; ++row) {
        SemClueGroup *g = hGroupAt(row);
        if (!g) continue;

        // deterministic per row
        quint32 st = rngSeed(0x33330000u + quint32(row));

        int made = 0;
        int attempts = 0;
        const int maxAttempts = 4000; // safe cap, prevents hang

        while (made < hPer && attempts < maxAttempts) {
            ++attempts;

            // hard time budget guard (also prevents long stalls)
            if (t.elapsed() > TIME_BUDGET_MS) break;
            const int pick = int(nextRand(st) % 3u); // 0..2

            if (pick == 0) {
                // (4) Is Left Of (unknown distance): pick two different columns
                int c1 = int(nextRand(st) % quint32(n));
                int c2 = int(nextRand(st) % quint32(n));
                if (c1 == c2) c2 = (c2 + 1) % n;
                if (c1 > c2) qSwap(c1, c2);

                SemClue sc;
                sc.orient = int(Horizontal);
                sc.index  = row;
                sc.sem.type = ClueType::LeftOf;
                sc.sem.given = true;

                sc.aRow = row; sc.aCol = c1; sc.sem.a = itemAt(row, c1);
                sc.bRow = row; sc.bCol = c2; sc.sem.b = itemAt(row, c2);

                sc.cRow = -1; sc.cCol = -1; sc.sem.c = -1;
                sc.sem.flags = 0;

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }

            if (pick == 1) {
                // (5) Is Next To: adjacent columns
                int c1 = int(nextRand(st) % quint32(n - 1));
                int c2 = c1 + 1;

                SemClue sc;
                sc.orient = int(Horizontal);
                sc.index  = row;
                sc.sem.type = ClueType::NextTo;
                sc.sem.given = true;

                sc.aRow = row; sc.aCol = c1; sc.sem.a = itemAt(row, c1);
                sc.bRow = row; sc.bCol = c2; sc.sem.b = itemAt(row, c2);

                sc.cRow = -1; sc.cCol = -1; sc.sem.c = -1;
                sc.sem.flags = 0;

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }

            {
                // (6) Is Not Next To: pick columns with distance >= 2
                int c1 = int(nextRand(st) % quint32(n));
                int c2 = int(nextRand(st) % quint32(n));
                if (c1 == c2) c2 = (c2 + 2) % n;

                // ensure not adjacent
                if (qAbs(c1 - c2) == 1) {
                    c2 = (c2 + 2) % n;
                }
                if (c1 > c2) qSwap(c1, c2);

                SemClue sc;
                sc.orient = int(Horizontal);
                sc.index  = row;
                sc.sem.type = ClueType::NotNextTo;
                sc.sem.given = true;

                sc.aRow = row; sc.aCol = c1; sc.sem.a = itemAt(row, c1);
                sc.bRow = row; sc.bCol = c2; sc.sem.b = itemAt(row, c2);

                sc.cRow = -1; sc.cCol = -1; sc.sem.c = -1;
                sc.sem.flags = 0;

                // Normalize / sanity / validate / dedupe BEFORE emitting
                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!rowsDistinctRequired(sc)) {
                    continue;
                }
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }

                const QString sig = clueSignature(sc);
                if (emitted.contains(sig)) continue;
                emitted.insert(sig);

                if (t.elapsed() > TIME_BUDGET_MS) {
                    break; // stop generating more clues this pass
                }
                g->clues.push_back(sc);
                ++made;
                continue;
            }
        }
        if (made == 0) {
            // Force at least one simple LeftOf clue per row if possible
            for (int col = 0; col < n-1; ++col) {
                SemClue sc;
                sc.orient = 1;
                sc.index = row;
                sc.sem.type = ClueType::LeftOf;
                sc.sem.given = true;

                sc.aRow = row;
                sc.aCol = col;
                sc.sem.a = itemAt(row, col);

                sc.bRow = row;
                sc.bCol = col + 1;
                sc.sem.b = itemAt(row, col + 1);

                // 1) normalize by swapping full tuples only (row-safe)
                normalizeDosSemClue(sc); 

                // 2) recompute columns from solution AFTER normalization
                recalcColsFromSolution(sc);

                // 3) validate against solution
                if (!clueHoldsInSolution(sc)) {
                    continue;
                }

                if (clueHoldsInSolution(sc)) {
                    g->clues.push_back(sc);
                    break;
                }
            }
        }
    }

    emit dosClueGroupsChanged();
    // --- DEBUG: verify what we actually produced ---
    int vGroups = 0, hGroups = 0, vClues = 0, hClues = 0;
    for (const auto &g : m_dosClueGroups) {
        if (g.orient == 0) { ++vGroups; vClues += g.clues.size(); }
        else if (g.orient == 1) { ++hGroups; hClues += g.clues.size(); }
        else { }//qDebug() << "[rebuildDosClues] WARNING: unknown orient" << g.orient; }
    }
//    qDebug() << "[rebuildDosClues] summary:"
//             << "vGroups=" << vGroups << "vClues=" << vClues
//             << "hGroups=" << hGroups << "hClues=" << hClues;

    // Optional: show first few horizontal clues if any
    for (const auto &g : m_dosClueGroups) {
        if (g.orient != 1) continue;
//        qDebug() << "[rebuildDosClues] horiz row" << g.index << "clues=" << g.clues.size();
        for (int i = 0; i < g.clues.size() && i < 3; ++i) {
            const auto &c = g.clues[i];
//            qDebug() << "  type=" << int(c.sem.type)
//                     << "aRow=" << c.aRow << "a=" << c.sem.a
//                     << "bRow=" << c.bRow << "b=" << c.sem.b
//                     << "flags=" << c.sem.flags;
        }
    }
//    qDebug() << "[rebuildDosClues] done groups=" << m_dosClueGroups.size();
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

int SherlockEngine::fixedItemAt(int row, int col) const
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size)
        return -1;

    const int i = idx(row, col);
    if (!isFixedIndex(i))
        return -1;

    const int cells = m_size * m_size;
    if (m_solution.size() != cells)
        return -1;

    const int item = m_solution[i];   // 0..n-1
    if (item < 0 || item >= m_size)
        return -1;

    return item;
}

void SherlockEngine::setMask(int row, int col, quint32 m)
{
    if (row < 0 || row >= m_size || col < 0 || col >= m_size) return;

    const int i = idx(row, col);

    // Never allow empty candidate set in the model.
    // (Empty masks cause blank tiles in QML.)
    m &= fullMask();
    if (m == 0) m = fullMask();

    if (m_masks[i] == m) return;

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
            propagateCertain(row, col, chosen);
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
            propagateCertain(row, col, chosen);
        }
    }

    updateSolvedState(true);
    emit boardChanged();
    saveState();
}

void SherlockEngine::recomputeRowCandidates(int row)
{
    if (row < 0 || row >= m_size) return;

    const quint32 fm = fullMask();

    // Collect all "certain" items in this row (fixed givens + user certainties)
    quint32 taken = 0;
    for (int c = 0; c < m_size; ++c) {
        const int i = idx(row, c);
        const quint32 m = (m_masks[i] & fm);
        if (m != 0 && ((m & (m - 1)) == 0)) { // singleton => certain
            taken |= m;
        }
    }

    // Baseline for non-certain cells in this row
    const quint32 baseline = (fm & ~taken);

    for (int c = 0; c < m_size; ++c) {
        const int i = idx(row, c);
        if (isFixedIndex(i)) continue; // fixed stays singleton

        quint32 m = (m_masks[i] & fm);
        const bool certain = (m != 0 && ((m & (m - 1)) == 0));
        if (certain) continue;         // keep user certainties

        // Not fixed + not certain -> baseline candidates (only remove taken-from-row)
        quint32 nm = baseline;
        if (nm == 0) nm = fm;          // defensive
        m_masks[i] = nm;
    }
}

void SherlockEngine::propagateCertain(int row, int col, int item)
{
    clearConflicts();

    // Remove 'item' from all other cells in the same row (Sherlock rule: row-only).

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
        clearConflicts();
        clearHint();

        m_masks[i] = fullMask();
        recomputeRowCandidates(row);

        updateSolvedState(true);
        emit boardChanged();
        saveState();
        return;
    }

    pushUndoSnapshot();
    clearRedo();

    clearConflicts();
    clearHint();

    // Batch update: write directly to avoid emit/save twice
    m_masks[i] = b;

    // Propagate constraints
    propagateCertain(row, col, item);

    // Solve detection + notifications
    updateSolvedState(true);
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