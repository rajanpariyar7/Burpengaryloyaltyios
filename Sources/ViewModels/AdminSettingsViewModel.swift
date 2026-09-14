import Foundation

@MainActor
final class AdminSettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var isLoading = false
    @Published var statusMessage: String?

    func load() async {
        isLoading = true
        do {
            settings = try await FirestoreService.shared.fetchSettings()
        } catch {
            statusMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        isLoading = true
        statusMessage = nil
        do {
            try await FirestoreService.shared.updateSettings(settings)
            statusMessage = "Settings saved."
        } catch {
            statusMessage = error.localizedDescription
        }
        isLoading = false
    }
}
