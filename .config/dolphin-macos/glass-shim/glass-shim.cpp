// Glass additions for Dolphin that neither its settings, the Kvantum theme nor glass.qss can do.
// Loaded with LD_PRELOAD by ~/.local/bin/dolphin-macos. Rebuild with ./build.sh (needed only if a
// Qt or KDE Frameworks update changes their major version; without the library Dolphin starts
// normally and just shows its stock location bar and icons).
//
//  1. Location bar padding: Dolphin pads the bar so the path lines up with the file view
//     (DolphinNavigatorsWidgetAction::adjustSpacing). Inside the pill that is a hole, so the one
//     Qt call it uses is replaced and that single widget is pinned to a small width.
//  2. Breadcrumb: Dolphin's own buttons show "▸ Downloads" in bold. A transparent widget is laid
//     over them that draws "⌂ Home › Downloads" instead and handles the clicks; Dolphin's buttons
//     underneath are kept but not painted. Editing the path (click on the empty part, Ctrl+L)
//     still uses Dolphin's own editor.
//  3. Toolbar icons: back, forward, view and search use SF Symbols, like the shell's bar.
#include <KUrlNavigator>
#include <QAction>
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QKeyEvent>
#include <QFontDatabase>
#include <QHash>
#include <QLineEdit>
#include <QMouseEvent>
#include <QPainter>
#include <QPointer>
#include <QPushButton>
#include <QSet>
#include <QSplitter>
#include <QTimer>
#include <QToolBar>
#include <QToolButton>
#include <cstdlib>

namespace {

const int kLead = 10; // left padding of the path inside the pill

// SF Symbols (private-use code points of SF Pro, the same font file the shell's bar uses)
const char32_t kHouse = 0x10039E, kFolder = 0x100215, kTrash = 0x100211;
const QHash<QString, char32_t> kToolbarGlyphs = {
    {QStringLiteral("go_back"), 0x100189},
    {QStringLiteral("go_forward"), 0x10018A},
    {QStringLiteral("view_settings"), 0x1001F7},
    {QStringLiteral("toggle_search"), 0x1002AB},
};

QString sfFamily()
{
    static QString family;
    static bool tried = false;
    if (!tried) {
        tried = true;
        const int id = QFontDatabase::addApplicationFont(QDir::homePath() + QStringLiteral("/.config/quickshell/ii/assets/fonts/SF-Pro-Text-Medium.otf"));
        const QStringList families = id < 0 ? QStringList() : QFontDatabase::applicationFontFamilies(id);
        if (!families.isEmpty())
            family = families.first();
    }
    return family;
}

void drawGlyph(QPainter &p, const QRectF &box, char32_t glyph, qreal pixelSize, const QColor &colour)
{
    QFont f(sfFamily());
    f.setPixelSize(qRound(pixelSize));
    p.setFont(f);
    p.setPen(colour);
    p.drawText(box, Qt::AlignCenter, QString::fromUcs4(&glyph, 1));
}

QIcon glyphIcon(char32_t glyph)
{
    QIcon icon;
    const int size = 16, scale = 3;
    const QPair<QIcon::Mode, int> modes[] = {{QIcon::Normal, 235}, {QIcon::Active, 255}, {QIcon::Disabled, 90}};
    for (const auto &mode : modes) {
        QPixmap pm(size * scale, size * scale);
        pm.setDevicePixelRatio(scale);
        pm.fill(Qt::transparent);
        QPainter p(&pm);
        p.setRenderHint(QPainter::TextAntialiasing);
        drawGlyph(p, QRectF(0, 0, size, size), glyph, 13, QColor(255, 255, 255, mode.second));
        p.end();
        icon.addPixmap(pm, mode.first);
    }
    return icon;
}

// ---------------------------------------------------------------------------------------------
// The breadcrumb drawn over Dolphin's location bar.
class Crumbs : public QWidget
{
public:
    explicit Crumbs(KUrlNavigator *nav)
        : QWidget(nav)
        , m_nav(nav)
    {
        setMouseTracking(true);
        setAttribute(Qt::WA_NoSystemBackground);
        setGeometry(nav->rect());
        connect(nav, &KUrlNavigator::urlChanged, this, [this] {
            rebuild();
            QTimer::singleShot(0, this, [this] { raise(); });
        });
        connect(nav, &KUrlNavigator::editableStateChanged, this, [this](bool editable) {
            setVisible(!editable);
            if (!editable)
                raise();
        });
        rebuild();
        setVisible(!nav->isUrlEditable());
        raise();
        if (qEnvironmentVariableIsSet("GLASS_SHIM_SELFTEST"))
            selfTest();
    }

