#include "SherlockEngine.h"
#include "ClueSemantics.h"
#include "ClueGenerator.h"
#include "CandidateCompletion.h"
#include "HintSolver.h"

#include <algorithm>
#include <utility>
#include <vector>

#include <QDateTime>
#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFont>
#include <QIODevice>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QPainter>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

#include "ShiReader.h"

static QString appSettingsPath()
{
    const QString directory = QStandardPaths::writableLocation(
        QStandardPaths::AppConfigLocation);
    QDir().mkpath(directory);
    return QDir(directory).filePath(QStringLiteral("harbour-sherlock.conf"));
}

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
    clearDimmedClues();
    rebuildDosClues();
    saveState();
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
            QStringList keyParts;
            keyParts << QString::number(g.orient)
                     << QString::number(g.index)
                     << QString::number(int(c.sem.type))
                     << QString::number(c.aRow)
                     << QString::number(c.sem.a)
                     << QString::number(c.bRow)
                     << QString::number(c.sem.b)
                     << QString::number(c.cRow)
                     << QString::number(c.sem.c)
                     << QString::number(c.sem.flags)
                     << QString::number(c.sem.xMark);
            m["key"] = keyParts.join(QLatin1Char(':'));
            list.push_back(m);
        }

        gm["clues"] = list;
        out.push_back(gm);
    }

    return out;
}

QStringList SherlockEngine::dimmedClueKeys() const
{
    QStringList keys = m_dimmedClueKeys.values();
    std::sort(keys.begin(), keys.end());
    return keys;
}

void SherlockEngine::toggleDimmedClue(const QString &key)
{
    if (key.isEmpty() || key.size() > 192)
        return;

    if (m_dimmedClueKeys.contains(key))
        m_dimmedClueKeys.remove(key);
    else
        m_dimmedClueKeys.insert(key);

    emit dimmedCluesChanged();
    saveState();
}

