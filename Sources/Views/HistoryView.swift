import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var presentationArchiveService = PresentationArchiveService.shared
    @Binding var selection: NavigationItem?
    @Binding var activeSessionId: UUID?
    @State private var selectedTab: HistoryTab = .sessions
    
    enum HistoryTab: String, CaseIterable, Identifiable {
        case sessions = "Sessions"
        case media = "Media"
        case presentations = "Apresentações"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Filter
            HStack {
                Text("Archives")
                    .font(DesignSystem.font(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.text.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Text("Filter")
                        .font(DesignSystem.font(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.text.opacity(0.7))
                        .lineLimit(1)
                    
                    Picker("", selection: $selectedTab) {
                        ForEach(HistoryTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
            }
            .padding()
            .background(DesignSystem.background)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.border), alignment: .bottom)
            
            // Content
            ZStack {
                DesignSystem.background.ignoresSafeArea()
                
                switch selectedTab {
                case .sessions:
                    SessionsListView(
                        sessions: historyService.sessions,
                        selection: $selection,
                        activeSessionId: $activeSessionId
                    )
                case .media:
                    MediaGalleryView(sessions: historyService.sessions)
                case .presentations:
                    PresentationArchiveView(presentations: presentationArchiveService.presentations)
                }
            }
        }
    }
}

struct SessionsListView: View {
    let sessions: [ChatSession]
    @Binding var selection: NavigationItem?
    @Binding var activeSessionId: UUID?
    
    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.text.opacity(0.15))
                    Text("aqui vao ficar suas interaçoes")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sessions) { session in
                            HStack(spacing: 0) {
                                Button {
                                    activeSessionId = session.id
                                    selection = .chat
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.name)
                                                .font(DesignSystem.font(size: 16))
                                                .fontWeight(.semibold)
                                                .foregroundColor(DesignSystem.text)
                                                .lineLimit(1)
                                            
                                            Text(session.creationDate.formatted(date: .numeric, time: .shortened))
                                                .font(DesignSystem.font(size: 12))
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("\(session.retentionDays) days left")
                                                .font(DesignSystem.font(size: 11))
                                                .fontWeight(.medium)
                                                .foregroundColor(DesignSystem.text.opacity(0.6))
                                            
                                            if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: session.expirationDate).day {
                                                Text("Expires in: \(daysLeft) days")
                                                    .font(DesignSystem.font(size: 11))
                                                    .fontWeight(.medium)
                                                    .foregroundColor(daysLeft < 2 ? .red : .gray)
                                            }
                                        }
                                    }
                                    .padding()
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Rectangle()
                                    .fill(DesignSystem.border.opacity(0.3))
                                    .frame(width: 1)
                                    .padding(.vertical, 8)
                                
                                Button {
                                    HistoryService.shared.deleteSession(session.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(DesignSystem.text.opacity(0.5))
                                        .frame(width: 50)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                            .elementStyle()
                            .contextMenu {
                                Button(role: .destructive) {
                                    HistoryService.shared.deleteSession(session.id)
                                } label: {
                                    Text("Delete Session")
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(DesignSystem.background)
    }
}

struct MediaGalleryView: View {
    let sessions: [ChatSession]
    @State private var selectedImage: ImageItem?
    @State private var hoveredImageId: String?
    
    struct ImageItem: Identifiable {
        let id: String
        let url: URL
        let prompt: String
        let date: Date
        let sessionId: UUID
        let messageId: UUID
    }
    
    var allImages: [ImageItem] {
        sessions.flatMap { session in
            session.messages.compactMap { msg -> ImageItem? in
                guard let url = msg.imageURL else { return nil }
                // Clean up prompt prefix if exists (legacy support)
                let prompt = msg.content.replacingOccurrences(of: "GENERATED_IMAGE :: ", with: "")
                                        .replacingOccurrences(of: "Generated Image: ", with: "")
                return ImageItem(
                    id: url.absoluteString,
                    url: url,
                    prompt: prompt,
                    date: msg.timestamp,
                    sessionId: session.id,
                    messageId: msg.id
                )
            }
        }
        .sorted { $0.date > $1.date }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            if allImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.text.opacity(0.15))
                    Text("aqui vao ficar suas interaçoes")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(allImages) { item in
                            ZStack(alignment: .bottom) {
                            // Image Container
                            AsyncImage(url: item.url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        DesignSystem.surface.opacity(0.1)
                                        ProgressView()
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                case .failure:
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        Image(systemName: "photo.fill")
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .clipShape(SquircleShape())
                            .overlay(
                                SquircleShape()
                                    .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
                            )
                            .overlay(
                                Color.black.opacity(hoveredImageId == item.id ? 0.4 : 0)
                                    .clipShape(SquircleShape())
                            )
                            .onTapGesture {
                                selectedImage = item
                            }
                            
                            // Hover Controls
                            if hoveredImageId == item.id {
                                HStack {
                                    Button {
                                        downloadImage(url: item.url)
                                    } label: {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .background(Color.black.clipShape(Circle()))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                    
                                    Spacer()
                                    
                                    Button {
                                        deleteImage(item)
                                    } label: {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.red)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 8)
                                }
                                .padding(.bottom, 8)
                            }
                            }
                            .onHover { hovering in
                                hoveredImageId = hovering ? item.id : nil
                            }
                            .animation(.easeInOut(duration: 0.2), value: hoveredImageId)
                        }
                    }
                }
                .padding()
            }
            
            // Fullscreen Highlight
            if let item = selectedImage {
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()
                        .onTapGesture {
                            selectedImage = nil
                        }
                    
                    VStack(spacing: 20) {
                        HStack {
                            Spacer()
                            Button {
                                selectedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                        }
                        
                        AsyncImage(url: item.url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 1000, maxHeight: 800)
                                    .clipShape(SquircleShape())
                                    .shadow(radius: 20)
                            } else {
                                ProgressView()
                            }
                        }
                        
                        Text(item.prompt)
                            .font(DesignSystem.font(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(SquircleShape())
                    }
                }
                .transition(.opacity)
            }
        }
        .background(DesignSystem.background)
    }
    
    func downloadImage(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Image"
        savePanel.message = "Choose a folder and a name to store the image."
        savePanel.nameFieldStringValue = "generated_image_\(Date().timeIntervalSince1970).png"
        
        savePanel.begin { response in
            if response == .OK, let targetUrl = savePanel.url {
                URLSession.shared.dataTask(with: url) { data, _, error in
                    guard let data = data, error == nil else { return }
                    do {
                        try data.write(to: targetUrl)
                    } catch {
                        print("Error saving file: \(error)")
                    }
                }.resume()
            }
        }
    }
    
    func deleteImage(_ item: ImageItem) {
        if let sessionIndex = HistoryService.shared.sessions.firstIndex(where: { $0.id == item.sessionId }) {
            var session = HistoryService.shared.sessions[sessionIndex]
            session.messages.removeAll { $0.id == item.messageId }
            HistoryService.shared.updateSession(session)
        }
    }
}

