# Phase 5 – Net Worth & Analytics Polish

## Objectives
1. Enhance net-worth analytics (multi-month charts, breakdowns, annotations) and export capability.
2. Provide customizable dashboard widgets/history views.
3. Improve resiliency: data export/import, backup/restore, performance tuning.

## Scope
- Net-worth history detail: range filters, core/tangible/volatile overlays, annotations per snapshot.
- Exports: CSV for wallets/transactions/budgets/net-worth snapshots; JSON backup/restore.
- Settings: advanced options (already added notification toggle) plus export/import UI.

## Implementation Checklist
1. Net worth history screens & charts.
2. CSV export service and share sheet integration.
3. Backup/restore workflow.
4. Performance profiling & improvements.
5. QA/testing plan updates.

## Risks
- Export privacy; mitigate with explicit confirmation and share sheet only.
- Large data loads; stream CSV writing.
- Import conflicts; warn users and provide merge instructions.

## QA Checklist
1. Exercise each net-worth range (3M/6M/1Y/All) and verify toggling overlays redraws the chart and annotations remain attached to the correct snapshots.
2. Add/edit snapshot notes from the analytics view and confirm they persist after relaunch.
3. Export every CSV type plus the full JSON backup, share the files, and spot-check their headers/content.
4. Import a freshly exported backup, confirm no duplicates are created, and make sure wallets/budgets/goals/net-worth charts refresh immediately.
5. Reorder and hide dashboard widgets, then relaunch the app to ensure the customized order persists on the home view.
