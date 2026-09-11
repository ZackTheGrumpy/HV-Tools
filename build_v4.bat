@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo       Building Tools V4.0.exe (Modernized Edition)
echo ========================================================
echo.

set "CSC_EXE="
if exist "%windir%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" (
    set "CSC_EXE=%windir%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
) else if exist "%windir%\Microsoft.NET\Framework\v4.0.30319\csc.exe" (
    set "CSC_EXE=%windir%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

if "%CSC_EXE%"=="" (
    echo [ERROR] .NET Framework C# Compiler csc.exe was not found.
    pause
    exit /b 1
)

echo [*] Using compiler: %CSC_EXE%
echo [*] Embedding payload: Tools V4.0.ps1
echo [*] Applying icon: SUO_tools.ico
echo [*] Applying UAC manifest: build\app.manifest
echo.

echo [*] Compiling Tools V4.0.3.exe...
"%CSC_EXE%" /nologo /target:exe /optimize+ /out:"Tools V4.0.3.exe" "/res:Tools V4.0.ps1,ToolsV4.ps1" /win32icon:"SUO_tools.ico" /win32manifest:"build\app.manifest" "build\Program.cs"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Compilation failed!
    pause
    exit /b %errorlevel%
)

echo [*] Updating Tools V4.0.exe...
copy /y "Tools V4.0.3.exe" "Tools V4.0.exe" >nul 2>&1
if %errorlevel% neq 0 (
    echo [NOTE] Tools V4.0.exe is currently running by another process; Tools V4.0.3.exe was updated.
) else (
    echo [*] Tools V4.0.exe updated successfully.
)

echo.
echo [SUCCESS] Tools V4.0.3.exe built successfully!
echo.
pause
