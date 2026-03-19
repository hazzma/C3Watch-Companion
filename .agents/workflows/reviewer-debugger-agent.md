---
description: Run the Reviewer / Debugger Agent to audit the codebase for consistent theme, binary logic, and BLE stability.
---

1.  Review the codebase structure for adherence to FSD Section 5.
2.  Check for any hardcoded hex colors (all should be in `AppColors`).
3.  Analyze BLE logic for proper stream management (cancelling subscriptions).
4.  Verify the XOR checksum logic in `time_sync.dart`.
5.  Audit the Isolate implementation in `rgb565_converter.dart`.
6.  Perform a final UI pass for staggered animations and responsive layouts.
7.  Check for error states and edge cases (BLE off, permission denied).

// turbo
8. Generate a "Final Audit Report" summarizing findings.
9. Propose fixes for any CRITICAL or UI inconsistency issues.
10. Final sign-off on the FSD Success Criteria (Section 11).
