import SwiftUI
import PhotosUI

// "admin can add, modify or delete the notifications sent with uploading
// option with text content" — e.g. a "Wednesday Special" or "Weekend
// Special" announcement with a flyer image attached.
//
// Writing here queues the notification (Firestore doc). Actual delivery to
// devices happens via the Cloud Function in functions/index.js — see that
// file's header comment for why this can't be done directly from the app.
struct AdminNotificationsView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var showComposer = false
    @State private var editingNotification: AppNotification?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0).ignoresSafeArea()

                if viewModel.notifications.isEmpty {
                    Text("No notifications yet. Tap + to announce a special.")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.notifications) { note in
                                notificationRow(note)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingNotification = nil
                        showComposer = true
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(AppColors.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showComposer) {
                NotificationComposerSheet(viewModel: viewModel, notification: editingNotification)
            }
        }
    }

    private func notificationRow(_ note: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImageOrPlaceholder(urlString: note.imageUrl)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(note.title).font(.system(size: 15, weight: .bold)).foregroundColor(AppColors.darkGreen)
                    Text(note.sent ? "Sent" : "Pending")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(note.sent ? AppColors.primaryGreen : Color.orange)
                        .cornerRadius(6)
                }
                Text(note.message).font(.system(size: 12)).foregroundColor(.gray).lineLimit(2)
            }
            Spacer()

            Menu {
                Button("Edit") { editingNotification = note; showComposer = true }
                Button("Delete", role: .destructive) { viewModel.deleteNotification(note) }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

private struct NotificationComposerSheet: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss

    let notification: AppNotification?

    @State private var title: String
    @State private var message: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false

    init(viewModel: LoyaltyViewModel, notification: AppNotification?) {
        self.viewModel = viewModel
        self.notification = notification
        _title = State(initialValue: notification?.title ?? "")
        _message = State(initialValue: notification?.message ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Announcement") {
                    TextField("Title (e.g. Wednesday Special)", text: $title)
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Flyer Image (optional)") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(selectedImageData != nil ? "Change image" : "Upload flyer")
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage).resizable().scaledToFit().frame(height: 200)
                    } else if let existingUrl = notification?.imageUrl, let url = URL(string: existingUrl) {
                        AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.1) }
                            .frame(height: 200)
                    }
                }
            }
            .navigationTitle(notification == nil ? "New Notification" : "Edit Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(title.isEmpty || message.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        var toSave = notification ?? AppNotification()
        toSave.title = title
        toSave.message = message

        Task {
            await viewModel.saveNotification(toSave, imageData: selectedImageData)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
