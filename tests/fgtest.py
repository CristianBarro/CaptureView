"""Runs fgtest.qml and checks the generated in-between frames.

Pass: the white square in the t=0.5 frame is centred within 6 px of the
midpoint between its previous and current positions, and is not ghosted
(no strong white at the old/new edges only).
"""
import os
import sys

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QGuiApplication, QImage
from PySide6.QtQml import QQmlApplicationEngine


class Tester(QObject):
    def __init__(self) -> None:
        super().__init__()
        self.rows = []

    @Slot(QImage, float, float, float)
    def measure(self, img: QImage, expect: float, prev_c: float, cur_c: float) -> None:
        y = 560
        xs = [x for x in range(img.width()) if img.pixelColor(x, y).lightness() > 240]
        centre = sum(xs) / len(xs) if xs else -1.0
        width = (max(xs) - min(xs) + 1) if xs else 0
        self.rows.append((expect, centre, width, prev_c, cur_c))

    @Slot()
    def done(self) -> None:
        ok = True
        for expect, centre, width, prev_c, cur_c in self.rows:
            err = abs(centre - expect)
            good = err <= 6 and 100 <= width <= 140
            ok &= good
            print(f"expect {expect:7.1f}  got {centre:7.1f}  err {err:5.1f}  width {width:4d}  "
                  f"(prev {prev_c:.0f}, cur {cur_c:.0f})  {'OK' if good else 'FAIL'}")
        print("RESULT", "PASS" if ok and self.rows else "FAIL")
        QGuiApplication.quit()


def main() -> int:
    os.environ.setdefault("QSG_RHI_BACKEND", "d3d11")
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    tester = Tester()
    engine.rootContext().setContextProperty("tester", tester)
    engine.load(QUrl.fromLocalFile(os.path.join(os.path.dirname(os.path.abspath(__file__)), "fgtest.qml")))
    if not engine.rootObjects():
        return 1
    ret = app.exec()
    del engine
    return ret


if __name__ == "__main__":
    sys.exit(main())
