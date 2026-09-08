@echo off
:: Kill MSI Afterburner & RTSS and block them from relaunching
:: Run as Administrator before launching your game

fltmc >nul 2>&1 || (
    echo Requesting admin rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Killing MSI Afterburner and RTSS...
taskkill /IM MSIAfterburner.exe /F >nul 2>&1
taskkill /IM RTSS.exe /F >nul 2>&1
taskkill /IM RTSSHooksLoader64.exe /F >nul 2>&1
taskkill /IM EncoderServer64.exe /F >nul 2>&1

set "AB_DIR=C:\Program Files (x86)\MSI Afterburner"
if exist "%AB_DIR%\MSIAfterburner.exe" (
    ren "%AB_DIR%\MSIAfterburner.exe" "MSIAfterburner.exe.blocked"
    echo MSI Afterburner BLOCKED.
) else (
    echo Afterburner exe not found or already blocked.
)

echo.
echo Done. Afterburner cannot relaunch. Run RestoreAfterburner.bat when finished.
pause
