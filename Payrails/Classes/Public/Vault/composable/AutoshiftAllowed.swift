/*
 * Copyright (c) 2022 Skyflow
*/
//
//  Created by Bharti Sagar on 19/07/23.
//

import Foundation

let ALLOWED_FOCUS_AUTO_SHIFT_ELEMENT_TYPES: [ElementType] = [
    .CARD_NUMBER,
    .EXPIRATION_DATE,
    .EXPIRATION_YEAR,
    .EXPIRATION_MONTH
]

func shouldAutoShiftFocus(
    fieldType: ElementType,
    isFirstResponder: Bool,
    lastEditWasDeletion: Bool,
    isEmpty: Bool,
    isValid: Bool
) -> Bool {
    ALLOWED_FOCUS_AUTO_SHIFT_ELEMENT_TYPES.contains(fieldType) &&
    isFirstResponder &&
    !lastEditWasDeletion &&
    !isEmpty &&
    isValid
}
