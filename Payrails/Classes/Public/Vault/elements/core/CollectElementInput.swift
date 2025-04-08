/*
 * Copyright (c) 2022 Skyflow
*/

// An Object that describes SkyflowInputField

import Foundation

public struct CollectElementInput {
    var table: String
    var column: String
    var inputStyles: Styles
    var labelStyles: Styles
    var errorTextStyles: Styles
    var iconStyles: Styles
    var label: String
    var placeholder: String
    var type: ElementType?
    var validations: ValidationSet
    var customErrorMessage: String?

    public init(table: String = "", column: String = "",
                inputStyles: Styles? = Styles(), labelStyles: Styles? = Styles(), errorTextStyles: Styles? = Styles(), iconStyles: Styles? = Styles(), label: String? = "",
                placeholder: String? = "", validations: ValidationSet=ValidationSet(),
                customErrorMessage: String? = nil) {
        self.table = table
        self.column = column
        self.inputStyles = inputStyles!
        self.labelStyles = labelStyles!
        self.errorTextStyles = errorTextStyles!
        self.iconStyles = iconStyles!
        self.label = label!
        self.placeholder = placeholder!
        self.validations = validations
        self.customErrorMessage = customErrorMessage
    }

    public init(table: String = "", column: String = "",
                inputStyles: Styles? = Styles(), labelStyles: Styles? = Styles(), errorTextStyles: Styles? = Styles(), iconStyles: Styles? = Styles(), label: String? = "",
                placeholder: String? = "", type: ElementType?, validations: ValidationSet=ValidationSet(),
                customErrorMessage: String? = nil) {
        self.table = table
        self.column = column
        self.inputStyles = inputStyles!
        self.labelStyles = labelStyles!
        self.errorTextStyles = errorTextStyles!
        self.iconStyles = iconStyles!
        self.label = label!
        self.placeholder = placeholder!
        self.type = type
        self.validations = validations
        self.customErrorMessage = customErrorMessage
    }
    
}
