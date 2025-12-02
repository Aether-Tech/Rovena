import SwiftUI

struct PresentationLoadingView: View {
    @ObservedObject var presentationService: PresentationService
    @State private var rotationAngle: Double = 0
    @State private var showCancelAlert = false
    
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
                
                Text(presentationService.currentStep.isEmpty ? "Preparing..." : presentationService.currentStep)
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
            
            // Cancel button
            Button(action: {
                showCancelAlert = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel")
                }
                .font(DesignSystem.font(size: 14))
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .clipShape(SquircleShape())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .onAppear {
            rotationAngle = 360
        }
        .alert("Cancel Generation?", isPresented: $showCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                cancelGeneration()
            }
        } message: {
            Text("Are you sure you want to cancel the presentation generation? This action cannot be undone.")
        }
    }
    
    private func cancelGeneration() {
        LogManager.shared.addLog("User cancelled presentation generation", level: .info, category: "PresentationLoadingView")
        presentationService.isGenerating = false
        presentationService.generationProgress = 0.0
        presentationService.currentStep = ""
    }
}

