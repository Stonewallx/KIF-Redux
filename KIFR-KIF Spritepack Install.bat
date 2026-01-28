@echo off
title KIF Spritepack Installer/Updater
color 0A

echo ============================================================
echo              KIF SPRITEPACK INSTALLER / UPDATER
echo ============================================================
echo:

echo [1/5] Extracting portable Git...
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

echo [2/5] Initializing local repository...
%mgit% init . > nul 2>&1
echo       Done!
echo:

echo [3/5] Connecting to GitHub repository...
%mgit% remote remove origin > nul 2>&1
%mgit% remote add origin "https://github.com/Stonewallx/KIF-Spritepack.git"
echo       Connected to: github.com/Stonewallx/KIF-Spritepack
echo:

echo [4/5] Downloading latest files from GitHub...
echo       This may take a while depending on your internet speed...
%mgit% fetch origin main
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to fetch from GitHub. Check your internet connection.
    pause
    exit /b 1
)
echo       Download complete!
echo:

echo [5/5] Updating files (keeping your local additions)...
%mgit% checkout origin/main -- . > nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo:
    echo [ERROR] Failed to apply updates.
    pause
    exit /b 1
)
echo       All files updated!
echo:

echo ============================================================
color 0B
echo:
echo   SUCCESS! KIF Spritepack has been installed/updated!
echo:
echo   - Downloaded files have been added/updated
echo:
echo   You can now close this window.
echo:
echo ============================================================

set arg1=%1
if "%arg1%" == "auto" (
    start "" .\Game.exe
) else (
    pause
)