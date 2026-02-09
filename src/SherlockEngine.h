#pragma once

#include <sailfishapp.h>
#include <QObject>
#include <QVector>
#include <QImage>
#include <QElapsedTimer>
#include <QVariantList>
#include <QString>
#include <QSettings>
#include <QDateTime>
#include <QHash>
#include <QTimer>
#include <QSet>
#include <QJsonDocument>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include "ClueSemantics.h"

class SherlockEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int size READ size WRITE setSize NOTIFY sizeChanged)
    Q_PROPERTY(QVariantList boardMasks READ boardMasks NOTIFY boardChanged)

    Q_PROPERTY(bool hasImportedImages READ hasImportedImages NOTIFY imagesChanged)
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)

    Q_PROPERTY(IconSource iconSource READ iconSource WRITE setIconSource NOTIFY iconSourceChanged)

    Q_PROPERTY(int iconEpoch READ iconEpoch NOTIFY imagesChanged)
    int iconEpoch() const { return m_iconEpoch; }
    Q_PROPERTY(QVariantList clues READ clues NOTIFY cluesChanged)
    Q_PROPERTY(QVariantList clueGroups READ clueGroups NOTIFY clueGroupsChanged)
    // DOS-authentic semantic clues derived from the solution
    Q_PROPERTY(QVariantList dosClueGroups READ dosClueGroups NOTIFY dosClueGroupsChanged)

    Q_PROPERTY(int puzzleSource READ puzzleSource NOTIFY puzzleIdentityChanged)
    Q_PROPERTY(int puzzleId READ puzzleId NOTIFY puzzleIdentityChanged)
    Q_PROPERTY(quint32 puzzleSeed READ puzzleSeed NOTIFY puzzleIdentityChanged)

    Q_PROPERTY(int lastTouchedRow READ lastTouchedRow NOTIFY lastTouchedChanged)
    Q_PROPERTY(int lastTouchedCol READ lastTouchedCol NOTIFY lastTouchedChanged)

    Q_PROPERTY(int elapsedSeconds READ elapsedSeconds NOTIFY elapsedSecondsChanged)
    Q_PROPERTY(bool timerRunning READ timerRunning NOTIFY timerRunningChanged)

    Q_PROPERTY(QVariantList scores READ scores NOTIFY scoresChanged)
    Q_PROPERTY(bool autoCompleteEnabled READ autoCompleteEnabled WRITE setAutoCompleteEnabled NOTIFY autoCompleteEnabledChanged)

