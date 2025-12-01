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
        availableCharts: [GeneratedChart] = [],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        debugLog = "" // Clear previous log
        log("Starting presentation generation")
        log("Topic: \(topic)")
        log("Slide count: \(slideCount)")
        log("Language: \(languageName) (\(languageCode))")
        log("Image style: \(imageStyle)")
        
        isGenerating = true
        currentTopic = topic
        currentStep = "Refining concept..."
        generationProgress = 0.1
        
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
        
        Requirements:
        - Vary the tone and focus of each slide (data-driven, inspirational, practical advice, storytelling, etc.).
        - Provide richer content: each slide's "content" must contain 4-6 bullet lines (each starting with "- ") with actionable insights, micro-examples, or statistics.
        - Add a single-sentence "highlight" that summarizes the slide or shares a surprising fact.
        - Choose a "visual_style" per slide from ["image-right","image-left","full-bleed","chart-focus","chart-large","chart-split"]:
          * Use "chart-focus", "chart-large", or "chart-split" ONLY when the slide mentions a chart (contains @handle).
          * Use "image-right", "image-left", or "full-bleed" for slides without charts.
        - Ensure "image_prompt" is vivid, specific, and stylistically varied (mention mood, color palette, composition, camera angle, etc.) but always base the aesthetic around "\(imageStyle)".
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
        aiService.sendMessage([ChatMessage(role: .user, content: structurePrompt)], model: "gpt-4o") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let jsonString):
                self.log("✓ Received response from OpenAI")
                self.log("Response length: \(jsonString.count) chars")
                self.log("First 200 chars: \(String(jsonString.prefix(200)))")
                
                if jsonString.isEmpty {
                    self.log("✗ ERROR: Response is empty")
                    self.isGenerating = false
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
                completion(.failure(error))
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
            completion(.failure(NSError(domain: "PresentationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse presentation structure."])))
            return
        }
        
        do {
            let slides = try JSONDecoder().decode([SlideContent].self, from: data)
            log("✓ Successfully decoded \(slides.count) slides")
            
            // Continue with image generation...
            self.continueWithImageGeneration(slides: slides, completion: completion)
            
        } catch {
            log("✗ JSON Decode Error: \(error.localizedDescription)")
            self.isGenerating = false
            completion(.failure(NSError(domain: "PresentationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON parsing failed: \(error.localizedDescription)"])))
            return
        }
    }
    
    private func continueWithImageGeneration(slides: [SlideContent], completion: @escaping (Result<String, Error>) -> Void) {
        var processedSlides = slides
        
        // 2. Generate Images for each slide (Parallel)
        let group = DispatchGroup()
        
        // Only generate images for first 5 slides to save tokens/time/money in this demo, or all if requested
        let slidesToGenerate = processedSlides.indices
        let totalImages = Double(slidesToGenerate.count)
        var imagesDone = 0.0
        
        for index in slidesToGenerate {
            group.enter()
            let prompt = processedSlides[index].imagePrompt
            
            self.aiService.generateImage(prompt: prompt) { result in
                DispatchQueue.main.async {
                    if case .success(let url) = result {
                        processedSlides[index].imageUrl = url
                    }
                    imagesDone += 1
                    self.generationProgress = 0.3 + (0.6 * (imagesDone / totalImages))
                    self.currentStep = "Rendering slide \(Int(imagesDone))/\(Int(totalImages))..."
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
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


