# Smartwatch Companion — Specialized Agents

This directory contains the definitions and workflows for 7 specialized AI agents designed to build a premium Flutter companion app for an ESP32-C3 smartwatch.

## 🚀 Execution Sequence

To build the app correctly according to FSD v1.0, run the following workflows in order:

1.  **[Step 1-Project Setup](workflows/step-1-project-setup.md)**: Foundation, theme, constants.
2.  **[Step 2-Wallpaper Studio](workflows/step-2-wallpaper-studio.md)**: Image engine, converter, presets. (Can be done offline)
3.  **[Step 3-BLE Service](workflows/step-3-ble-service.md)**: Connectivity, scanning, status.
4.  **[Step 4-Time Sync](workflows/step-4-time-sync.md)**: Binary protocol, auto-sync.
5.  **[Step 5-Dashboard & Data](workflows/step-5-dashboard-data.md)**: Live telemetry, heart rate, battery.
6.  **[Step 6-Settings & Integration](workflows/step-6-settings-integration.md)**: Preferences, final polish.

---

## 🛡️ Audit & QA

- **[Reviewer / Debugger Agent](workflows/reviewer-debugger-agent.md)**: Run this at any time or as a final check to audit theme consistency, logic, and BLE stability.

## 🛠️ Design Philosophy

- **Dark-first**: `bgPrimary = Color(0xFF0D0D14)`.
- **Inter Font**: Tabular figures for clocks.
- **Micro-animations**: `flutter_animate` for a premium feel.
- **Offline Reliability**: Conversion and Data Caching are key.
