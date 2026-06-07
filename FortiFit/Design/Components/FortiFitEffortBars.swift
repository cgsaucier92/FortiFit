import SwiftUI

struct FortiFitEffortBars: View {
    let rpe: Int
    var size: CGFloat = 16

    private static let barCount = 5
    private static let heightFractions: [CGFloat] = [0.40, 0.55, 0.70, 0.85, 1.00]

    static func litBarCount(forRPE rpe: Int) -> Int {
        switch rpe {
        case 1, 2: return 1
        case 3, 4: return 2
        case 5, 6: return 3
        case 7, 8: return 4
        case 9, 10: return 5
        default: return 0
        }
    }

    private var litCount: Int { Self.litBarCount(forRPE: rpe) }
    private var litColor: Color { AppConstants.effortColor(for: rpe) }
    private var unlitColor: Color { FortiFitColors.mutedText.opacity(0.25) }

    private var barWidth: CGFloat { max(2, size * 0.18) }
    private var spacing: CGFloat { max(1.5, size * 0.10) }

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                Capsule()
                    .fill(index < litCount ? litColor : unlitColor)
                    .frame(width: barWidth, height: size * Self.heightFractions[index])
            }
        }
        .frame(height: size, alignment: .bottom)
    }
}
