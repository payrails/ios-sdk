//
//  CardFieldConfig.swift
//  Pods
//
//


public struct CardFieldConfig {
    public let type: CardFieldType
    public let placeholder: String?
    public let title: String?
    public let style: CardFormStyle?

    public init(
        type: CardFieldType,
        placeholder: String? = nil,
        title: String? = nil,
        style: CardFormStyle? = nil
    ) {
        self.type = type
        self.placeholder = placeholder
        self.title = title
        self.style = style
    }
}
