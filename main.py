import os
import sys
from collections import deque

import numpy as np

from PySide6.QtCore import Property, QObject, QProcess, QSettings, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtMultimedia import QVideoFrame, QVideoFrameFormat
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle


class FmtName(QObject):
    """Turns a QVideoFrameFormat.PixelFormat int into a short name for the UI."""

    @Slot(int, result=str)
    def name(self, pf: int) -> str:
        try:
            return QVideoFrameFormat.PixelFormat(pf).name.replace("Format_", "")
        except ValueError:
            return str(pf)


class FrameGen(QObject):
    """Detects repeated frames (e.g. a 30 fps game inside a 60 Hz signal).

    Samples ~2k bytes of each mapped frame and compares with the previous one.
    Emits frameInfo(unique, repeatMode): repeatMode is true while repeated
    frames were seen recently, which is when interpolation is worth doing.
    """

    frameInfo = Signal(bool, bool)
    statsChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._last = None
        self._hist: deque = deque(maxlen=8)
        self._enabled = False
        self._dups = 0
        self._total = 0
        self._dup_ratio = 0.0

    @Slot(QObject)
    def attach(self, sink: QObject) -> None:
        sink.videoFrameChanged.connect(self._on_frame)

    @Slot(bool)
    def setEnabled(self, on: bool) -> None:
        self._enabled = on
        self._last = None
        self._hist.clear()

    @Property(float, notify=statsChanged)
    def dupRatio(self) -> float:
        return self._dup_ratio

    def _on_frame(self, frame) -> None:
        if not self._enabled:
            return
        unique = True
        f = QVideoFrame(frame)
        if f.map(QVideoFrame.MapMode.ReadOnly):
            try:
                n = f.mappedBytes(0)
                buf = np.frombuffer(f.bits(0), dtype=np.uint8, count=n)
                sample = buf[:: max(1, n // 2048)].astype(np.int16)
                if self._last is not None and sample.shape == self._last.shape:
                    unique = float(np.abs(sample - self._last).mean()) > 0.6
                self._last = sample
            except (TypeError, ValueError):
                unique = True
            finally:
                f.unmap()
        self._hist.append(not unique)
        self._total += 1
        self._dups += 0 if unique else 1
        if self._total >= 60:
            self._dup_ratio = self._dups / self._total
            self._dups = self._total = 0
            self.statsChanged.emit()
        self.frameInfo.emit(unique, any(self._hist))


class SelftestLog(QObject):
    """Writes the --selftest result to %TEMP%\\CaptureView-selftest.log (GUI exe has no console)."""

    @Slot(str)
    def write(self, msg: str) -> None:
        path = os.path.join(os.environ.get("TEMP", "."), "CaptureView-selftest.log")
        with open(path, "w", encoding="utf-8") as f:
            f.write(msg + "\n")


class AppControl(QObject):
    """Restart the app (renderer change needs a fresh process)."""

    @Slot()
    def restart(self) -> None:
        exe = sys.executable
        args = [] if getattr(sys, "frozen", False) else [os.path.abspath(__file__)]
        if "--restarttest" in sys.argv:
            args.append("--selftest")  # build check: new process logs and quits
        else:
            args += [a for a in sys.argv[1:] if a not in ("--selftest", "--gpu", "--d3d11", "--d3d12")]
        # onefile: new process must unpack its own copy, not reuse ours (deleted on exit)
        os.environ["PYINSTALLER_RESET_ENVIRONMENT"] = "1"
        QProcess.startDetached(exe, args)
        QGuiApplication.quit()

    @Slot(result=str)
    def renderer(self) -> str:
        return os.environ.get("QSG_RHI_BACKEND", "d3d11")


def base_dir() -> str:
    if getattr(sys, "frozen", False):
        return getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def main() -> int:
    # Renderer: D3D11 (default) or D3D12 (needed for ReShade DX12 add-ons like DLSS5).
    # Saved by the QML Settings item; "--d3d12" / "--d3d11" override it.
    renderer = str(QSettings("CaptureView", "CaptureView").value("renderer", "d3d11"))
    if "--d3d12" in sys.argv:
        renderer = "d3d12"
    elif "--d3d11" in sys.argv:
        renderer = "d3d11"
    os.environ["QSG_RHI_BACKEND"] = "d3d12" if renderer == "d3d12" else "d3d11"
    QQuickStyle.setStyle("Fusion")

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("CaptureView")
    app.setApplicationName("CaptureView")

    engine = QQmlApplicationEngine()
    fmt_name = FmtName()
    selftest_log = SelftestLog()
    engine.rootContext().setContextProperty("fmtName", fmt_name)
    engine.rootContext().setContextProperty("selftestLog", selftest_log)
    frame_gen = FrameGen()
    engine.rootContext().setContextProperty("frameGen", frame_gen)
    app_control = AppControl()
    engine.rootContext().setContextProperty("appControl", app_control)
    engine.load(QUrl.fromLocalFile(os.path.join(base_dir(), "main.qml")))
    if not engine.rootObjects():
        return 1
    ret = app.exec()
    # tear down QML before the Python helpers it references
    del engine
    return ret


if __name__ == "__main__":
    sys.exit(main())
