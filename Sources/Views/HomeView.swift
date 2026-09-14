import SwiftUI

struct HomeView: View {
    let user: AppUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back,")
                            .foregroundStyle(.secondary)
                        Text(user.name)
                            .font(.title).bold()
                    }

                    HStack(spacing: 12) {
                        balanceCard(title: "Stamps", value: "\(user.stamps)", tint: .brown)
                        balanceCard(title: "Points", value: "\(user.points)", tint: .green)
                    }

                    Text("Lifetime stamps earned: \(user.lifetimeStamps)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }

    private func balanceCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
