@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3.11 -m tools.ui_component_studio_quick %*
) else (
    python -m tools.ui_component_studio_quick %*
)

if errorlevel 1 (
    echo.
    echo Failed to run ui_component_studio.py.
    pause
)