    // GLASS_SHIM_SELFTEST=<log file>: clicks "Home", then the empty part, then presses Escape, by
    // sending the events directly (the real pointer is not touched) and logs what happened.
    void selfTest()
    {
        auto log = [this](const char *step) {
            QFile f(qEnvironmentVariable("GLASS_SHIM_SELFTEST"));
            if (f.open(QIODevice::Append))
                f.write(QByteArray(step) + " url=" + m_nav->locationUrl().toString().toUtf8() + " editable=" + (m_nav->isUrlEditable() ? "1" : "0")
                        + " crumbs=" + (isVisible() ? "shown" : "hidden") + " segments=" + QByteArray::number(m_all.size()) + "\n");
        };
        auto click = [this](const QPoint &at) {
            QMouseEvent press(QEvent::MouseButtonPress, at, mapToGlobal(at), Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
            QApplication::sendEvent(this, &press);
            QMouseEvent release(QEvent::MouseButtonRelease, at, mapToGlobal(at), Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
            QApplication::sendEvent(this, &release);
        };
        QTimer::singleShot(900, this, [=] { log("start"); click(m_all.first().box.center()); });
        QTimer::singleShot(1300, this, [=] { log("after-click-home"); click(QPoint(width() - 60, height() / 2)); });
        QTimer::singleShot(1700, this, [=] { log("after-click-empty"); });
        if (qEnvironmentVariable("GLASS_SHIM_SELFTEST_ESC") == QLatin1String("1")) {
            QTimer::singleShot(2000, this, [=] {
                if (auto *edit = m_nav->findChild<QLineEdit *>()) {
                    QKeyEvent press(QEvent::KeyPress, Qt::Key_Escape, Qt::NoModifier);
                    QApplication::sendEvent(edit, &press);
                }
            });
            QTimer::singleShot(2300, this, [=] { log("after-escape"); });
        }
    }

    void rebuild()
    {
        m_all.clear();
        const QUrl url = m_nav->locationUrl();
        const QString home = QDir::homePath();
        QUrl root;
        QString rest;
        if (url.isLocalFile()) {
            const QString path = QDir::cleanPath(url.toLocalFile());
            if (path == home || path.startsWith(home + QLatin1Char('/'))) {
                root = QUrl::fromLocalFile(home);
                rest = path.mid(home.length());
                m_glyph = kHouse;
                m_all.append({QStringLiteral("Home"), root, QRect()});
            } else {
                root = QUrl::fromLocalFile(QStringLiteral("/"));
                rest = path;
                m_glyph = kFolder;
                m_all.append({QStringLiteral("Computer"), root, QRect()});
            }
        } else {
            root = url;
            root.setPath(QStringLiteral("/"));
            root.setQuery(QString());
            rest = url.path();
            const QString scheme = url.scheme();
            m_glyph = scheme == QLatin1String("trash") ? kTrash : kFolder;
            QString name = !url.host().isEmpty() ? url.host()
                : scheme == QLatin1String("trash") ? QStringLiteral("Trash")
                : scheme == QLatin1String("remote") ? QStringLiteral("Network")
                : scheme == QLatin1String("recentlyused") || scheme == QLatin1String("timeline") ? QStringLiteral("Recent")
                : scheme == QLatin1String("tags") ? QStringLiteral("Tags")
                : scheme;
            m_all.append({name, root, QRect()});
        }
        QString walked = root.path();
        const QStringList parts = rest.split(QLatin1Char('/'), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            if (!walked.endsWith(QLatin1Char('/')))
                walked += QLatin1Char('/');
            walked += part;
            QUrl u = root;
            u.setPath(walked);
            m_all.append({part, u, QRect()});
        }
        m_hover = -1;
        arrange();
        update();
    }

protected:
    struct Seg {
        QString text;
        QUrl url;
        QRect box;
    };

    QFont textFont() const
    {
        QFont f = m_nav->font();
        f.setWeight(QFont::Normal);
        return f;
    }

    // Lays the segments out left to right; when they do not fit, the ones after the first are
    // dropped (shown as "…") until they do.
    void arrange()
    {
        const QFontMetrics fm(textFont());
        const int sepWidth = fm.horizontalAdvance(QStringLiteral("›")) + 2 * kGap;
        const int available = width() - kIconLeft - kIcon - kGap - 16;
        int skip = 0;
        for (;; ++skip) {
            int need = 0;
            for (int i = 0; i < m_all.size(); ++i) {
                if (i > 0 && i <= skip)
                    continue;
                need += fm.horizontalAdvance(m_all[i].text) + (i > 0 ? sepWidth : 0);
            }
            if (skip > 0)
                need += fm.horizontalAdvance(QStringLiteral("…")) + sepWidth;
            if (need <= available || skip >= m_all.size() - 2)
                break;
        }
        m_skip = m_all.size() > 2 ? skip : 0;
        int x = kIconLeft + kIcon + kGap;
        for (int i = 0; i < m_all.size(); ++i) {
            if (i > 0 && i <= m_skip) {
                m_all[i].box = QRect();
                continue;
            }
            if (i > 0)
                x += sepWidth;
            if (i == 1 + m_skip && m_skip > 0)
                x += fm.horizontalAdvance(QStringLiteral("…")) + sepWidth;
            const int w = fm.horizontalAdvance(m_all[i].text);
            m_all[i].box = QRect(x - 5, (height() - 20) / 2, w + 10, 20);
            x += w;
        }
    }

    int segmentAt(const QPoint &pos) const
    {
        for (int i = 0; i < m_all.size(); ++i) {
            if (m_all[i].box.contains(pos))
                return i;
        }
        return -1;
    }

    void paintEvent(QPaintEvent *) override
    {
        QPainter p(this);
        p.setRenderHints(QPainter::Antialiasing | QPainter::TextAntialiasing);
        drawGlyph(p, QRectF(kIconLeft, (height() - kIcon) / 2.0, kIcon, kIcon), m_glyph, 12.5, QColor(255, 255, 255, 235));
        const QFont f = textFont();
        const QFontMetrics fm(f);
        const QColor dim(255, 255, 255, 150);
        const int sepWidth = fm.horizontalAdvance(QStringLiteral("›")) + 2 * kGap;
        for (int i = 0; i < m_all.size(); ++i) {
            const Seg &s = m_all[i];
            if (s.box.isNull())
                continue;
            p.setFont(f);
            if (i > 0) {
                p.setPen(dim);
                QRect sep(s.box.left() + 5 - sepWidth, 0, sepWidth, height());
                p.drawText(sep, Qt::AlignCenter, QStringLiteral("›"));
                if (i == 1 + m_skip && m_skip > 0) {
                    const int w = fm.horizontalAdvance(QStringLiteral("…"));
                    p.drawText(QRect(sep.left() - w, 0, w, height()), Qt::AlignCenter, QStringLiteral("…"));
                    p.drawText(QRect(sep.left() - w - sepWidth, 0, sepWidth, height()), Qt::AlignCenter, QStringLiteral("›"));
                }
            }
            if (i == m_hover) {
                p.setPen(Qt::NoPen);
                p.setBrush(QColor(255, 255, 255, 30));
                p.drawRoundedRect(s.box, 7, 7);
            }
            p.setPen(Qt::white);
            p.drawText(s.box, Qt::AlignCenter, s.text);
        }
    }

    void resizeEvent(QResizeEvent *) override
    {
        arrange();
    }

    void mouseMoveEvent(QMouseEvent *e) override
    {
        const int at = segmentAt(e->pos());
        if (at != m_hover) {
            m_hover = at;
            setCursor(at >= 0 ? Qt::PointingHandCursor : Qt::IBeamCursor);
            update();
        }
    }

    void leaveEvent(QEvent *) override
    {
        m_hover = -1;
        update();
    }

    void mousePressEvent(QMouseEvent *e) override
    {
        if (e->button() == Qt::LeftButton || e->button() == Qt::MiddleButton) {
            m_pressed = segmentAt(e->pos());
            e->accept();
        } else {
            e->ignore(); // right click: Dolphin's own location-bar menu
        }
    }

    void mouseReleaseEvent(QMouseEvent *e) override
    {
        if (e->button() != Qt::LeftButton && e->button() != Qt::MiddleButton) {
            e->ignore();
            return;
        }
        const int at = segmentAt(e->pos());
        const QPointer<KUrlNavigator> nav = m_nav;
        if (at >= 0 && at == m_pressed) {
            const QUrl url = m_all[at].url;
            if (e->button() == Qt::MiddleButton)
                Q_EMIT nav->tabRequested(url);
            else
                nav->setLocationUrl(url);
        } else if (at < 0 && m_pressed < 0 && e->button() == Qt::LeftButton) {
            nav->setUrlEditable(true);
            if (nav) {
                if (auto *edit = nav->findChild<QLineEdit *>()) {
                    edit->setFocus();
                    edit->selectAll();
                }
            }
        }
        m_pressed = -1;
    }

    void contextMenuEvent(QContextMenuEvent *e) override
    {
        e->ignore();
    }

private:
    static constexpr int kIconLeft = 4, kIcon = 16, kGap = 7;
    KUrlNavigator *m_nav;
    QList<Seg> m_all;
    char32_t m_glyph = kHouse;
    int m_skip = 0, m_hover = -1, m_pressed = -1;
};

// ---------------------------------------------------------------------------------------------
class GlassFilter : public QObject
{
public:
    using QObject::QObject;

    bool eventFilter(QObject *watched, QEvent *event) override
    {
        if (!watched->isWidgetType())
            return false;
        switch (event->type()) {
        case QEvent::Paint: {
            // Dolphin's own breadcrumb buttons stay in place but are not drawn while ours is shown.
            auto *w = static_cast<QWidget *>(watched);
            const auto it = m_crumbs.constFind(w->parentWidget());
            if (it != m_crumbs.constEnd() && *it && w != *it && (*it)->isVisible() && qobject_cast<QPushButton *>(w))
                return true;
            break;
        }
        case QEvent::Polish:
            if (auto *nav = qobject_cast<KUrlNavigator *>(watched)) {
                if (!m_crumbs.contains(nav)) {
                    m_crumbs.insert(nav, nullptr);
                    QTimer::singleShot(0, nav, [this, nav] {
                        m_crumbs[nav] = new Crumbs(nav);
                        connect(nav, &QObject::destroyed, this, [this, nav] { m_crumbs.remove(nav); });
                    });
                }
            } else if (auto *button = qobject_cast<QToolButton *>(watched)) {
                applyIcon(button);
            }
            break;
        case QEvent::ActionChanged:
            // the button copies the action's icon again while handling this, so go after it
            if (auto *button = qobject_cast<QToolButton *>(watched))
                QTimer::singleShot(0, button, [this, button] { applyIcon(button); });
            break;
        case QEvent::Resize:
        case QEvent::ChildAdded: {
            const auto it = m_crumbs.constFind(static_cast<QWidget *>(watched));
            if (it != m_crumbs.constEnd() && *it) {
                Crumbs *crumbs = *it;
                if (event->type() == QEvent::Resize)
                    crumbs->setGeometry(static_cast<QWidget *>(watched)->rect());
                else
                    QTimer::singleShot(0, crumbs, [crumbs] { crumbs->raise(); });
            }
            break;
        }
        default:
            break;
        }
        return false;
    }

private:
    void applyIcon(QToolButton *button)
    {
        auto *bar = qobject_cast<QToolBar *>(button->parentWidget());
        QAction *action = button->defaultAction();
        if (!bar || !action || bar->objectName() != QLatin1String("mainToolBar") || sfFamily().isEmpty())
            return;
        const auto glyph = kToolbarGlyphs.constFind(action->objectName());
        if (glyph == kToolbarGlyphs.constEnd())
            return;
        auto icon = m_icons.constFind(action->objectName());
        if (icon == m_icons.constEnd())
            icon = m_icons.insert(action->objectName(), glyphIcon(*glyph));
        if (button->icon().cacheKey() != icon->cacheKey())
            button->setIcon(*icon); // only the toolbar button; menus keep the theme's icon
    }

    QHash<QWidget *, Crumbs *> m_crumbs;
    QHash<QString, QIcon> m_icons;
};

void glassStart()
{
    if (QCoreApplication::applicationName() != QLatin1String("dolphin") && !QCoreApplication::applicationFilePath().endsWith(QLatin1String("/dolphin")))
        return;
    qApp->installEventFilter(new GlassFilter(qApp));
}
Q_COREAPP_STARTUP_FUNCTION(glassStart)

__attribute__((constructor)) void glassShimInit()
{
    unsetenv("LD_PRELOAD"); // keep it out of the programs Dolphin starts
}

bool isLocationPadding(const QWidget *w)
{
    if (!w || w->metaObject() != &QWidget::staticMetaObject)
        return false;
    const QWidget *holder = w->parentWidget();
    if (!holder || holder->metaObject() != &QWidget::staticMetaObject)
        return false;
    return qobject_cast<const QSplitter *>(holder->parentWidget()) != nullptr;
}

} // namespace

extern "C" __attribute__((visibility("default"))) void _ZN7QWidget15setMinimumWidthEi(QWidget *self, int width)
{
    if (isLocationPadding(self)) {
        self->setMinimumSize(kLead, self->minimumHeight());
        self->setMaximumSize(kLead, self->maximumHeight());
        return;
    }
    self->setMinimumSize(width, self->minimumHeight());
}
