/*
 * Copyright (c) 2022 Skyflow
*/

import Foundation
#if os(iOS)
import UIKit
#endif

internal class StateforText: State
{
    /// true if `SkyflowTextField` input in valid
    internal(set) open var isValid = false

    /// true  if `SkyflowTextField` input is empty
    internal(set) open var isEmpty = false

    /// true if `SkyflowTextField` was edited
    internal(set) open var isDirty = false

    /// represents length of SkyflowTextField
    internal(set) open var inputLength: Int = 0

//    internal(set) open var isComplete = false

    internal(set) open var isFocused = false

    internal(set) open var elementType: ElementType!

    internal(set) open var value: String?
    /// Array of `SkyflowValidationError`. Should be empty when textfield input is valid.
    internal(set) open var validationError = SkyflowValidationError()
    
    internal(set) open var isCustomRuleFailed = false
    internal(set) open var isDefaultRuleFailed = false
    internal(set) open var selectedCardScheme: CardType?

    init(tf: TextField) {
        super.init(columnName: tf.columnName, isRequired: tf.isRequired)
        print("StateforText init - columnName:", tf.columnName)
        print("StateforText init - isRequired:", tf.isRequired)
        
        validationError = tf.validate()
        print("StateforText init - validationError:", validationError)
        
        isDefaultRuleFailed = validationError.count != 0
        let customError = tf.validateCustomRules()
        isCustomRuleFailed = customError.count != 0
        isValid = !(isDefaultRuleFailed || isCustomRuleFailed)
        print("StateforText init - isValid:", isValid)
        
        print("StateforText init - getSecureRawText:", tf.textField.getSecureRawText ?? "nil")
        isEmpty = (tf.textField.getSecureRawText?.count == 0)
        print("StateforText init - isEmpty:", isEmpty)
        
        isDirty = tf.isDirty
        inputLength = tf.textField.getSecureRawText?.count ?? 0
        elementType = tf.collectInput.type
        isFocused = tf.hasFocus
        selectedCardScheme = tf.selectedCardBrand
        
        print("StateforText init - actualValue:", tf.actualValue)
        print("StateforText init - contextOptions.env:", tf.contextOptions.env)
        
        if tf.contextOptions.env == .DEV {
            value = tf.actualValue
        } else {
            if tf.fieldType == .CARD_NUMBER {
                // AMEX supports only first 6 characters as BIN
                if CardType.forCardNumber(cardNumber: tf.actualValue) == .AMEX {
                    value = CreditCard.getBIN(tf.actualValue, 6)
                } else {
                    // Default 8 char BIN for all other card types
                    value = CreditCard.getBIN(tf.actualValue)
                }
            }
        }
        print("StateforText init - final value:", value ?? "nil")
        
        if validationError.count == 0 {
            validationError = customError
        }
    }

    public override func getState() -> [String: Any] {
        var result = [String: Any]()
        result["isRequired"] = isRequired
        result["columnName"] = columnName
        result["isEmpty"] = isEmpty
        result["isDirty"] = isDirty
        result["isValid"] = isValid
        result["inputLength"] = inputLength
        result["validationError"] = validationError
        result["isCustomRuleFailed"] = isCustomRuleFailed
        result["isDefaultRuleFailed"] = isDefaultRuleFailed
        result["value"] = value

        return result
    }

    public func getStateForListener() -> [String: Any] {
        var result = [String: Any]()
        result["isEmpty"] = isEmpty
        result["isValid"] = isValid
        result["elementType"] = elementType
        result["isFocused"] = isFocused
        result["value"] = value == nil ? "" : value
        result["isCustomRuleFailed"] = isCustomRuleFailed
        if elementType == .CARD_NUMBER {
            result["selectedCardScheme"] = selectedCardScheme == nil ? "" : selectedCardScheme?.instance.defaultName.uppercased()
        }
        return result
    }
}
