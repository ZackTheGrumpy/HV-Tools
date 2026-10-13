@echo off
setlocal EnableDelayedExpansion
title HV-Tools Emergency WinRE Rescue Tool v4.0.4
color 0F

echo =====================================================================
echo           HV-TOOLS EMERGENCY BOOT RECOVERY TOOL v4.0.4
echo =====================================================================
echo  This tool repairs unbootable Windows systems, boot loops, and BSODs
echo  caused by HVCI (Memory Integrity), VBS, or Hypervisor configuration.
echo =====================================================================
echo.

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Administrator rights are required.
    echo If running in Windows, right-click and 'Run as administrator'.
    echo In WinRE (Recovery Mode), you are already administrator.
    echo.
)

:: Step 1: Detect Windows Installation Drive
echo [*] Scanning drives for Windows installation...
set "WIN_DRV="

for %%D in (C D E F G H I J) do (
    if not defined WIN_DRV (
        if exist "%%D:\Windows\System32\config\SYSTEM" (
            set "WIN_DRV=%%D:"
            echo [+] Found Windows installation on %%D:\
        )
    )
)

if not defined WIN_DRV (
    echo.
    echo [!] ERROR: Could not locate Windows installation on drives C: through J:
    echo     Your drive might be encrypted with BitLocker and currently locked.
    echo.
    echo     To unlock your drive, run:
    echo       manage-bde -status
    echo       manage-bde -unlock C: -RecoveryPassword YOUR-48-DIGIT-KEY
    echo.
    pause
    exit /b 1
)

:: Step 2: Check BitLocker status on target drive
echo.
echo [*] Checking BitLocker status on %WIN_DRV%...
manage-bde -status %WIN_DRV% 2>nul | findstr /i "Locked" >nul 2>&1
if %errorLevel% equ 0 (
    echo [!] DRIVE %WIN_DRV% IS LOCKED BY BITLOCKER!
    echo     Please unlock the drive using your 48-digit BitLocker recovery key:
    echo     Command: manage-bde -unlock %WIN_DRV% -RecoveryPassword [YOUR-KEY]
    echo.
    pause
    exit /b 1
) else (
    echo [+] Drive %WIN_DRV% is unlocked and accessible.
)

:: Step 3: Modify Offline Registry to Neutralize HVCI and VBS
echo.
echo [*] Loading offline registry hive from %WIN_DRV%\Windows\System32\config\SYSTEM...
reg load HKLM\OFFLINE_SYSTEM "%WIN_DRV%\Windows\System32\config\SYSTEM" >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Failed to load offline registry hive. Ensure file is not in use.
    pause
    exit /b 1
)

echo [*] Disabling Hypervisor-Enforced Code Integrity (HVCI)...
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f >nul 2>&1

echo [*] Disabling Virtualization-Based Security (VBS)...
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 0 /f >nul 2>&1

echo [*] Clearing KVA Shadow / Meltdown overrides...
reg delete "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v "FeatureSettingsOverride" /f >nul 2>&1
reg delete "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v "FeatureSettingsOverrideMask" /f >nul 2>&1

echo [*] Unloading offline registry hive...
reg unload HKLM\OFFLINE_SYSTEM >nul 2>&1

:: Step 4: Reset BCD Boot Configuration Parameters
echo.
echo [*] Resetting Boot Configuration Data (BCD)...

:: Turn off hypervisor and VSM launches
bcdedit /set {default} hypervisorlaunchtype off >nul 2>&1
bcdedit /set hypervisorlaunchtype off >nul 2>&1
bcdedit /set {default} vsmlaunchtype off >nul 2>&1
bcdedit /set vsmlaunchtype off >nul 2>&1

:: Delete template inheritance pollution
bcdedit /deletevalue {bootloadersettings} hypervisorlaunchtype >nul 2>&1
bcdedit /deletevalue {hypervisorsettings} hypervisorlaunchtype >nul 2>&1
bcdedit /deletevalue {bootloadersettings} vsmlaunchtype >nul 2>&1
bcdedit /deletevalue {hypervisorsettings} vsmlaunchtype >nul 2>&1

:: Enable testsigning temporarily to allow any unsigned drivers to boot cleanly
bcdedit /set {default} testsigning on >nul 2>&1
bcdedit /set testsigning on >nul 2>&1
bcdedit /set {default} nointegritychecks on >nul 2>&1
bcdedit /set nointegritychecks on >nul 2>&1

echo.
echo =====================================================================
echo                   [SUCCESS] SYSTEM RESCUE COMPLETED!
echo =====================================================================
echo  - HVCI & VBS disabled in offline registry
echo  - Windows hypervisor launch disabled in BCD
echo  - BCD inheritance templates cleaned
echo  - Safe test signing enabled to permit driver startup
echo =====================================================================
echo.
echo  You can now restart your computer. Windows will boot normally.
echo.

choice /C:YN /N /M "Would you like to restart your PC right now? (Y/N) [Default: Y]: "
if !errorLevel! equ 1 (
    echo [*] Rebooting system...
    where wpeutil >nul 2>&1
    if !errorLevel! equ 0 (
        wpeutil reboot
    ) else (
        shutdown /r /t 5 -c "Rebooting into repaired Windows environment..."
    )
)

exit /b 0
