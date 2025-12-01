import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChartGeneratorView: View {
    @ObservedObject var chartService = ChartService.shared
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var unit: String = ""
    @State private var chartType: ChartType = .bar
    @State private var rawData: String = "Janeiro: 120\nFevereiro: 180\nMarço: 240"
    @State private var generationMessage: String = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            generatorForm
            chartList
        }
        .padding()
        .background(DesignSystem.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert(isPresented: $showAlert) {
            Alert(title: Text(generationMessage), dismissButton: .default(Text("Ok")))
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Área de gráficos", systemImage: "chart.pie.fill")
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.8))
                Spacer()
                Button(action: { clearForm() }) {
                    Label("Limpar", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .help("Limpa os campos do formulário")
            }
            Text("Monte datasets rápidos e use @graficoX nos slides para injetar a visualização renderizada.")
                .font(DesignSystem.font(size: 12))
                .foregroundColor(DesignSystem.text.opacity(0.6))
        }
    }
    
    private var generatorForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Título do gráfico", text: $title)
                .textFieldStyle(.roundedBorder)
            
            TextField("Descrição (opcional)", text: $description)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Picker("Tipo", selection: $chartType) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                TextField("Unidade (ex: % ou R$)", text: $unit)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Dados (Categoria:Valor por linha)")
                    .font(DesignSystem.font(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                TextEditor(text: $rawData)
                    .font(DesignSystem.font(size: 12, weight: .regular))
                    .frame(height: 100)
                    .padding(8)
                    .background(DesignSystem.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                    )
            }
            
            Button(action: handleGenerateChart) {
                HStack {
                    if chartService.isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "chart.bar.fill")
                    }
                    Text(chartService.isGenerating ? "Gerando..." : "Gerar gráfico")
                }
                .font(DesignSystem.font(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(chartService.isGenerating ? Color.gray : DesignSystem.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(chartService.isGenerating)
        }
    }
    
    private var chartList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meus gráficos (\(chartService.charts.count))")
                    .font(DesignSystem.font(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                Spacer()
            }
            
            if chartService.charts.isEmpty {
                Text("Nenhum gráfico salvo ainda. Crie o primeiro acima.")
                    .font(DesignSystem.font(size: 12))
                    .foregroundColor(DesignSystem.text.opacity(0.5))
            } else {
                ForEach(chartService.charts) { chart in
                    chartRow(chart)
                }
            }
        }
    }
    
    private func chartRow(_ chart: GeneratedChart) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(chart.title)
                    .font(DesignSystem.font(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.text)
                Spacer()
                Button(action: { exportChart(chart) }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .help("Salvar PNG")
                Button(action: { copyMention(chart.mentionToken) }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copiar \(chart.mentionToken)")
                
                Button(role: .destructive, action: { chartService.deleteChart(chart) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            
            if let base64 = chart.imageBase64,
               let data = Data(base64Encoded: base64),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Gráfico sem visualização. Regere para criar a imagem.")
                    .font(DesignSystem.font(size: 11))
                    .foregroundColor(.red)
            }
            
            Divider()
        }
        .padding(.vertical, 6)
    }
    
    private func handleGenerateChart() {
        chartService.createChart(
            title: title,
            description: description,
            chartType: chartType,
            unit: unit,
            rawData: rawData
        ) { result in
            switch result {
            case .success(let chart):
                generationMessage = "Gráfico \(chart.mentionToken) criado!"
                showAlert = true
                clearForm(keepData: true)
            case .failure(let error):
                generationMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    private func clearForm(keepData: Bool = false) {
        title = ""
        description = ""
        unit = ""
        if !keepData {
            rawData = ""
        }
        chartType = .bar
    }
    
    private func copyMention(_ mention: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mention, forType: .string)
        generationMessage = "\(mention) copiado!"
        showAlert = true
    }
    
    @MainActor
    private func exportChart(_ chart: GeneratedChart) {
        guard let pngData = chartService.pngData(for: chart) else {
            generationMessage = "Não foi possível gerar o PNG deste gráfico."
            showAlert = true
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(chart.handle).png"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try pngData.write(to: url)
                generationMessage = "Gráfico salvo como \(url.lastPathComponent)."
            } catch {
                generationMessage = "Erro ao salvar PNG: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}
