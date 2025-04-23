//
//  CardFieldConfig.swift
//  Pods
//
//  Created by Mustafa Dikici on 23.04.25.
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
