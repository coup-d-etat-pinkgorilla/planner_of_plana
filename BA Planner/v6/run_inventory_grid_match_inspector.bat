@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3.11 -m tools.inventory_grid_match_inspector %*
) else (
    python -m tools.inventory_grid_match_inspector %*
)

if errorlevel 1 (
    echo.
    echo Failed to run inventory_grid_match_inspector.py.
    pause
)

