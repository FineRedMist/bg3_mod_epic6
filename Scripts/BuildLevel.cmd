@echo off 
setlocal

REM From https://github.com/ShinyHobo/BG3-Modders-Multitool/wiki/Command-Line-Interface
SET BG3TOOL=D:\GitHub\frm\BG3_E6\bg3-modders-multitool\bg3-modders-multitool.exe
SET LEVEL=%1
if "%1"=="" (
    echo Usage: BuildLevel.cmd [level]
    echo Example: BuildLevel.cmd 6
    exit /b 1
)

SET OVERRIDE_DIR=%~dp0..\LevelOverrides\%LEVEL%
if not exist "%OVERRIDE_DIR%" (
    echo Override directory %OVERRIDE_DIR% does not exist.
    exit /b 1
)

SET TARGET_NAME=DnD-Epic%LEVEL%
SET GENERATED_DIR=%~dp0..\.Generated\%TARGET_NAME%
rmdir /s /q "%GENERATED_DIR%"

robocopy /mir /np "%~dp0..\DnD-EpicBase" "%GENERATED_DIR%"
REM Do it twice. If no changes, the exit code is zero.
robocopy /mir /np "%~dp0..\DnD-EpicBase" "%GENERATED_DIR%"
SET ERRCODE=%ERRORLEVEL%
if NOT "%ERRCODE%"=="0" (
    echo Failed to copy files to target directory: %ERRCODE%
    exit /b 1
)

echo Copying override files from %OVERRIDE_DIR% to %GENERATED_DIR%...
xcopy /dyfrs "%OVERRIDE_DIR%\*" "%GENERATED_DIR%\"
SET ERRCODE=%ERRORLEVEL%
if NOT "%ERRCODE%"=="0" (
    echo Failed to copy override files: %ERRCODE%
    exit /b 1
)

SET /P VERSION=<%~dp0..\Version.ver
if NOT "%ERRCODE%"=="0" (
    echo Version file is empty or not found: %ERRCODE%
    exit /b 1
)

echo Renaming files...
powershell RenameFiles.ps1 "%GENERATED_DIR%" "DnD-EpicBase" "%TARGET_NAME%"

echo Transforming files...

echo Building %TARGET_NAME% with version %VERSION%...

SET BG3MODFILE="%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\%TARGET_NAME%.pak"

del /q %BG3MODFILE%
del /q "%GENERATED_DIR%.zip"

REM start /wait "Building %TARGET_NAME% pak file for installed game..." "%BG3TOOL%" -s "%GENERATED_DIR%" -d %BG3MODFILE% -v %VERSION% -c 2
REM start /wait "Building %TARGET_NAME% zip file..." "%BG3TOOL%" -s "%GENERATED_DIR%" -d "%GENERATED_DIR%.zip" -v %VERSION% -c 2
