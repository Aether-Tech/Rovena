import Foundation
import SwiftUI

// Serviço para calcular posicionamento inteligente de elementos baseado no layout
class SlideLayoutService {
    static let shared = SlideLayoutService()
    
    private init() {}
    
    // Canvas dimensions
    private let canvasWidth: CGFloat = 1280
    private let canvasHeight: CGFloat = 720
    
    func calculateElementPositions(
        title: String,
        content: String,
        highlight: String?,
        imageUrl: URL?,
        layout: String
    ) -> [EditableElement] {
        var elements: [EditableElement] = []
        
        // Determinar layout
        let slideLayout = layout.lowercased()
        
        // Título sempre no topo
        let titleElement = EditableElement(
            type: .text,
            content: title,
            position: CodablePoint(CGPoint(x: 80, y: 60)),
            size: CodableSize(CGSize(width: canvasWidth - 160, height: 100)),
            fontSize: 56,
            fontWeight: "bold",
            zIndex: 10
        )
        elements.append(titleElement)
        
        // Subtítulo (se houver)
        if let highlight = highlight {
            let subtitleElement = EditableElement(
                type: .subtitle,
                content: highlight,
                position: CodablePoint(CGPoint(x: 80, y: 180)),
                size: CodableSize(CGSize(width: canvasWidth - 160, height: 50)),
                fontSize: 28,
                fontWeight: "medium",
                zIndex: 9
            )
            elements.append(subtitleElement)
        }
        
        // Posicionar conteúdo e imagem baseado no layout
        let hasImage = imageUrl != nil
        let contentStartY: CGFloat = highlight != nil ? 250 : 200
        
        if slideLayout.contains("image-right") || slideLayout.contains("chart-focus") {
            // Layout: Texto à esquerda, imagem à direita
            let contentWidth = hasImage ? (canvasWidth - 160) * 0.55 : canvasWidth - 160
            let contentElement = EditableElement(
                type: .text,
                content: content,
                position: CodablePoint(CGPoint(x: 80, y: contentStartY)),
                size: CodableSize(CGSize(width: contentWidth, height: canvasHeight - contentStartY - 80)),
                fontSize: 28,
                zIndex: 8
            )
            elements.append(contentElement)
            
            if let imageUrl = imageUrl {
                let imageX = 80 + contentWidth + 40
                let imageWidth = canvasWidth - imageX - 80
                let imageElement = EditableElement(
                    type: .image,
                    content: imageUrl.absoluteString,
                    position: CodablePoint(CGPoint(x: imageX, y: contentStartY)),
                    size: CodableSize(CGSize(width: imageWidth, height: canvasHeight - contentStartY - 80)),
                    zIndex: 7
                )
                elements.append(imageElement)
            }
            
        } else if slideLayout.contains("image-left") {
            // Layout: Imagem à esquerda, texto à direita
            if let imageUrl = imageUrl {
                let imageWidth = (canvasWidth - 160) * 0.45
                let imageElement = EditableElement(
                    type: .image,
                    content: imageUrl.absoluteString,
                    position: CodablePoint(CGPoint(x: 80, y: contentStartY)),
                    size: CodableSize(CGSize(width: imageWidth, height: canvasHeight - contentStartY - 80)),
                    zIndex: 7
                )
                elements.append(imageElement)
            }
            
            let contentX = hasImage ? 80 + (canvasWidth - 160) * 0.45 + 40 : 80
            let contentWidth = hasImage ? (canvasWidth - 160) * 0.55 : canvasWidth - 160
            let contentElement = EditableElement(
                type: .text,
                content: content,
                position: CodablePoint(CGPoint(x: contentX, y: contentStartY)),
                size: CodableSize(CGSize(width: contentWidth, height: canvasHeight - contentStartY - 80)),
                fontSize: 28,
                zIndex: 8
            )
            elements.append(contentElement)
            
        } else if slideLayout.contains("full-bleed") || slideLayout.contains("chart-large") {
            // Layout: Imagem grande centralizada, texto abaixo
            if let imageUrl = imageUrl {
                let imageHeight = (canvasHeight - contentStartY) * 0.65
                let imageElement = EditableElement(
                    type: .image,
                    content: imageUrl.absoluteString,
                    position: CodablePoint(CGPoint(x: 80, y: contentStartY)),
                    size: CodableSize(CGSize(width: canvasWidth - 160, height: imageHeight)),
                    zIndex: 7
                )
                elements.append(imageElement)
                
                let textY = contentStartY + imageHeight + 20
                let contentElement = EditableElement(
                    type: .text,
                    content: content,
                    position: CodablePoint(CGPoint(x: 80, y: textY)),
                    size: CodableSize(CGSize(width: canvasWidth - 160, height: canvasHeight - textY - 80)),
                    fontSize: 24,
                    zIndex: 8
                )
                elements.append(contentElement)
            } else {
                // Sem imagem: texto centralizado
                let contentElement = EditableElement(
                    type: .text,
                    content: content,
                    position: CodablePoint(CGPoint(x: 80, y: contentStartY)),
                    size: CodableSize(CGSize(width: canvasWidth - 160, height: canvasHeight - contentStartY - 80)),
                    fontSize: 32,
                    zIndex: 8
                )
                elements.append(contentElement)
            }
            
        } else {
            // Layout padrão: texto centralizado, imagem abaixo (se houver)
            let contentHeight = hasImage ? (canvasHeight - contentStartY) * 0.6 : canvasHeight - contentStartY - 80
            let contentElement = EditableElement(
                type: .text,
                content: content,
                position: CodablePoint(CGPoint(x: 80, y: contentStartY)),
                size: CodableSize(CGSize(width: canvasWidth - 160, height: contentHeight)),
                fontSize: 28,
                zIndex: 8
            )
            elements.append(contentElement)
            
            if let imageUrl = imageUrl {
                let imageY = contentStartY + contentHeight + 20
                let imageElement = EditableElement(
                    type: .image,
                    content: imageUrl.absoluteString,
                    position: CodablePoint(CGPoint(x: 80, y: imageY)),
                    size: CodableSize(CGSize(width: canvasWidth - 160, height: canvasHeight - imageY - 80)),
                    zIndex: 7
                )
                elements.append(imageElement)
            }
        }
        
        return elements
    }
}

