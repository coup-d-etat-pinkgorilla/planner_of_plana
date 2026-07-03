@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3.11 -m tools.template_alignment_studio %*
) else (
    python -m tools.template_alignment_studio %*
)

if errorlevel 1 (
    echo.
    echo Failed to run template_alignment_studio.py.
    pause
)
