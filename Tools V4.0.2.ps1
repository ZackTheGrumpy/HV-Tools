[CmdletBinding()]
param(
    [switch]$CliOnly,
    [switch]$cli
)

# =========================================================================
# HV BYPASS TOOL v4.0.2 - ADVANCED MODERNIZED EDITION
# =========================================================================
# Clean native architecture, Widescreen Dashboard UI, 1-Click Auto Setup,
# SUO Auto-Downloader with Live Progress, Video Tutorial Guide & BitLocker Safety
# =========================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net
[System.Windows.Forms.Application]::EnableVisualStyles()

# Self-elevation check if executed directly as .ps1
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[*] Requesting administrator privileges..." -ForegroundColor Yellow
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass")
    $targetPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }
    if ($targetPath) {
        $argList += @("-File", "`"$targetPath`"")
        if ($CliOnly -or $cli -or ($args -contains '-cli') -or ($args -contains '/cli')) {
            $argList += "-cli"
        }
    }
    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "[ERROR] Administrator privileges are required to run this tool." -ForegroundColor Red
        Write-Host "Please right-click PowerShell or the script and select 'Run as administrator'." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    exit
}

# Windows API Declarations (User32 for console visibility, CI for live kernel code integrity)
if (-not ([System.Management.Automation.PSTypeName]'User32').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")] public static extern bool AllocConsole();
}
public class CI {
    [DllImport("ntdll.dll")] public static extern uint NtQuerySystemInformation(int c, IntPtr b, uint s, out uint r);
}
'@
}

$Script:ConsoleHandle = [User32]::GetConsoleWindow()

function Show-ToolConsole {
    if ($Script:ConsoleHandle -eq $null -or $Script:ConsoleHandle -eq [IntPtr]::Zero) {
        $Script:ConsoleHandle = [User32]::GetConsoleWindow()
        if ($Script:ConsoleHandle -eq $null -or $Script:ConsoleHandle -eq [IntPtr]::Zero) {
            try { [User32]::AllocConsole() | Out-Null } catch {}
            $Script:ConsoleHandle = [User32]::GetConsoleWindow()
        }
    }
    if ($Script:ConsoleHandle -and $Script:ConsoleHandle -ne [IntPtr]::Zero) {
        [User32]::ShowWindow($Script:ConsoleHandle, 5) | Out-Null
    }
}

function Hide-ToolConsole {
    if ($Script:ConsoleHandle -eq $null -or $Script:ConsoleHandle -eq [IntPtr]::Zero) {
        $Script:ConsoleHandle = [User32]::GetConsoleWindow()
    }
    if ($Script:ConsoleHandle -and $Script:ConsoleHandle -ne [IntPtr]::Zero) {
        [User32]::ShowWindow($Script:ConsoleHandle, 0) | Out-Null
    }
}

# --- Configuration & Global State ---
$SCRIPT_VERSION = "4.0.2"
$CFG_GITHUB_API = "https://api.github.com/repos/barryhamsy/gamelist/releases/latest"
$SUO_DIR        = "C:\Program Files\Steam Unlock ONENNABE"
$Script:ActionLog = [System.Collections.Generic.List[string]]::new()
$isCliRequested   = ($CliOnly -or $cli -or ($args -contains '-cli') -or ($args -contains '/cli'))
$Script:NextMode  = if ($isCliRequested) { "CLI" } else { "GUI" }
if ($Script:NextMode -eq "GUI") {
    Hide-ToolConsole
}
$Script:BackgroundJob = $null
$Script:IsDownloadingSuo = $false

# Global UI control references
$Script:MainForm        = $null
$Script:BtnAuto         = $null
$Script:BtnTest         = $null
$Script:BtnVbs          = $null
$Script:BtnSuo          = $null
$Script:StatusBar       = $null
$Script:GuideBox        = $null
$Script:ReadyBadge      = $null
$Script:LblVirt         = $null
$Script:LblSb           = $null
$Script:LblVbs          = $null
$Script:LblHvci         = $null
$Script:LblDse          = $null
$Script:LblTest         = $null
$Script:LblHello        = $null
$Script:LblConflict     = $null
$Script:BtnConflict     = $null
$Script:BtnHello        = $null
$Script:UpdateUI        = $null
$Script:TooltipProvider = $null

# Color Palette (Dark Modern Cyber Theme)
$Colors = @{
    BgForm       = [System.Drawing.Color]::FromArgb(16, 18, 24)       # #101218
    BgPanel      = [System.Drawing.Color]::FromArgb(24, 28, 38)       # #181C26
    BgCard       = [System.Drawing.Color]::FromArgb(30, 36, 50)       # #1E2432
    BgHighlight  = [System.Drawing.Color]::FromArgb(20, 42, 30)       # Greenish tint for recommended box
    BorderGreen  = [System.Drawing.Color]::FromArgb(46, 160, 67)      # Emerald border
    Border       = [System.Drawing.Color]::FromArgb(45, 52, 70)       # #2D3446
    Accent       = [System.Drawing.Color]::FromArgb(56, 139, 253)     # #388BFD
    AccentGlow   = [System.Drawing.Color]::FromArgb(88, 166, 255)     # #58A6FF
    BtnGreen     = [System.Drawing.Color]::FromArgb(35, 134, 54)      # #238636
    BtnGreenHov  = [System.Drawing.Color]::FromArgb(46, 160, 67)      # #2EA043
    BtnDanger    = [System.Drawing.Color]::FromArgb(218, 54, 51)      # #DA3633
    BtnBlue      = [System.Drawing.Color]::FromArgb(31, 111, 235)     # #1F6FEB
    BtnDark      = [System.Drawing.Color]::FromArgb(34, 40, 54)       # #222836
    BtnDisabled  = [System.Drawing.Color]::FromArgb(28, 32, 40)       # #1C2028
    TextLight    = [System.Drawing.Color]::FromArgb(240, 246, 252)    # #F0F6FC
    TextMuted    = [System.Drawing.Color]::FromArgb(139, 148, 158)    # #8B949E
    TextDimmed   = [System.Drawing.Color]::FromArgb(90, 98, 108)      # #5A626C
    StatusGood   = [System.Drawing.Color]::FromArgb(63, 185, 80)      # #3FB950
    StatusBad    = [System.Drawing.Color]::FromArgb(248, 81, 73)      # #F85149
    StatusWarn   = [System.Drawing.Color]::FromArgb(210, 153, 34)     # #D29922
}

function Write-ActionLog([string]$Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    $Script:ActionLog.Add($entry)
}

# --- Manufacturer BIOS Key & Video Guides ---

function Get-BiosKeyHint {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $mfg = if ($cs) { "$($cs.Manufacturer)".ToUpper() } else { "" }
    if ($mfg -like "*LENOVO*") { return "F2 or Fn+F2 (Novo Button)" }
    if ($mfg -like "*ASUS*")   { return "Delete or F2" }
    if ($mfg -like "*MSI*")    { return "Delete" }
    if ($mfg -like "*GIGABYTE*" -or $mfg -like "*AORUS*") { return "Delete or F2" }
    if ($mfg -like "*DELL*" -or $mfg -like "*ALIENWARE*") { return "F2 or F12" }
    if ($mfg -like "*HP*" -or $mfg -like "*HEWLETT*")     { return "F10 or Esc" }
    if ($mfg -like "*ACER*")   { return "F2 or Delete" }
    if ($mfg -like "*ASROCK*") { return "Delete or F2" }
    return "Delete or F2"
}

function Get-BiosVideoUrl {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $mfg = if ($cs) { "$($cs.Manufacturer)".ToUpper() } else { "" }
    if ($mfg -like "*MSI*" -or $mfg -like "*MICRO-STAR*") { return "https://www.youtube.com/watch?v=qKIcbKNI-g0" }
    if ($mfg -like "*GIGABYTE*" -or $mfg -like "*AORUS*") { return "https://www.youtube.com/watch?v=fpHEbny3Mhs" }
    if ($mfg -like "*ASROCK*")                            { return "https://www.youtube.com/watch?v=p0QeY9tyAbI" }
    if ($mfg -like "*ASUS*")                              { return "https://www.youtube.com/watch?v=bQDVvhtBeO4" }
    if ($mfg -like "*DELL*" -or $mfg -like "*ALIENWARE*") { return "https://www.youtube.com/watch?v=n-C1hz42Qxw" }
    if ($mfg -like "*LENOVO*")                            { return "https://www.youtube.com/watch?v=EEDddQTq-QE" }
    return "https://www.youtube.com/watch?v=Vzm2YQDcsfw"
}

# --- BitLocker Safety Check & Suspension ---

$Script:CachedBitLocker = $null
function Test-BitLockerProtected {
    if ($Script:CachedBitLocker -ne $null) { return $Script:CachedBitLocker }
    try {
        $bl = Get-CimInstance -Namespace root\CIMV2\Security\MicrosoftVolumeEncryption -ClassName Win32_EncryptableVolume -Property DriveLetter, ProtectionStatus -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq $env:SystemDrive }
        $Script:CachedBitLocker = ($bl -and $bl.ProtectionStatus -eq 1)
    } catch {
        $Script:CachedBitLocker = $false
    }
    return $Script:CachedBitLocker
}

function Suspend-BitLockerSafety {
    if (Test-BitLockerProtected) {
        $msg = "BitLocker Drive Encryption is currently ACTIVE on drive $env:SystemDrive.`n`n" +
               "Changing Secure Boot in BIOS can cause Windows BitLocker to trip and ask for your 48-digit recovery key upon boot.`n`n" +
               "Would you like to temporarily suspend BitLocker protection for 1 reboot? (Highly Recommended)"
        $res = [System.Windows.Forms.MessageBox]::Show($msg, "BitLocker Protection Alert", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                $vol = Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftVolumeEncryption -Class Win32_EncryptableVolume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq $env:SystemDrive }
                if ($vol) {
                    $vol.DisableKeyProtectors(1) | Out-Null
                    Write-ActionLog "BitLocker suspended for 1 reboot via WMI."
                    [System.Windows.Forms.MessageBox]::Show("BitLocker protection suspended for 1 reboot.`nYour PC will not prompt for the recovery key during the next boot.", "BitLocker Suspended", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
            } catch {
                Write-ActionLog "Failed to suspend BitLocker: $_"
            }
        }
    }
}

# --- Native Core Utilities ---

function Set-VBSAndHVCIStatus([bool]$Enable) {
    $val = if ($Enable) { 1 } else { 0 }
    $btype = if ($Enable) { "auto" } else { "off" }
    
    try {
        $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        
        if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
        if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
        
        Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value $val -Type DWord -Force
        Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value $val -Type DWord -Force
        
        bcdedit /set hypervisorlaunchtype $btype | Out-Null
        
        if (-not $Enable) {
            # Disengage Windows Hello VBS & Enhanced Sign-in Security scenarios (VBS.cmd reference)
            Disable-WindowsHelloProtection -Silent
        }
        
        $action = if ($Enable) { "Enabled" } else { "Disabled" }
        Write-ActionLog "VBS & HVCI $action successfully."
        return $true
    } catch {
        Write-ActionLog "ERROR setting VBS/HVCI: $_"
        return $false
    }
}

function Set-TestingModeStatus([bool]$Enable) {
    $mode = if ($Enable) { "on" } else { "off" }
    try {
        & bcdedit /set testsigning $mode 2>$null | Out-Null
        & bcdedit /set nointegritychecks $mode 2>$null | Out-Null
        & bcdedit /set "{current}" testsigning $mode 2>$null | Out-Null
        & bcdedit /set "{current}" nointegritychecks $mode 2>$null | Out-Null
        Write-ActionLog "Test Signing Mode set to $mode in BCD."
        return $true
    } catch {
        Write-ActionLog "ERROR setting Test Signing: $_"
        return $false
    }
}

function Restart-DirectToUEFI {
    Suspend-BitLockerSafety
    
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $mfg = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() } else { "PC" }
    $hint = Get-BiosKeyHint
    
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Your computer will immediately restart into BIOS/UEFI Setup.`n`n" +
        "Detected PC: $mfg`n" +
        "BIOS Hotkey: $hint`n`n" +
        "In BIOS:`n" +
        "1. Go to Security or Boot tab`n" +
        "2. Set Secure Boot to [Disabled]`n" +
        "3. Press F10 to Save & Exit`n`n" +
        "If BIOS does not open automatically, press [$hint] when your screen turns on.`n`n" +
        "Ready to reboot now?",
        "Reboot to BIOS / UEFI",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-ActionLog "Rebooting to UEFI firmware interface..."
        shutdown /r /fw /t 5
        if ($LASTEXITCODE -ne 0) {
            shutdown /r /o /t 5
        }
    }
}

