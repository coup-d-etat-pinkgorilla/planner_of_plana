---
title: "Standalone Developer Tools"
summary: "The v7 metadata editor, template extractor, and grid match inspector use Flutter windows backed by short-lived Python processes."
topics: [architecture, migration]
sources:
  - id: migration-note
    type: file
    path: docs/migration/developer-tools-migration.md
  - id: flutter-entry
    type: file
    path: frontend/lib/developer_tools_main.dart
  - id: python-entry
    type: file
    path: backend/tools/developer_tools.py
---

# Standalone Developer Tools

The student metadata editor, student template extractor, and inventory grid
match inspector are independent Flutter Windows processes. A required `--tool`
mode selects the surface. Each operation starts the Python developer-tool
backend, sends one protocol-v1 JSON request through stdin, reads one JSON
response from stdout, and lets the process exit. [@flutter-entry] [@python-entry]

The tools use v7 generated metadata and recognition assets directly. Template
extraction updates both the PNG and its recognition manifest integrity fields.
Grid inspection is read-only and uses the production v7 template matcher and
packaged region catalog. No v6 module and no Qt/Tk presentation code is a v7
runtime dependency. [@migration-note] [@python-entry]

The root `.cmd` launchers prefer `release/developer_tools/ba_planner_v7.exe`
and fall back to `flutter run` during development. Each launcher starts a new
OS process, so closing a tool cannot close the main Planner UI process.
