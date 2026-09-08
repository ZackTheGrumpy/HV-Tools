@echo off
:: Restore MSI Afterburner after gaming session
:: Run as Administrator

fltmc >nul 2>&1 || (
    echo Requesting admin rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "AB_DIR=C:\Program Files (x86)\MSI Afterburner"
if exist "%AB_DIR%\MSIAfterburner.exe.blocked" (
    ren "%AB_DIR%\MSIAfterburner.exe.blocked" "MSIAfterburner.exe"
    echo MSI Afterburner RESTORED.
    start "" "%AB_DIR%\MSIAfterburner.exe"
) else (
    echo Nothing to restore.
)

pause
