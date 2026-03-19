---
description: Run the Dashboard & Data Agent to build the Home and Watch Data screens.
---

1.  Set up the `watch_data_provider.dart` for handling incoming BLE telemetry.
2.  Develop the "Home" dashboard with big clock and 2x2 grid.
3.  Develop the "Watch Data" screen for more details (HR tab and Steps tab).
4.  Implement the pulsating EKG animation for HR and circular progress for Steps.
5.  Use `flutter_animate` for staggered fade-in animations (FSD 9.1).
6.  Ensure data caching exists for offline states ("Last known").

// turbo
7. Verify notification subscriptions for all characteristics (HR, Steps, Batt).
8. Test animations for smoothness (no frame drops).
9. Confirm values update in real-time on screen as data arrives.