public:
    enum PuzzleSource { Bank = 0, GeneratedPuzzle = 1 };
    Q_ENUM(PuzzleSource)

    Q_INVOKABLE int PUZZLE_BANK() const { return int(Bank); }
    Q_INVOKABLE int PUZZLE_GENERATED() const { return int(GeneratedPuzzle); }

    int puzzleSource() const { return int(m_puzzleSource); }
    int puzzleId() const { return m_puzzleId; }
    quint32 puzzleSeed() const { return m_puzzleSeed; }
    int lastTouchedRow() const { return m_lastTouchedRow; }
    int lastTouchedCol() const { return m_lastTouchedCol; }

    int elapsedSeconds() const { return m_elapsedSeconds; }
    bool timerRunning() const { return m_timerRunning; }

    Q_INVOKABLE void startRandomPuzzle();
    Q_INVOKABLE void startBankPuzzle(int puzzleId);
    Q_INVOKABLE void nextBankPuzzle();
    Q_INVOKABLE void previousBankPuzzle();
    Q_INVOKABLE void restartCurrentPuzzle();
    Q_INVOKABLE void setBoardSize(int n);   // convenience for QML (wraps setSize)

    Q_INVOKABLE void timerReset();
    Q_INVOKABLE void timerStart();
    Q_INVOKABLE void timerStop();
    Q_INVOKABLE void timerOnUserAction();   // call this from QML on first move

    Q_INVOKABLE void clearScores();
    Q_INVOKABLE void reloadScores();

    Q_INVOKABLE void setPlayerName(const QString &name);

    QVariantList scores() const { return m_scores; }

    enum IconSource {
        Generated = 0,
        Shi       = 1
    };
    Q_ENUM(IconSource)
    Q_INVOKABLE int ICON_GENERATED() const { return int(Generated); }
    Q_INVOKABLE int ICON_SHI() const { return int(Shi); }

    explicit SherlockEngine(QObject *parent = nullptr);

    int size() const { return m_size; }

    QVariantList boardMasks() const;
    QVariantList clues() const;
    QVariantList clueGroups() const;
    QVariantList dosClueGroups() const; // DOS-authentic semantic clues derived from the solution
    bool hasImportedImages() const { return m_hasImages; }

    QString dataDir() const;

    // Image lookup used by SherlockImageProvider
    QImage iconFor(int row, int item, int pixelSize) const;

    Q_INVOKABLE void newGame();
    Q_INVOKABLE void resetMarks();
    Q_INVOKABLE int maskAt(int row, int col) const;

    // Debug helper (for now): force board to the generated solution
    Q_INVOKABLE void revealSolution();

    // Candidate operations: item is 0..(size-1)
    Q_INVOKABLE void toggleCandidate(int row, int col, int item);
    Q_INVOKABLE void eliminateCandidate(int row, int col, int item);
    Q_INVOKABLE void setCertain(int row, int col, int item);

    Q_INVOKABLE bool importSherlockShi(const QString &sourcePath);
    Q_INVOKABLE void resetCell(int row, int col);

    // "givens" (locked cells)
    Q_INVOKABLE bool fixedAt(int row, int col) const;

    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoRedoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY undoRedoChanged)

    Q_INVOKABLE bool canUndo() const { return !m_undo.isEmpty(); }
    Q_INVOKABLE bool canRedo() const { return !m_redo.isEmpty(); }

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    Q_PROPERTY(bool solved READ solved NOTIFY solvedChanged)
    bool solved() const { return m_solved; }

    Q_PROPERTY(QVariantList conflictCells READ conflictCells NOTIFY conflictCellsChanged)
    Q_INVOKABLE QVariantList conflictCells() const;
    Q_INVOKABLE void verify();

    Q_PROPERTY(int hintCell READ hintCell NOTIFY hintChanged)
    Q_PROPERTY(int hintItem READ hintItem NOTIFY hintChanged)
    Q_PROPERTY(bool hasHint READ hasHint NOTIFY hintChanged)

    int hintCell() const { return m_hintCell; }   // 0..n*n-1, or -1
    int hintItem() const { return m_hintItem; }   // 0..n-1, or -1
    bool hasHint() const { return m_hintCell >= 0 && m_hintItem >= 0; }

    Q_INVOKABLE void hint();
    Q_INVOKABLE void applyHint();
    Q_INVOKABLE void clearHint();

    IconSource iconSource() const { return m_iconSource; }
    void setIconSource(int v);

    enum ClueOrient { Vertical = 0, Horizontal = 1 };
    Q_ENUM(ClueOrient)

    Q_INVOKABLE int bankCount();
    Q_INVOKABLE void setSize(int n);

    // Bank puzzle picker + solved persistence
    Q_INVOKABLE QVariantList bankPuzzleEntries() const;   // [{ id: 0..count-1, solved: bool }, ...]
    Q_INVOKABLE bool bankPuzzleSolved(int puzzleId) const;
    Q_INVOKABLE void clearSolvedBankPuzzles();            // clears for current size
    Q_INVOKABLE int currentBankPuzzleId() const;

    bool autoCompleteEnabled() const { return m_autoCompleteEnabled; }
    Q_INVOKABLE void setAutoCompleteEnabled(bool on);

signals:
    void sizeChanged();
    void boardChanged();
    void cluesChanged();
    void clueGroupsChanged();
    void imagesChanged();
    void message(const QString &text);
    void iconSourceChanged();
    void undoRedoChanged();
    void conflictCellsChanged();
    void solvedChanged();
    void hintChanged();
    void puzzleIdentityChanged();
    void lastTouchedChanged();
    void dosClueGroupsChanged();
    void elapsedSecondsChanged();
    void timerRunningChanged();
    void scoresChanged();
    void solvedBankChanged();
    void autoCompleteEnabledChanged();

private:
    int idx(int row, int col) const { return row * m_size + col; }
    quint32 fullMask() const { return (m_size >= 32) ? 0xFFFFFFFFu : ((1u << m_size) - 1u); }
    static quint32 bit(int item) { return (item >= 0 && item < 32) ? (1u << item) : 0u; }

    bool isFixedIndex(int i) const { return (i >= 0 && i < m_fixed.size() && m_fixed[i] != 0); }
    int defaultGivenCount() const;

    void setMask(int row, int col, quint32 m);
    void rebuildForSize();
    void propagateCertain(int row, int col, int item);

    bool loadSherlockShiFromDataDir();
    void buildPlaceholderIcons();

    QTimer m_gameTimer;
    int m_elapsedSeconds = 0;
    bool m_timerRunning = false;
    bool m_timerArmed = false; // "start on first action" gate

