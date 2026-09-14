import SwiftUI

@MainActor
final class StaffToolsViewModel: ObservableObject {
    @Published var lookupEmail = ""
    @Published var foundUser: AppUser?
    @Published var pointsToAdd = ""
    @Published var isLoading = false
    @Published var statusMessage: String?

    func lookup() async {
        guard !lookupEmail.isEmpty else { return }
        isLoading = true
        statusMessage = nil
        do {
            foundUser = try await FirestoreService.shared.lookupUser(email: lookupEmail)
            if foundUser == nil { statusMessage = "No member found with that email." }
        } catch {
            statusMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addStamp() async {
        guard let email = foundUser?.email else { return }
        do {
            try await FirestoreService.shared.addStamp(email: email)
            statusMessage = "Stamp added."
            await lookup()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addPoints() async {
        guard let email = foundUser?.email, let points = Int(pointsToAdd), points > 0 else { return }
        do {
            try await FirestoreService.shared.addPoints(email: email, points: points)
            statusMessage = "\(points) points added."
            pointsToAdd = ""
            await lookup()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

/// Matches the Android app's cashier actions: look up a member by email,
/// award a stamp (purchase punch), or add points directly.
struct StaffToolsView: View {
    @StateObject private var viewModel = StaffToolsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Find a member") {
                    HStack {
                        TextField("Member email", text: $viewModel.lookupEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        Button("Search") {
                            Task { await viewModel.lookup() }
                        }
                        .disabled(viewModel.lookupEmail.isEmpty)
                    }
                }

                if let user = viewModel.foundUser {
                    Section(user.name) {
                        LabeledContent("Stamps", value: "\(user.stamps)")
                        LabeledContent("Points", value: "\(user.points)")

                        Button("Add 1 stamp") {
                            Task { await viewModel.addStamp() }
                        }

                        HStack {
                            TextField("Points to add", text: $viewModel.pointsToAdd)
                                .keyboardType(.numberPad)
                            Button("Add") {
                                Task { await viewModel.addPoints() }
                            }
                            .disabled(Int(viewModel.pointsToAdd) == nil)
                        }
                    }
                }

                if let status = viewModel.statusMessage {
                    Section {
                        Text(status).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Staff Tools")
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
    }
}
