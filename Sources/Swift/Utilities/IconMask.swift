//
//  IconMask.swift
//  Hermes
//
//  Utilities for creating macOS Tahoe-style squircle icons
//

import AppKit

/// Utilities for creating macOS Tahoe-style squircle masked icons
enum IconMask {
    
    /// Standard macOS dock icon size (128pt, but we render at 2x for Retina)
    static let dockIconSize: CGFloat = 128
    
    /// Render size for high-resolution dock icons (2x for Retina displays)
    static let dockIconRenderSize: CGFloat = 256
    
    /// macOS Tahoe squircle corner radius ratio (~22.37% of content size)
    static let cornerRadiusRatio: CGFloat = 0.2237
    
    /// macOS Tahoe applies padding around dock icons - content is ~82% of total size
    static let dockContentRatio: CGFloat = 0.82
    
    // MARK: - Scaling
    
    /// Scales an image to a target size with high-quality interpolation
    /// - Parameters:
    ///   - image: The source image to scale
    ///   - size: The target size (square)
    ///   - mode: The scaling mode (aspectFill or aspectFit)
    /// - Returns: A new scaled image
    static func scale(
        _ image: NSImage,
        to size: CGFloat,
        mode: ScaleMode = .aspectFill
    ) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let result = NSImage(size: targetSize)
        
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        
        let sourceSize = image.size
        let widthRatio = size / sourceSize.width
        let heightRatio = size / sourceSize.height
        
        let scale: CGFloat
        switch mode {
        case .aspectFill:
            scale = max(widthRatio, heightRatio)
        case .aspectFit:
            scale = min(widthRatio, heightRatio)
        }
        
        let scaledWidth = sourceSize.width * scale
        let scaledHeight = sourceSize.height * scale
        let drawRect = NSRect(
            x: (size - scaledWidth) / 2,
            y: (size - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: sourceSize), operation: .copy, fraction: 1.0)
        
        result.unlockFocus()
        return result
    }
    
    // MARK: - Masking
    
    /// Applies a squircle mask to an image (no scaling, no padding)
    /// - Parameters:
    ///   - image: The source image to mask
    ///   - cornerRadiusRatio: The corner radius as a ratio of the image size
    /// - Returns: A new image with the squircle mask applied
    static func applyMask(
        to image: NSImage,
        cornerRadiusRatio: CGFloat = cornerRadiusRatio
    ) -> NSImage {
        let size = image.size
        let cornerRadius = min(size.width, size.height) * cornerRadiusRatio
        
        let result = NSImage(size: size)
        result.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()
        
        image.draw(in: rect)
        
        result.unlockFocus()
        return result
    }
    
    // MARK: - Combined Operations
    
    /// Creates a dock icon: scales, adds padding, and applies squircle mask
    /// - Parameters:
    ///   - image: The source image
    ///   - size: The total icon size (default: 256 for high-res dock icons)
    ///   - contentRatio: How much of the total size is content vs padding (default: 82%)
    /// - Returns: A new image ready for use as a dock icon
    static func createDockIcon(
        from image: NSImage,
        size: CGFloat = dockIconRenderSize,
        contentRatio: CGFloat = dockContentRatio
    ) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let contentSize = size * contentRatio
        let padding = (size - contentSize) / 2
        let cornerRadius = contentSize * cornerRadiusRatio
        
        let result = NSImage(size: targetSize)
        result.lockFocus()
        
        // Create the squircle path centered with padding
        let contentRect = NSRect(x: padding, y: padding, width: contentSize, height: contentSize)
        let path = NSBezierPath(roundedRect: contentRect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()
        
        // Use high-quality interpolation for crisp scaling
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // Calculate aspect-fill scaling to fill the content area
        let sourceSize = image.size
        let widthRatio = contentSize / sourceSize.width
        let heightRatio = contentSize / sourceSize.height
        let scale = max(widthRatio, heightRatio)
        
        let scaledWidth = sourceSize.width * scale
        let scaledHeight = sourceSize.height * scale
        let drawRect = NSRect(
            x: padding + (contentSize - scaledWidth) / 2,
            y: padding + (contentSize - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: sourceSize), operation: .copy, fraction: 1.0)
        
        result.unlockFocus()
        return result
    }
    
    /// Creates a dock icon with an optional play/pause overlay at full resolution
    /// - Parameters:
    ///   - image: The source image
    ///   - isPlaying: Whether to show pause (true) or play (false) icon
    ///   - showOverlay: Whether to show the play/pause overlay
    /// - Returns: A new image ready for use as a dock icon
    static func createDockIcon(
        from image: NSImage,
        isPlaying: Bool,
        showOverlay: Bool
    ) -> NSImage {
        let size = dockIconRenderSize
        let contentSize = size * dockContentRatio
        let padding = (size - contentSize) / 2
        
        // First create the base dock icon at full resolution
        let baseIcon = createDockIcon(from: image, size: size)
        
        guard showOverlay else { return baseIcon }
        
        // Apply the play/pause overlay at full resolution
        let result = NSImage(size: baseIcon.size)
        result.lockFocus()
        
        baseIcon.draw(in: NSRect(origin: .zero, size: baseIcon.size))
        
        // Calculate icon position within the content area (accounting for padding)
        let iconSize = contentSize * 0.6
        let iconRect = NSRect(
            x: padding + (contentSize - iconSize) / 2,
            y: padding + (contentSize - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        let symbolName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            // Configure symbol for large size rendering
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            let configuredSymbol = symbol.withSymbolConfiguration(config) ?? symbol
            
            // Create a white-tinted version of the symbol
            let tintedSymbol = NSImage(size: NSSize(width: iconSize, height: iconSize))
            tintedSymbol.lockFocus()
            
            // Draw the symbol centered and scaled to fill
            let symbolRect = NSRect(origin: .zero, size: tintedSymbol.size)
            configuredSymbol.draw(in: symbolRect)
            NSColor.white.set()
            symbolRect.fill(using: .sourceAtop)
            
            tintedSymbol.unlockFocus()
            
            // Draw with shadow
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -4), blur: 8, color: NSColor.black.withAlphaComponent(0.5).cgColor)
                tintedSymbol.draw(in: iconRect)
                context.restoreGState()
            }
        }
        
        result.unlockFocus()
        return result
    }
    
    /// Creates a small masked thumbnail: scales and applies squircle mask (no padding)
    /// - Parameters:
    ///   - image: The source image
    ///   - size: The target size
    /// - Returns: A new scaled and masked image
    static func createThumbnail(
        from image: NSImage,
        size: CGFloat
    ) -> NSImage {
        let scaled = scale(image, to: size, mode: .aspectFill)
        return applyMask(to: scaled)
    }
    
    enum ScaleMode {
        case aspectFill
        case aspectFit
    }
}
