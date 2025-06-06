/*
 * Copyright (c) 2022 Skyflow
*/

// An Object that describes Style of SkyflowTextField

import Foundation
#if os(iOS)
import UIKit
#endif

public struct Style {
    var borderColor: UIColor?
    var cornerRadius: CGFloat?
    var padding: UIEdgeInsets?
    var borderWidth: CGFloat?
    var font: UIFont?
    var textAlignment: NSTextAlignment?
    var textColor: UIColor?
    var boxShadow: CALayer?
    var backgroundColor: UIColor?
    var minWidth: CGFloat?
    var maxWidth: CGFloat?
    var minHeight: CGFloat?
    var maxHeight: CGFloat?
    var cursorColor: UIColor?
    var width: CGFloat?
    var height: CGFloat?
    var placeholderColor: UIColor?
    var cardIconAlignment: CardIconAlignment?

    public init(borderColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                padding: UIEdgeInsets? = nil,
                borderWidth: CGFloat? = nil,
                font: UIFont? = nil,
                textAlignment: NSTextAlignment? = nil,
                textColor: UIColor? = nil,
                boxShadow: CALayer? = nil,
                backgroundColor: UIColor? = nil,
                minWidth: CGFloat? = nil,
                maxWidth: CGFloat? = nil,
                minHeight: CGFloat? = nil,
                maxHeight: CGFloat? = nil,
                cursorColor: UIColor? = nil,
                width: CGFloat? = nil,
                height: CGFloat? = nil,
                placeholderColor: UIColor? = nil,
                cardIconAlignment: CardIconAlignment? = .left
    ) {
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderWidth = borderWidth
        self.font = font
        self.textAlignment = textAlignment
        self.textColor = textColor
        self.boxShadow = boxShadow
        self.backgroundColor = backgroundColor
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.cursorColor = cursorColor
        self.width = width
        self.height = height
        self.placeholderColor = placeholderColor
        self.cardIconAlignment = cardIconAlignment
    }
    
    func merged(over base: Style?) -> Style {
        let baseStyle = base ?? Style()
        return Style(
            borderColor: self.borderColor ?? baseStyle.borderColor,
            cornerRadius: self.cornerRadius ?? baseStyle.cornerRadius,
            padding: self.padding ?? baseStyle.padding,
            borderWidth: self.borderWidth ?? baseStyle.borderWidth,
            font: self.font ?? baseStyle.font,
            textAlignment: self.textAlignment ?? baseStyle.textAlignment,
            textColor: self.textColor ?? baseStyle.textColor,
            boxShadow: self.boxShadow ?? baseStyle.boxShadow,
            backgroundColor: self.backgroundColor ?? baseStyle.backgroundColor,
            minWidth: self.minWidth ?? baseStyle.minWidth,
            maxWidth: self.maxWidth ?? baseStyle.maxWidth,
            minHeight: self.minHeight ?? baseStyle.minHeight,
            maxHeight: self.maxHeight ?? baseStyle.maxHeight,
            cursorColor: self.cursorColor ?? baseStyle.cursorColor,
            width: self.width ?? baseStyle.width,
            height: self.height ?? baseStyle.height,
            placeholderColor: self.placeholderColor ?? baseStyle.placeholderColor,
            cardIconAlignment: self.cardIconAlignment ?? baseStyle.cardIconAlignment
        )
    }
}
