//
//  IconMask.swift
//  Hermes
//
//  Utilities for creating macOS Tahoe-style squircle icons
//

import AppKit

/// Utilities for creating macOS Tahoe-style squircle masked icons
enum IconMask {
    
    /// Standard macOS dock icon size
    static let dockIconSize: CGFloat = 128
    
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
    ///   - size: The total icon size (default: 128 for dock icons)
    ///   - contentRatio: How much of the total size is content vs padding (default: 82%)
    /// - Returns: A new image ready for use as a dock icon
    static func createDockIcon(
        from image: NSImage,
        size: CGFloat = dockIconSize,
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
