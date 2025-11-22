import SwiftUI

struct DashboardPreferencesView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var visibleWidgets: [DashboardWidget] = DashboardWidget.defaultOrder
    @State private var hasLoaded = false

    var body: some View {
        List {
            Section("Visible Widgets") {
                if visibleWidgets.isEmpty {
                    Text("No widgets pinned. Use the section below to add them back.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(visibleWidgets.enumerated()), id: \.element.id) { _, widget in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(widget.title, systemImage: widget.iconName)
                            Text(widget.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }

            Section("Add Widgets") {
                if hiddenWidgets.isEmpty {
                    Text("All widgets are currently visible.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hiddenWidgets) { widget in
                        Button(action: { add(widget) }) {
                            Label("Add \(widget.title)", systemImage: "plus")
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!hasChanges)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, .constant(.active))
        .onAppear(perform: sync)
    }

    private var hiddenWidgets: [DashboardWidget] {
        DashboardWidget.allCases.filter { widget in
            !visibleWidgets.contains(widget)
        }
    }

    private var hasChanges: Bool {
        visibleWidgets != appSettingsStore.snapshot.dashboardWidgets
    }

    private func sync() {
        guard !hasLoaded else { return }
        visibleWidgets = appSettingsStore.snapshot.dashboardWidgets
        hasLoaded = true
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        visibleWidgets.move(fromOffsets: offsets, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        visibleWidgets.remove(atOffsets: offsets)
    }

    private func add(_ widget: DashboardWidget) {
        guard !visibleWidgets.contains(widget) else { return }
        visibleWidgets.append(widget)
    }

    private func save() {
        appSettingsStore.updateDashboardWidgets(visibleWidgets)
        dismiss()
    }
}
