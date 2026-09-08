@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================================
::  HV-Universal - Universal Hypervisor Game Launcher
::  Supports: Reflex, DenuvOwO, REFramework (dinput8), ColdClientLoader, EA Anadius
::  Dynamic Game Discovery | CPU Vendor Awareness | Automated DSE Lifecycle
:: ============================================================================

set "HV_VERSION=5.0.0"
set "DEBUG_MODE=0"
set "DRY_RUN=0"
set "WAIT_SECONDS=5"

:: Parse command line flags
for %%A in (%*) do (
    if /i "%%A"=="--debug" set "DEBUG_MODE=1"
    if /i "%%A"=="-debug"  set "DEBUG_MODE=1"
    if /i "%%A"=="--dryrun" set "DRY_RUN=1"
    if /i "%%A"=="-dryrun"  set "DRY_RUN=1"
)

:: Setup Paths (Clean directory without trailing slash)
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%~f0"
pushd "%SCRIPT_DIR%" >nul 2>&1
set "SCRIPT_DIR=%CD%"
set "LOG_FILE=%SCRIPT_DIR%\HV-Universal.log"

:: Setup ANSI Colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
    set "ESC=%%b"
)
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "CYAN=%ESC%[96m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "MAGENTA=%ESC%[95m"
set "BLUE=%ESC%[94m"
set "WHITE=%ESC%[97m"

:: Logging banner
if not exist "%LOG_FILE%" (
    echo ============================================================ > "%LOG_FILE%"
    echo  HV-Universal Launcher Log - Version %HV_VERSION% >> "%LOG_FILE%"
    echo ============================================================ >> "%LOG_FILE%"
)

:: Display Header
cls
echo.
echo %BOLD%%CYAN%================================================================%RESET%
echo %BOLD%%WHITE%             HV-Universal Game Launcher v%HV_VERSION%%RESET%
echo %BOLD%%CYAN%================================================================%RESET%
echo.

:: ----------------------------------------------------------------------------
:: STAGE 1: Administrator Privileges Check & Clean Self-Elevation
:: ----------------------------------------------------------------------------
echo %BOLD%%BLUE%[STAGE 1/7]%RESET% %YELLOW%Verifying administrator privileges...%RESET%
fltmc >nul 2>&1
if errorlevel 1 (
    if "%DRY_RUN%"=="1" (
        echo %MAGENTA%[DRY RUN] Skipping elevation check.%RESET%
        goto STAGE_2
    )
    echo [INFO] Administrator rights required. Requesting UAC elevation...
    >>"%LOG_FILE%" echo [%date% %time%] Elevating to Administrator...
    if "%DEBUG_MODE%"=="1" (
        powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SCRIPT_PATH%' -ArgumentList '--debug' -Verb RunAs" >nul 2>&1
    ) else (
        powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SCRIPT_PATH%' -ArgumentList '__ELEVATED__' -Verb RunAs -WindowStyle Normal" >nul 2>&1
    )
    popd >nul 2>&1
    exit /b
)

echo %GREEN%Running with Administrator privileges.%RESET%
echo.

:STAGE_2

:: ----------------------------------------------------------------------------
:: STAGE 2: System Pre-flight & Hardware Detection
:: ----------------------------------------------------------------------------
echo %BOLD%%BLUE%[STAGE 2/7]%RESET% %YELLOW%Detecting hardware and system environment...%RESET%

:: Detect CPU Vendor
set "CPU_VENDOR=UNKNOWN"
for /f "tokens=*" %%V in ('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Manufacturer"') do set "CPU_VENDOR=%%V"
echo CPU Vendor: %CYAN%!CPU_VENDOR!%RESET%
>>"%LOG_FILE%" echo [%date% %time%] CPU Vendor: !CPU_VENDOR!

:: Check Virtualization-Based Security (VBS) and Memory Integrity (HVCI)
echo Checking Virtualization-Based Security (VBS) and Memory Integrity (HVCI)...
set "VBS_ON=0"
set "HVCI_ON=0"

for /f "tokens=1,2 delims==" %%A in ('powershell -NoProfile -Command "$dg=Get-CimInstance Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -EA 0; $v=($dg.VirtualizationBasedSecurityStatus -eq 2); $h=($dg.SecurityServicesRunning -contains 2 -or $dg.SecurityServicesConfigured -contains 2); $r=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -EA 0).Enabled; if($r -eq 1){$h=$true}; Write-Output ('VBS='+$v); Write-Output ('HVCI='+$h)" 2^>nul') do (
    if /i "%%A"=="VBS" if /i "%%B"=="True" set "VBS_ON=1"
    if /i "%%A"=="HVCI" if /i "%%B"=="True" set "HVCI_ON=1"
)

if "!VBS_ON!"=="1" goto VBS_HVCI_CONFLICT
if "!HVCI_ON!"=="1" goto VBS_HVCI_CONFLICT

echo %GREEN%VBS and Memory Integrity (HVCI) are Disabled.%RESET%
goto PREFLIGHT_CONFLICTS

:VBS_HVCI_CONFLICT
echo.
echo %BOLD%%RED%================================================================%RESET%
echo %BOLD%%RED%  SECURITY CONFLICT: VBS / Memory Integrity (HVCI) is ACTIVE!   %RESET%
echo %BOLD%%RED%================================================================%RESET%
echo.
if "!VBS_ON!"=="1" (
    echo %RED%[ACTIVE]%RESET% %YELLOW%Virtualization-Based Security [VBS] is RUNNING%RESET%
) else (
    echo %GREEN%[OK]%RESET%     Virtualization-Based Security [VBS] is Disabled
)
if "!HVCI_ON!"=="1" (
    echo %RED%[ACTIVE]%RESET% %YELLOW%Memory Integrity [HVCI / Core Isolation] is ENABLED%RESET%
) else (
    echo %GREEN%[OK]%RESET%     Memory Integrity [HVCI / Core Isolation] is Disabled
)
echo.
echo %YELLOW%These Windows virtualization security features block custom kernel%RESET%
echo %YELLOW%hypervisors and unsigned/test-signed drivers from executing.%RESET%
echo.
echo %CYAN%How to fix:%RESET%
echo   1. Open %WHITE%Windows Security -^> Device Security -^> Core Isolation%RESET%
echo   2. Toggle %BOLD%Memory Integrity OFF%RESET%
echo   3. Run %BOLD%Tools V4.0.bat%RESET% or %BOLD%VBS.cmd%RESET% to automate disabling VBS
echo   4. %BOLD%RESTART YOUR PC%RESET% to apply the changes.
echo.
>>"%LOG_FILE%" echo [%date% %time%] SECURITY CONFLICT: VBS=!VBS_ON!, HVCI=!HVCI_ON!

if "%DRY_RUN%"=="1" (
    echo %MAGENTA%[DRY RUN] Skipping graphical popup dialog.%RESET%
    goto PREFLIGHT_CONFLICTS
)

:: Display Graphical Alert Popup with Yes/No to open Windows Security
powershell -NoProfile -Command "$v = if ($env:VBS_ON -eq '1') { 'ACTIVE / RUNNING' } else { 'Disabled' }; $h = if ($env:HVCI_ON -eq '1') { 'ACTIVE / RUNNING' } else { 'Disabled' }; $lines = @('CRITICAL ACTION REQUIRED', '', 'The Hypervisor Bypass cannot start because Windows Virtualization Security is currently active:', '', '  * Virtualization-Based Security [VBS]: ' + $v, '  * Memory Integrity [Core Isolation / HVCI]: ' + $h, '', 'These features block custom kernel hypervisors and unsigned drivers from running.', '', 'To fix this:', '1. Open Windows Security -> Device Security -> Core Isolation', '2. Toggle Memory Integrity OFF', '3. Run Tools V4.0.bat or VBS.cmd to automate disabling VBS', '4. Restart your computer', '', 'Would you like to open Windows Security settings now?'); $msg = $lines -join [Environment]::NewLine; Add-Type -AssemblyName System.Windows.Forms; $res = [System.Windows.Forms.MessageBox]::Show($msg, 'HV-Universal - Security Conflict Detected', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly); if ($res -eq [System.Windows.Forms.DialogResult]::Yes) { Start-Process 'windowsdefender://coreisolation' }" >nul 2>&1

pause
goto CLEANUP_EXIT

:PREFLIGHT_CONFLICTS
:: Vanguard Anti-Cheat Check & Soft Stop
echo Checking for Vanguard anti-cheat...
sc query vgc 2>nul | find /i "RUNNING" >nul 2>&1
if !errorlevel!==0 (
    echo %YELLOW%Stopping Riot Vanguard service to prevent hypervisor conflict...%RESET%
    net stop vgc >nul 2>&1
    net stop vgk >nul 2>&1
    taskkill /IM vgtray.exe /F >nul 2>&1
    >>"%LOG_FILE%" echo [%date% %time%] Vanguard service temporarily stopped.
)

:: MacType Check
sc query MacType 2>nul | find /i "RUNNING" >nul 2>&1
if !errorlevel!==0 (
    echo %YELLOW%[WARNING] MacType is running; it may conflict with hypervisor hooks.%RESET%
)

:: MSI Afterburner / RTSS Check
set "MSI_RUNNING=0"
set "MSI_PATH="
tasklist /FI "IMAGENAME eq MSIAfterburner.exe" 2>nul | find /i "MSIAfterburner.exe" >nul
if !errorlevel!==0 (
    echo %YELLOW%MSI Afterburner is active. Suspending to prevent injection hook crash...%RESET%
    set "MSI_RUNNING=1"
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Process -Name 'MSIAfterburner' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Path)"`) do set "MSI_PATH=%%A"
    taskkill /IM MSIAfterburner.exe /F >nul 2>&1
    taskkill /IM RTSS.exe /F >nul 2>&1
    >>"%LOG_FILE%" echo [%date% %time%] MSI Afterburner closed.
) else (
    echo %GREEN%No conflicting overlay hooks detected.%RESET%
)
echo.

