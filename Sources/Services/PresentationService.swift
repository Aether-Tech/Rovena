import Foundation
import Combine

class PresentationService: ObservableObject {
    static let shared = PresentationService()
    
    @Published var isGenerating = false
    @Published var currentStep = ""
    @Published var generationProgress: Double = 0.0
    @Published var debugLog = ""
    
    private let aiService = AIService.shared
    private let archiveService = PresentationArchiveService.shared
    
    private var currentTopic: String?
    
    @Published var lastSlides: [SlideContent] = []
    
    private func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        debugLog += "[\(timestamp)] \(message)\n"
        print(message)
    }
    
    // Struct to hold slide data before final markdown assembly
    struct SlideContent: Codable, Identifiable {
        var id = UUID()
        var title: String
        var content: String
        var highlight: String?
        var visualStyle: String?
        var imagePrompt: String
        var imageUrl: URL?
        
        enum CodingKeys: String, CodingKey {
            case title
            case content
            case highlight
            case visualStyle = "visual_style"
            case imagePrompt = "image_prompt"
            case imageUrl
        }
    }
    
    enum SlideLayout: String, CaseIterable {
        case imageRight = "image-right"
        case imageLeft = "image-left"
        case fullBleed = "full-bleed"
        case chartFocus = "chart-focus" // Gráfico em destaque, conteúdo ao lado
        case chartLarge = "chart-large" // Gráfico grande centralizado, texto abaixo
        case chartSplit = "chart-split" // Gráfico e conteúdo divididos igualmente
        
        static func random() -> SlideLayout {
            SlideLayout.allCases.randomElement() ?? .imageRight
        }
    }
    
    func generatePresentation(
        topic: String,
        slideCount: Int = 5,
        languageCode: String = "pt-BR",
        languageName: String = "Português brasileiro",
        imageStyle: String = "realistic photography with natural lighting",
        stylizationLevel: Double = 0,
        availableCharts: [GeneratedChart] = [],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Resetar estado anterior se houver
        if isGenerating {
            log("⚠️ Warning: Previous generation still in progress, resetting...")
            isGenerating = false
            generationProgress = 0.0
            currentStep = ""
        }
        
        debugLog = "" // Clear previous log
        log("Starting presentation generation")
        log("Topic: \(topic)")
        log("Slide count: \(slideCount)")
        log("Language: \(languageName) (\(languageCode))")
        log("Image style: \(imageStyle)")
        log("Stylization level: \(Int(stylizationLevel))/100")
        
        // Verificar tokens antes de começar (se usar Rovena Cloud)
        if SettingsManager.shared.useRovenaCloud {
            // Estimativa base + acréscimo proporcional ao nível de estilização
            let extraFactor = max(0, min(1, stylizationLevel / 100.0))
            let estimatedTokensForStructure = 2000 + Int(1500 * extraFactor)
            if !TokenService.shared.canUseTokens(estimatedTokensForStructure) {
                let error = NSError(
                    domain: "PresentationService",
                    code: 429,
                    userInfo: [NSLocalizedDescriptionKey: "Token limit exceeded. Cannot generate presentation. Please upgrade your plan or wait for the limit to reset."]
                )
                log("✗ ERROR: Token limit exceeded before starting generation")
                LogManager.shared.addLog("Presentation generation blocked: Token limit exceeded", level: .error, category: "PresentationService")
                completion(.failure(error))
                return
            }
        }
        
        isGenerating = true
        currentTopic = topic
        currentStep = "Refining concept..."
        generationProgress = 0.1
        
        LogManager.shared.addLog("Presentation generation started: \(topic)", level: .info, category: "PresentationService")
        
        // Build chart information for the prompt
        var chartInfoSection = ""
        if !availableCharts.isEmpty {
            chartInfoSection = "\n\nAVAILABLE CHARTS (mention them using their handle like @handle in the content where relevant):\n"
            for chart in availableCharts {
                chartInfoSection += "- \(chart.mentionToken): \"\(chart.title)\" - \(chart.description). Type: \(chart.chartType.displayName).\n"
            }
            chartInfoSection += "\nIMPORTANT CHART USAGE RULES:\n"
            chartInfoSection += "1. When a chart is mentioned in a slide's content (using @handle), that slide MUST use a chart-focused layout.\n"
            chartInfoSection += "2. Choose the appropriate chart layout based on the slide's focus:\n"
            chartInfoSection += "   - \"chart-focus\": Use when the chart is the main focus, with supporting text beside it. Best for data-heavy slides.\n"
            chartInfoSection += "   - \"chart-large\": Use when you want the chart prominently displayed with explanatory text below. Best for key insights.\n"
            chartInfoSection += "   - \"chart-split\": Use when chart and content are equally important. Best for balanced presentations.\n"
            chartInfoSection += "3. If a slide mentions a chart, include the chart handle (@handle) in the \"content\" field where it should appear.\n"
            chartInfoSection += "4. For slides with charts, the \"image_prompt\" can be more minimal or focus on complementary visuals, as the chart will be the primary visual element.\n"
        }
        
        // 1. Refine Prompt & Generate Structure
        let structurePrompt = """
        You are a presentation generator API. 
        Create a presentation outline for the topic: "\(topic)".
        Target audience: General public with mixed backgrounds.
        Presentation language: \(languageName) (locale code \(languageCode)). Use authentic localized tone and diacritics.
        Number of slides: \(slideCount).\(chartInfoSection)
        
        Stylization level (0-100): \(Int(stylizationLevel)).
        - At 0, use very simple visual design: white background, black text, one supporting image per slide, minimal decoration.
        - Between 30 and 70, start adding subtle geometric shapes, accent color blocks, and more varied image placements.
        - Above 70, strongly emphasize visual design: colorful geometric backgrounds, creative layouts, bolder accent colors, and more dynamic compositions.
        
        Requirements:
        - Vary the tone and focus of each slide (data-driven, inspirational, practical advice, storytelling, etc.).
        - Provide richer content: each slide's "content" must contain 4-6 bullet lines (each starting with "- ") with actionable insights, micro-examples, or statistics.
        - Add a single-sentence "highlight" that summarizes the slide or shares a surprising fact.
        - Choose a "visual_style" per slide from ["image-right","image-left","full-bleed","chart-focus","chart-large","chart-split"]:
          * Use "chart-focus", "chart-large", or "chart-split" ONLY when the slide mentions a chart (contains @handle).
          * Use "image-right", "image-left", or "full-bleed" for slides without charts.
          * For higher stylization levels, prefer more varied layouts and use "full-bleed" more often when appropriate.
        - Ensure "image_prompt" is vivid, specific, and stylistically varied (mention mood, color palette, composition, camera angle, etc.) but always base the aesthetic around "\(imageStyle)".
        - At higher stylization levels, describe backgrounds that include colorful geometric shapes, gradients, or textures, and mention more creative compositions.
        - For slides with charts, the image_prompt should complement the chart or be more minimal since the chart is the primary visual.
        
        CRITICAL: Return ONLY a valid JSON array. Do not wrap it in markdown code blocks like ```json. Do not add any intro text. Just the raw JSON array.
        
        Format:
        [
          {
            "title": "Slide Title",
            "content": "- Bullet point 1\\n- Bullet point 2\\n- Bullet point 3",
            "highlight": "One-sentence key insight or statistic.",
            "visual_style": "image-right",
            "image_prompt": "Visual description for DALL-E"
          }
        ]
        """
        
        log("Sending request to OpenAI API (GPT-4o)...")
        LogManager.shared.addLog("Sending structure request to OpenAI", level: .info, category: "PresentationService")
        
        aiService.sendMessage([ChatMessage(role: .user, content: structurePrompt)], model: "gpt-4o") { [weak self] result in
            guard let self = self else {
                LogManager.shared.addLog("PresentationService deallocated during generation", level: .error, category: "PresentationService")
                return
            }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let jsonString):
                    self.log("✓ Received response from OpenAI")
                    self.log("Response length: \(jsonString.count) chars")
                    self.log("First 200 chars: \(String(jsonString.prefix(200)))")
                    LogManager.shared.addLog("Received structure response from OpenAI (\(jsonString.count) chars)", level: .info, category: "PresentationService")
                    
                    if jsonString.isEmpty {
                        self.log("✗ ERROR: Response is empty")
                        self.isGenerating = false
                        self.generationProgress = 0.0
                        self.currentStep = ""
                        self.currentTopic = nil
                        LogManager.shared.addLog("Presentation generation failed: Empty response from AI", level: .error, category: "PresentationService")
                        completion(.failure(NSError(domain: "PresentationService", code: -2, userInfo: [NSLocalizedDescriptionKey: "AI returned empty response. Check your API key."])))
                        return
                    }
                    
                    self.currentStep = "Designing visuals..."
                    self.generationProgress = 0.3
                    self.parseAndGenerateImages(jsonString: jsonString, completion: completion)
                    
                case .failure(let error):
                    self.log("✗ ERROR: AI Service failed")
                    self.log("Error: \(error.localizedDescription)")
                    self.isGenerating = false
                    self.generationProgress = 0.0
                    self.currentStep = ""
                    self.currentTopic = nil
                    
                    // Melhorar mensagem de erro para chave de API incorreta
                    var errorMsg = "Presentation generation failed: \(error.localizedDescription)"
                    var finalError = error
                    
                    if error.localizedDescription.contains("Incorrect API key") || error.localizedDescription.contains("Invalid API key") {
                        errorMsg = """
                        Invalid or expired API key.
                        
                        The OpenAI API key configured in Config.plist appears to be incorrect or expired.
                        Please verify your ROVENA_DEFAULT_API_KEY in Sources/Config.plist and ensure it's a valid OpenAI API key.
                        
                        Original error: \(error.localizedDescription)
                        """
                        LogManager.shared.addLog("API key validation failed - key may be expired or incorrect", level: .error, category: "PresentationService")
                        finalError = NSError(domain: "PresentationService", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                    }
                    
                    LogManager.shared.addLog(errorMsg, level: .error, category: "PresentationService")
                    
                    // Garantir que o completion seja chamado na main thread
                    completion(.failure(finalError))
                }
            }
        }
    }
    
    private func parseAndGenerateImages(jsonString: String, completion: @escaping (Result<String, Error>) -> Void) {
        log("Parsing JSON response...")
        log("Full response:\n\(jsonString)\n---")
        
        // Robust cleanup: Remove markdown code blocks and find the array brackets
        var cleanJson = jsonString.replacingOccurrences(of: "```json", with: "")
                                  .replacingOccurrences(of: "```", with: "")
        
        // Find start and end of the JSON array
        if let startIndex = cleanJson.firstIndex(of: "["),
           let endIndex = cleanJson.lastIndex(of: "]") {
            cleanJson = String(cleanJson[startIndex...endIndex])
            log("Extracted JSON array from response")
        } else {
            log("⚠️ Warning: No JSON array brackets found")
        }
        
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)
        log("Cleaned JSON:\n\(cleanJson)\n---")
        
        guard let data = cleanJson.data(using: .utf8) else {
            log("✗ Failed to convert JSON string to Data")
            self.isGenerating = false
            self.generationProgress = 0.0
            self.currentStep = ""
            self.currentTopic = nil
            LogManager.shared.addLog("Presentation generation failed: Failed to convert JSON to Data", level: .error, category: "PresentationService")
            completion(.failure(NSError(domain: "PresentationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse presentation structure."])))
            return
        }
        
        do {
            let slides = try JSONDecoder().decode([SlideContent].self, from: data)
            log("✓ Successfully decoded \(slides.count) slides")
            
            if slides.isEmpty {
                log("✗ ERROR: No slides decoded")
                self.isGenerating = false
                self.generationProgress = 0.0
                self.currentStep = ""
                self.currentTopic = nil
                LogManager.shared.addLog("Presentation generation failed: No slides decoded", level: .error, category: "PresentationService")
                completion(.failure(NSError(domain: "PresentationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No slides were generated. Please try again with a different topic."])))
                return
            }
            
            // Continue with image generation...
            self.continueWithImageGeneration(slides: slides, completion: completion)
            
        } catch {
            log("✗ JSON Decode Error: \(error.localizedDescription)")
            self.isGenerating = false
            self.generationProgress = 0.0
            self.currentStep = ""
            self.currentTopic = nil
            LogManager.shared.addLog("Presentation generation failed: JSON parsing error - \(error.localizedDescription)", level: .error, category: "PresentationService")
            completion(.failure(NSError(domain: "PresentationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON parsing failed: \(error.localizedDescription)"])))
            return
        }
    }
    
    private func continueWithImageGeneration(slides: [SlideContent], completion: @escaping (Result<String, Error>) -> Void) {
        log("Starting image generation for \(slides.count) slides")
        LogManager.shared.addLog("Starting image generation for \(slides.count) slides", level: .info, category: "PresentationService")
        
        var processedSlides = slides
        
        // 2. Generate Images for each slide (Parallel)
        let group = DispatchGroup()
        
        // Only generate images for first 5 slides to save tokens/time/money in this demo, or all if requested
        let slidesToGenerate = processedSlides.indices
        let totalImages = Double(slidesToGenerate.count)
        var imagesDone = 0.0
        var firstError: Error?
        let errorLock = NSLock()
        var hasCriticalError = false
        
        for index in slidesToGenerate {
            group.enter()
            let prompt = processedSlides[index].imagePrompt
            let slideIndex = index + 1
            
            log("Generating image \(slideIndex)/\(slides.count): \(prompt.prefix(50))...")
            
            self.aiService.generateImage(prompt: prompt) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        processedSlides[index].imageUrl = url
                        self.log("✓ Image \(slideIndex) generated successfully")
                    case .failure(let error):
                        // Capturar o primeiro erro crítico (limite de tokens)
                        errorLock.lock()
                        if firstError == nil {
                            // Verificar se é um erro crítico que deve abortar a geração
                            if let nsError = error as NSError?, nsError.code == 429 {
                                // Limite de tokens excedido - erro crítico
                                firstError = error
                                hasCriticalError = true
                                self.log("✗ CRITICAL ERROR: Token limit exceeded during image generation for slide \(slideIndex)")
                                LogManager.shared.addLog("CRITICAL: Token limit exceeded during image generation", level: .error, category: "PresentationService")
                            } else {
                                // Erro não crítico - apenas logar e continuar
                                self.log("⚠️ Warning: Failed to generate image for slide \(slideIndex): \(error.localizedDescription)")
                                LogManager.shared.addLog("Image generation failed for slide \(slideIndex): \(error.localizedDescription)", level: .warning, category: "PresentationService")
                            }
                        }
                        errorLock.unlock()
                    }
                    
                    imagesDone += 1
                    self.generationProgress = 0.3 + (0.6 * (imagesDone / totalImages))
                    self.currentStep = "Rendering slide \(Int(imagesDone))/\(Int(totalImages))..."
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // Se houver um erro crítico, abortar a geração
            errorLock.lock()
            let criticalError = firstError
            let shouldAbort = hasCriticalError
            errorLock.unlock()
            
            if shouldAbort, let error = criticalError {
                self.log("✗ Aborting presentation generation due to critical error")
                self.isGenerating = false
                self.generationProgress = 0.0
                self.currentStep = ""
                self.currentTopic = nil
                LogManager.shared.addLog("Presentation generation aborted due to critical error", level: .error, category: "PresentationService")
                completion(.failure(error))
                return
            }
            
            // Continuar com a finalização mesmo se algumas imagens falharam
            self.log("✓ All images processed, finalizing presentation...")
            self.currentStep = "Finalizing..."
            self.generationProgress = 0.95
            self.lastSlides = processedSlides
            let markdown = self.assembleMarkdown(slides: processedSlides)
            self.isGenerating = false
            self.generationProgress = 1.0
            
            if let topic = self.currentTopic {
                self.archiveService.archivePresentation(
                    topic: topic,
                    markdown: markdown,
                    slides: processedSlides
                )
            }
            self.currentTopic = nil
            
            self.log("✓ Presentation generation completed successfully")
            LogManager.shared.addLog("Presentation generation completed successfully", level: .info, category: "PresentationService")
            completion(.success(markdown))
        }
    }
    
    func assembleMarkdown(slides: [SlideContent]) -> String {
        let chartService = ChartService.shared
        var markdown = "---\nmarp: true\ntheme: default\npaginate: true\n---\n\n"
        
        for slide in slides {
            let layout = SlideLayout(rawValue: slide.visualStyle ?? "") ?? .random()
            
            // Check if slide contains chart mentions
            let hasChart = chartService.charts.contains { chart in
                slide.content.contains(chart.mentionToken) || slide.title.contains(chart.mentionToken)
            }
            
            markdown += "# \(slide.title)\n\n"
            
            // Handle chart-focused layouts
            if hasChart && (layout == .chartFocus || layout == .chartLarge || layout == .chartSplit) {
                // For chart layouts, we'll let the chart be inserted via replaceMentions
                // and use special markdown classes for styling
                markdown += "<!-- chart-layout: \(layout.rawValue) -->\n\n"
            }
            
            // Add background image only if not a chart-focused layout or if it's a complementary image
            if let url = slide.imageUrl, !hasChart {
                switch layout {
                case .imageRight:
                    markdown += "![bg right:35%](\(url.absoluteString))\n\n"
                case .imageLeft:
                    markdown += "![bg left:35%](\(url.absoluteString))\n\n"
                case .fullBleed:
                    markdown += "![bg](\(url.absoluteString))\n\n"
                default:
                    break
                }
            } else if let url = slide.imageUrl, hasChart {
                // For chart slides, use a subtle background if needed
                markdown += "![bg opacity:0.1](\(url.absoluteString))\n\n"
            }
            
            if let highlight = slide.highlight, !highlight.isEmpty {
                markdown += "> \(highlight)\n\n"
            }
            
            markdown += "\(slide.content)\n\n"
            markdown += "---\n\n"
        }
        
        return markdown
    }
}


