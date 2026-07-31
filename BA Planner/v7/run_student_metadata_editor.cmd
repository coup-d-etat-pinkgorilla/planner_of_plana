@echo off
setlocal
cd /d "%~dp0"
set "BA_PLANNER_BACKEND_DIR=%CD%\backend"
if exist "release\developer_tools\ba_planner_v7.exe" (
  start "" "release\developer_tools\ba_planner_v7.exe" --tool=student-metadata --backend-dir="%BA_PLANNER_BACKEND_DIR%"
) else (
  pushd frontend
  flutter run -d windows -t lib/developer_tools_main.dart --dart-entrypoint-args=--tool=student-metadata
  popd
)