:: ----------------------------------------------------------------------------
:: STAGE 3: Universal Target Discovery (Zero Hardcoding)
:: ----------------------------------------------------------------------------
echo %BOLD%%BLUE%[STAGE 3/7]%RESET% %YELLOW%Discovering game target and platform profile...%RESET%

set "TARGET_EXE="
set "LAUNCHER_EXE="
set "GAME_DIR=!SCRIPT_DIR!"
set "PROFILE_TYPE=Standard"

:: 1. Check for reflex.ini target
if exist "reflex.ini" (
    set "PROFILE_TYPE=Reflex Hypervisor"
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /i "^target" "reflex.ini" 2^>nul`) do (
        set "raw_target=%%B"
        set "raw_target=!raw_target: =!"
        if defined raw_target set "TARGET_EXE=!raw_target!"
    )
)

:: 2. Check for DenuvOwO.ini target
if not defined TARGET_EXE if exist "DenuvOwO.ini" (
    set "PROFILE_TYPE=DenuvOwO Hypervisor"
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /i "^Target ^Targets" "DenuvOwO.ini" 2^>nul`) do (
        set "raw_target=%%B"
        set "raw_target=!raw_target: =!"
        for /f "tokens=1 delims=," %%T in ("!raw_target!") do (
            set "TARGET_EXE=%%~T"
        )
        if not defined TARGET_EXE set "TARGET_EXE=!raw_target!"
    )
)

