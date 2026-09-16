import SwiftUI

/// 10 slot loyalty punch card; the final slot is the reward slot.
struct DigitalPunchCard: View {
    let stamps: Int
    var total: Int = 10

    private var isComplete: Bool { stamps >= total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Punch Card")
                    .font(.headline)
                    .foregroundColor(Palette.extraDarkGreen)
                Spacer()
                Text("\(min(stamps, total)) / \(total)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Palette.primaryGreen)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(0..<total, id: \.self) { index in
                    slot(index: index)
                }
            }

            if isComplete {
                Text("Card complete — claim your free reward in store!")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.deepOrange)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.borderSlate))
    }

    @ViewBuilder
    private func slot(index: Int) -> some View {
        let isFilled = index < stamps
        let isRewardSlot = index == total - 1

        ZStack {
            if isFilled {
                Circle().fill(isRewardSlot ? Palette.accentOrange : Palette.primaryGreen)
                Image(systemName: isRewardSlot ? "gift.fill" : "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            } else {
                Circle()
                    .fill(Palette.emptyPunchBg)
                    .overlay(
                        Circle().strokeBorder(
                            isRewardSlot ? Palette.accentOrange : Palette.borderSlate,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                        )
                    )
                if isRewardSlot {
                    Image(systemName: "gift")
                        .foregroundColor(Palette.accentOrange)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .frame(height: 44)
    }
}
