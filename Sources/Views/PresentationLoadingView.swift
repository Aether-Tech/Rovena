import SwiftUI

struct PresentationLoadingView: View {
    @ObservedObject var presentationService: PresentationService
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .stroke(DesignSystem.accent.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(DesignSystem.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.accent)
            }
            
            VStack(spacing: 12) {
                Text("Generating Presentation")
                    .font(DesignSystem.font(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.text)
                
                Text(presentationService.currentStep)
                    .font(DesignSystem.font(size: 16))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: presentationService.generationProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 400)
                
                Text("\(Int(presentationService.generationProgress * 100))%")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.5))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .onAppear {
            rotationAngle = 360
        }
    }
}