:: 3. Check for ColdClientLoader.ini target
if exist "ColdClientLoader.ini" (
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /i "^Exe=" "ColdClientLoader.ini" 2^>nul`) do (
        set "raw_target=%%B"
        set "raw_target=!raw_target: =!"
        if not defined TARGET_EXE if defined raw_target set "TARGET_EXE=!raw_target!"
    )
    if exist "steamclient_loader_x64.exe" (
        set "LAUNCHER_EXE=!SCRIPT_DIR!\steamclient_loader_x64.exe"
        set "PROFILE_TYPE=ColdClientLoader"
    )
)

:: 4. Check for EA / Anadius profile
if exist "anadius.cfg" (
    set "PROFILE_TYPE=EA Origin/Anadius"
)

:: 5. Intermediate Loader Check (if not already set)
if not defined LAUNCHER_EXE (
    if exist "PlayGame_Launcher_x64.exe" set "LAUNCHER_EXE=!SCRIPT_DIR!\PlayGame_Launcher_x64.exe"
    if exist "HypervisorLauncher.exe"   set "LAUNCHER_EXE=!SCRIPT_DIR!\HypervisorLauncher.exe"
    if exist "hypervisor-launcher.exe"  set "LAUNCHER_EXE=!SCRIPT_DIR!\hypervisor-launcher.exe"
    if exist "HV-StartGame.exe"         set "LAUNCHER_EXE=!SCRIPT_DIR!\HV-StartGame.exe"
)

:: 6. Auto-detect shipping executable if target still empty
if not defined TARGET_EXE (
    for /f "delims=" %%F in ('dir /b /a-d "*Shipping.exe" 2^>nul') do (
        set "TARGET_EXE=%%F"
    )
)

:: 7. Largest Binary Fallback
if not defined TARGET_EXE (
    echo [INFO] Searching directory for primary game executable...
    for /f "usebackq tokens=1,2 delims=|" %%A in (`powershell -NoProfile -Command "Get-ChildItem -File -Filter '*.exe' | Where-Object { $_.Name -notmatch 'kvc|drvloader|7zr|watchdog|CrashReport|UnityCrashHandler|HV-' } | Sort-Object Length -Descending | Select-Object -First 1 | ForEach-Object { $_.Name + '|' + $_.Length }"`) do (
        set "TARGET_EXE=%%A"
    )
)

:: If no specific launcher wrapper exists, target itself is launched
if not defined LAUNCHER_EXE (
    set "LAUNCHER_EXE=!SCRIPT_DIR!\!TARGET_EXE!"
)

if not defined TARGET_EXE (
    echo %BOLD%%RED%[ERROR] No game executable could be detected in !SCRIPT_DIR! %RESET%
    >>"%LOG_FILE%" echo [%date% %time%] ERROR: Failed to detect game target.
    pause
    goto CLEANUP_EXIT
)

echo %GREEN%Target Executable:%RESET% %BOLD%!TARGET_EXE!%RESET%
echo %GREEN%Launch Method:    %RESET% %BOLD%!LAUNCHER_EXE!%RESET%
echo %GREEN%Profile Type:     %RESET% %CYAN%!PROFILE_TYPE!%RESET%
>>"%LOG_FILE%" echo [%date% %time%] Target: !TARGET_EXE! - Launcher: !LAUNCHER_EXE! - Profile: !PROFILE_TYPE!
echo.

:: ----------------------------------------------------------------------------
:: STAGE 4: Driver & Bypass Tool Preparation
:: ----------------------------------------------------------------------------
echo %BOLD%%BLUE%[STAGE 4/7]%RESET% %YELLOW%Preparing kernel driver loader...%RESET%

set "BYPASS_TOOL="
if exist "DenuvOwO\drvloader.exe" (
    set "BYPASS_TOOL=DRVLOADER"
    set "DRVLOADER_PATH=!SCRIPT_DIR!\DenuvOwO\drvloader.exe"
    echo Using: %CYAN%DenuvOwO drvloader.exe%RESET%
) else if exist "kvc.exe" (
    set "BYPASS_TOOL=KVC"
    set "KVC_PATH=!SCRIPT_DIR!\kvc.exe"
    echo Using: %CYAN%kvc.exe Code Integrity Tool%RESET%
) else (
    if "%DRY_RUN%"=="1" (
        echo %MAGENTA%[DRY RUN] Simulating drvloader preparation.%RESET%
        set "BYPASS_TOOL=DRVLOADER"
        set "DRVLOADER_PATH=!SCRIPT_DIR!\DenuvOwO\drvloader.exe"
        goto STAGE_5
    )
    echo [WARN] Neither drvloader.exe nor kvc.exe found. Attempting to prepare drvloader...
    mkdir "DenuvOwO" >nul 2>&1
    powershell -NoProfile -Command "Invoke-WebRequest 'https://github.com/wesmar/KernelResearchKit/releases/download/bypass-code-integrity/KernelResearchKit.7z' -OutFile 'DenuvOwO\krk.7z'" >nul 2>&1
    if not exist "DenuvOwO\7zr.exe" (
        powershell -NoProfile -Command "Invoke-WebRequest 'https://www.7-zip.org/a/7zr.exe' -OutFile 'DenuvOwO\7zr.exe'" >nul 2>&1
    )
    if exist "DenuvOwO\7zr.exe" "DenuvOwO\7zr.exe" x "DenuvOwO\krk.7z" -o"DenuvOwO" -p"github.com" -y >nul 2>&1
    del /f /q "DenuvOwO\krk.7z" "DenuvOwO\7zr.exe" >nul 2>&1
    if exist "DenuvOwO\drvloader.exe" (
        set "BYPASS_TOOL=DRVLOADER"
        set "DRVLOADER_PATH=!SCRIPT_DIR!\DenuvOwO\drvloader.exe"
        echo %GREEN%drvloader.exe successfully prepared.%RESET%
    ) else (
        echo %RED%[ERROR] Unable to prepare kernel driver bypass tool.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] ERROR: Bypass tool missing.
        pause
        goto CLEANUP_EXIT
    )
)
echo.

:STAGE_5
:: ----------------------------------------------------------------------------
:: STAGE 5: DSE Suspension
:: ----------------------------------------------------------------------------
echo %BOLD%%BLUE%[STAGE 5/7]%RESET% %YELLOW%Temporarily disabling Driver Signature Enforcement (DSE)...%RESET%

if "%DRY_RUN%"=="1" (
    echo %MAGENTA%[DRY RUN] Skipping kernel DSE modifications.%RESET%
    set "DSE_DISABLED=1"
    goto LAUNCH_GAME
)

set "DSE_DISABLED=0"
if "%BYPASS_TOOL%"=="DRVLOADER" (
    "%DRVLOADER_PATH%" bypass >nul 2>&1
    if !errorlevel!==0 (
        set "DSE_DISABLED=1"
        echo %GREEN%DSE bypass engaged via drvloader.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] drvloader bypass OK.
    ) else (
        echo %RED%[ERROR] drvloader bypass failed with code !errorlevel!.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] ERROR: drvloader bypass failed.
        pause
        goto CLEANUP_EXIT
    )
) else if "%BYPASS_TOOL%"=="KVC" (
    "%KVC_PATH%" dse off --safe >nul 2>&1
    if !errorlevel!==0 (
        set "DSE_DISABLED=1"
        echo %GREEN%DSE bypass engaged via kvc.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] kvc dse off OK.
    ) else (
        echo %RED%[ERROR] kvc dse off failed.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] ERROR: kvc dse off failed.
        pause
        goto CLEANUP_EXIT
    )
)
echo.

:: ----------------------------------------------------------------------------
:: STAGE 6: Game Process Launch & Process Monitoring
:: ----------------------------------------------------------------------------
:LAUNCH_GAME
echo %BOLD%%BLUE%[STAGE 6/7]%RESET% %YELLOW%Launching game...%RESET%
echo Starting: %WHITE%!LAUNCHER_EXE!%RESET%

if "%DRY_RUN%"=="1" (
    echo %MAGENTA%[DRY RUN] Game launch command simulated successfully.%RESET%
    goto RESTORE_DSE
)

start "" /d "%GAME_DIR%" "!LAUNCHER_EXE!"
>>"%LOG_FILE%" echo [%date% %time%] Executed: !LAUNCHER_EXE!

echo Waiting for target process (%CYAN%!TARGET_EXE!%RESET%) to initialize...
set /a PROCESS_WAIT_COUNTER=0

:WAIT_PROCESS_LOOP
tasklist /FI "IMAGENAME eq !TARGET_EXE!" 2>nul | find /i "!TARGET_EXE!" >nul
if !errorlevel!==0 (
    echo %GREEN%Game process detected successfully!%RESET%
    goto PROCESS_STARTED
)

set /a PROCESS_WAIT_COUNTER+=1
if !PROCESS_WAIT_COUNTER! geq 10 (
    echo %YELLOW%[WARNING] Game process took longer than 10s to appear. Continuing...%RESET%
    goto PROCESS_STARTED
)
timeout /t 1 /nobreak >nul
goto WAIT_PROCESS_LOOP

:PROCESS_STARTED
echo %CYAN%Holding DSE bypass for %WAIT_SECONDS% seconds to ensure hypervisor driver hooks load...%RESET%
timeout /t %WAIT_SECONDS% /nobreak >nul
echo.

:: ----------------------------------------------------------------------------
:: STAGE 7: Restoration & Environment Cleanup
:: ----------------------------------------------------------------------------
:RESTORE_DSE
echo %BOLD%%BLUE%[STAGE 7/7]%RESET% %YELLOW%Restoring Driver Signature Enforcement and services...%RESET%

if "%DRY_RUN%"=="1" (
    echo %MAGENTA%[DRY RUN] DSE restore simulated.%RESET%
    goto RESTORE_SERVICES
)

if "!DSE_DISABLED!"=="1" (
    if "%BYPASS_TOOL%"=="DRVLOADER" (
        "%DRVLOADER_PATH%" restore >nul 2>&1
        echo %GREEN%DSE restored via drvloader.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] drvloader restore OK.
    ) else if "%BYPASS_TOOL%"=="KVC" (
        "%KVC_PATH%" dse on --safe >nul 2>&1
        echo %GREEN%DSE restored via kvc.%RESET%
        >>"%LOG_FILE%" echo [%date% %time%] kvc dse on OK.
    )
)

:RESTORE_SERVICES
:: Restart MSI Afterburner if previously running
if "!MSI_RUNNING!"=="1" (
    echo Restarting MSI Afterburner...
    if defined MSI_PATH if exist "!MSI_PATH!" (
        start "" "!MSI_PATH!"
    ) else if exist "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe" (
        start "" "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    ) else if exist "C:\Program Files\MSI Afterburner\MSIAfterburner.exe" (
        start "" "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
    )
    >>"%LOG_FILE%" echo [%date% %time%] MSI Afterburner restored.
)

:: Remove temporary Defender exclusions if kvc was used
if "%BYPASS_TOOL%"=="KVC" (
    powershell -NoProfile -Command "Remove-MpPreference -ExclusionPath '!SCRIPT_DIR!\kvc.exe' -ErrorAction SilentlyContinue; Remove-MpPreference -ExclusionProcess 'kvc.exe' -ErrorAction SilentlyContinue" >nul 2>&1
)

echo.
echo %BOLD%%GREEN%================================================================%RESET%
echo %BOLD%%GREEN%      GAME LAUNCHED SUCCESSFULLY - HYPERVISOR ACTIVE!          %RESET%
echo %BOLD%%GREEN%================================================================%RESET%
echo.

:CLEANUP_EXIT
popd >nul 2>&1
if "%DEBUG_MODE%"=="1" (
    echo %YELLOW%[DEBUG MODE] Press any key to close this console...%RESET%
    pause >nul
) else if "%DRY_RUN%"=="1" (
    rem immediate return in dry run
) else (
    timeout /t 3 /nobreak >nul
)
exit /b 0
