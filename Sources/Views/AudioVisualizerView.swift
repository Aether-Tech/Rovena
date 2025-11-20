import SwiftUI
import Combine

struct AudioVisualizerView: View {
    var levels: [Float]
    var spacing: CGFloat = 4
    var color: Color = DesignSystem.accent
    
    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: CGFloat(levels[index]) * 30)
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
    }
}
