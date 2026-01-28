@echo off
setlocal EnableDelayedExpansion
title KIF Redux Installer/Updater
color 0A

echo ============================================================
echo               KIF REDUX INSTALLER / UPDATER
echo ============================================================
echo:

echo [1/7] Extracting portable Git...
.\REQUIRED_BY_INSTALLER_UPDATER\7z.exe e -spf -aoa "REQUIRED_BY_INSTALLER_UPDATER\MinGit.7z" > nul
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to extract Git. Make sure REQUIRED_BY_INSTALLER_UPDATER folder exists.
    pause
    exit /b 1
)
echo       Done!
echo:

set mgit=".\REQUIRED_BY_INSTALLER_UPDATER\cmd\git.exe"

echo [2/7] Initializing local repository...
%mgit% init . > nul 2>&1
echo       Done!
echo:

echo [3/7] Connecting to GitHub repository...
%mgit% remote remove origin > nul 2>&1
%mgit% remote add origin "https://github.com/Stonewallx/KIF-Redux.git"
echo       Connected to: github.com/Stonewallx/KIF-Redux
echo:

echo [4/7] Checking for updates...
echo       Contacting GitHub server...
%mgit% fetch origin main --progress
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to fetch from GitHub. Check your internet connection.
    pause
    exit /b 1
)
echo       Fetch complete!
echo:

REM Get local version (if exists)
set "LOCAL_VERSION=Not Installed"
if exist "Data\VERSION-KIFR" (
    set /p LOCAL_VERSION=<"Data\VERSION-KIFR"
)

REM Get remote version
%mgit% show origin/main:Data/VERSION-KIFR > "%TEMP%\kifr_remote_version.txt" 2>nul
set "REMOTE_VERSION=unknown"
if exist "%TEMP%\kifr_remote_version.txt" (
    set /p REMOTE_VERSION=<"%TEMP%\kifr_remote_version.txt"
    del "%TEMP%\kifr_remote_version.txt" > nul 2>&1
)

echo [5/7] Comparing versions...
echo       -------------------------------------
echo       Local version:  %LOCAL_VERSION%
echo       Remote version: %REMOTE_VERSION%
echo       -------------------------------------
echo:

REM Compare versions
if "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    color 0B
    echo ============================================================
    echo:
    echo   ALREADY UP TO DATE!
    echo:
    echo   Your KIF Redux is running the latest version: %LOCAL_VERSION%
    echo:
    echo   You can now close this window.
    echo:
    echo ============================================================
    pause
    exit /b 0
)

echo [6/7] Downloading and applying updates...
echo       Updating from %LOCAL_VERSION% to %REMOTE_VERSION%
echo:
echo       Applying changes...
%mgit% checkout origin/main -- .
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to apply updates.
    pause
    exit /b 1
)
echo       Files updated successfully!
echo:

echo [7/7] Cleaning up...
echo       Done!
echo:

color 0B
echo ============================================================
echo:
if "%LOCAL_VERSION%"=="Not Installed" (
    echo   SUCCESS! KIF Redux has been installed!
    echo:
    echo   Installed version: %REMOTE_VERSION%
) else (
    echo   SUCCESS! KIF Redux has been updated!
    echo:
    echo   Previous version: %LOCAL_VERSION%
    echo   New version:      %REMOTE_VERSION%
)
echo:
echo   - All game files have been downloaded
echo   - Your save files and custom content are untouched
echo:
echo   You can now close this window and play!
echo:
echo ============================================================

pause@echo off
setlocal EnableDelayedExpansion
title KIF Redux Installer/Updater
color 0A

echo ============================================================
echo               KIF REDUX INSTALLER / UPDATER
echo ============================================================
echo:

echo [1/7] Extracting portable Git...
.\REQUIRED_BY_INSTALLER_UPDATER\7z.exe e -spf -aoa "REQUIRED_BY_INSTALLER_UPDATER\MinGit.7z" > nul
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to extract Git. Make sure REQUIRED_BY_INSTALLER_UPDATER folder exists.
    pause
    exit /b 1
)
echo       Done!
echo:

set mgit=".\REQUIRED_BY_INSTALLER_UPDATER\cmd\git.exe"

echo [2/7] Initializing local repository...
%mgit% init . > nul 2>&1
echo       Done!
echo:

echo [3/7] Connecting to GitHub repository...
%mgit% remote remove origin > nul 2>&1
%mgit% remote add origin "https://github.com/Stonewallx/KIF-Redux.git"
echo       Connected to: github.com/Stonewallx/KIF-Redux
echo:

echo [4/7] Checking for updates...
echo       Contacting GitHub server...
%mgit% fetch origin main --progress
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to fetch from GitHub. Check your internet connection.
    pause
    exit /b 1
)
echo       Fetch complete!
echo:

REM Get local version (if exists)
set "LOCAL_VERSION=Not Installed"
if exist "Data\VERSION-KIFR" (
    set /p LOCAL_VERSION=<"Data\VERSION-KIFR"
)