void SherlockEngine::clearDimmedClues()
{
    if (m_dimmedClueKeys.isEmpty())
        return;
    m_dimmedClueKeys.clear();
    emit dimmedCluesChanged();
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
    clearDimmedClues();
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
    emit message(tr("Random puzzle started."));
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

    emit message(tr("Bank puzzle #%1 started.").arg(m_puzzleId + 1));
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
        emit message(tr("Puzzle restarted."));
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
    emit message(tr("Board size set to %1×%1.").arg(m_size));
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

void SherlockEngine::setIconTheme(const QString &theme)
{
    const QString selected = resolveIconTheme(theme);
    if (selected.isEmpty())
        return;

    const bool themeWasChanged = (m_iconTheme != selected);
    const bool sourceChanged = (m_iconSource != Generated);
    if (!themeWasChanged && !sourceChanged)
        return;

    m_iconTheme = selected;
    m_iconSource = Generated;
    ++m_iconEpoch;

    if (themeWasChanged)
        emit iconThemeChanged();
    if (sourceChanged)
        emit iconSourceChanged();
    emit imagesChanged();
    saveState();
}

void SherlockEngine::setIconThemeRoot(const QString &path)
{
    m_iconThemeRoot = path.trimmed().isEmpty()
                    ? QString() : QDir::cleanPath(path);
    refreshIconThemes();
}

bool SherlockEngine::isValidIconTheme(const QString &themeName) const
{
    if (m_iconThemeRoot.isEmpty() || themeName.isEmpty())
        return false;

    const QDir themeDir(QDir(m_iconThemeRoot).filePath(themeName));
    if (!themeDir.exists(QStringLiteral("theme_preview.png")))
        return false;

    const QDir iconDir(themeDir.filePath(QStringLiteral("icons_32x32")));
    if (!iconDir.exists(QStringLiteral("00_blank.png")))
        return false;

    int index = 1;
    for (int row = 0; row < 6; ++row) {
        const QChar rowLetter = QStringLiteral("ABCDEF").at(row);
        for (int item = 0; item < 6; ++item, ++index) {
            const QString fileName = QStringLiteral("%1_%2%3.png")
                .arg(index, 2, 10, QLatin1Char('0'))
                .arg(rowLetter)
                .arg(item + 1);
            if (!iconDir.exists(fileName))
                return false;
        }
    }

    return true;
}

QString SherlockEngine::resolveIconTheme(const QString &themeName) const
{
    const QString requested = themeName.trimmed();
    for (const QString &available : m_availableIconThemes) {
        if (available == requested)
            return available;
    }
    for (const QString &available : m_availableIconThemes) {
        if (available.compare(requested, Qt::CaseInsensitive) == 0)
            return available;
    }
    return QString();
}

void SherlockEngine::refreshIconThemes()
{
    QStringList discovered;
    if (!m_iconThemeRoot.isEmpty()) {
        const QDir root(m_iconThemeRoot);
        const QStringList directories = root.entryList(
            QDir::Dirs | QDir::NoDotAndDotDot,
            QDir::Name | QDir::IgnoreCase);
        for (const QString &directory : directories) {
            if (isValidIconTheme(directory))
                discovered.append(directory);
        }
    }

    const bool catalogChanged = (m_availableIconThemes != discovered);
    m_availableIconThemes = discovered;

    QString selected = resolveIconTheme(m_iconTheme);
    if (selected.isEmpty() && !m_availableIconThemes.isEmpty())
        selected = m_availableIconThemes.first();

    const bool themeWasChanged = (m_iconTheme != selected);
    m_iconTheme = selected;

    if (catalogChanged)
        emit iconThemesChanged();
    if (themeWasChanged) {
        ++m_iconEpoch;
        emit iconThemeChanged();
        emit imagesChanged();
        saveState();
    }
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
    QSettings s(appSettingsPath(), QSettings::NativeFormat);

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

    // The installed theme catalog is scanned after construction. Keep the
    // saved directory name here so it can be resolved case-insensitively once
    // the application supplies the asset root.
    m_iconTheme = s.value(QStringLiteral("iconTheme")).toString().trimmed();

    // Autocomplete
    m_autoCompleteEnabled = s.value(QStringLiteral("autoCompleteEnabled"), false).toBool();
    emit autoCompleteEnabledChanged();

    const int savedDifficulty =
        s.value(QStringLiteral("difficulty"), int(Medium)).toInt();
    m_difficulty = (savedDifficulty >= int(Easy) && savedDifficulty <= int(Hard))
                 ? savedDifficulty : int(Medium);
    emit difficultyChanged();

    const QStringList savedDimmedClues =
        s.value(QStringLiteral("dimmedClueKeys")).toStringList();
    m_dimmedClueKeys.clear();
    for (const QString &key : savedDimmedClues) {
        if (!key.isEmpty() && key.size() <= 192)
            m_dimmedClueKeys.insert(key);
    }
    emit dimmedCluesChanged();

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
    emit iconThemeChanged();
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
    QSettings s(appSettingsPath(), QSettings::NativeFormat);
    s.setValue(QStringLiteral("size"), m_size);
    s.setValue(QStringLiteral("iconSource"), int(m_iconSource));
    s.setValue(QStringLiteral("iconTheme"), m_iconTheme);
    s.setValue(QStringLiteral("autoCompleteEnabled"), m_autoCompleteEnabled);
    s.setValue(QStringLiteral("difficulty"), m_difficulty);
    s.setValue(QStringLiteral("dimmedClueKeys"), dimmedClueKeys());
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

bool SherlockEngine::applyForcedRowCompletion()
{
    m_inAutoComplete = true;

    std::vector<std::uint32_t> masks(m_masks.cbegin(), m_masks.cend());
    const std::vector<std::uint8_t> fixed(m_fixed.cbegin(), m_fixed.cend());
    const bool anyOverallChange = SherlockCandidates::closeForcedRows(
        m_size, masks, fixed);
    if (anyOverallChange)
        std::copy(masks.cbegin(), masks.cend(), m_masks.begin());

    m_inAutoComplete = false;
    return anyOverallChange;
}

bool SherlockEngine::isSolvedNow() const
{
    const int cells = m_size * m_size;
    if (m_solution.size() != cells)
        return false;

    // Rows are independent icon categories. A solved board must match the
    // hidden solution exactly; equal numeric item indexes in different rows
    // are not column duplicates.
    for (int i = 0; i < cells; ++i) {
        if (m_masks[i] != bit(m_solution[i]))
            return false;
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
            emit message(tr("Solved!"));
            appendScoreIfSolved();
            markCurrentBankPuzzleSolved();
            timerStop();
        }
    }

    // Autocomplete performs every forced row-only deduction after a user
    // action. It never guesses, and no global progress threshold applies.
    if (announce && m_autoCompleteEnabled && !m_solved && !m_inAutoComplete) {
        if (applyForcedRowCompletion()) {
            // After applying, re-check solved state and announce if solved.
            const bool solvedAfter = isSolvedNow();
            if (solvedAfter != m_solved) {
                m_solved = solvedAfter;
                emit solvedChanged();
            }
            if (m_solved) {
                emit message(tr("Solved!"));
                appendScoreIfSolved();
                markCurrentBankPuzzleSolved();
                timerStop();
            }
        }
    }
}

void SherlockEngine::setHint(int cell, int item, bool eliminates,
                             const QString &clueKey)
{
    if (m_hintCell == cell && m_hintItem == item &&
            m_hintEliminates == eliminates && m_hintClueKey == clueKey)
        return;
    m_hintCell = cell;
    m_hintItem = item;
    m_hintEliminates = eliminates;
    m_hintClueKey = clueKey;
    emit hintChanged();
}

void SherlockEngine::clearHint()
{
    if (m_hintCell < 0 && m_hintItem < 0 && !m_hintEliminates &&
            m_hintClueKey.isEmpty())
        return;
    m_hintCell = -1;
    m_hintItem = -1;
    m_hintEliminates = false;
    m_hintClueKey.clear();
    emit hintChanged();
}

void SherlockEngine::verify()
{
    const int n = m_size;
    const int cells = n * n;

    QVector<int> conflicts;
    conflicts.reserve(cells);

    // Any cell which no longer contains its correct icon is contradictory.
    for (int i = 0; i < cells; ++i) {
        if (i >= m_solution.size() ||
                (m_masks[i] & bit(m_solution[i])) == 0) {
            conflicts.push_back(i);
        }
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

    setConflicts(conflicts);

    if (m_conflictCells.isEmpty()) {
        emit message(tr("No contradictions found."));
    } else {
        emit message(tr("Contradictions found: %1 cell(s).").arg(m_conflictCells.size()));
    }
}

void SherlockEngine::hint()
{
    clearHint();

    if (m_solved) {
        emit message(tr("Already solved."));
        return;
    }

    std::vector<SherlockClues::Clue> clues;
    std::vector<QString> clueKeys;
    for (const SemClueGroup &group : m_dosClueGroups) {
        for (const SemClue &source : group.clues) {
            SherlockClues::Clue clue;
            clue.type = int(source.sem.type);
            clue.orient = source.orient;
            clue.index = source.index;
            clue.a = source.sem.a;
            clue.b = source.sem.b;
            clue.c = source.sem.c;
            clue.aRow = source.aRow;
            clue.aCol = source.aCol;
            clue.bRow = source.bRow;
            clue.bCol = source.bCol;
            clue.cRow = source.cRow;
            clue.cCol = source.cCol;
            clue.xMark = source.sem.xMark;
            clue.flags = source.sem.flags;
            clues.push_back(clue);

            QStringList parts;
            parts << QString::number(group.orient)
                  << QString::number(group.index)
                  << QString::number(int(source.sem.type))
                  << QString::number(source.aRow)
                  << QString::number(source.sem.a)
                  << QString::number(source.bRow)
                  << QString::number(source.sem.b)
                  << QString::number(source.cRow)
                  << QString::number(source.sem.c)
                  << QString::number(source.sem.flags)
                  << QString::number(source.sem.xMark);
            clueKeys.push_back(parts.join(QLatin1Char(':')));
        }
    }

    std::vector<std::uint32_t> masks;
    masks.reserve(static_cast<std::size_t>(m_masks.size()));
    for (quint32 mask : m_masks)
        masks.push_back(static_cast<std::uint32_t>(mask));
    const std::vector<std::uint8_t> fixed(m_fixed.cbegin(), m_fixed.cend());
    const std::vector<int> solution(m_solution.cbegin(), m_solution.cend());

    const SherlockHints::Hint found = SherlockHints::find(
        m_size, masks, fixed, solution, clues);
    if (found.action != SherlockHints::NoAction && found.cell >= 0 &&
            found.item >= 0) {
        const bool eliminates = found.action == SherlockHints::Eliminate;
        const bool hasClue = found.clueIndex >= 0 &&
                             found.clueIndex < static_cast<int>(clueKeys.size());
        setHint(found.cell, found.item, eliminates,
                hasClue ? clueKeys[static_cast<std::size_t>(found.clueIndex)]
                        : QString());
        if (hasClue) {
            emit message(eliminates
                         ? tr("Hint: remove the highlighted candidate using the highlighted clue.")
                         : tr("Hint: make the highlighted candidate certain using the highlighted clue."));
        } else {
            emit message(eliminates
                         ? tr("Hint: remove the highlighted candidate using the one-of-each row rule.")
                         : tr("Hint: make the highlighted candidate certain using the one-of-each row rule."));
        }
        return;
    }

    emit message(tr("No hint is needed."));
}

void SherlockEngine::applyHint()
{
    if (!hasHint()) {
        emit message(tr("No hint to apply."));
        return;
    }

    const int n = m_size;
    const int i = m_hintCell;
    const int row = i / n;
    const int col = i % n;
    const int item = m_hintItem;
    const bool eliminates = m_hintEliminates;

    // A stale hint must never invoke setCertain's deliberate tap-again reset.
    // Clear it and find the next deduction instead.
    const quint32 candidate = bit(item);
    if ((eliminates && (m_masks[i] & candidate) == 0) ||
            (!eliminates && m_masks[i] == candidate)) {
        clearHint();
        hint();
        return;
    }

    if (eliminates)
        eliminateCandidate(row, col, item);
    else
        setCertain(row, col, item);
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
    if (s.masks.size() != cells || s.fixed.size() != cells ||
            s.solution.size() != cells) {
        return false;
    }

    // Undo/redo belongs to the current puzzle. Givens, solution, seed and
    // clues are immutable puzzle identity; only candidate masks may change.
    // Reject a stale/legacy snapshot instead of silently replacing identity
    // and regenerating a different-looking clue model.
    if (s.fixed != m_fixed || s.solution != m_solution)
        return false;

    m_masks = s.masks;

    const quint32 fm = fullMask();

    // Defensive mask normalization.
    if (m_masks.size() != cells) {
        const int old = m_masks.size();
        m_masks.resize(cells);
        for (int i = old; i < cells; ++i) m_masks[i] = fm;
    }

    // Clamp masks: no zeros, no bits outside fullMask
    for (int i = 0; i < cells; ++i) {
        quint32 m = (m_masks[i] & fm);
        if (m == 0) m = fm;
        m_masks[i] = m;
    }

    clearHint();

    // Clues deliberately stay untouched: Undo/Redo changes board marks only.
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
    m_dosClueGroups.clear();

    const std::vector<int> solution(m_solution.cbegin(), m_solution.cend());
    const std::vector<std::uint8_t> fixed(m_fixed.cbegin(), m_fixed.cend());
    const SherlockClues::Result generated = SherlockClues::generate(
        m_size, solution, fixed, m_puzzleSeed, m_difficulty);

    if (!generated.valid) {
        emit dosClueGroupsChanged();
        return;
    }

    m_dosClueGroups.reserve(int(generated.groups.size()));
    for (const SherlockClues::Group &sourceGroup : generated.groups) {
        SemClueGroup group;
        group.orient = sourceGroup.orient;
        group.index = sourceGroup.index;
        group.clues.reserve(int(sourceGroup.clues.size()));

        for (const SherlockClues::Clue &source : sourceGroup.clues) {
            SemClue clue;
            clue.orient = source.orient;
            clue.index = source.index;
            clue.sem.type = static_cast<ClueType>(source.type);
            clue.sem.a = source.a;
            clue.sem.b = source.b;
            clue.sem.c = source.c;
            clue.sem.xMark = source.xMark;
            clue.sem.flags = source.flags;
            clue.sem.given = true;
            clue.aRow = source.aRow;
            clue.bRow = source.bRow;
            clue.cRow = source.cRow;
            clue.aCol = source.aCol;
            clue.bCol = source.bCol;
            clue.cCol = source.cCol;
            group.clues.push_back(clue);
        }
        m_dosClueGroups.push_back(group);
    }

    emit dosClueGroupsChanged();
    return;

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
        emit message(tr("No solution available to reveal."));
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
    emit message(tr("Solution revealed (debug)."));
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
        emit message(tr("Import failed: source file not found."));
        return false;
    }

    const QString destPath = QDir(dataDir()).filePath(QStringLiteral("sherlock.shi"));

    if (QFile::exists(destPath))
        QFile::remove(destPath);

    if (!QFile::copy(sourcePath, destPath)) {
        emit message(tr("Import failed: could not copy file into app data directory."));
        return false;
    }

    // Ensure readable
    QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser);

    const bool ok = loadSherlockShiFromDataDir();
    if (ok) emit message(tr("Imported sherlock.shi successfully."));
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
        emit message(tr("sherlock.shi is present but could not be decoded. Using placeholder icons."));
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
