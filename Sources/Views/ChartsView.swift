import SwiftUI

struct ChartsView: View {
    @ObservedObject var chartService = ChartService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Charts")
                        .font(DesignSystem.font(size: 32, weight: .bold))
                        .foregroundColor(DesignSystem.text)
                    
                    Text("Create and manage data visualizations. Use @graficoX in presentations to include your charts.")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Chart Generator
                ChartGeneratorView()
                    .padding(.horizontal)
                
                // Stats
                if !chartService.charts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(DesignSystem.font(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.text)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            ChartStatCard(
                                title: "Total Charts",
                                value: "\(chartService.charts.count)",
                                icon: "chart.bar.fill"
                            )
                            
                            ChartStatCard(
                                title: "Bar Charts",
                                value: "\(chartService.charts.filter { $0.chartType == .bar }.count)",
                                icon: "chart.bar.xaxis"
                            )
                            
                            ChartStatCard(
                                title: "Line Charts",
                                value: "\(chartService.charts.filter { $0.chartType == .line }.count)",
                                icon: "chart.xyaxis.line"
                            )
                            
                            ChartStatCard(
                                title: "Pie Charts",
                                value: "\(chartService.charts.filter { $0.chartType == .pie }.count)",
                                icon: "chart.pie.fill"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(DesignSystem.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chart Stat Card

struct ChartStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.accent)
                Spacer()
            }
            
            Text(value)
                .font(DesignSystem.font(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.text)
            
            Text(title)
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface)
        .clipShape(SquircleShape())
        .overlay(
            SquircleShape()
                .stroke(DesignSystem.border.opacity(0.3), lineWidth: 1)
        )
    }
}

