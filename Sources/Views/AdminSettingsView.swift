import SwiftUI

struct AdminSettingsView: View {
    @StateObject private var viewModel = AdminSettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Cashier login") {
                    Toggle("Cashier login enabled", isOn: $viewModel.settings.cashierLoginEnabled)

                    if viewModel.settings.cashierLoginEnabled {
                        DatePicker(
                            "Login window start",
                            selection: timeBinding(for: \.cashierLoginStartTime),
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "Login window end",
                            selection: timeBinding(for: \.cashierLoginEndTime),
                            displayedComponents: .hourAndMinute
                        )
                        Text("Cashier accounts can only sign in between these times (store-local time). Admin and Super Admin logins are never restricted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("All cashier accounts are currently locked out, regardless of time.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Loyalty engine") {
                    Toggle("Allow Admin to edit point rules", isOn: $viewModel.settings.adminWriteEnabled)
                    Stepper("Points per $1 spent: \(viewModel.settings.pointsPerDollar)",
                            value: $viewModel.settings.pointsPerDollar, in: 1...100)
                    Stepper("Minimum points to redeem: \(viewModel.settings.redemptionThreshold)",
                            value: $viewModel.settings.redemptionThreshold, in: 0...5000, step: 10)
                }

                if let status = viewModel.statusMessage {
                    Section {
                        Text(status).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Save settings") {
                        Task { await viewModel.save() }
                    }
                }
            }
            .navigationTitle("Admin Settings")
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
            .task { await viewModel.load() }
        }
    }

    /// Bridges the "HH:mm" strings stored in Firestore to a DatePicker, which
    /// needs a Date. Only the hour/minute components are ever read or written.
    private func timeBinding(for keyPath: WritableKeyPath<AppSettings, String>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: viewModel.settings[keyPath: keyPath]) ?? Date()
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                viewModel.settings[keyPath: keyPath] = formatter.string(from: newDate)
            }
        )
    }
}
