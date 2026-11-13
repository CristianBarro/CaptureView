@echo off
rem Builds dist\CaptureView.exe (single file).
rem Needs Python 3.12+ on PATH. First run creates .venv and installs deps.
setlocal
cd /d "%~dp0"

if not exist .venv\Scripts\python.exe (
  python -m venv .venv || exit /b 1
  .venv\Scripts\python.exe -m pip install --upgrade pip
  .venv\Scripts\pip.exe install -r requirements.txt || exit /b 1
)

set QSB=.venv\Lib\site-packages\PySide6\qsb.exe
for %%S in (cas flow interp) do (
  "%QSB%" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o %%S.frag.qsb %%S.frag || exit /b 1
)

.venv\Scripts\pyinstaller.exe --noconfirm --onefile --windowed --name CaptureView ^
  --add-data "main.qml;." --add-data "cas.frag.qsb;." --add-data "flow.frag.qsb;." --add-data "interp.frag.qsb;." ^
  --exclude-module PySide6.QtWebEngineCore --exclude-module PySide6.QtWebEngineWidgets ^
  --exclude-module PySide6.Qt3DCore --exclude-module PySide6.QtCharts ^
  --exclude-module PySide6.QtDataVisualization --exclude-module PySide6.QtPdf --exclude-module tkinter ^
  main.py || exit /b 1

echo.
echo Pronto: dist\CaptureView.exe
