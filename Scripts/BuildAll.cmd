@echo off

for /d %%I in (%~dp0..\LevelOverrides\*) do (
    echo Building %%~nxI...
    if exist "%%I\Transform.json" (
        call "%~dp0BuildLevel.cmd" %%~nxI
        if errorlevel 1 (
            echo Failed to build %%~nxI
            exit /b 1
        )
    )
)