#pragma once

#include <QObject>
#include <QVector>
#include <QImage>
#include <QElapsedTimer>
#include <QVariantList>
#include <QSettings>
#include <QDateTime>

class SherlockEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int size READ size WRITE setSize NOTIFY sizeChanged)
    Q_PROPERTY(QVariantList boardMasks READ boardMasks NOTIFY boardChanged)
    Q_PROPERTY(QVariantList clues READ clues NOTIFY cluesChanged)

    Q_PROPERTY(bool hasImportedImages READ hasImportedImages NOTIFY imagesChanged)
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)

    Q_PROPERTY(IconSource iconSource READ iconSource WRITE setIconSource NOTIFY iconSourceChanged)

    Q_PROPERTY(int iconEpoch READ iconEpoch NOTIFY imagesChanged)
    int iconEpoch() const { return m_iconEpoch; }

public:
    enum IconSource {
        Generated = 0,
        Shi       = 1
    };
    Q_ENUM(IconSource)
    Q_INVOKABLE int ICON_GENERATED() const { return int(Generated); }
    Q_INVOKABLE int ICON_SHI() const { return int(Shi); }

    explicit SherlockEngine(QObject *parent = nullptr);

    int size() const { return m_size; }
    void setSize(int n);

    QVariantList boardMasks() const;
    QVariantList clues() const;
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

    IconSource iconSource() const { return m_iconSource; }
    void setIconSource(int v);

signals:
    void sizeChanged();
    void boardChanged();
    void cluesChanged();
    void imagesChanged();
    void message(const QString &text);
    void iconSourceChanged();

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

private:
    int m_size {6};
    QVector<quint32> m_masks;
    QVector<quint8>  m_fixed;           // 1 => given/locked cell
    bool m_hasImages {false};
    int m_iconEpoch {0};

    QVector<QImage> m_placeholders;
    QVector<QImage> m_fullShi;
    QVector<QImage> m_halfShi;

    IconSource m_iconSource {Generated};

    // hidden solution (size*size entries, each 0..(size-1))
    QVector<int> m_solution;

    QVector<QString> m_clues;
    void rebuildClues();   // placeholder generator for now

    // minimal generator (Latin-square-like; good enough for now)
    void generateSolution();

    void loadState();
    void saveState() const;
    QString settingsPathHint() const;
};
