import SwiftUI
import PhotosUI

// Admin + Cashier screen: "Offers: offers collection, sales, promotion ...
// cashiers can add items, category". A "special" (like the Wednesday/Weekend
// Special flyers) is just an Offer with category "Special" and an uploaded
// image — no separate schema needed.
struct AdminOffersView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var showEditor = false
    @State private var editingOffer: Offer?

    private var isCashier: Bool { viewModel.currentUser?.role == .cashier }

    private let categories = ["General", "Special", "Produce", "Grocery", "Bakery", "Drinks"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0).ignoresSafeArea()

                if viewModel.offers.isEmpty {
                    Text("No offers yet. Tap + to add one.")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.offers) { offer in
                                offerRow(offer)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Offers & Specials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingOffer = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppColors.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                OfferEditorSheet(viewModel: viewModel, offer: editingOffer, categories: categories)
            }
        }
    }

    private func offerRow(_ offer: Offer) -> some View {
        HStack(spacing: 12) {
            AsyncImageOrPlaceholder(urlString: offer.imageUrl)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(offer.title).font(.system(size: 15, weight: .bold)).foregroundColor(AppColors.darkGreen)
                Text("\(offer.category) • \(offer.price)").font(.system(size: 12)).foregroundColor(.gray)
            }
            Spacer()

            if !isCashier {
                Menu {
                    Button("Edit") { editingOffer = offer; showEditor = true }
                    Button("Delete", role: .destructive) { viewModel.deleteOffer(offer) }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

private struct OfferEditorSheet: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss

    let offer: Offer?
    let categories: [String]

    @State private var title: String
    @State private var price: String
    @State private var description: String
    @State private var category: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false

    init(viewModel: LoyaltyViewModel, offer: Offer?, categories: [String]) {
        self.viewModel = viewModel
        self.offer = offer
        self.categories = categories
        _title = State(initialValue: offer?.title ?? "")
        _price = State(initialValue: offer?.price ?? "")
        _description = State(initialValue: offer?.description ?? "")
        _category = State(initialValue: offer?.category ?? categories.first ?? "General")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title (e.g. Cabbage)", text: $title)
                    TextField("Price (e.g. 89¢ each, $1.99 per kg)", text: $price)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Image") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(selectedImageData != nil ? "Change image" : "Upload flyer / photo")
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
                        Image(uiImage: uiImage).resizable().scaledToFit().frame(height: 160)
                    } else if let existingUrl = offer?.imageUrl, let url = URL(string: existingUrl) {
                        AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.1) }
                            .frame(height: 160)
                    }
                }
            }
            .navigationTitle(offer == nil ? "New Offer" : "Edit Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(title.isEmpty || price.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        var toSave = offer ?? Offer()
        toSave.title = title
        toSave.price = price
        toSave.description = description
        toSave.category = category

        Task {
            await viewModel.saveOffer(toSave, imageData: selectedImageData)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

struct AsyncImageOrPlaceholder: View {
    let urlString: String?

    var body: some View {
        if let urlString = urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xD4/255.0).opacity(0.5)
            }
        } else {
            ZStack {
                Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xD4/255.0).opacity(0.5)
                Image(systemName: "photo").foregroundColor(AppColors.primaryGreen)
            }
        }
    }
}
