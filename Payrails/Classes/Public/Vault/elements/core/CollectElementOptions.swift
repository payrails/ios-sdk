/*
 * Copyright (c) 2022 Skyflow
*/

// An Object that describes Options parameter for SkyflowInputField

import Foundation
#if os(iOS)
import UIKit
#endif

public struct CollectElementOptions {
    var required: Bool
    var enableCardIcon: Bool
    var format: String
    var translation: [ Character: String ]?
    var enableCopy: Bool
    var showRequiredAsterisk: Bool
    // Typed co-branded scheme payload (set internally by the card form), replacing the former
    // stringly-typed `[String: Any]` dictionary. Not part of the public init — set via the property.
    var cardSchemeMetadata: CardSchemeMetadata?
    var fieldVariant: FieldVariant

    public init(required: Bool? = false, enableCardIcon: Bool = true, format: String = "mm/yy", translation: [ Character: String ]? = nil, enableCopy: Bool = false, showRequiredAsterisk: Bool = true, fieldVariant: FieldVariant = .outlined) {
        self.required = required!
        self.enableCardIcon = enableCardIcon
        self.format = format
        self.translation = translation
        self.enableCopy = enableCopy
        self.showRequiredAsterisk = showRequiredAsterisk
        self.fieldVariant = fieldVariant

        if self.translation != nil {
            for (key, value) in self.translation! {
                if value == "" {
                    var contextOptions =  ContextOptions()
                    contextOptions.interface = InterfaceName.COLLECT_CONTAINER
                    contextOptions.logLevel = .WARN
                    Log.warn(message: .EMPTY_TRANSLATION_VALUE, values: [], contextOptions: contextOptions)
                }
            }

        }
    }

}