private:
    // --- Undo/Redo snapshot (Step 1: internal) ---
    struct Snapshot {
        int size = 0;
        QVector<quint32> masks;   // m_masks
        QVector<quint8> fixed;    // m_fixed
        QVector<int> solution;    // m_solution (keeps game identity stable for undo/redo + future “check” features)
    };

    Snapshot captureSnapshot() const;
    bool applySnapshot(const Snapshot &s, bool persist);

    QVector<Snapshot> m_undo;
    QVector<Snapshot> m_redo;

    bool m_solved {false};
    void updateSolvedState(bool announce);
    bool isSolvedNow() const;
    bool m_autoPropagate {false};   // v1.0: classic marking only (no auto elimination)

    int m_lastTouchedRow {-1};
    int m_lastTouchedCol {-1};
    void setLastTouched(int row, int col);

    int m_size {6};
    QVector<quint32> m_masks;
    QVector<quint8>  m_fixed;           // 1 => given/locked cell
    // hidden solution (size*size entries, each 0..(size-1))
    QVector<int> m_solution;

    QVector<int> m_conflictCells; // stores 0..(n*n-1) indices
    void clearConflicts();
    void setConflicts(const QVector<int> &cells);

    bool m_hasImages {false};
    int m_iconEpoch {0};

    QVector<QImage> m_placeholders;
    QVector<QImage> m_fullShi;
    QVector<QImage> m_halfShi;

    IconSource m_iconSource {Generated};

    int m_undoLimit {50};

    void rebuildClues();
    void rebuildDosClues();

    void generateSolutionFromSeed(quint32 seed);

    void loadState();
    void saveState() const;
    QString settingsPathHint() const;

    struct Clue {
        int type = 0; // keep your meaning (0=Given for now)
        int row = 0;
        int col = 0;
        int item = 0;
        // formal meaning
        ClueSemantic sem;
    };

    QVector<Clue> m_clues;
    struct ClueGroup {
        int orient = Vertical;     // 0=Vertical, 1=Horizontal
        int index = -1;             // 0..(n-1), column for vertical, row for horizontal
        QVector<Clue> clues;       // 2..3 entries ideally
    };

    QVector<ClueGroup> m_clueGroups;

    // Semantic (DOS-style) clue stream
    struct SemClue {
        ClueSemantic sem;
        int orient = Vertical; // Vertical/Horizontal for grouping
        int index = 0;         // column or row index
        int aRow = 0;
        int aCol = 0;
        int bRow = 0;
        int bCol = 0;
    };
    struct SemClueGroup {
        int orient = Vertical;
        int index = 0;
        QVector<SemClue> clues;
    };
    QVector<SemClueGroup> m_dosClueGroups;

    void pushUndoSnapshot();
    void clearRedo();

    int m_hintCell {-1};
    int m_hintItem {-1};

    void setHint(int cell, int item);

    PuzzleSource m_puzzleSource {GeneratedPuzzle};
    int m_puzzleId {-1};        // valid when Bank
    quint32 m_puzzleSeed {0};   // valid when GeneratedPuzzle (or also for Bank stub)

    quint32 makeBankSeed(int size, int puzzleId) const;
    void startPuzzleCommon(bool clearProgress);

    // Bank seeds (loaded from qml/assets/puzzles/bank_{4,5,6}.txt)
    QVector<quint32> m_bankSeeds4;
    QVector<quint32> m_bankSeeds5;
    QVector<quint32> m_bankSeeds6;
    bool m_bankLoaded4 {false};
    bool m_bankLoaded5 {false};
    bool m_bankLoaded6 {false};

    bool ensureBankLoaded(int size);
    const QVector<quint32>& bankSeedsForSize(int size) const;
    QVector<quint32>& bankSeedsForSize(int size);
    int bankCountForSize(int size);
    bool isSeedInBank(int size, quint32 seed) const;

    QVariantList m_scores;
    QString scoresFilePath() const;
    void loadScoresFromDisk();
    void saveScoresToDisk() const;
    void appendScoreIfSolved();

    QString m_playerName;

    QString solvedBankFilePath(int size) const;
    void loadSolvedBankFromDisk(int size);
    void saveSolvedBankToDisk(int size) const;
    void markCurrentBankPuzzleSolved();
    QSet<int> m_solvedBankIds; // for current m_size only

    int ambiguousCellCount() const;
    bool applyHiddenSinglesPass(bool &anyChange);
    bool tryAutoCompleteTrivialFinish();

    bool m_autoCompleteEnabled = false;
    bool m_inAutoComplete = false;
};