@echo off
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
    echo Setting up speech-to-text for the first time...
    py -m venv .venv || goto :error
    .venv\Scripts\python.exe -m pip install --upgrade pip || goto :error
    .venv\Scripts\python.exe -m pip install -r requirements.txt || goto :error
)
.venv\Scripts\python.exe app.py
exit /b %errorlevel%

:error
echo.
echo Setup failed. Make sure Python 3 is installed and available as "py".
pause
exit /b 1