REM Get remote version
%mgit% show origin/main:Data/VERSION-KIFR > "%TEMP%\kifr_remote_version.txt" 2>nul
set "REMOTE_VERSION=unknown"
if exist "%TEMP%\kifr_remote_version.txt" (
    set /p REMOTE_VERSION=<"%TEMP%\kifr_remote_version.txt"
    del "%TEMP%\kifr_remote_version.txt" > nul 2>&1
)

echo [5/7] Comparing versions...
echo       -------------------------------------
echo       Local version:  %LOCAL_VERSION%
echo       Remote version: %REMOTE_VERSION%
echo       -------------------------------------
echo:

REM Compare versions
if "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    color 0B
    echo ============================================================
    echo:
    echo   ALREADY UP TO DATE!
    echo:
    echo   Your KIF Redux is running the latest version: %LOCAL_VERSION%
    echo:
    echo   You can now close this window.
    echo:
    echo ============================================================
    pause
    exit /b 0
)

echo [6/7] Downloading and applying updates...
echo       Updating from %LOCAL_VERSION% to %REMOTE_VERSION%
echo:
echo       Applying changes...
%mgit% checkout origin/main -- .
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to apply updates.
    pause
    exit /b 1
)
echo       Files updated successfully!
echo:

echo [7/7] Cleaning up...
echo       Done!
echo:

color 0B
echo ============================================================
echo:
if "%LOCAL_VERSION%"=="Not Installed" (
    echo   SUCCESS! KIF Redux has been installed!
    echo:
    echo   Installed version: %REMOTE_VERSION%
) else (
    echo   SUCCESS! KIF Redux has been updated!
    echo:
    echo   Previous version: %LOCAL_VERSION%
    echo   New version:      %REMOTE_VERSION%
)
echo:
echo   - All game files have been downloaded
echo   - Your save files and custom content are untouched
echo:
echo   You can now close this window and play!
echo:
echo ============================================================

pause@echo off
setlocal EnableDelayedExpansion
title KIF Redux Installer/Updater
color 0A

echo ============================================================
echo               KIF REDUX INSTALLER / UPDATER
echo ============================================================
echo:

echo [1/7] Extracting portable Git...
.\REQUIRED_BY_INSTALLER_UPDATER\7z.exe e -spf -aoa "REQUIRED_BY_INSTALLER_UPDATER\MinGit.7z" > nul
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to extract Git. Make sure REQUIRED_BY_INSTALLER_UPDATER folder exists.
    pause
    exit /b 1
)
echo       Done!
echo:

set mgit=".\REQUIRED_BY_INSTALLER_UPDATER\cmd\git.exe"

echo [2/7] Initializing local repository...
%mgit% init . > nul 2>&1
echo       Done!
echo:

echo [3/7] Connecting to GitHub repository...
%mgit% remote remove origin > nul 2>&1
%mgit% remote add origin "https://github.com/Stonewallx/KIF-Redux.git"
echo       Connected to: github.com/Stonewallx/KIF-Redux
echo:

echo [4/7] Checking for updates...
echo       Contacting GitHub server...
%mgit% fetch origin main --progress
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to fetch from GitHub. Check your internet connection.
    pause
    exit /b 1
)
echo       Fetch complete!
echo:

REM Get local version (if exists)
set "LOCAL_VERSION=Not Installed"
if exist "Data\VERSION-KIFR" (
    set /p LOCAL_VERSION=<"Data\VERSION-KIFR"
)

REM Get remote version
%mgit% show origin/main:Data/VERSION-KIFR > "%TEMP%\kifr_remote_version.txt" 2>nul
set "REMOTE_VERSION=unknown"
if exist "%TEMP%\kifr_remote_version.txt" (
    set /p REMOTE_VERSION=<"%TEMP%\kifr_remote_version.txt"
    del "%TEMP%\kifr_remote_version.txt" > nul 2>&1
)

echo [5/7] Comparing versions...
echo       -------------------------------------
echo       Local version:  %LOCAL_VERSION%
echo       Remote version: %REMOTE_VERSION%
echo       -------------------------------------
echo:

REM Compare versions
if "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    color 0B
    echo ============================================================
    echo:
    echo   ALREADY UP TO DATE!
    echo:
    echo   Your KIF Redux is running the latest version: %LOCAL_VERSION%
    echo:
    echo   You can now close this window.
    echo:
    echo ============================================================
    pause
    exit /b 0
)

echo [6/7] Downloading and applying updates...
echo       Updating from %LOCAL_VERSION% to %REMOTE_VERSION%
echo:
echo       Applying changes...
%mgit% checkout origin/main -- .
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to apply updates.
    pause
    exit /b 1
)
echo       Files updated successfully!
echo:

echo [7/7] Cleaning up...
echo       Done!
echo:

color 0B
echo ============================================================
echo:
if "%LOCAL_VERSION%"=="Not Installed" (
    echo   SUCCESS! KIF Redux has been installed!
    echo:
    echo   Installed version: %REMOTE_VERSION%
) else (
    echo   SUCCESS! KIF Redux has been updated!
    echo:
    echo   Previous version: %LOCAL_VERSION%
    echo   New version:      %REMOTE_VERSION%
)
echo:
echo   - All game files have been downloaded
echo   - Your save files and custom content are untouched
echo:
echo   You can now close this window and play!
echo:
echo ============================================================

pause