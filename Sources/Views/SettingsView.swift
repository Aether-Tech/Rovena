import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Configuration")
                .font(DesignSystem.font(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.text)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(DesignSystem.font(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.text.opacity(0.7))
                            .padding(.leading, 4)
                        
                        VStack(spacing: 0) {
                            // Dark Mode Toggle
                            Toggle("Dark Mode", isOn: $settings.isDarkMode)
                                .toggleStyle(.switch)
                                .font(DesignSystem.font(size: 14))
                                .foregroundColor(DesignSystem.text)
                                .padding()
                            
                            Divider().opacity(0.5)
                            
                            // Theme Selector
                            HStack {
                                Text("Theme")
                                    .font(DesignSystem.font(size: 14))
                                    .foregroundColor(DesignSystem.text)
                                
                                Spacer()
                                
                                Picker("", selection: $settings.selectedTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            .padding()
                        }
                        .elementStyle()
                    }
                    
                    // Keys Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("API Keys")
                                .font(DesignSystem.font(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.text.opacity(0.7))
                            
                            Menu {
                                Text("O que é uma API Key?")
                                    .font(DesignSystem.font(size: 12, weight: .bold))
                                
                                Text("Imagine que a API Key é como uma 'chave mágica' ou uma 'senha VIP' que deixa o Rovena conversar com os cérebros gigantes da internet (como o GPT da OpenAI ou o Claude da Anthropic).")
                                
                                Text("Sem essa chave, eles não sabem quem somos e não nos deixam entrar!")
                                
                                Divider()
                                
                                Link("Obter chave OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                Link("Obter chave Anthropic", destination: URL(string: "https://console.anthropic.com/")!)
                                Link("Obter chave Gemini", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(DesignSystem.accent)
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .padding(.leading, 4)
                        
                        VStack(spacing: 16) {
                            KeyField(title: "OpenAI API Key", value: $settings.openAIKey)
                            KeyField(title: "Anthropic API Key", value: $settings.anthropicKey)
                            KeyField(title: "Gemini API Key", value: $settings.geminiKey)
                            KeyField(title: "Custom Endpoint", value: $settings.customEndpoint)
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .background(DesignSystem.background)
    }
}

struct KeyField: View {
    let title: String
    @Binding var value: String
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignSystem.font(size: 13))
                .foregroundColor(DesignSystem.text)
            
            HStack {
                if isVisible {
                    TextField("Enter Key", text: $value)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .onSubmit {
                            SettingsManager.shared.saveKeys()
                        }
                        .onChange(of: value) {
                            SettingsManager.shared.saveKeys()
                        }
                } else {
                    SecureField("Enter Key", text: $value)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text)
                        .onSubmit {
                            SettingsManager.shared.saveKeys()
                        }
                        .onChange(of: value) {
                            SettingsManager.shared.saveKeys()
                        }
                }
                
                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .elementStyle()
        }
    }
}