struct PresentationArchiveView: View {
    let presentations: [ArchivedPresentation]
    @State private var hoveredSlideId: UUID?
    @State private var focusedSlide: (ArchivedPresentation, ArchivedPresentation.Slide)?
    
    var body: some View {
        ZStack {
            if presentations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.play")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.text.opacity(0.15))
                    Text("aqui vao ficar suas interaçoes")
                        .font(DesignSystem.font(size: 14))
                        .foregroundColor(DesignSystem.text.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(presentations) { presentation in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(presentation.title)
                                            .font(DesignSystem.font(size: 16, weight: .semibold))
                                            .foregroundColor(DesignSystem.text)
                                        Text(presentation.displaySubtitle)
                                            .font(DesignSystem.font(size: 12))
                                            .foregroundColor(DesignSystem.text.opacity(0.6))
                                    }
                                    Spacer()
                                    Button {
                                        PresentationArchiveService.shared.deletePresentation(presentation.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(presentation.slides) { slide in
                                            SlidePreviewCard(
                                                presentation: presentation,
                                                slide: slide,
                                                hoveredSlideId: $hoveredSlideId,
                                                focusedSlide: $focusedSlide
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(DesignSystem.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.border.opacity(0.6), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                }
            }
            
            if let focus = focusedSlide {
                SlideFocusView(
                    presentation: focus.0,
                    slide: focus.1,
                    isVisible: Binding(
                        get: { focusedSlide != nil },
                        set: { _ in focusedSlide = nil }
                    )
                )
            }
        }
    }
}

private struct SlidePreviewCard: View {
    let presentation: ArchivedPresentation
    let slide: ArchivedPresentation.Slide
    @Binding var hoveredSlideId: UUID?
    @Binding var focusedSlide: (ArchivedPresentation, ArchivedPresentation.Slide)?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                if let url = slide.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                DesignSystem.surface.opacity(0.1)
                                ProgressView()
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                    .frame(width: 220, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    placeholder
                        .frame(width: 220, height: 140)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(slide.title)
                        .font(DesignSystem.font(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.text)
                        .lineLimit(2)
                    if let highlight = slide.highlight, !highlight.isEmpty {
                        Text(highlight)
                            .font(DesignSystem.font(size: 11))
                            .foregroundColor(DesignSystem.text.opacity(0.6))
                            .lineLimit(2)
                    }
                }
            }
            .padding(10)
            .background(DesignSystem.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DesignSystem.border.opacity(0.4), lineWidth: 1)
            )
            .onTapGesture {
                focusedSlide = (presentation, slide)
            }
            .onHover { hovering in
                hoveredSlideId = hovering ? slide.id : nil
            }
            
            if hoveredSlideId == slide.id {
                HStack {
                    Button {
                        focusedSlide = (presentation, slide)
                    } label: {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    if let url = slide.imageURL {
                        Button {
                            downloadImage(url: url)
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(role: .destructive) {
                        PresentationArchiveService.shared.deleteSlide(
                            presentationId: presentation.id,
                            slideId: slide.id
                        )
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hoveredSlideId)
    }
    
    private var placeholder: some View {
        ZStack {
            DesignSystem.surface.opacity(0.2)
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.text.opacity(0.3))
        }
        .frame(width: 220, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func downloadImage(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Salvar slide"
        savePanel.message = "Escolha onde salvar a imagem do slide."
        savePanel.nameFieldStringValue = "slide_\(slide.title.filter { !$0.isWhitespace })_\(Int(Date().timeIntervalSince1970)).png"
        
        savePanel.begin { response in
            if response == .OK, let targetUrl = savePanel.url {
                URLSession.shared.dataTask(with: url) { data, _, error in
                    guard let data = data, error == nil else { return }
                    try? data.write(to: targetUrl)
                }.resume()
            }
        }
    }
}

private struct SlideFocusView: View {
    let presentation: ArchivedPresentation
    let slide: ArchivedPresentation.Slide
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    isVisible = false
                }
            
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(presentation.title)
                            .font(DesignSystem.font(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(slide.title)
                            .font(DesignSystem.font(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Button {
                        isVisible = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                if let url = slide.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 900, maxHeight: 600)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if let highlight = slide.highlight, !highlight.isEmpty {
                        Text("Highlight: \(highlight)")
                            .font(DesignSystem.font(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(slide.content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: 900)
            }
            .padding()
        }
        .transition(.opacity)
    }
    
    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "rectangle.on.rectangle")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 48))
        }
        .frame(maxWidth: 900, maxHeight: 600)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