function Revert-ToSafeMode {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "REVERT ALL SETTINGS TO DEFAULT (SAFE MODE)`n`n" +
        "This will:`n" +
        "1. Turn OFF Testing Mode (Re-enable Driver Signature Enforcement)`n" +
        "2. Re-enable VBS & Memory Integrity (HVCI)`n" +
        "3. Reset Hypervisor launch type to Auto`n`n" +
        "This restores your PC to standard security required by anti-cheat games (Valorant / Faceit).`n`n" +
        "Proceed?",
        "Revert to Default",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    
    & bcdedit /set testsigning off 2>$null | Out-Null
    & bcdedit /set nointegritychecks off 2>$null | Out-Null
    & bcdedit /set "{current}" testsigning off 2>$null | Out-Null
    & bcdedit /set "{current}" nointegritychecks off 2>$null | Out-Null
    Set-VBSAndHVCIStatus -Enable $true | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-ActionLog "System restored to default safe mode."
    if ($Script:UpdateUI) { & $Script:UpdateUI }
    
    [System.Windows.Forms.MessageBox]::Show(
        "System settings reverted to standard default security.`n`nPlease restart your computer to apply changes.",
        "Reverted to Default",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

function Add-DefenderExclusion {
    $folder = if ($env:TOOL_DIR -and (Test-Path $env:TOOL_DIR)) { $env:TOOL_DIR } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    try {
        Add-MpPreference -ExclusionPath $folder -ErrorAction Stop
        Write-ActionLog "Added Defender exclusion: $folder"
        [System.Windows.Forms.MessageBox]::Show(
            "Current folder whitelisted in Windows Defender:`n$folder`n`nDrivers and hypervisor will not be blocked.",
            "Defender Whitelist Added",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-ActionLog "Failed to add Defender exclusion: $_"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to add Defender exclusion: $($_.Exception.Message)`nEnsure Windows Defender is running.",
            "Exclusion Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}

function New-SystemRestorePoint {
    param([string]$Mode = 'GUI')
    $description = "HV Tool v$SCRIPT_VERSION - Pre-Setup Restore Point"
    try {
        if ($Mode -eq 'GUI') {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Create a System Restore Point?`n`nDescription: $description`n`nThis provides a safety net before applying changes.",
                "System Restore Point",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }
        Write-ActionLog "Creating System Restore Point..."
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        $msg = "System Restore Point created successfully."
        Write-ActionLog $msg
        if ($Mode -eq 'GUI') {
            [System.Windows.Forms.MessageBox]::Show($msg, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } else {
            Write-Host $msg -ForegroundColor Green
        }
    } catch {
        $errMsg = "Failed to create restore point: $($_.Exception.Message)"
        Write-ActionLog "ERROR: $errMsg"
        if ($Mode -eq 'GUI') {
            [System.Windows.Forms.MessageBox]::Show($errMsg, "Restore Point Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else {
            Write-Host $errMsg -ForegroundColor Red
        }
    }
}

# --- Windows Hello & Sign-in Security Management (Reference from VBS.cmd) ---

function Disable-WindowsHelloProtection([switch]$Silent) {
    try {
        # 1. DeviceGuard Scenarios (VBS.cmd reference lines 766, 800, 804, 808, 812, 816, 820)
        $scenarios = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello",
            "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics",
            "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureBiometrics",
            "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureFingerprint",
            "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureFingerprint"
        )
        foreach ($sc in $scenarios) {
            if (-not (Test-Path $sc)) { New-Item -Path $sc -Force | Out-Null }
            Set-ItemProperty -Path $sc -Name "Enabled" -Value 0 -Type DWord -Force | Out-Null
        }
        
        # Root scenario entries
        $scRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios"
        if (Test-Path $scRoot) {
            Set-ItemProperty -Path $scRoot -Name "SecureBiometrics" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $scRoot -Name "SecureFingerprint" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # 2. Passport for Work policies (stops force-PIN prompts)
        $passportPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
        if (-not (Test-Path $passportPath)) { New-Item -Path $passportPath -Force | Out-Null }
        Set-ItemProperty -Path $passportPath -Name "Enabled" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path $passportPath -Name "DisablePostLogonProvisioning" -Value 1 -Type DWord -Force | Out-Null

        # 3. Un-grey the "Remove" PIN button in Settings (DevicePasswordLessBuildVersion = 0)
        $pwLessPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
        if (-not (Test-Path $pwLessPath)) { New-Item -Path $pwLessPath -Force | Out-Null }
        Set-ItemProperty -Path $pwLessPath -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -Force | Out-Null

        Write-ActionLog "Windows Hello VBS protection scenarios & policies disabled."
        if (-not $Silent) {
            [System.Windows.Forms.MessageBox]::Show(
                "Windows Hello VBS Protection scenarios and policies have been DISABLED.`n`n" +
                "1. DeviceGuard Windows Hello & ESS scenarios set to 0.`n" +
                "2. Passport for Work policy set to disabled.`n" +
                "3. The 'Remove' PIN button in Windows Settings is now UNLOCKED.",
                "Windows Hello Protection Disabled",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        return $true
    } catch {
        Write-ActionLog "ERROR disabling Windows Hello protection: $_"
        return $false
    }
}

function Unlock-WindowsHelloRemoveButton {
    try {
        $pwLessPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
        if (-not (Test-Path $pwLessPath)) { New-Item -Path $pwLessPath -Force | Out-Null }
        Set-ItemProperty -Path $pwLessPath -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -Force | Out-Null
        Write-ActionLog "Unlocked 'Remove' PIN button in Windows Settings."
        
        Start-Process "ms-settings:signinoptions"
        
        [System.Windows.Forms.MessageBox]::Show(
            "The 'Remove' PIN button has been UNLOCKED in Windows Settings!`n`n" +
            "Windows Settings has been opened to 'Sign-in options'.`n`n" +
            "Instructions:`n" +
            "1. Click on 'PIN (Windows Hello)'`n" +
            "2. Click the 'Remove' button`n" +
            "3. Enter your account password to confirm`n`n" +
            "(Ensure you know your Microsoft/Local account password before removing PIN!)",
            "Windows Hello PIN Unlocked",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-ActionLog "ERROR unlocking PIN Remove: $_"
    }
}

function Toggle-WindowsHelloPinProvider {
    $pinProvider = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"
    $curr = (Get-ItemProperty -Path $pinProvider -Name "Disabled" -ErrorAction SilentlyContinue).Disabled
    $isDisabled = ($curr -eq 1)

    if ($isDisabled) {
        Remove-ItemProperty -Path $pinProvider -Name "Disabled" -ErrorAction SilentlyContinue | Out-Null
        Write-ActionLog "PIN Credential Provider restored (Enabled)."
        [System.Windows.Forms.MessageBox]::Show("Windows Hello PIN Credential Provider has been RESTORED.`nPIN will be visible on the login screen.", "PIN Restored", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "Disabling the PIN Credential Provider will HIDE the PIN prompt at the Windows lock screen, forcing standard Password login.`n`n" +
            "IMPORTANT: Ensure you know your account Password before doing this!`n`n" +
            "Do you want to disable the PIN login provider?",
            "Confirm Disable PIN Provider",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            Set-ItemProperty -Path $pinProvider -Name "Disabled" -Value 1 -Type DWord -Force | Out-Null
            Write-ActionLog "PIN Credential Provider DISABLED on login screen."
            [System.Windows.Forms.MessageBox]::Show("PIN Credential Provider is now DISABLED.`nWindows will require your standard Password at the login screen.", "PIN Disabled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
}

function Confirm-WindowsHelloPreFlight([string]$CallingAction = "Disable VBS") {
    $st = Get-LiveStatuses
    
    # Check if there is an active VBS + Windows Hello conflict (exact check from VBS.cmd line 494)
    if ($st.HelloConflict) {
        Write-ActionLog "Pre-flight: Windows Hello VBS conflict detected!"
        
        $msg = "CRITICAL WINDOWS HELLO CONFLICT DETECTED`n`n" +
               "Windows Hello (PIN / Biometrics) is active with VBS Protection enabled.`n`n" +
               "WARNING (Reference from VBS.cmd):`n" +
               "Disabling VBS while Windows Hello is active will result in:`n" +
               "'Something happened and your PIN isn't available. Click to set up your PIN again.'`n" +
               "on your next Windows login screen!`n`n" +
               "What would you like to do?`n`n" +
               "- Click [Yes] to Auto-Disable Hello VBS protection scenarios & continue`n" +
               "- Click [No] to Open Windows Settings and manually Remove your PIN first`n" +
               "- Click [Cancel] to Abort"
        
        $res = [System.Windows.Forms.MessageBox]::Show(
            $msg,
            "Windows Hello Pre-Flight Check",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            Disable-WindowsHelloProtection -Silent
            return $true
        } elseif ($res -eq [System.Windows.Forms.DialogResult]::No) {
            Unlock-WindowsHelloRemoveButton
            return $false
        } else {
            return $false
        }
    }
    
    if ($st.HelloVbs) {
        Disable-WindowsHelloProtection -Silent
    }
    
    return $true
}

function Confirm-WindowsHelloPreFlightCli {
    $st = Get-LiveStatuses
    if ($st.HelloConflict) {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "         CRITICAL WINDOWS HELLO CONFLICT DETECTED" -ForegroundColor Yellow
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "  Windows Hello (PIN/Biometrics) is active with VBS Protection." -ForegroundColor White
        Write-Host "  Disabling VBS while Hello is active can cause login PIN failure:" -ForegroundColor Yellow
        Write-Host "  'Something happened and your PIN isn't available.'" -ForegroundColor DarkYellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [1] Auto-Disable Windows Hello VBS Protection & Proceed" -ForegroundColor Green
        Write-Host "  [2] Unlock 'Remove' Button & Open Windows Settings" -ForegroundColor Cyan
        Write-Host "  [3] Cancel" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        $c = Read-Host "Select option (1-3)"
        if ($c -eq "1") {
            Disable-WindowsHelloProtection -Silent
            return $true
        } elseif ($c -eq "2") {
            Unlock-WindowsHelloRemoveButton
            return $false
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return $false
        }
    }
    if ($st.HelloVbs) {
        Disable-WindowsHelloProtection -Silent
    }
    return $true
}

function Show-WindowsHelloDialog {
    $st = Get-LiveStatuses
    
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Windows Hello & Sign-in Security Management (v$SCRIPT_VERSION)"
    $dlg.Size = New-Object System.Drawing.Size(640, 520)
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = $Colors.BgForm
    
    $icoPath = if ($env:TOOL_DIR) { Join-Path $env:TOOL_DIR "SUO_tools.ico" } elseif ($PSScriptRoot) { Join-Path $PSScriptRoot "SUO_tools.ico" } else { "SUO_tools.ico" }
    if (Test-Path $icoPath) {
        try { $dlg.Icon = New-Object System.Drawing.Icon($icoPath) } catch {}
    }

    # Header Panel
    $head = New-Object System.Windows.Forms.Panel
    $head.Location = New-Object System.Drawing.Point(0, 0)
    $head.Size = New-Object System.Drawing.Size(640, 50)
    $head.BackColor = $Colors.BgPanel
    
    $headLbl = New-Object System.Windows.Forms.Label
    $headLbl.Text = "WINDOWS HELLO & PIN MANAGEMENT"
    $headLbl.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $headLbl.ForeColor = $Colors.AccentGlow
    $headLbl.Location = New-Object System.Drawing.Point(20, 12)
    $headLbl.AutoSize = $true
    $head.Controls.Add($headLbl)
    $dlg.Controls.Add($head)

    # Status Panel
    $stPanel = New-Object System.Windows.Forms.Panel
    $stPanel.Location = New-Object System.Drawing.Point(20, 65)
    $stPanel.Size = New-Object System.Drawing.Size(585, 120)
    $stPanel.BackColor = $Colors.BgPanel
    
    $stHdr = New-Object System.Windows.Forms.Label
    $stHdr.Text = "CURRENT SIGN-IN SECURITY STATUS"
    $stHdr.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $stHdr.ForeColor = $Colors.AccentGlow
    $stHdr.Location = New-Object System.Drawing.Point(12, 8)
    $stHdr.AutoSize = $true

    $fontStat = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblWhVbs = New-Object System.Windows.Forms.Label
    $lblWhVbs.Font = $fontStat
    $lblWhVbs.Location = New-Object System.Drawing.Point(15, 30)
    $lblWhVbs.Size = New-Object System.Drawing.Size(550, 20)
    if ($st.HelloVbs) {
        $lblWhVbs.Text = "* VBS Hello Scenario: [ENABLED / ACTIVE] (Blocks VBS Disengagement)"
        $lblWhVbs.ForeColor = $Colors.StatusBad
    } else {
        $lblWhVbs.Text = "* VBS Hello Scenario: [DISABLED] (Safe for Custom Hypervisors)"
        $lblWhVbs.ForeColor = $Colors.StatusGood
    }

    $lblWhCred = New-Object System.Windows.Forms.Label
    $lblWhCred.Font = $fontStat
    $lblWhCred.Location = New-Object System.Drawing.Point(15, 52)
    $lblWhCred.Size = New-Object System.Drawing.Size(550, 20)
    if ($st.HelloCred) {
        $lblWhCred.Text = "* User Enrolled Credentials: [PIN / BIOMETRICS ACTIVE]"
        $lblWhCred.ForeColor = if ($st.HelloConflict) { $Colors.StatusBad } else { $Colors.AccentGlow }
    } else {
        $lblWhCred.Text = "* User Enrolled Credentials: [NOT ENROLLED / NO PIN]"
        $lblWhCred.ForeColor = $Colors.StatusGood
    }

    $lblWhLock = New-Object System.Windows.Forms.Label
    $lblWhLock.Font = $fontStat
    $lblWhLock.Location = New-Object System.Drawing.Point(15, 74)
    $lblWhLock.Size = New-Object System.Drawing.Size(550, 20)
    if ($st.HelloPinLocked) {
        $lblWhLock.Text = "* 'Remove PIN' in Settings: [LOCKED / GREYED OUT by Windows]"
        $lblWhLock.ForeColor = $Colors.StatusWarn
    } else {
        $lblWhLock.Text = "* 'Remove PIN' in Settings: [UNLOCKED / ACTIVE]"
        $lblWhLock.ForeColor = $Colors.StatusGood
    }

    $lblWhSumm = New-Object System.Windows.Forms.Label
    $lblWhSumm.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $lblWhSumm.Location = New-Object System.Drawing.Point(15, 96)
    $lblWhSumm.Size = New-Object System.Drawing.Size(550, 20)
    if ($st.HelloConflict) {
        $lblWhSumm.Text = "STATUS: CONFLICT! Hello is VBS-protected (PIN error risk if VBS disabled)."
        $lblWhSumm.ForeColor = $Colors.StatusBad
    } else {
        $lblWhSumm.Text = "STATUS: NO CONFLICT. System sign-in is safe for VBS configuration."
        $lblWhSumm.ForeColor = $Colors.StatusGood
    }

    $stPanel.Controls.AddRange(@($stHdr, $lblWhVbs, $lblWhCred, $lblWhLock, $lblWhSumm))
    $dlg.Controls.Add($stPanel)

    # Explanation Box
    $infoLbl = New-Object System.Windows.Forms.Label
    $infoLbl.Location = New-Object System.Drawing.Point(20, 195)
    $infoLbl.Size = New-Object System.Drawing.Size(585, 55)
    $infoLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $infoLbl.ForeColor = $Colors.TextMuted
    $infoLbl.Text = "Reference (VBS.cmd): If Windows Hello is enrolled while VBS is active, credentials are tied to Virtual Secure Mode. Disabling VBS without clearing Hello protection can cause 'PIN isn't available' at login. Use the 1-click tools below to resolve this safely."
    $dlg.Controls.Add($infoLbl)

    # Action Buttons Panel
    $btnAutoFix = New-StyledButton "1. Auto-Disable Windows Hello Protection & Policies" 20 255 585 38 $Colors.BtnDark {
        Disable-WindowsHelloProtection
        $dlg.Close()
        if ($Script:UpdateUI) { & $Script:UpdateUI }
    } -TooltipText "Disables DeviceGuard Hello/ESS scenarios, PassportForWork, and unlocks Remove button"

    $btnUnlockSet = New-StyledButton "2. Unlock 'Remove PIN' & Open Windows Sign-in Settings" 20 300 585 38 ([System.Drawing.Color]::FromArgb(35, 75, 120)) {
        Unlock-WindowsHelloRemoveButton
        $dlg.Close()
        if ($Script:UpdateUI) { & $Script:UpdateUI }
    } -TooltipText "Un-greys the Remove button and opens Settings so you can click Remove"

    $btnToggleCred = New-StyledButton "3. Hide / Unhide PIN Credential Provider at Login Screen" 20 345 585 38 ([System.Drawing.Color]::FromArgb(45, 60, 85)) {
        Toggle-WindowsHelloPinProvider
        $dlg.Close()
        if ($Script:UpdateUI) { & $Script:UpdateUI }
    } -TooltipText "Hides the PIN login option at lockscreen (forces Password login)"

    $btnClose = New-StyledButton "Close Window" 20 410 585 34 ([System.Drawing.Color]::FromArgb(34, 38, 48)) {
        $dlg.Close()
    }

    $dlg.Controls.AddRange(@($btnAutoFix, $btnUnlockSet, $btnToggleCred, $btnClose))
    $dlg.ShowDialog() | Out-Null
    $dlg.Dispose()
}

function Show-WindowsHelloCliMenu {
    $st = Get-LiveStatuses
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "             WINDOWS HELLO & PIN SECURITY MANAGEMENT" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  * VBS Hello Scenario      : " -NoNewline
    if ($st.HelloVbs) { Write-Host "ENABLED (Blocks VBS disable)" -ForegroundColor Red } else { Write-Host "DISABLED (Safe)" -ForegroundColor Green }
    Write-Host "  * Enrolled Credentials    : " -NoNewline
    if ($st.HelloCred) { Write-Host "ACTIVE (PIN/Biometrics Enrolled)" -ForegroundColor Cyan } else { Write-Host "NOT ENROLLED" -ForegroundColor Green }
    Write-Host "  * 'Remove PIN' in Settings: " -NoNewline
    if ($st.HelloPinLocked) { Write-Host "LOCKED (Greyed out by Windows)" -ForegroundColor Yellow } else { Write-Host "UNLOCKED" -ForegroundColor Green }
    Write-Host "  * Conflict Status         : " -NoNewline
    if ($st.HelloConflict) { Write-Host "CONFLICT DETECTED! Hello is VBS-protected." -ForegroundColor Red } else { Write-Host "NO CONFLICT - Safe for VBS." -ForegroundColor Green }
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] Auto-Disable Windows Hello Protection & Policies" -ForegroundColor Green
    Write-Host "  [2] Unlock 'Remove' Button & Launch Windows Settings" -ForegroundColor Cyan
    Write-Host "  [3] Toggle PIN Login Provider (Hide/Show at Lock Screen)" -ForegroundColor Yellow
    Write-Host "  [4] Return to Main Menu" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    $c = Read-Host "Select option (1-4)"
    switch ($c) {
        "1" { Disable-WindowsHelloProtection; Start-Sleep -Seconds 2 }
        "2" { Unlock-WindowsHelloRemoveButton; Start-Sleep -Seconds 2 }
        "3" { Toggle-WindowsHelloPinProvider; Start-Sleep -Seconds 2 }
        default { return }
    }
}

# --- Steam Unlock (SUO) Auto-Downloader with Real-Time Progress ---

function Start-SuoDownloaderWorkflow {
    if ($Script:IsDownloadingSuo) {
        [System.Windows.Forms.MessageBox]::Show("Download is already in progress! Please wait...", "Downloading", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $suoInstalled = Test-Path "C:\Program Files\Steam Unlock ONENNABE\SteamUnlock.exe"
    if ($suoInstalled) {
        $ask = [System.Windows.Forms.MessageBox]::Show(
            "Steam Unlock ONENNABE is already installed on your PC!`n`nWould you like to launch it now?`n`n(Click 'No' to download the latest installer from GitHub)",
            "SUO Already Installed",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process "C:\Program Files\Steam Unlock ONENNABE\SteamUnlock.exe"
            return
        } elseif ($ask -eq [System.Windows.Forms.DialogResult]::Cancel) {
            return
        }
    }
    
    # Query GitHub Release API
    $dlUrl = "https://github.com/barryhamsy/gamelist/releases/download/V1.4.6/SteamUnlock_ONENNABEE_1.4.6.exe"
    $fileName = "SteamUnlock_ONENNABEE_1.4.6.exe"
    
    try {
        if ($Script:StatusBar) {
            $Script:StatusBar.Text = "Status: Querying GitHub for latest Steam Unlock release..."
            $Script:StatusBar.ForeColor = $Colors.AccentGlow
        }
        $apiUrl = "https://api.github.com/repos/barryhamsy/gamelist/releases/latest"
        $rel = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "Mozilla/5.0" } -UseBasicParsing -ErrorAction Stop
        if ($rel.assets) {
            $asset = $rel.assets | Where-Object { $_.browser_download_url -match '\.exe$' } | Select-Object -First 1
            if ($asset -and $asset.browser_download_url) {
                $dlUrl = $asset.browser_download_url
                $fileName = $asset.name
            }
        }
    } catch {
        Write-ActionLog "GitHub API notice: $_. Using release URL."
    }
    
    $downFolder = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
    if (-not (Test-Path $downFolder)) { $downFolder = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path } }
    $targetFile = [System.IO.Path]::Combine($downFolder, $fileName)
    
    # Check if already downloaded
    if (Test-Path $targetFile) {
        $launch = [System.Windows.Forms.MessageBox]::Show(
            "Installer already downloaded in Downloads:`n$targetFile`n`nLaunch installer now?`n(Click 'No' to redownload)",
            "Installer Ready",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($launch -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process $targetFile
            return
        } elseif ($launch -eq [System.Windows.Forms.DialogResult]::Cancel) {
            return
        }
    }
    
    $prompt = [System.Windows.Forms.MessageBox]::Show(
        "Download latest Steam Unlock installer?`n`nFile: $fileName`nDestination: $downFolder`n`nDownload will run in background with live progress.",
        "Download Steam Unlock",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($prompt -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    
    $Script:IsDownloadingSuo = $true
    
    # Set high-visibility active style (Bright Sapphire Blue background, Crisp White Text)
    if ($Script:BtnSuo) {
        $Script:BtnSuo.BackColor = [System.Drawing.Color]::FromArgb(25, 95, 175)
        $Script:BtnSuo.ForeColor = [System.Drawing.Color]::White
        $Script:BtnSuo.Text = "[WAIT] CONNECTING..."
    }
    if ($Script:StatusBar) {
        $Script:StatusBar.Text = "Status: Connecting to GitHub CDN for $fileName..."
        $Script:StatusBar.ForeColor = $Colors.StatusWarn
    }
    
    # WebClient with asynchronous live progress
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0")
    
    $wc.add_DownloadProgressChanged({
        param($s, $e)
        try {
            $pct = $e.ProgressPercentage
            $recMB = [Math]::Round($e.BytesReceived / 1MB, 1)
            $totMB = [Math]::Round($e.TotalBytesToReceive / 1MB, 1)
            
            if ($Script:BtnSuo) {
                $Script:BtnSuo.Text = "[WAIT] DOWNLOADING: $pct% ($recMB / $totMB MB)"
            }
            if ($Script:StatusBar) {
                $Script:StatusBar.Text = "Status: Downloading Steam Unlock: $pct% ($recMB MB / $totMB MB)"
            }
        } catch {}
    })
    
    $wc.add_DownloadFileCompleted({
        param($s, $e)
        try {
            $Script:IsDownloadingSuo = $false
            $wc.Dispose()
            
            if ($Script:BtnSuo) {
                $Script:BtnSuo.BackColor = $Colors.BtnGreen
                $Script:BtnSuo.ForeColor = [System.Drawing.Color]::White
                $Script:BtnSuo.Text = "[OK] DOWNLOAD COMPLETED"
            }
            if ($Script:StatusBar) {
                $Script:StatusBar.Text = "Status: [OK] Steam Unlock installer ready in Downloads!"
                $Script:StatusBar.ForeColor = $Colors.StatusGood
            }
            
            if (Test-Path $targetFile) {
                $ask = [System.Windows.Forms.MessageBox]::Show(
                    "Steam Unlock installer downloaded successfully!`n`nLocation: $targetFile`n`nLaunch installer now?",
                    "Download Complete",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Start-Process $targetFile
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Download did not complete. Opening release page in web browser...", "Download Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                Start-Process $dlUrl
            }
        } catch {}
    })
    
    $wc.DownloadFileAsync([System.Uri]$dlUrl, $targetFile)
}

# --- Built-In Tutorial Guide Modal with YouTube Video Links ---

function Show-TutorialGuideDialog {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $mfg = if ($cs) { "$($cs.Manufacturer)".ToUpper() } else { "YOUR PC" }
    $brandClean = if ($mfg -like "*LENOVO*") { "Lenovo" } elseif ($mfg -like "*ASUS*") { "ASUS" } elseif ($mfg -like "*MSI*") { "MSI" } elseif ($mfg -like "*GIGABYTE*") { "Gigabyte" } elseif ($mfg -like "*DELL*") { "Dell" } else { "PC" }
    $biosHint = Get-BiosKeyHint
    $biosVideoUrl = Get-BiosVideoUrl
    $genVideoUrl = "https://www.youtube.com/watch?v=Vzm2YQDcsfw"

    $tut = New-Object System.Windows.Forms.Form
    $tut.Text = "HV Bypass Tool - Quick Tutorial & Video Guide"
    $tut.Size = New-Object System.Drawing.Size(740, 665)
    $tut.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $tut.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $tut.MaximizeBox = $false
    $tut.MinimizeBox = $false
    $tut.BackColor = [System.Drawing.Color]::FromArgb(16, 18, 24)

    # Top Bar: Video Buttons
    $btnYtBios = New-Object System.Windows.Forms.Button
    $btnYtBios.Text = "[>] Watch $brandClean BIOS Video Guide (YouTube)"
    $btnYtBios.Location = New-Object System.Drawing.Point(25, 15)
    $btnYtBios.Size = New-Object System.Drawing.Size(330, 42)
    $btnYtBios.BackColor = [System.Drawing.Color]::FromArgb(204, 0, 0)
    $btnYtBios.ForeColor = [System.Drawing.Color]::White
    $btnYtBios.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnYtBios.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $btnYtBios.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnYtBios.add_Click({ Start-Process $biosVideoUrl })
    $tut.Controls.Add($btnYtBios)

    $btnYtGen = New-Object System.Windows.Forms.Button
    $btnYtGen.Text = "[>] Watch General Setup Video (YouTube)"
    $btnYtGen.Location = New-Object System.Drawing.Point(370, 15)
    $btnYtGen.Size = New-Object System.Drawing.Size(330, 42)
    $btnYtGen.BackColor = [System.Drawing.Color]::FromArgb(31, 111, 235)
    $btnYtGen.ForeColor = [System.Drawing.Color]::White
    $btnYtGen.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnYtGen.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $btnYtGen.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnYtGen.add_Click({ Start-Process $genVideoUrl })
    $tut.Controls.Add($btnYtGen)

    # Tip label
    $tipLbl = New-Object System.Windows.Forms.Label
    $tipLbl.Text = "Lazy to read? Click either red or blue button above to watch the video walkthrough directly on YouTube."
    $tipLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $tipLbl.ForeColor = [System.Drawing.Color]::FromArgb(139, 148, 158)
    $tipLbl.Location = New-Object System.Drawing.Point(25, 62)
    $tipLbl.AutoSize = $true
    $tut.Controls.Add($tipLbl)

    # Container Box around text window to align with scrollbar
    $boxPanel = New-Object System.Windows.Forms.Panel
    $boxPanel.Location = New-Object System.Drawing.Point(25, 88)
    $boxPanel.Size = New-Object System.Drawing.Size(675, 475)
    $boxPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 38)
    $boxPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $tut.Controls.Add($boxPanel)

    $txt = New-Object System.Windows.Forms.RichTextBox
    $txt.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txt.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 38)
    $txt.ForeColor = [System.Drawing.Color]::FromArgb(240, 246, 252)
    $txt.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txt.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $txt.ReadOnly = $true
    $boxPanel.Controls.Add($txt)

    # Helper function to append styled rich text sections
    $AddSection = {
        param([string]$Title, [string[]]$Bullets, [string]$Tip = "")
        $txt.SelectionStart = $txt.TextLength
        $txt.SelectionLength = 0
        $txt.SelectionFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        $txt.SelectionColor = [System.Drawing.Color]::FromArgb(88, 166, 255)
        $txt.SelectionBullet = $false
        $txt.AppendText("$Title`n")

        $fontBody = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Regular)
        $colBody = [System.Drawing.Color]::FromArgb(230, 235, 245)

        foreach ($b in $Bullets) {
            $txt.SelectionStart = $txt.TextLength
            $txt.SelectionLength = 0
            $txt.SelectionFont = $fontBody
            $txt.SelectionColor = $colBody
            $txt.SelectionBullet = $false
            $txt.AppendText("   * $b`n")
        }

        if ($Tip) {
            $txt.SelectionStart = $txt.TextLength
            $txt.SelectionLength = 0
            $txt.SelectionFont = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
            $txt.SelectionColor = [System.Drawing.Color]::FromArgb(210, 153, 34)
            $txt.SelectionBullet = $false
            $txt.AppendText("     Tip: $Tip`n")
        }

        $txt.SelectionStart = $txt.TextLength
        $txt.AppendText("`n")
    }

    $pcName = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() } else { "Your PC" }

    & $AddSection "STEP 1: QUICK START (RECOMMENDED FOR EVERYONE)" @(
        "If you are unsure what settings to pick, simply click: [*] 1-CLICK EASY SETUP.",
        "Creates a Windows System Restore Point snapshot for safe rollback anytime.",
        "Disables Windows VBS (Virtualization-Based Security).",
        "Disables Memory Integrity (HVCI).",
        "Disengages Windows Hello VBS protection scenarios to prevent PIN lockouts.",
        "Whitelists this folder in Windows Defender so drivers aren't blocked.",
        "Enables Driver Test Signing mode."
    ) "Everything runs silently in the background without freezing the app."

    & $AddSection "STEP 2: HOW TO DISABLE SECURE BOOT IN BIOS" @(
        "Detected PC: $pcName (BIOS Hotkey: $biosHint).",
        "Click 'Reboot Directly into BIOS / UEFI' on the dashboard.",
        "As your PC powers on, repeatedly tap [$biosHint] until BIOS opens.",
        "In BIOS, navigate to the Security tab or Boot tab.",
        "Find 'Secure Boot' and set it to [Disabled].",
        "Press F10 to Save & Exit.",
        "When Windows boots up, reopen this tool to confirm 'Secure Boot: [DISABLED]'."
    ) "Click the red button at the top to watch the video tutorial on YouTube."

    & $AddSection "STEP 3: BITLOCKER SAFETY (NO LOCKED SCREENS)" @(
        "Many modern laptops (like Lenovo Legion, Dell, HP) have BitLocker encryption active.",
        "Altering Secure Boot in BIOS can cause BitLocker to trip and ask for a 48-digit key.",
        "This tool automatically detects BitLocker on drive C: and suspends protection for 1 reboot.",
        "You will never get locked out when using the Reboot into BIOS button."
    ) "Always keep your Microsoft Account BitLocker recovery key handy just in case."

    & $AddSection "STEP 4: DRIVER SIGNATURE ENFORCEMENT (DSE)" @(
        "Windows x64 requires all kernel drivers to have an official digital signature.",
        "HV-PlugNPlay and HV-Universal temporarily bypass DSE on-the-fly for 5 seconds at game launch, then restore it automatically.",
        "Having DSE [Enabled] on your desktop is completely normal and keeps anti-cheats (Valorant/Faceit) happy.",
        "Turning 'Testing Mode' ON in BCD is an optional alternative method if you do not use PlugNPlay."
    ) "PlugNPlay handles DSE dynamically, so leaving DSE Enabled at desktop is normal and safe."

    & $AddSection "STEP 5: HOW TO REVERT BACK (FOR VALORANT / FACEIT)" @(
        "Anti-cheat games like Valorant (Vanguard) and CS2 (Faceit) require Secure Boot and HVCI to be ON.",
        "To revert back to factory default security, click '[[R]] Revert to Default (Safe Mode)'.",
        "Enter BIOS and re-enable Secure Boot.",
        "Your PC will be 100% back to factory default Windows security."
    ) "You can toggle between Bypass mode and Safe mode anytime."

    & $AddSection "STEP 6: STEAM UNLOCK (SUO)" @(
        "Click 'Steam Unlock (SUO Setup)' on the dashboard.",
        "The tool automatically queries GitHub for the latest official installer.",
        "Downloads the installer with live percentage progress into your Downloads folder.",
        "Once finished, prompts to launch the installer immediately."
    ) "If already installed, the button lets you launch Steam Unlock with 1 click."

    # Close Button
    $btnClose = New-StyledButton "Close Guide & Return to Dashboard" 235 575 270 36 $Colors.BtnDark {
        $tut.Close()
    }
    $tut.Controls.Add($btnClose)

    $tut.ShowDialog() | Out-Null
    $tut.Dispose()
}

# --- Anti-Cheat & Conflicting Overlay Process Management ---

function Stop-ConflictingServices([switch]$Silent) {
    $st = Get-LiveStatuses
    if (-not $st.HasConflicts) {
        if (-not $Silent) {
            [System.Windows.Forms.MessageBox]::Show(
                "No conflicting anti-cheat or overlay software is currently running.`n`nEnvironment is clean for launch.",
                "All Clean",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        return $true
    }

    $summary = $st.ConflictSummary
    if (-not $Silent) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "The following conflicting software was detected running:`n`n$summary`n`n" +
            "These hooks can crash custom hypervisors or cause Blue Screens (BSODs).`n`n" +
            "Would you like to safely stop Vanguard and close overlay hooks now?",
            "Stop Conflicting Software",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
    }

    Write-ActionLog "Stopping conflicting services and overlays: $summary"
    
    # 1. Vanguard
    try {
        & net stop vgc >$null 2>&1
        & net stop vgk >$null 2>&1
        Get-Process -Name "vgtray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-ActionLog "Vanguard services stopped."
    } catch {
        Write-ActionLog "Notice stopping Vanguard: $_"
    }

    # 2. MSI Afterburner & RTSS
    try {
        Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process -Name "RTSS" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-ActionLog "MSI Afterburner / RTSS closed."
    } catch {
        Write-ActionLog "Notice closing overlays: $_"
    }

    # 3. MacType
    try {
        & net stop MacType >$null 2>&1
        Get-Process -Name "MacType" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}

    if ($Script:UpdateUI) { & $Script:UpdateUI }

    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            "Conflicting services and overlays stopped successfully!`n`nYour system is now clear for game launch.",
            "Conflicts Resolved",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    return $true
}

# --- Telemetry & System Status Gathering ---

function Get-LiveStatuses {
    # 1. Virtualization Status (VT-x / AMD SVM)
    $vtx = $false
    try {
        $proc = Get-CimInstance -ClassName Win32_Processor -Property VirtualizationFirmwareEnabled -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.VirtualizationFirmwareEnabled) { $vtx = $true }
    } catch {}
    if (-not $vtx) {
        try {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -Property HypervisorPresent -ErrorAction SilentlyContinue
            if ($cs -and $cs.HypervisorPresent) { $vtx = $true }
        } catch {}
    }

    # 2. Secure Boot Status (Optional for modern SUO)
    $sb = $false
    try {
        $reg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -ErrorAction SilentlyContinue
        if ($reg -and $reg.UEFISecureBootEnabled -eq 1) { $sb = $true }
    } catch {}
    if (-not $sb) {
        try {
            if (Confirm-SecureBootUEFI) { $sb = $true }
        } catch {}
    }

    # 3. Live In-Memory Kernel Code Integrity Telemetry (NtQuerySystemInformation Class 103)
    $liveDseOff = $false
    $liveTestOn = $false
    $liveHvciOn = $false
    try {
        $pObj = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(8)
        [System.Runtime.InteropServices.Marshal]::WriteInt32($pObj, 8)
        $rObj = [uint32]0
        $ret = [CI]::NtQuerySystemInformation(103, $pObj, 8, [ref]$rObj)
        if ($ret -eq 0) {
            $raw = [System.Runtime.InteropServices.Marshal]::ReadInt32($pObj, 4)
            # Bit 0 (0x01): CODEINTEGRITY_OPTION_ENABLED (If cleared, DSE is disabled in kernel)
            # Bit 1 (0x02): CODEINTEGRITY_OPTION_TESTSIGN (Test signing active in running kernel)
            # Bit 10 (0x400): CODEINTEGRITY_OPTION_HVCI_KMCI_ENABLED (HVCI active in kernel)
            $liveDseOff = (-not ($raw -band 1))
            $liveTestOn = [bool]($raw -band 2)
            $liveHvciOn = [bool]($raw -band 0x400)
        }
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($pObj)
    } catch {}

    # 4. BCD Configuration Telemetry (Query bootloader settings without invalid /enum syntax)
    $bcdTestOn = $false
    $bcdDseOff = $false
    try {
        $bcd = (bcdedit 2>$null) -join "`n"
        if ($bcd -match 'testsigning\s+(Yes|True|1|on)') { $bcdTestOn = $true }
        if ($bcd -match 'nointegritychecks\s+(Yes|True|1|on)') { $bcdDseOff = $true }
    } catch {}

    # Combined state resolution
    $isTestModeOn = ($liveTestOn -or $bcdTestOn)
    $isDseOff = ($liveDseOff -or $bcdDseOff -or $isTestModeOn)

    # 5. VBS & HVCI Status
    $vbs = $false
    $hvci = $false
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -Property VirtualizationBasedSecurityStatus, SecurityServicesRunning, SecurityServicesConfigured -ErrorAction SilentlyContinue
        if ($dg) {
            if ($dg.VirtualizationBasedSecurityStatus -eq 2) { $vbs = $true }
            if ($dg.SecurityServicesRunning -contains 2 -or $dg.SecurityServicesConfigured -contains 2) { $hvci = $true }
        }
    } catch {}
    if ($liveHvciOn) { $hvci = $true }

    # 6. Windows Hello & Sign-in Security Telemetry (VBS.cmd Reference)
    $helloVbs = $false
    $helloCred = $false
    $helloEss = $false
    $helloPinLocked = $false
    $userSid = $null

    try {
        # Check if Windows Hello VBS Scenario is enabled (VBS.cmd line 485)
        $whReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" -Name "Enabled" -ErrorAction SilentlyContinue
        if ($whReg -and $whReg.Enabled -eq 1) { $helloVbs = $true }

        # Check Enhanced Sign-in Security (ESS / Biometrics scenarios) (VBS.cmd lines 783-794)
        $sbReg1 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics" -Name "Enabled" -ErrorAction SilentlyContinue
        $sbReg2 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios" -Name "SecureBiometrics" -ErrorAction SilentlyContinue
        $sbReg3 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureBiometrics" -Name "Enabled" -ErrorAction SilentlyContinue
        $sfReg1 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureFingerprint" -Name "Enabled" -ErrorAction SilentlyContinue
        $sfReg2 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios" -Name "SecureFingerprint" -ErrorAction SilentlyContinue
        $sfReg3 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureFingerprint" -Name "Enabled" -ErrorAction SilentlyContinue
        if (($sbReg1 -and $sbReg1.Enabled -eq 1) -or 
            ($sbReg2 -and $sbReg2.SecureBiometrics -eq 1) -or 
            ($sbReg3 -and $sbReg3.Enabled -eq 1) -or 
            ($sfReg1 -and $sfReg1.Enabled -eq 1) -or 
            ($sfReg2 -and $sfReg2.SecureFingerprint -eq 1) -or 
            ($sfReg3 -and $sfReg3.Enabled -eq 1)) {
            $helloEss = $true
        }

        # Query User SID (VBS.cmd line 487)
        $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if ($userSid) {
            # PIN Credential Provider: {D6886603-9D2F-4EB2-B667-1971041FA96B} (VBS.cmd line 489)
            $pinReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}\$userSid" -Name "LogonCredsAvailable" -ErrorAction SilentlyContinue
            if ($pinReg -and $pinReg.LogonCredsAvailable -eq 1) { $helloCred = $true }

            # Also check Fingerprint {BEC5B3F7-B598-430B-AF40-C6016309222D} and Face {8AF662BF-65A0-4D0A-A540-A338A999D36F}
            if (-not $helloCred) {
                $bioReg1 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{BEC5B3F7-B598-430B-AF40-C6016309222D}\$userSid" -Name "LogonCredsAvailable" -ErrorAction SilentlyContinue
                $bioReg2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{8AF662BF-65A0-4D0A-A540-A338A999D36F}\$userSid" -Name "LogonCredsAvailable" -ErrorAction SilentlyContinue
                if (($bioReg1 -and $bioReg1.LogonCredsAvailable -eq 1) -or ($bioReg2 -and $bioReg2.LogonCredsAvailable -eq 1)) {
                    $helloCred = $true
                }
            }
        }

        # Check if Remove PIN button is greyed out in Windows Settings
        $pwLess = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Name "DevicePasswordLessBuildVersion" -ErrorAction SilentlyContinue
        if ($pwLess -and $pwLess.DevicePasswordLessBuildVersion -eq 2) {
            $helloPinLocked = $true
        }
    } catch {}

    $helloConflict = ($helloVbs -and $helloCred)

    # 7. Anti-Cheat & Third-Party Hook Conflicts
    $conflicts = @()
    try {
        $vgService = Get-Service -Name "vgc" -ErrorAction SilentlyContinue
        if ($vgService -and $vgService.Status -eq 'Running') { $conflicts += "Vanguard" }
        if (Get-Process -Name "MSIAfterburner" -ErrorAction SilentlyContinue) { $conflicts += "MSI Afterburner" }
        if (Get-Process -Name "RTSS" -ErrorAction SilentlyContinue) { $conflicts += "RTSS" }
        if (Get-Process -Name "MacType" -ErrorAction SilentlyContinue) { $conflicts += "MacType" }
    } catch {}
    $hasConflicts = ($conflicts.Count -gt 0)
    $conflictSummary = if ($hasConflicts) { $conflicts -join ", " } else { "Clean" }

    # Overall Hypervisor Readiness
    # Ready requires Virtualization ON and VBS/HVCI OFF (Secure Boot is optional for modern SUO!)
    $isReady = ($vtx -and -not $vbs -and -not $hvci)

    return [PSCustomObject]@{
        Virt            = $vtx
        SecureBoot      = $sb
        VBS             = $vbs
        HVCI            = $hvci
        DseOff          = $isDseOff
        LiveDseOff      = $liveDseOff
        BcdDseOff       = $bcdDseOff
        TestOn          = $isTestModeOn
        TestActive      = $liveTestOn
        TestPending     = ($bcdTestOn -and -not $liveTestOn)
        BcdTestOn       = $bcdTestOn
        HelloVbs        = $helloVbs
        HelloCred       = $helloCred
        HelloConflict   = $helloConflict
        HelloEss        = $helloEss
        HelloPinLocked  = $helloPinLocked
        UserSid         = $userSid
        HasConflicts    = $hasConflicts
        ConflictSummary = $conflictSummary
        IsReady         = $isReady
    }
}

# --- Custom Button Component ---

function New-StyledButton {
    param(
        [string]$Text,
        [int]$X, [int]$Y,
        [int]$Width, [int]$Height,
        [System.Drawing.Color]$BackColor,
        [scriptblock]$Action,
        [string]$TooltipText = ""
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $btn.BackColor = $BackColor
    $btn.ForeColor = $Colors.TextLight
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.UseMnemonic = $false
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    
    $btn.add_MouseEnter({
        if ($this.Enabled) {
            $this.Tag = $this.BackColor
            $this.BackColor = [System.Drawing.Color]::FromArgb(
                [Math]::Min(255, $this.BackColor.R + 25),
                [Math]::Min(255, $this.BackColor.G + 25),
                [Math]::Min(255, $this.BackColor.B + 25)
            )
        }
    })
    $btn.add_MouseLeave({
        if ($this.Enabled -and $this.Tag) {
            $this.BackColor = $this.Tag
        }
    })
    
    if ($Action) { $btn.add_Click($Action) }
    if ($TooltipText -and $Script:TooltipProvider) {
        $Script:TooltipProvider.SetToolTip($btn, $TooltipText)
    }
    return $btn
}

# --- Widescreen Modern Dashboard GUI (810 x 625) ---

function Start-GuiMode {
    $Script:MainForm = New-Object System.Windows.Forms.Form
    $Script:MainForm.Text = "HV Bypass Tool v$SCRIPT_VERSION - Modern Dashboard"
    $Script:MainForm.ClientSize = New-Object System.Drawing.Size(810, 595)
    $Script:MainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $Script:MainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $Script:MainForm.MaximizeBox = $false
    $Script:MainForm.BackColor = $Colors.BgForm
    
    $icoPath = if ($env:TOOL_DIR) { Join-Path $env:TOOL_DIR "SUO_tools.ico" } elseif ($PSScriptRoot) { Join-Path $PSScriptRoot "SUO_tools.ico" } else { "SUO_tools.ico" }
    if (Test-Path $icoPath) {
        try { $Script:MainForm.Icon = New-Object System.Drawing.Icon($icoPath) } catch {}
    }
    
    $Script:TooltipProvider = New-Object System.Windows.Forms.ToolTip
    $Script:TooltipProvider.AutoPopDelay = 8000
    $Script:TooltipProvider.InitialDelay = 400

    # === HEADER PANEL ===
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.Size = New-Object System.Drawing.Size(810, 56)
    $headerPanel.BackColor = $Colors.BgPanel
    
    $titleLbl = New-Object System.Windows.Forms.Label
    $titleLbl.Text = "HV BYPASS TOOL"
    $titleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $titleLbl.ForeColor = $Colors.TextLight
    $titleLbl.Location = New-Object System.Drawing.Point(20, 12)
    $titleLbl.AutoSize = $true
    
    $verBadge = New-Object System.Windows.Forms.Label
    $verBadge.Text = "v$SCRIPT_VERSION PRO"
    $verBadge.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $verBadge.ForeColor = $Colors.Accent
    $verBadge.BackColor = [System.Drawing.Color]::FromArgb(40, 56, 139, 253)
    $verBadge.Location = New-Object System.Drawing.Point(215, 16)
    $verBadge.Size = New-Object System.Drawing.Size(85, 22)
    $verBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    
    $Script:ReadyBadge = New-Object System.Windows.Forms.Label
    $Script:ReadyBadge.Location = New-Object System.Drawing.Point(545, 12)
    $Script:ReadyBadge.Size = New-Object System.Drawing.Size(240, 32)
    $Script:ReadyBadge.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $Script:ReadyBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $Script:ReadyBadge.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Script:ReadyBadge.Text = "[$([char]0x25CF) Verifying Info...]"
    $Script:ReadyBadge.ForeColor = $Colors.TextMuted
    $Script:ReadyBadge.BackColor = [System.Drawing.Color]::FromArgb(25, 30, 40)
    
    $headerPanel.Controls.AddRange(@($titleLbl, $verBadge, $Script:ReadyBadge))
    $Script:MainForm.Controls.Add($headerPanel)

    # === LEFT COLUMN: TELEMETRY & SYSTEM STATUS ===
    
    # 1. System Card (Hardware & OS - Instant Registry Lookup)
    $regCpu = (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -Name "ProcessorNameString" -ErrorAction SilentlyContinue).ProcessorNameString
    $regOs = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
    $regBios = Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -ErrorAction SilentlyContinue
    $regMfg = if ($regBios) { "$($regBios.SystemManufacturer) $($regBios.SystemProductName)".Trim() } else { $null }

    $mfg = if ($regMfg) { $regMfg } else { "Verifying Info..." }
    $cpuText = if ($regCpu) { $regCpu.Trim() } else { "Verifying Info..." }
    $osArch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
    $osText = if ($regOs) { "$regOs ($osArch)" } else { "Verifying Info..." }
    
    $sysCard = New-Object System.Windows.Forms.Panel
    $sysCard.Location = New-Object System.Drawing.Point(20, 64)
    $sysCard.Size = New-Object System.Drawing.Size(365, 90)
    $sysCard.BackColor = $Colors.BgPanel
    
    $sysHeader = New-Object System.Windows.Forms.Label
    $sysHeader.Text = "HARDWARE & SYSTEM"
    $sysHeader.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $sysHeader.ForeColor = $Colors.AccentGlow
    $sysHeader.Location = New-Object System.Drawing.Point(12, 6)
    $sysHeader.AutoSize = $true
    
    $lblSys1 = New-Object System.Windows.Forms.Label
    $lblSys1.Text = "PC: $mfg"
    $lblSys1.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $lblSys1.ForeColor = $Colors.TextLight
    $lblSys1.Location = New-Object System.Drawing.Point(12, 26)
    $lblSys1.Size = New-Object System.Drawing.Size(340, 18)
    
    $lblSys2 = New-Object System.Windows.Forms.Label
    $lblSys2.Text = "CPU: $cpuText"
    $lblSys2.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $lblSys2.ForeColor = $Colors.TextMuted
    $lblSys2.Location = New-Object System.Drawing.Point(12, 46)
    $lblSys2.Size = New-Object System.Drawing.Size(340, 18)
    
    $lblSys3 = New-Object System.Windows.Forms.Label
    $lblSys3.Text = "OS: $osText"
    $lblSys3.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $lblSys3.ForeColor = $Colors.TextMuted
    $lblSys3.Location = New-Object System.Drawing.Point(12, 66)
    $lblSys3.Size = New-Object System.Drawing.Size(340, 18)
    
    $sysCard.Controls.AddRange(@($sysHeader, $lblSys1, $lblSys2, $lblSys3))
    $Script:MainForm.Controls.Add($sysCard)

    # 2. Live Security Telemetry Card (8 Telemetry Sensors)
    $secCard = New-Object System.Windows.Forms.Panel
    $secCard.Location = New-Object System.Drawing.Point(20, 160)
    $secCard.Size = New-Object System.Drawing.Size(365, 246)
    $secCard.BackColor = $Colors.BgPanel
    
    $secHeader = New-Object System.Windows.Forms.Label
    $secHeader.Text = "LIVE SECURITY TELEMETRY"
    $secHeader.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $secHeader.ForeColor = $Colors.AccentGlow
    $secHeader.Location = New-Object System.Drawing.Point(12, 6)
    $secHeader.AutoSize = $true
    
    $stFont = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    
    $Script:LblVirt     = New-Object System.Windows.Forms.Label; $Script:LblVirt.Font     = $stFont; $Script:LblVirt.Location     = New-Object System.Drawing.Point(12, 26);  $Script:LblVirt.Size     = New-Object System.Drawing.Size(340, 22)
    $Script:LblSb       = New-Object System.Windows.Forms.Label; $Script:LblSb.Font       = $stFont; $Script:LblSb.Location       = New-Object System.Drawing.Point(12, 53);  $Script:LblSb.Size       = New-Object System.Drawing.Size(340, 22)
    $Script:LblVbs      = New-Object System.Windows.Forms.Label; $Script:LblVbs.Font      = $stFont; $Script:LblVbs.Location      = New-Object System.Drawing.Point(12, 80);  $Script:LblVbs.Size      = New-Object System.Drawing.Size(340, 22)
    $Script:LblHvci     = New-Object System.Windows.Forms.Label; $Script:LblHvci.Font     = $stFont; $Script:LblHvci.Location     = New-Object System.Drawing.Point(12, 107); $Script:LblHvci.Size     = New-Object System.Drawing.Size(340, 22)
    $Script:LblDse      = New-Object System.Windows.Forms.Label; $Script:LblDse.Font      = $stFont; $Script:LblDse.Location      = New-Object System.Drawing.Point(12, 134); $Script:LblDse.Size      = New-Object System.Drawing.Size(340, 22)
    $Script:LblTest     = New-Object System.Windows.Forms.Label; $Script:LblTest.Font     = $stFont; $Script:LblTest.Location     = New-Object System.Drawing.Point(12, 161); $Script:LblTest.Size     = New-Object System.Drawing.Size(340, 22)
    $Script:LblHello    = New-Object System.Windows.Forms.Label; $Script:LblHello.Font    = $stFont; $Script:LblHello.Location    = New-Object System.Drawing.Point(12, 188); $Script:LblHello.Size    = New-Object System.Drawing.Size(340, 22)
    $Script:LblConflict = New-Object System.Windows.Forms.Label; $Script:LblConflict.Font = $stFont; $Script:LblConflict.Location = New-Object System.Drawing.Point(12, 215); $Script:LblConflict.Size = New-Object System.Drawing.Size(340, 22)
    
    # Initial status placeholder: Verifying Info...
    $Script:LblVirt.Text     = "Virtualization (AMD SVM / VT-x): [Verifying Info...]"
    $Script:LblSb.Text       = "Secure Boot: [Verifying Info...]"
    $Script:LblVbs.Text      = "VBS Security: [Verifying Info...]"
    $Script:LblHvci.Text     = "Memory Integrity (HVCI): [Verifying Info...]"
    $Script:LblDse.Text      = "Driver Signature (DSE): [Verifying Info...]"
    $Script:LblTest.Text     = "Testing Mode (BCD): [Verifying Info...]"
    $Script:LblHello.Text    = "Windows Hello: [Verifying Info...]"
    $Script:LblConflict.Text = "Anti-Cheat / Overlays: [Verifying Info...]"
    foreach ($lbl in @($Script:LblVirt, $Script:LblSb, $Script:LblVbs, $Script:LblHvci, $Script:LblDse, $Script:LblTest, $Script:LblHello, $Script:LblConflict)) {
        $lbl.ForeColor = $Colors.TextMuted
    }

    $secCard.Controls.AddRange(@($secHeader, $Script:LblVirt, $Script:LblSb, $Script:LblVbs, $Script:LblHvci, $Script:LblDse, $Script:LblTest, $Script:LblHello, $Script:LblConflict))
    $Script:MainForm.Controls.Add($secCard)

    # 3. Quick Utility Actions Card (Bottom Left - 4 Safety Tools)
    $utilCard = New-Object System.Windows.Forms.Panel
    $utilCard.Location = New-Object System.Drawing.Point(20, 412)
    $utilCard.Size = New-Object System.Drawing.Size(365, 140)
    $utilCard.BackColor = $Colors.BgPanel
    
    $utilHeader = New-Object System.Windows.Forms.Label
    $utilHeader.Text = "QUICK SAFETY UTILITIES"
    $utilHeader.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $utilHeader.ForeColor = $Colors.AccentGlow
    $utilHeader.Location = New-Object System.Drawing.Point(12, 4)
    $utilHeader.AutoSize = $true
    
    $btnDef = New-StyledButton "Whitelist Folder in Windows Defender" 12 23 341 26 $Colors.BtnDark {
        Add-DefenderExclusion
    } -TooltipText "Whitelist this folder in Windows Defender so hypervisor drivers are never quarantined"
    
    $btnRp = New-StyledButton "Create Windows Restore Point" 12 51 341 26 $Colors.BtnDark {
        New-SystemRestorePoint -Mode 'GUI'
    } -TooltipText "Create a Windows System Restore Point safety snapshot"
    
    $Script:BtnHello = New-StyledButton "Windows Hello / PIN Fix & Options" 12 79 341 26 ([System.Drawing.Color]::FromArgb(40, 60, 95)) {
        Show-WindowsHelloDialog
    } -TooltipText "Manage Windows Hello, unlock the Remove PIN button in Settings, or auto-disable VBS scenarios"
    
    $Script:BtnConflict = New-StyledButton "Stop Vanguard & Overlay Conflicts" 12 107 341 26 ([System.Drawing.Color]::FromArgb(50, 40, 30)) {
        Stop-ConflictingServices
    } -TooltipText "Stops Riot Vanguard, MSI Afterburner, and RTSS hooks to prevent game launch crashes"
    
    $utilCard.Controls.AddRange(@($utilHeader, $btnDef, $btnRp, $Script:BtnHello, $Script:BtnConflict))
    $Script:MainForm.Controls.Add($utilCard)

    # === RIGHT COLUMN: ACTION DASHBOARD CONTROLS ===
    
    # 1. PRIMARY HIGHLIGHTED CARD: "START HERE (RECOMMENDED)"
    $recCard = New-Object System.Windows.Forms.Panel
    $recCard.Location = New-Object System.Drawing.Point(405, 68)
    $recCard.Size = New-Object System.Drawing.Size(380, 115)
    $recCard.BackColor = $Colors.BgHighlight
    $recCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    $recHeader = New-Object System.Windows.Forms.Label
    $recHeader.Text = "[*] STEP 1: START HERE (RECOMMENDED)"
    $recHeader.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $recHeader.ForeColor = $Colors.StatusGood
    $recHeader.Location = New-Object System.Drawing.Point(12, 8)
    $recHeader.AutoSize = $true
    
    $recSub = New-Object System.Windows.Forms.Label
    $recSub.Text = "No IT knowledge needed - automatically fixes everything in 1 click"
    $recSub.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $recSub.ForeColor = $Colors.TextLight
    $recSub.Location = New-Object System.Drawing.Point(12, 28)
    $recSub.Size = New-Object System.Drawing.Size(356, 18)
    
    # Huge Primary Button
    $Script:BtnAuto = New-StyledButton "[*] 1-CLICK EASY SETUP (RECOMMENDED)" 12 50 354 52 $Colors.BtnGreen {
        if ($Script:BackgroundJob -and -not $Script:BackgroundJob.HasExited) {
            [System.Windows.Forms.MessageBox]::Show("Setup is already running in the background! Please wait...", "In Progress", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Pre-Flight Check: Windows Hello VBS Conflict (VBS.cmd reference)
        if (-not (Confirm-WindowsHelloPreFlight "1-Click Easy Setup")) { return }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "1-CLICK EASY SETUP will automatically:`n`n1. Create a System Restore Point (Safety Net)`n2. Disable VBS & Memory Integrity (HVCI)`n3. Disengage Windows Hello VBS scenarios`n4. Whitelist this folder in Windows Defender`n5. Configure Driver Testing Mode`n`nThe setup runs silently in the background so the app will not lag or freeze.`n`nStart now?",
            "1-Click Easy Setup",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        
        Suspend-BitLockerSafety
        
        $Script:BtnAuto.Text = "[WAIT] CONFIGURING IN BACKGROUND..."
        $Script:BtnAuto.BackColor = $Colors.BtnDark
        $Script:BtnAuto.Enabled = $false
        $Script:StatusBar.Text = "Status: [WAIT] Easy Setup is running silently in background. Please wait ~15-30s..."
        $Script:StatusBar.ForeColor = $Colors.StatusWarn
        
        $workerScript = @'
Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
Checkpoint-Computer -Description "HV Tool Auto-Setup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue

$dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
$hvci = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (-not (Test-Path $dg)) { New-Item -Path $dg -Force | Out-Null }
if (-not (Test-Path $hvci)) { New-Item -Path $hvci -Force | Out-Null }
Set-ItemProperty -Path $dg -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $hvci -Name "Enabled" -Value 0 -Type DWord -Force
bcdedit /set hypervisorlaunchtype off | Out-Null

# Disengage Windows Hello VBS & ESS Scenarios (VBS.cmd reference)
$whScenarios = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello",
    "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureBiometrics",
    "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureBiometrics",
    "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SecureFingerprint",
    "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHelloSecureFingerprint"
)
foreach ($s in $whScenarios) {
    if (-not (Test-Path $s)) { New-Item -Path $s -Force | Out-Null }
    Set-ItemProperty -Path $s -Name "Enabled" -Value 0 -Type DWord -Force | Out-Null
}
$scRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios"
if (Test-Path $scRoot) {
    Set-ItemProperty -Path $scRoot -Name "SecureBiometrics" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $scRoot -Name "SecureFingerprint" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
}
$pwLess = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
if (-not (Test-Path $pwLess)) { New-Item -Path $pwLess -Force | Out-Null }
Set-ItemProperty -Path $pwLess -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null

Add-MpPreference -ExclusionPath (Get-Location).Path -ErrorAction SilentlyContinue

bcdedit /set testsigning on | Out-Null
bcdedit /set nointegritychecks on | Out-Null
bcdedit /set "{current}" testsigning on | Out-Null
bcdedit /set "{current}" nointegritychecks on | Out-Null
'@
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($workerScript))
        $Script:BackgroundJob = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -WindowStyle Hidden -PassThru
        
        $jobWatcher = New-Object System.Windows.Forms.Timer
        $jobWatcher.Interval = 1000
        $jobWatcher.add_Tick({
            try {
                if ($Script:BackgroundJob -and $Script:BackgroundJob.HasExited) {
                    $this.Stop()
                    $this.Dispose()
                    
                    if ($Script:BtnAuto) {
                        $Script:BtnAuto.Text = "[OK] EASY SETUP COMPLETED"
                        $Script:BtnAuto.BackColor = $Colors.BtnGreen
                        $Script:BtnAuto.Enabled = $true
                    }
                    if ($Script:StatusBar) {
                        $Script:StatusBar.ForeColor = $Colors.TextMuted
                    }
                    Write-ActionLog "Background Easy Setup finished."
                    
                    if ($Script:UpdateUI) { & $Script:UpdateUI }
                    
                    $st = Get-LiveStatuses
                    $sbNote = if ($st.SecureBoot) { "`n`n(Note: Secure Boot is [Enabled] in BIOS. This is completely fine and optional for modern SUO! The bypass works as long as VBS & HVCI are disabled.)" } else { "" }
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "1-Click Easy Setup Complete!`n`n" +
                        "1. System Restore Point created (Safety Net)`n" +
                        "2. VBS & Memory Integrity (HVCI) disabled`n" +
                        "3. Windows Defender folder exclusion added`n" +
                        "4. Testing Mode configured in BCD$sbNote`n`n" +
                        "Please restart your computer to apply changes.",
                        "Setup Complete",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                }
            } catch {
                $this.Stop()
                $this.Dispose()
                Write-ActionLog "JobWatcher error: $_"
            }
        })
        $jobWatcher.Start()
    } -TooltipText "No IT knowledge needed: automatically configures all settings silently in background"
    $Script:BtnAuto.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    
    $recCard.Controls.AddRange(@($recHeader, $recSub, $Script:BtnAuto))
    $Script:MainForm.Controls.Add($recCard)

    # 2. SMART GUIDANCE BANNER
    $Script:GuideBox = New-Object System.Windows.Forms.Label
    $Script:GuideBox.Location = New-Object System.Drawing.Point(405, 191)
    $Script:GuideBox.Size = New-Object System.Drawing.Size(380, 42)
    $Script:GuideBox.BackColor = [System.Drawing.Color]::FromArgb(20, 25, 35)
    $Script:GuideBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Script:GuideBox.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $Script:GuideBox.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $Script:GuideBox.Text = "Verifying Info..."
    $Script:GuideBox.ForeColor = $Colors.TextMuted
    $Script:MainForm.Controls.Add($Script:GuideBox)

    # 3. ADVANCED MANUAL TOOLS PANEL
    $manPanel = New-Object System.Windows.Forms.Panel
    $manPanel.Location = New-Object System.Drawing.Point(405, 241)
    $manPanel.Size = New-Object System.Drawing.Size(380, 305)
    $manPanel.BackColor = $Colors.BgPanel
    
    $manHeader = New-Object System.Windows.Forms.Label
    $manHeader.Text = "ADVANCED / MANUAL CONTROLS (OPTIONAL)"
    $manHeader.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)
    $manHeader.ForeColor = $Colors.TextMuted
    $manHeader.Location = New-Object System.Drawing.Point(12, 7)
    $manHeader.AutoSize = $true
    
    # Button 1: Test Mode (Y=28)
    $Script:BtnTest = New-StyledButton "Turn ON Testing Mode (Optional - BCD)" 12 28 356 34 $Colors.BtnDark {
        $st = Get-LiveStatuses
        if ($st.TestOn) {
            # Turn OFF Testing Mode
            Set-TestingModeStatus -Enable $false | Out-Null
            if ($Script:UpdateUI) { & $Script:UpdateUI }
            [System.Windows.Forms.MessageBox]::Show(
                "Testing Mode has been turned OFF in BCD.`n`nPlease restart your computer to apply changes.",
                "Testing Mode Disabled",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            # Turn ON Testing Mode
            if ($st.SecureBoot) {
                $ans = [System.Windows.Forms.MessageBox]::Show(
                    "Secure Boot is currently [ENABLED] in your BIOS.`n`n" +
                    "NOTE: Modern SUO (Steam Unlock ONENNABE) works with Secure Boot ENABLED as long as VBS & HVCI are disabled.`n`n" +
                    "However, Windows Boot Manager will not show the 'Test Mode' desktop watermark unless Secure Boot is turned off in BIOS.`n`n" +
                    "Would you like to turn ON Test Signing in BCD anyway?`n`n" +
                    "(Click 'Yes' to configure in BCD, or 'No' to cancel)",
                    "Secure Boot Notice (Optional)",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            }
            
            Set-TestingModeStatus -Enable $true | Out-Null
            if ($Script:UpdateUI) { & $Script:UpdateUI }
            [System.Windows.Forms.MessageBox]::Show(
                "Testing Mode has been turned ON in BCD.`n`nPlease restart your computer to apply changes.",
                "Testing Mode Enabled",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    } -TooltipText "Toggle Windows Test Signing mode on or off"
    
    # Button 2: VBS & HVCI (Y=66)
    $Script:BtnVbs = New-StyledButton "Disable VBS & Memory Integrity" 12 66 356 34 $Colors.BtnDark {
        $st = Get-LiveStatuses
        if ($st.VBS -or $st.HVCI) {
            if (-not (Confirm-WindowsHelloPreFlight "Disable VBS")) { return }
            Set-VBSAndHVCIStatus -Enable $false | Out-Null
            if ($Script:UpdateUI) { & $Script:UpdateUI }
            [System.Windows.Forms.MessageBox]::Show("VBS & Memory Integrity (HVCI) have been DISABLED in registry and BCD.`nRestart to commit.", "Processed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            $toggle = [System.Windows.Forms.MessageBox]::Show("VBS & HVCI are currently OFF.`nWould you like to re-enable them?", "VBS/HVCI Off", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($toggle -eq [System.Windows.Forms.DialogResult]::Yes) {
                Set-VBSAndHVCIStatus -Enable $true | Out-Null
                if ($Script:UpdateUI) { & $Script:UpdateUI }
                [System.Windows.Forms.MessageBox]::Show("VBS & Memory Integrity (HVCI) have been RE-ENABLED.`nRestart to commit.", "Processed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
    } -TooltipText "Toggle Virtualization-Based Security and Memory Integrity"

    # Button 3: Reboot BIOS (Y=104)
    $btnUefi = New-StyledButton "Reboot Directly into BIOS / UEFI" 12 104 356 34 ([System.Drawing.Color]::FromArgb(45, 60, 85)) {
        Restart-DirectToUEFI
    } -TooltipText "Restarts the PC straight into UEFI firmware settings with BitLocker safety"
    
    # Button 4: SUO Setup & Downloader (Y=142)
    $Script:BtnSuo = New-StyledButton "Steam Unlock (SUO Setup)" 12 142 356 34 $Colors.BtnDark {
        Start-SuoDownloaderWorkflow
    } -TooltipText "Download and launch the latest official Steam Unlock installer"

    # Button 5: Revert to Safe Mode (Y=180)
    $btnRevert = New-StyledButton "[[R]] Revert to Default (Safe Mode)" 12 180 356 34 ([System.Drawing.Color]::FromArgb(48, 38, 56)) {
        Revert-ToSafeMode
    } -TooltipText "Restore default factory Windows security for games like Valorant and Faceit"

    # Button 6 & 7: 50/50 Split - CLI Mode | Tutorial Guide (Y=218)
    $btnCli = New-StyledButton "CLI Mode" 12 218 174 34 $Colors.BtnDark {
        $Script:NextMode = "CLI"
        $refreshTimer.Stop()
        $Script:MainForm.Close()
    } -TooltipText "Switch to lightweight text-based command line interface"

    $btnTut = New-StyledButton "Tutorial Guide" 194 218 174 34 ([System.Drawing.Color]::FromArgb(35, 75, 120)) {
        Show-TutorialGuideDialog
    } -TooltipText "Open complete user tutorial and video guides"

    # Button 8: Exit Tool (Y=256)
    $btnExit = New-StyledButton "Exit Tool" 12 256 356 32 ([System.Drawing.Color]::FromArgb(34, 38, 48)) {
        $Script:NextMode = "Exit"
        $refreshTimer.Stop()
        $Script:MainForm.Close()
    } -TooltipText "Close the utility"

    $manPanel.Controls.AddRange(@($manHeader, $Script:BtnTest, $Script:BtnVbs, $btnUefi, $Script:BtnSuo, $btnRevert, $btnCli, $btnTut, $btnExit))
    $Script:MainForm.Controls.Add($manPanel)

    # === BOTTOM STATUS BAR & SUBTITLE ===
    $Script:StatusBar = New-Object System.Windows.Forms.Label
    $Script:StatusBar.Location = New-Object System.Drawing.Point(0, 565)
    $Script:StatusBar.Size = New-Object System.Drawing.Size(390, 30)
    $Script:StatusBar.BackColor = [System.Drawing.Color]::FromArgb(12, 14, 18)
    $Script:StatusBar.ForeColor = $Colors.TextMuted
    $Script:StatusBar.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $Script:StatusBar.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $Script:StatusBar.Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
    $Script:StatusBar.UseMnemonic = $false
    $Script:StatusBar.Text = "Status: Verifying Info..."
    $Script:MainForm.Controls.Add($Script:StatusBar)

    $subTitleLbl = New-Object System.Windows.Forms.Label
    $subTitleLbl.Text = "Next-Gen Virtualization & Hypervisor Configuration Utility"
    $subTitleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $subTitleLbl.ForeColor = $Colors.TextDimmed
    $subTitleLbl.BackColor = [System.Drawing.Color]::FromArgb(12, 14, 18)
    $subTitleLbl.Location = New-Object System.Drawing.Point(390, 565)
    $subTitleLbl.Size = New-Object System.Drawing.Size(420, 30)
    $subTitleLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $subTitleLbl.Padding = New-Object System.Windows.Forms.Padding(0, 0, 15, 0)
    $subTitleLbl.UseMnemonic = $false
    $Script:MainForm.Controls.Add($subTitleLbl)

    # --- Live Status Update Routine ---
    $Script:UpdateUI = {
        if ($Script:MainForm -eq $null -or $Script:MainForm.IsDisposed) { return }
        $st = Get-LiveStatuses
        
        # Virtualization
        if ($Script:LblVirt) {
            if ($st.Virt) {
                $Script:LblVirt.Text = "Virtualization (AMD SVM / VT-x): [ENABLED]"
                $Script:LblVirt.ForeColor = $Colors.StatusGood
            } else {
                $Script:LblVirt.Text = "Virtualization (AMD SVM / VT-x): [DISABLED]"
                $Script:LblVirt.ForeColor = $Colors.StatusBad
            }
        }

        # Secure Boot (Optional for SUO)
        if ($Script:LblSb) {
            if ($st.SecureBoot) {
                $Script:LblSb.Text = "Secure Boot (BIOS): [ENABLED] (Optional OFF)"
                $Script:LblSb.ForeColor = $Colors.AccentGlow
            } else {
                $Script:LblSb.Text = "Secure Boot (BIOS): [DISABLED] (Test Mode ON)"
                $Script:LblSb.ForeColor = $Colors.StatusGood
            }
        }

        # VBS
        if ($Script:LblVbs) {
            if ($st.VBS) {
                $Script:LblVbs.Text = "VBS Security: [RUNNING]"
                $Script:LblVbs.ForeColor = $Colors.StatusBad
            } else {
                $Script:LblVbs.Text = "VBS Security: [OFF]"
                $Script:LblVbs.ForeColor = $Colors.StatusGood
            }
        }

        # HVCI
        if ($Script:LblHvci) {
            if ($st.HVCI) {
                $Script:LblHvci.Text = "Memory Integrity (HVCI): [ENABLED]"
                $Script:LblHvci.ForeColor = $Colors.StatusBad
            } else {
                $Script:LblHvci.Text = "Memory Integrity (HVCI): [DISABLED]"
                $Script:LblHvci.ForeColor = $Colors.StatusGood
            }
        }

        # Readiness Badge
        if ($Script:ReadyBadge) {
            if ($st.IsReady) {
                $Script:ReadyBadge.Text = "[$([char]0x25CF) READY FOR HYPERVISOR]"
                $Script:ReadyBadge.ForeColor = $Colors.StatusGood
                $Script:ReadyBadge.BackColor = [System.Drawing.Color]::FromArgb(20, 50, 30)
            } else {
                $Script:ReadyBadge.Text = "[$([char]0x25B2) ACTION REQUIRED]"
                $Script:ReadyBadge.ForeColor = $Colors.StatusWarn
                $Script:ReadyBadge.BackColor = [System.Drawing.Color]::FromArgb(50, 35, 20)
            }
        }

        # DSE (Option A: Soft Blue / Cyan with PnP Note)
        if ($Script:LblDse) {
            if ($st.LiveDseOff -or $st.TestActive) {
                $Script:LblDse.Text = "Driver Signature (DSE): [Disabled] (Active in Kernel)"
                $Script:LblDse.ForeColor = $Colors.StatusGood
            } elseif ($st.DseOff) {
                $Script:LblDse.Text = "Driver Signature (DSE): [Disabled] (Pending Reboot)"
                $Script:LblDse.ForeColor = $Colors.StatusWarn
            } else {
                $Script:LblDse.Text = "Driver Signature (DSE): [Enabled] (Auto-Handled by PnP)"
                $Script:LblDse.ForeColor = $Colors.AccentGlow
            }
        }

        # Test Mode Button & Label (Clarified as Optional BCD alternative)
        if ($Script:LblTest -and $Script:BtnTest) {
            if ($st.TestActive) {
                $Script:LblTest.Text = "Testing Mode (BCD): [ON] (Active in Kernel)"
                $Script:LblTest.ForeColor = $Colors.StatusGood
                $Script:BtnTest.Text = "Turn OFF Testing Mode (BCD)"
                $Script:BtnTest.BackColor = $Colors.BtnDanger
            } elseif ($st.TestPending) {
                $Script:LblTest.Text = "Testing Mode (BCD): [PENDING] (Restart Required)"
                $Script:LblTest.ForeColor = $Colors.StatusWarn
                $Script:BtnTest.Text = "Turn OFF Testing Mode (BCD)"
                $Script:BtnTest.BackColor = $Colors.BtnDanger
            } else {
                $Script:LblTest.Text = "Testing Mode (BCD): [OFF] (Optional for PnP)"
                $Script:LblTest.ForeColor = $Colors.TextMuted
                $Script:BtnTest.Text = "Turn ON Testing Mode (Optional - BCD)"
                $Script:BtnTest.BackColor = $Colors.BtnDark
            }
        }

        # Windows Hello & Sign-in Security
        if ($Script:LblHello) {
            if ($st.HelloConflict) {
                $Script:LblHello.Text = "Windows Hello: [VBS PROTECTED - CONFLICT]"
                $Script:LblHello.ForeColor = $Colors.StatusBad
            } elseif ($st.HelloCred) {
                $Script:LblHello.Text = "Windows Hello: [PIN ACTIVE (Safe)]"
                $Script:LblHello.ForeColor = $Colors.AccentGlow
            } elseif ($st.HelloVbs) {
                $Script:LblHello.Text = "Windows Hello: [VBS POLICY ACTIVE]"
                $Script:LblHello.ForeColor = $Colors.StatusWarn
            } else {
                $Script:LblHello.Text = "Windows Hello: [DISABLED / SAFE]"
                $Script:LblHello.ForeColor = $Colors.StatusGood
            }
        }

        # Anti-Cheat & Overlays Conflict Telemetry & Button
        if ($Script:LblConflict) {
            if ($st.HasConflicts) {
                $Script:LblConflict.Text = "Anti-Cheat / Overlays: [ACTIVE: $($st.ConflictSummary)]"
                $Script:LblConflict.ForeColor = $Colors.StatusWarn
            } else {
                $Script:LblConflict.Text = "Anti-Cheat / Overlays: [CLEAN / NO CONFLICTS]"
                $Script:LblConflict.ForeColor = $Colors.StatusGood
            }
        }

        if ($Script:BtnConflict) {
            if ($st.HasConflicts) {
                $Script:BtnConflict.Text = "[!] Stop Conflicts ($($st.ConflictSummary))"
                $Script:BtnConflict.BackColor = [System.Drawing.Color]::FromArgb(90, 60, 20)
                $Script:BtnConflict.ForeColor = $Colors.StatusWarn
            } else {
                $Script:BtnConflict.Text = "[OK] Anti-Cheat & Overlays: Clean"
                $Script:BtnConflict.BackColor = $Colors.BtnDark
                $Script:BtnConflict.ForeColor = $Colors.TextMuted
            }
        }

        # VBS/HVCI Button Text
        if ($Script:BtnVbs) {
            if ($st.VBS -or $st.HVCI) {
                $Script:BtnVbs.Text = "Disable VBS & Memory Integrity"
            } else {
                $Script:BtnVbs.Text = "Enable VBS & Memory Integrity"
            }
        }

        # Smart Guidance Box text
        if ($Script:GuideBox) {
            if (-not $st.Virt) {
                $hint = Get-BiosKeyHint
                $Script:GuideBox.Text = "ACTION REQUIRED: Enable Virtualization in BIOS ($hint)"
                $Script:GuideBox.ForeColor = $Colors.StatusWarn
                $Script:GuideBox.BackColor = [System.Drawing.Color]::FromArgb(40, 50, 20)
            } elseif ($st.VBS -or $st.HVCI) {
                $Script:GuideBox.Text = "RECOMMENDED: Click '1-CLICK EASY SETUP' above"
                $Script:GuideBox.ForeColor = $Colors.AccentGlow
                $Script:GuideBox.BackColor = [System.Drawing.Color]::FromArgb(20, 35, 55)
            } else {
                $Script:GuideBox.Text = "ALL SET: Your PC is ready for SUO! (Secure Boot is optional)"
                $Script:GuideBox.ForeColor = $Colors.StatusGood
                $Script:GuideBox.BackColor = [System.Drawing.Color]::FromArgb(18, 40, 25)
            }
        }

        # Status Bar text (only if not running background worker or download)
        if ($Script:StatusBar -and -not $Script:IsDownloadingSuo -and (-not ($Script:BackgroundJob -and -not $Script:BackgroundJob.HasExited))) {
            $timeStr = Get-Date -Format 'HH:mm:ss'
            $blState = if (Test-BitLockerProtected) { "BitLocker: Active" } else { "BitLocker: Safe" }
            $Script:StatusBar.Text = "Status: Ready  |  $blState  |  Actions: $($Script:ActionLog.Count)  |  $timeStr"
        }
    }

    # Refresh timer every 4 seconds
    $refreshTimer = New-Object System.Windows.Forms.Timer
    $refreshTimer.Interval = 4000
    $refreshTimer.add_Tick({ if ($Script:UpdateUI) { & $Script:UpdateUI } })

    # Fast deferred initial scan: runs 50ms after form is drawn on screen
    $firstScanTimer = New-Object System.Windows.Forms.Timer
    $firstScanTimer.Interval = 50
    $firstScanTimer.add_Tick({
        $this.Stop()
        $this.Dispose()
        if ($Script:UpdateUI) { & $Script:UpdateUI }
        $refreshTimer.Start()
    })

    # Prioritize app window opening (Bring to front / top priority)
    $Script:MainForm.TopMost = $true
    $Script:MainForm.add_Shown({
        $this.Activate()
        $this.BringToFront()
        $topRelease = New-Object System.Windows.Forms.Timer
        $topRelease.Interval = 200
        $topRelease.add_Tick({
            $this.Stop()
            $this.Dispose()
            if ($Script:MainForm -and -not $Script:MainForm.IsDisposed) {
                $Script:MainForm.TopMost = $false
            }
        })
        $topRelease.Start()
        $firstScanTimer.Start()
    })

    $Script:MainForm.add_FormClosing({
        param($s, $e)
        if ($Script:NextMode -eq "GUI") {
            $Script:NextMode = "Exit"
        }
    })

    $Script:MainForm.ShowDialog() | Out-Null
    $refreshTimer.Stop()
    $refreshTimer.Dispose()
    if ($Script:TooltipProvider) { $Script:TooltipProvider.Dispose() }
    if ($Script:MainForm) { $Script:MainForm.Dispose() }
}

# --- Lightweight Modern CLI Mode ---

function Start-CliMode {
    while ($true) {
        try { Clear-Host } catch {}
        $st = Get-LiveStatuses
        $hint = Get-BiosKeyHint
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "             HV BYPASS TOOL v$SCRIPT_VERSION - CLI DASHBOARD" -ForegroundColor White
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Virtualization (VT-x/SVM) : " -NoNewline
        if ($st.Virt) { Write-Host "ENABLED" -ForegroundColor Green } else { Write-Host "DISABLED (Enable in BIOS)" -ForegroundColor Red }
        
        Write-Host "  [2] Secure Boot (BIOS)        : " -NoNewline
        if ($st.SecureBoot) { Write-Host "ENABLED (Optional - Compatible with SUO)" -ForegroundColor Cyan } else { Write-Host "DISABLED (Test Mode Allowed)" -ForegroundColor Green }
        
        Write-Host "  [3] VBS Security              : " -NoNewline
        if ($st.VBS) { Write-Host "RUNNING" -ForegroundColor Red } else { Write-Host "OFF" -ForegroundColor Green }
        
        Write-Host "  [4] Memory Integrity (HVCI)   : " -NoNewline
        if ($st.HVCI) { Write-Host "ENABLED" -ForegroundColor Red } else { Write-Host "DISABLED" -ForegroundColor Green }
        
        Write-Host "  [5] Driver Signature (DSE)    : " -NoNewline
        if ($st.LiveDseOff -or $st.TestActive) { Write-Host "DISABLED (Active)" -ForegroundColor Green } elseif ($st.DseOff) { Write-Host "DISABLED (Pending Reboot)" -ForegroundColor Yellow } else { Write-Host "ENABLED (Auto-Handled by PnP)" -ForegroundColor Cyan }
        
        Write-Host "  [6] Testing Mode (BCD)        : " -NoNewline
        if ($st.TestActive) { Write-Host "ON (Active in Kernel)" -ForegroundColor Green } elseif ($st.TestPending) { Write-Host "PENDING (Restart Required)" -ForegroundColor Yellow } else { Write-Host "OFF (Optional for PnP)" -ForegroundColor DarkGray }
        
        Write-Host "  [7] Windows Hello             : " -NoNewline
        if ($st.HelloConflict) { Write-Host "VBS PROTECTED (Conflict!)" -ForegroundColor Red } elseif ($st.HelloCred) { Write-Host "PIN ACTIVE (Safe)" -ForegroundColor Cyan } else { Write-Host "OFF / DISABLED" -ForegroundColor Green }

        Write-Host "  [8] Anti-Cheat & Overlays     : " -NoNewline
        if ($st.HasConflicts) { Write-Host "ACTIVE: $($st.ConflictSummary)" -ForegroundColor Yellow } else { Write-Host "CLEAN (None Detected)" -ForegroundColor Green }

        Write-Host ""
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [A] [*] 1-Click Easy Setup (Recommended for Everyone)" -ForegroundColor Green
        Write-Host "  [B] [!] Reboot Directly into BIOS / UEFI Setup ($hint)" -ForegroundColor Yellow
        Write-Host "  [T] [~] Toggle Testing Mode (Turn ON / Turn OFF)" -ForegroundColor White
        Write-Host "  [V] [-] Toggle VBS & Memory Integrity (Enable / Disable)" -ForegroundColor White
        Write-Host "  [W] [*] Windows Hello / PIN Fix & Management Options" -ForegroundColor Cyan
        Write-Host "  [C] [!] Stop Vanguard & Overlay Conflicts (MSI/RTSS)" -ForegroundColor Yellow
        Write-Host "  [S] [[D]] Download & Launch Steam Unlock (SUO)" -ForegroundColor Cyan
        Write-Host "  [X] [[R]] Revert to Default (Safe Mode for Valorant/Faceit)" -ForegroundColor Magenta
        Write-Host "  [H] [?] Open Tutorial & Video Guide" -ForegroundColor Yellow
        Write-Host "  [D] [+] Whitelist Folder in Windows Defender" -ForegroundColor White
        Write-Host "  [R] [S] Create System Restore Point" -ForegroundColor White
        Write-Host "  [G] [M] Switch back to GUI Dashboard" -ForegroundColor Cyan
        Write-Host "  [Q] [X] Exit" -ForegroundColor Gray
        Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "Select option"
        if ([string]::IsNullOrWhiteSpace($choice)) { continue }
        switch ($choice.Trim().ToUpper()) {
            "A" {
                if (-not (Confirm-WindowsHelloPreFlightCli)) { continue }
                Write-Host "[*] Running Easy Setup in background..." -ForegroundColor Cyan
                Suspend-BitLockerSafety
                Set-VBSAndHVCIStatus -Enable $false | Out-Null
                Add-DefenderExclusion
                Set-TestingModeStatus -Enable $true | Out-Null
                Write-Host "[OK] Easy Setup complete! Please restart your PC." -ForegroundColor Green
                if ($st.SecureBoot) {
                    Write-Host "[i] Note: Secure Boot is enabled in BIOS (Optional for modern SUO)." -ForegroundColor Cyan
                }
                Start-Sleep -Seconds 2
            }
            "B" { Restart-DirectToUEFI }
            "T" {
                if ($st.TestOn) {
                    Set-TestingModeStatus -Enable $false | Out-Null
                    Write-Host "[OK] Testing Mode turned OFF in BCD. Restart PC to apply." -ForegroundColor Green
                    Write-ActionLog "Testing Mode: OFF"
                } else {
                    if ($st.SecureBoot) {
                        Write-Host "[i] Secure Boot is ENABLED in BIOS." -ForegroundColor Yellow
                        Write-Host "    Modern SUO works with Secure Boot enabled as long as VBS/HVCI is off." -ForegroundColor Cyan
                    }
                    Set-TestingModeStatus -Enable $true | Out-Null
                    Write-Host "[OK] Testing Mode turned ON in BCD. Restart PC to apply." -ForegroundColor Green
                    Write-ActionLog "Testing Mode: ON"
                }
                Start-Sleep -Seconds 2
            }
            "V" {
                $newVbs = -not ($st.VBS -or $st.HVCI)
                if (-not $newVbs) {
                    if (-not (Confirm-WindowsHelloPreFlightCli)) { continue }
                }
                Set-VBSAndHVCIStatus -Enable $newVbs | Out-Null
                $stStr = if ($newVbs) { "Enabled" } else { "Disabled" }
                Write-Host "VBS & HVCI $stStr. Restart PC to apply." -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
            "W" { Show-WindowsHelloCliMenu; Start-Sleep -Seconds 1 }
            "S" { Start-SuoDownloaderWorkflow; Start-Sleep -Seconds 2 }
            "X" { Revert-ToSafeMode; Start-Sleep -Seconds 2 }
            "H" { Show-TutorialGuideDialog }
            "D" { Add-DefenderExclusion; Start-Sleep -Seconds 2 }
            "R" { New-SystemRestorePoint -Mode 'CLI'; Start-Sleep -Seconds 2 }
            "G" {
                $Script:NextMode = "GUI"
                return
            }
            "Q" { $Script:NextMode = "Exit"; return }
        }
    }
}

# --- Application Startup ---

while ($Script:NextMode -ne "Exit") {
    if ($Script:NextMode -eq "GUI") {
        Hide-ToolConsole
        try {
            Start-GuiMode
        } catch {
            Show-ToolConsole
            Write-Host "GUI encountered an issue: $_" -ForegroundColor Red
            Write-Host "Switching to CLI Mode..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $Script:NextMode = "CLI"
        }
    }
    if ($Script:NextMode -eq "CLI") {
        Show-ToolConsole
        Start-CliMode
    }
}

Show-ToolConsole
Write-Host "Exiting HV Bypass Tool v$SCRIPT_VERSION..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 500
