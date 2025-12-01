import SwiftUI
import Charts

struct ChartPreviewCard: View {
    let chart: GeneratedChart
    
    private var displayPoints: [ChartDataPoint] {
        chart.dataPoints
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chart.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if !chart.description.isEmpty {
                Text(chart.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Chart(displayPoints) { point in
                switch chart.chartType {
                case .bar:
                    BarMark(
                        x: .value("Valor", point.value),
                        y: .value("Categoria", point.label)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                case .line:
                    LineMark(
                        x: .value("Categoria", point.label),
                        y: .value("Valor", point.value)
                    )
                    .lineStyle(.init(lineWidth: 3, lineCap: .round))
                    .symbol(.circle)
                    .interpolationMethod(.catmullRom)
                case .area:
                    AreaMark(
                        x: .value("Categoria", point.label),
                        y: .value("Valor", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                case .pie:
                    SectorMark(
                        angle: .value("Valor", point.value),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Categoria", point.label))
                }
            }
            .chartYAxisLabel(chart.unit.isEmpty ? "Valor" : chart.unit)
            .chartLegend(chart.chartType == .pie ? .visible : .hidden)
            .padding(.top, 8)
            .frame(maxHeight: .infinity)
            
            Divider()
            
            HStack {
                Text("Use \(chart.mentionToken) nos slides para inserir o gráfico")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}



