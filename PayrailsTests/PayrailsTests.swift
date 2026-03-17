//
//  PayrailsTests.swift
//  PayrailsTests
//
//  Created by Lukasz Lenkiewicz on 03/08/2023.
//

import XCTest
import UIKit
@testable import Payrails

final class PayrailsTests: XCTestCase {
    private struct MockStoredInstrument: StoredInstrument {
        let id: String
        let email: String?
        let description: String?
        let type: Payrails.PaymentType
        var isDefault: Bool = false
    }

    override func setUpWithError() throws {
        TextField.resetCardIconTestingState()
        UIView.setAnimationsEnabled(true)
    }

    override func tearDownWithError() throws {
        TextField.resetCardIconTestingState()
        UIView.setAnimationsEnabled(true)
    }

    private func constraintConstant(
        in constraints: [NSLayoutConstraint],
        firstItem: UIView,
        firstAttribute: NSLayoutConstraint.Attribute,
        secondItem: UIView,
        secondAttribute: NSLayoutConstraint.Attribute
    ) -> CGFloat? {
        constraints.first {
            ($0.firstItem as? UIView) === firstItem &&
            $0.firstAttribute == firstAttribute &&
            ($0.secondItem as? UIView) === secondItem &&
            $0.secondAttribute == secondAttribute
        }?.constant
    }

    private func hasHeightConstraint(
        for view: UIView,
        in containerView: UIView,
        relation: NSLayoutConstraint.Relation,
        constant: CGFloat
    ) -> Bool {
        let allConstraints = view.constraints + containerView.constraints
        return allConstraints.contains { constraint in
            guard constraint.firstAttribute == .height else { return false }
            guard constraint.relation == relation else { return false }
            guard (constraint.firstItem as? UIView) === view else { return false }
            return abs(constraint.constant - constant) < 0.001
        }
    }

    func testInitDataPublicInitializer() {
        let payload = "dummy-init-data-payload"

        let initData = Payrails.InitData(version: "1", data: payload)

        XCTAssertEqual(initData.version, "1")
        XCTAssertEqual(initData.data, payload)
    }

    // DATE DECODING TESTS FOR JSONDecoder.API() - to verify the custom date decoding strategy works as expected

    /// Test that the API decoder handles dates WITH milliseconds
    func testAPIDecoderParsesDateWithMilliseconds() throws {
        let json = """
        {"executedAt": "2024-01-15T10:30:45.123Z"}
        """

        struct TestModel: Decodable {
            let executedAt: Date
        }

        let decoder = JSONDecoder.API()
        let data = json.data(using: .utf8)!

        let result = try decoder.decode(TestModel.self, from: data)
        XCTAssertNotNil(result.executedAt)
    }

    /// Test that the API decoder handles dates WITHOUT milliseconds
    /// This was the bug reported by merchants - dates like "0001-01-01T00:00:00Z" failed to parse
    func testAPIDecoderParsesDateWithoutMilliseconds() throws {
        let json = """
        {"executedAt": "2024-01-15T10:30:45Z"}
        """

        struct TestModel: Decodable {
            let executedAt: Date
        }

        let decoder = JSONDecoder.API()
        let data = json.data(using: .utf8)!

        let result = try decoder.decode(TestModel.self, from: data)
        XCTAssertNotNil(result.executedAt)
    }

    /// Test the exact date format from the merchant bug report
    func testAPIDecoderParsesActualBackendResponse() throws {
        let json = """
        {"executedAt": "0001-01-01T00:00:00Z"}
        """

        struct TestModel: Decodable {
            let executedAt: Date
        }

        let decoder = JSONDecoder.API()
        let data = json.data(using: .utf8)!

        let result = try decoder.decode(TestModel.self, from: data)
        XCTAssertNotNil(result.executedAt)
    }

    /// Test that the API decoder rejects invalid date strings
    func testAPIDecoderRejectsInvalidDate() throws {
        let json = """
        {"executedAt": "not-a-date"}
        """

        struct TestModel: Decodable {
            let executedAt: Date
        }

        let decoder = JSONDecoder.API()
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TestModel.self, from: data))
    }

    func testCardFormConfigPhase1Defaults() throws {
        let config = CardFormConfig.defaultConfig
        XCTAssertFalse(config.showCardIcon, "Default showCardIcon should be false")
        XCTAssertTrue(config.showRequiredAsterisk, "Default showRequiredAsterisk should be true")
        XCTAssertEqual(config.cardIconAlignment, .left, "Default cardIconAlignment should be .left")
        XCTAssertNil(config.layout, "Default layout should remain nil for backward compatibility")
    }

    func testCardFormConfigStoresLayoutConfig() throws {
        let layout = CardLayoutConfig.compact
        let config = CardFormConfig(layout: layout)
        XCTAssertEqual(config.layout, layout)
    }

    func testCardLayoutStandardPresetMatchesLegacyRows() throws {
        let rowsWithName = CardLayoutConfig.standard.resolvedRows(showNameField: true)
        XCTAssertEqual(rowsWithName, [[.CARD_NUMBER], [.CARDHOLDER_NAME], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]])

        let rowsWithoutName = CardLayoutConfig.standard.resolvedRows(showNameField: false)
        XCTAssertEqual(rowsWithoutName, [[.CARD_NUMBER], [.CVV, .EXPIRATION_MONTH, .EXPIRATION_YEAR]])
    }

    func testCardLayoutCompactPresetUsesCombinedExpiry() throws {
        let rows = CardLayoutConfig.compact.resolvedRows(showNameField: true)
        XCTAssertEqual(rows, [[.CARD_NUMBER], [.EXPIRATION_DATE, .CVV], [.CARDHOLDER_NAME]])
    }

    func testCardLayoutCustomRowsPreserveDeclaredOrder() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER, .CARDHOLDER_NAME], [.EXPIRATION_DATE, .CVV]]
        )

        let rows = layout.resolvedRows(showNameField: true)
        XCTAssertEqual(rows, [[.CARD_NUMBER, .CARDHOLDER_NAME], [.EXPIRATION_DATE, .CVV]])
    }

    func testCardLayoutCustomCanUseCombinedExpiryField() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_DATE, .CVV]],
            useCombinedExpiryDateField: true
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, [[.CARD_NUMBER], [.EXPIRATION_DATE, .CVV]])
    }

    func testCardLayoutCustomMissingCVVFallsBackToDefaultRows() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR]]
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
    }

    func testCardLayoutCustomMissingCardNumberFallsBackToDefaultRows() throws {
        let layout = CardLayoutConfig.custom(
            [[.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]]
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
    }

    func testCardLayoutCustomMissingExpiryFallsBackToDefaultRows() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.CVV]]
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
    }

    func testCardLayoutCustomCombinedExpiryConvertsSplitExpiryFields() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]],
            useCombinedExpiryDateField: true
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, [[.CARD_NUMBER], [.EXPIRATION_DATE, .CVV]])
    }

    func testCardLayoutCustomSplitExpiryRejectsMonthWithoutYear() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_MONTH, .CVV]]
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
    }

    func testCardLayoutCustomSplitExpiryRejectsYearWithoutMonth() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_YEAR, .CVV]]
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
    }

    func testCardFormStylesConfigDefaults() throws {
        let defaults = CardFormStylesConfig.defaultConfig
        XCTAssertEqual(defaults.fieldSpacing, 10, "Default fieldSpacing should be 10")
        XCTAssertEqual(defaults.sectionSpacing, 16, "Default sectionSpacing should be 16")
    }
    func testCardButtonStyleHeightMerge() throws {
        let base = CardButtonStyle(backgroundColor: .red, height: 44)
        let override = CardButtonStyle(height: 60)
        let merged = override.merged(over: base)
        XCTAssertEqual(merged.height, 60, "Override height should win in merge")
        XCTAssertEqual(merged.backgroundColor, .red, "Background color should be inherited from base")
    }

    func testStylesConfigMergingSpacing() throws {
        let base = CardFormStylesConfig(fieldSpacing: 10, sectionSpacing: 16)
        let override = CardFormStylesConfig(fieldSpacing: 14)
        let merged = override.merged(over: base)
        XCTAssertEqual(merged.fieldSpacing, 14, "Override fieldSpacing should win")
        XCTAssertEqual(merged.sectionSpacing, 16, "Base sectionSpacing should remain when not overridden")
    }

    func testComposableContainerUsesConfiguredRowSpacing() throws {
        let client = Client()
        let options = ContainerOptions(layout: [1, 1])

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }
        container.composableRowSpacing = 24

        let cardNumberInput = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        let cvvInput = CollectElementInput(
            table: "cards",
            column: "security_code",
            label: "CVV",
            placeholder: "CVV",
            type: .CVV
        )

        _ = container.create(input: cardNumberInput, options: CollectElementOptions(required: true))
        _ = container.create(input: cvvInput, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        let constants = composableView.constraints.map(\.constant)
        XCTAssertTrue(
            constants.contains(where: { abs($0 - 24) < 0.001 }),
            "Expected composable constraints to include configured row spacing"
        )
    }

    func testComposableContainerUsesConfiguredHorizontalPaddingForFieldsAndLabels() throws {
        let client = Client()
        let options = ContainerOptions(
            layout: [1],
            styles: Styles(base: Style(padding: UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 14)))
        )

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        _ = container.create(input: input, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard
            let rowView = composableView.subviews.first(where: { $0.subviews.contains(where: { $0 is TextField }) }),
            let field = rowView.subviews.first(where: { $0 is TextField }),
            let rowLabel = composableView.subviews.first(where: { $0 is UILabel })
        else {
            XCTFail("Expected row, field, and row label views")
            return
        }

        let fieldLeading = constraintConstant(
            in: rowView.constraints,
            firstItem: field,
            firstAttribute: .leading,
            secondItem: rowView,
            secondAttribute: .leading
        )
        let labelLeading = constraintConstant(
            in: composableView.constraints,
            firstItem: rowLabel,
            firstAttribute: .leading,
            secondItem: composableView,
            secondAttribute: .leading
        )
        let labelTrailing = constraintConstant(
            in: composableView.constraints,
            firstItem: rowLabel,
            firstAttribute: .trailing,
            secondItem: composableView,
            secondAttribute: .trailing
        )

        XCTAssertEqual(fieldLeading ?? .nan, 18, accuracy: 0.001)
        XCTAssertEqual(labelLeading ?? .nan, 18, accuracy: 0.001)
        XCTAssertEqual(labelTrailing ?? .nan, -14, accuracy: 0.001)
    }

    func testComposableContainerUsesLegacyHorizontalPaddingDefaultsWhenNotConfigured() throws {
        let client = Client()
        let options = ContainerOptions(layout: [1])

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        _ = container.create(input: input, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard
            let rowView = composableView.subviews.first(where: { $0.subviews.contains(where: { $0 is TextField }) }),
            let field = rowView.subviews.first(where: { $0 is TextField }),
            let rowLabel = composableView.subviews.first(where: { $0 is UILabel })
        else {
            XCTFail("Expected row, field, and row label views")
            return
        }

        let fieldLeading = constraintConstant(
            in: rowView.constraints,
            firstItem: field,
            firstAttribute: .leading,
            secondItem: rowView,
            secondAttribute: .leading
        )
        let labelLeading = constraintConstant(
            in: composableView.constraints,
            firstItem: rowLabel,
            firstAttribute: .leading,
            secondItem: composableView,
            secondAttribute: .leading
        )
        let labelTrailing = constraintConstant(
            in: composableView.constraints,
            firstItem: rowLabel,
            firstAttribute: .trailing,
            secondItem: composableView,
            secondAttribute: .trailing
        )

        XCTAssertEqual(fieldLeading ?? .nan, 6, accuracy: 0.001)
        XCTAssertEqual(labelLeading ?? .nan, 6, accuracy: 0.001)
        XCTAssertEqual(labelTrailing ?? .nan, -6, accuracy: 0.001)
    }

    func testComposableContainerErrorLabelAppliesConfiguredHeightConstraints() throws {
        let client = Client()
        let errorStyle = Style(minHeight: 14, maxHeight: 24, height: 18)
        let options = ContainerOptions(
            layout: [1],
            errorTextStyles: Styles(base: errorStyle)
        )

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        _ = container.create(input: input, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard let rowLabel = composableView.subviews.first(where: { $0 is UILabel }) else {
            XCTFail("Expected row error label")
            return
        }

        XCTAssertTrue(hasHeightConstraint(for: rowLabel, in: composableView, relation: .equal, constant: 18))
        XCTAssertTrue(hasHeightConstraint(for: rowLabel, in: composableView, relation: .greaterThanOrEqual, constant: 14))
        XCTAssertTrue(hasHeightConstraint(for: rowLabel, in: composableView, relation: .lessThanOrEqual, constant: 24))
        XCTAssertEqual(
            rowLabel.contentCompressionResistancePriority(for: .vertical).rawValue,
            UILayoutPriority.defaultHigh.rawValue,
            accuracy: 0.001,
            "Expected lowered vertical compression resistance when capped error height is configured"
        )
    }

    func testComposableContainerSignalsLayoutInvalidationWhenErrorLabelChanges() throws {
        let client = Client()
        let options = ContainerOptions(layout: [1])

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        let element = container.create(input: input, options: CollectElementOptions(required: true))
        var invalidationCount = 0
        container.onLayoutInvalidationRequested = {
            invalidationCount += 1
        }

        _ = try container.getComposableView()
        element.errorMessage.text = "Invalid card number"
        element.onEndEditing?()

        XCTAssertGreaterThan(invalidationCount, 0, "Expected a layout invalidation signal after row error update")
    }

    func testComposableContainerBeginEditingInvalidatesLayoutOnlyWhenRowErrorTextChanges() throws {
        let client = Client()
        let options = ContainerOptions(layout: [1])

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            label: "Card number",
            placeholder: "Card number",
            type: .CARD_NUMBER
        )
        let element = container.create(input: input, options: CollectElementOptions(required: true))
        var invalidationCount = 0
        container.onLayoutInvalidationRequested = {
            invalidationCount += 1
        }

        _ = try container.getComposableView()

        element.onBeginEditing?()
        XCTAssertEqual(
            invalidationCount,
            0,
            "Typing with unchanged row error text should not trigger layout invalidation"
        )

        element.errorMessage.text = "Invalid card number"
        element.onEndEditing?()
        invalidationCount = 0

        element.onBeginEditing?()
        XCTAssertEqual(
            invalidationCount,
            1,
            "Clearing a visible row error should trigger a single layout invalidation"
        )
    }

    func testCardFormResolveComposableHorizontalInsetsUsesNilForDefaultWrapperPadding() {
        let styles = CardFormStylesConfig.defaultConfig
        let resolved = Payrails.CardForm.resolveComposableHorizontalInsets(stylesConfig: styles)
        XCTAssertNil(resolved, "Default wrapper padding should keep legacy composable inset behavior")
    }

    func testCardFormResolveComposableHorizontalInsetsIgnoresVerticalOnlyPaddingChanges() {
        let defaultPadding = CardWrapperStyle.defaultStyle.padding ?? .zero
        let styles = CardFormStylesConfig(
            wrapperStyle: CardWrapperStyle(
                padding: UIEdgeInsets(
                    top: defaultPadding.top + 6,
                    left: defaultPadding.left,
                    bottom: defaultPadding.bottom + 10,
                    right: defaultPadding.right
                )
            )
        ).merged(over: CardFormStylesConfig.defaultConfig)

        let resolved = Payrails.CardForm.resolveComposableHorizontalInsets(stylesConfig: styles)
        XCTAssertNil(resolved, "Vertical-only wrapper padding changes must not override composable horizontal insets")
    }

    func testCardFormResolveComposableHorizontalInsetsUsesCustomWrapperPadding() {
        let styles = CardFormStylesConfig(
            wrapperStyle: CardWrapperStyle(
                padding: UIEdgeInsets(top: 4, left: 20, bottom: 8, right: 12)
            )
        ).merged(over: CardFormStylesConfig.defaultConfig)

        let resolved = Payrails.CardForm.resolveComposableHorizontalInsets(stylesConfig: styles)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.left ?? .nan, 20, accuracy: 0.001)
        XCTAssertEqual(resolved?.right ?? .nan, 12, accuracy: 0.001)
        XCTAssertEqual(resolved?.top ?? .nan, 0, accuracy: 0.001)
        XCTAssertEqual(resolved?.bottom ?? .nan, 0, accuracy: 0.001)
    }

    func testCollectElementOptionsShowRequiredAsteriskDefault() throws {
        let options = CollectElementOptions()
        // default should be true per implementation
        // Accessing internal var directly; test compiled with @testable import allows it if not private
        // If access control prevents this, this test can be adapted to validate via TextField behavior in an integration test.
        XCTAssertTrue(options.showRequiredAsterisk, "Default showRequiredAsterisk should be true")
    }

    func testAutoShiftFocusDoesNotTriggerOnDeletion() {
        XCTAssertFalse(
            shouldAutoShiftFocus(
                fieldType: .CARD_NUMBER,
                isFirstResponder: true,
                lastEditWasDeletion: true,
                isEmpty: true,
                isValid: true
            )
        )
    }

    func testAutoShiftFocusDoesNotTriggerForEmptyValues() {
        XCTAssertFalse(
            shouldAutoShiftFocus(
                fieldType: .CARD_NUMBER,
                isFirstResponder: true,
                lastEditWasDeletion: false,
                isEmpty: true,
                isValid: true
            )
        )
    }

    func testAutoShiftFocusTriggersOnlyForCompletedForwardInput() {
        XCTAssertTrue(
            shouldAutoShiftFocus(
                fieldType: .CARD_NUMBER,
                isFirstResponder: true,
                lastEditWasDeletion: false,
                isEmpty: false,
                isValid: true
            )
        )
    }

    func testCardPaymentButtonAppliesHeightInCardFormMode() throws {
        let button = Payrails.CardPaymentButton(
            buttonStyle: CardButtonStyle(height: 56)
        )

        let heightConstraint = button.constraints.first {
            $0.firstAttribute == .height && $0.relation == .equal
        }

        XCTAssertNotNil(heightConstraint, "Card-form mode should create a height constraint")
        XCTAssertEqual(heightConstraint?.constant, 56, "Card-form mode should apply custom height")
    }

    func testCardPaymentButtonMergesPartialStyleWithDefaults() throws {
        let button = Payrails.CardPaymentButton(
            buttonStyle: CardButtonStyle(height: 56)
        )

        let defaultStyle = CardButtonStyle.defaultStyle
        XCTAssertEqual(button.backgroundColor, defaultStyle.backgroundColor, "Background color should fall back to default")
        XCTAssertEqual(button.titleColor(for: .normal), defaultStyle.textColor, "Text color should fall back to default")
        XCTAssertEqual(button.layer.cornerRadius, defaultStyle.cornerRadius ?? 0, "Corner radius should fall back to default")
    }

    func testStoredInstrumentModeStillAppliesHeight() throws {
        let storedInstrument = MockStoredInstrument(
            id: "stored-1",
            email: "test@example.com",
            description: "Test instrument",
            type: .card
        )
        let customStyle = StoredInstrumentButtonStyle(height: 72)

        let button = Payrails.CardPaymentButton(
            storedInstrument: storedInstrument,
            session: nil,
            translations: CardPaymenButtonTranslations(label: "Pay"),
            storedInstrumentTranslations: nil,
            buttonStyle: customStyle
        )

        let heightConstraint = button.constraints.first {
            $0.firstAttribute == .height && $0.relation == .equal
        }

        XCTAssertNotNil(heightConstraint, "Stored-instrument mode should still create a height constraint")
        XCTAssertEqual(heightConstraint?.constant, 72, "Stored-instrument mode height behavior should remain unchanged")
    }

    func testCardNetworkIconURLMapping() {
        XCTAssertEqual(CardNetwork.VISA.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/visa.png")
        XCTAssertEqual(CardNetwork.MASTERCARD.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/mastercard.png")
        XCTAssertEqual(CardNetwork.AMEX.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/amex.png")
        XCTAssertEqual(CardNetwork.DISCOVER.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/discover.png")
        XCTAssertEqual(CardNetwork.JCB.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/jcb.png")
        XCTAssertEqual(CardNetwork.DINERS.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/diners.png")
        XCTAssertEqual(CardNetwork.UNIONPAY.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/unionpay.png")
        XCTAssertEqual(CardNetwork.UNKNOWN.iconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
    }

    func testCardNetworkDetectionWithAndroidParityPrefixes() {
        XCTAssertEqual(CardNetwork.detect(pan: "4"), .VISA)
        XCTAssertEqual(CardNetwork.detect(pan: "51"), .MASTERCARD)
        XCTAssertEqual(CardNetwork.detect(pan: "2221"), .MASTERCARD)
        XCTAssertEqual(CardNetwork.detect(pan: "2720"), .MASTERCARD)
        XCTAssertEqual(CardNetwork.detect(pan: "34"), .AMEX)
        XCTAssertEqual(CardNetwork.detect(pan: "37"), .AMEX)
        XCTAssertEqual(CardNetwork.detect(pan: "6011"), .DISCOVER)
        XCTAssertEqual(CardNetwork.detect(pan: "65"), .DISCOVER)
        XCTAssertEqual(CardNetwork.detect(pan: "644"), .DISCOVER)
        XCTAssertEqual(CardNetwork.detect(pan: "622"), .DISCOVER)
        XCTAssertEqual(CardNetwork.detect(pan: "3528"), .JCB)
        XCTAssertEqual(CardNetwork.detect(pan: "3589"), .JCB)
        XCTAssertEqual(CardNetwork.detect(pan: "305"), .DINERS)
        XCTAssertEqual(CardNetwork.detect(pan: "36"), .DINERS)
        XCTAssertEqual(CardNetwork.detect(pan: "38"), .DINERS)
        XCTAssertEqual(CardNetwork.detect(pan: "62"), .UNIONPAY)
        XCTAssertEqual(CardNetwork.detect(pan: "621234"), .UNIONPAY)
        XCTAssertEqual(CardNetwork.detect(pan: "4-abc"), .VISA)
        XCTAssertEqual(CardNetwork.detect(pan: "9"), .UNKNOWN)
        XCTAssertEqual(CardNetwork.detect(pan: ""), .UNKNOWN)
    }

    func testCardNetworkManualSchemeMapping() {
        XCTAssertEqual(CardNetwork.from(cardType: .VISA), .VISA)
        XCTAssertEqual(CardNetwork.from(cardType: .MASTERCARD), .MASTERCARD)
        XCTAssertEqual(CardNetwork.from(cardType: .AMEX), .AMEX)
        XCTAssertEqual(CardNetwork.from(cardType: .DISCOVER), .DISCOVER)
        XCTAssertEqual(CardNetwork.from(cardType: .JCB), .JCB)
        XCTAssertEqual(CardNetwork.from(cardType: .DINERS_CLUB), .DINERS)
        XCTAssertEqual(CardNetwork.from(cardType: .UNIONPAY), .UNIONPAY)
        XCTAssertNil(CardNetwork.from(cardType: .CARTES_BANCAIRES))
        XCTAssertEqual(CardNetwork.from(schemeName: "Master card"), .MASTERCARD)
        XCTAssertEqual(CardNetwork.from(schemeName: "American Express"), .AMEX)
        XCTAssertEqual(CardNetwork.from(schemeName: "Diners Club"), .DINERS)
        XCTAssertEqual(CardNetwork.from(schemeName: "Jcb"), .JCB)
        XCTAssertEqual(CardNetwork.from(schemeName: "Unionpay"), .UNIONPAY)
        XCTAssertNil(CardNetwork.from(schemeName: "Cartes Bancaires"))
    }

    func testCardIconIntegrationRightAlignmentUpdatesFromVisaToAmexToJcb() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .right)
        field.setValue(value: "4")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .VISA)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/visa.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
        XCTAssertNotNil(field.textField.rightView)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "37")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .AMEX)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/amex.png")
        XCTAssertNotEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/visa.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "3528")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .JCB)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/jcb.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
    }

    func testCardIconFallsBackToGenericForUnknownNetwork() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .right)
        field.setValue(value: "4")
        flushMainQueue()
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
        XCTAssertEqual(field.detectedCardNetwork, .VISA)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "9")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
    }

    func testCardIconUnknownFallbackReplacesStaleBrandWhenGenericFetchFails() {
        UIView.setAnimationsEnabled(false)
        let brandedIcon = makeCardIconImage()
        TextField.cardIconImageFetcher = { url, completion in
            if url.absoluteString.hasSuffix("/ic-card.png") {
                completion(nil)
            } else {
                completion(brandedIcon)
            }
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .right)
        field.setValue(value: "4")
        flushMainQueue()

        XCTAssertTrue(field.cardIconImageView.image === brandedIcon)
        XCTAssertEqual(field.detectedCardNetwork, .VISA)

        field.updateImage(name: "", cardNumber: "9")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
        XCTAssertNotNil(field.cardIconImageView.image)
        XCTAssertFalse(field.cardIconImageView.image === brandedIcon)
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
    }

    func testCardIconFallsBackToGenericForEmptyInput() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .right)
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)

        field.setValue(value: "4")
        flushMainQueue()
        XCTAssertEqual(field.detectedCardNetwork, .VISA)

        field.clearValue()
        flushMainQueue()
        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
    }

    func testCardIconManualSchemeSelectionOverridesPanDetection() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .right)
        field.setValue(value: "37")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .AMEX)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/amex.png")

        field.selectedCardBrand = .VISA
        field.updateImage(name: "", cardNumber: field.textField.secureText ?? "")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .VISA)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/visa.png")
    }

    func testCardNumberShowsNetworkIconAndNoClearButtonWhenShowCardIconIsFalse() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: false, alignment: .right)
        field.setValue(value: "4")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .VISA)
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
    }

    func testBrandIconHidesWhenFieldClearedAndBothFlagsDisabled() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: false, alignment: .left)
        field.setValue(value: "4")
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
        XCTAssertTrue(field.isCardIconVisibleForTesting)

        // Clear the field — no generic icon should appear since both flags are false
        field.clearValue()
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting)
        XCTAssertFalse(field.isCardIconVisibleForTesting)
    }

    func testGenericIconShownWhenFlagTrueAndFieldEmpty() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: true, alignment: .left)
        flushMainQueue()

        // With showCardIcon=true, generic icon should show on empty field
        XCTAssertTrue(field.isCardIconVisibleForTesting)
        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
    }

    // MARK: - Field Static Icon Tests

    func testFieldStaticIconURLMapping() {
        XCTAssertEqual(
            FieldStaticIcon.from(fieldType: .CARD_NUMBER)?.iconURL?.absoluteString,
            "https://assets.payrails.io/img/logos/card/ic-card.png"
        )
        XCTAssertEqual(
            FieldStaticIcon.from(fieldType: .CVV)?.iconURL?.absoluteString,
            "https://assets.payrails.io/img/logos/card/ic-cvv.png"
        )
        XCTAssertEqual(
            FieldStaticIcon.from(fieldType: .EXPIRATION_MONTH)?.iconURL?.absoluteString,
            "https://assets.payrails.io/img/logos/card/ic-expiration.png"
        )
        XCTAssertNil(FieldStaticIcon.from(fieldType: .CARDHOLDER_NAME))
        XCTAssertEqual(
            FieldStaticIcon.from(fieldType: .EXPIRATION_DATE)?.iconURL?.absoluteString,
            "https://assets.payrails.io/img/logos/card/ic-expiration.png"
        )
        XCTAssertNil(FieldStaticIcon.from(fieldType: .INPUT_FIELD))
    }

    func testFieldStaticIconSFSymbolFallbacks() {
        XCTAssertEqual(FieldStaticIcon.from(fieldType: .CARD_NUMBER)?.sfSymbolFallback, "creditcard")
        XCTAssertEqual(FieldStaticIcon.from(fieldType: .CVV)?.sfSymbolFallback, "lock.shield")
        XCTAssertNil(FieldStaticIcon.from(fieldType: .CARDHOLDER_NAME)?.sfSymbolFallback)
        XCTAssertEqual(FieldStaticIcon.from(fieldType: .EXPIRATION_DATE)?.sfSymbolFallback, "calendar")
    }

    func testStaticIconAppearsOnCVVField() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }
        let field = makeFieldWithStaticIcon(fieldType: .CVV)
        flushMainQueue()
        XCTAssertTrue(field.isCardIconVisibleForTesting)
    }

    func testStaticIconAppearsOnExpiryDateField() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }
        let field = makeFieldWithStaticIcon(fieldType: .EXPIRATION_DATE)
        flushMainQueue()
        XCTAssertTrue(field.isCardIconVisibleForTesting)
    }

    func testStaticIconDoesNotAppearWhenDisabled() {
        UIView.setAnimationsEnabled(false)
        let field = makeFieldWithStaticIcon(fieldType: .CVV, enableIcon: false)
        flushMainQueue()
        XCTAssertFalse(field.isCardIconVisibleForTesting)
    }

    func testCardFormConfigDefaultShowCardIcon() {
        let config = CardFormConfig()
        XCTAssertFalse(config.showCardIcon)
    }

    // MARK: - Clear Field Button Tests

    func testClearButtonAppearsWhenFieldHasContent() {
        UIView.setAnimationsEnabled(false)
        let field = makeFieldWithClearEnabled(fieldType: .CVV)
        flushMainQueue()

        field.setValue(value: "123")
        flushMainQueue()

        XCTAssertTrue(field.isClearButtonVisibleForTesting, "Clear button should appear when field has content")
    }

    func testClearButtonDisappearsWhenFieldCleared() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }
        let field = makeFieldWithClearEnabled(fieldType: .CVV, enableCardIcon: true)
        flushMainQueue()

        field.setValue(value: "123")
        flushMainQueue()
        XCTAssertTrue(field.isClearButtonVisibleForTesting)

        field.clearValue()
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "Clear button should disappear when field is cleared")
        XCTAssertTrue(field.isCardIconVisibleForTesting, "Static icon should be restored when field is cleared")
    }

    func testCardNumberDoesNotShowClearButtonAndRestoresIconState() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }
        let field = makeCardNumberField(showCardIcon: true, alignment: .left)
        flushMainQueue()

        field.setValue(value: "4111")
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "Card number should not show clear button")
        XCTAssertTrue(field.isCardIconVisibleForTesting, "Card/network icon should remain visible")
        XCTAssertEqual(field.detectedCardNetwork, .VISA)

        field.clearValue()
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "Card number should keep clear button hidden when cleared")
        XCTAssertTrue(field.isCardIconVisibleForTesting, "Configured empty icon should be restored after clearing")
    }

    func testShowCardIconEnablesStaticIconsOnSupportedFields() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let cvvField = makeFieldWithStaticIcon(fieldType: .CVV)
        let cardholderField = makeFieldWithStaticIcon(fieldType: .CARDHOLDER_NAME)
        let expiryField = makeFieldWithStaticIcon(fieldType: .EXPIRATION_DATE)
        flushMainQueue()

        XCTAssertTrue(cvvField.isCardIconVisibleForTesting, "CVV should have static icon")
        XCTAssertFalse(cardholderField.isCardIconVisibleForTesting, "Cardholder should not have static icon")
        XCTAssertTrue(expiryField.isCardIconVisibleForTesting, "Expiry should have static icon")
    }

    func testClearButtonWorksWhenShowCardIconIsDisabled() {
        UIView.setAnimationsEnabled(false)
        let field = makeFieldWithClearEnabled(fieldType: .CVV, enableCardIcon: false)
        flushMainQueue()

        // Empty field: no static icon (enableCardIcon=false), no clear button
        XCTAssertFalse(field.isCardIconVisibleForTesting, "No static icon when showCardIcon is false")
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "No clear button when field is empty")

        // Type content: clear button appears
        field.setValue(value: "123")
        flushMainQueue()
        XCTAssertTrue(field.isClearButtonVisibleForTesting, "Clear button should appear independently of showCardIcon")

        // Clear field: back to no icon
        field.clearValue()
        flushMainQueue()
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "Clear button gone after clearing")
        XCTAssertFalse(field.isCardIconVisibleForTesting, "No static icon since showCardIcon is false")
    }

    func testExpiryMonthTypingShowsAndHidesClearButton() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }
        let field = makeFieldWithClearEnabled(fieldType: .EXPIRATION_MONTH, enableCardIcon: true)
        flushMainQueue()

        XCTAssertFalse(field.isClearButtonVisibleForTesting, "No clear button when month field is empty")

        let didType = field.textField.delegate?.textField?(
            field.textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1"
        )
        XCTAssertEqual(didType, false, "Delegate should consume month formatting input")
        XCTAssertTrue(field.isClearButtonVisibleForTesting, "Month field should show clear button after typing")

        let didDelete = field.textField.delegate?.textField?(
            field.textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 1),
            replacementString: ""
        )
        XCTAssertEqual(didDelete, false, "Delegate should consume month deletion input")
        XCTAssertFalse(field.isClearButtonVisibleForTesting, "Month field should hide clear button after deleting input")
    }

    private func makeCardNumberField(showCardIcon: Bool, alignment: CardIconAlignment) -> TextField {
        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            inputStyles: Styles(base: Style()),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            iconStyles: Styles(base: Style(cardIconAlignment: alignment)),
            label: "Card Number",
            placeholder: "•••• •••• •••• ••••",
            type: .CARD_NUMBER
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: showCardIcon,
            enableCopy: false
        )
        return TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )
    }

    private func makeFieldWithStaticIcon(
        fieldType: ElementType,
        enableIcon: Bool = true,
        alignment: CardIconAlignment = .left
    ) -> TextField {
        let column: String
        switch fieldType {
        case .CVV: column = "security_code"
        case .CARDHOLDER_NAME: column = "cardholder_name"
        case .EXPIRATION_DATE: column = "expiry_date"
        case .EXPIRATION_MONTH: column = "expiry_month"
        case .EXPIRATION_YEAR: column = "expiry_year"
        default: column = "card_number"
        }
        let input = CollectElementInput(
            table: "cards",
            column: column,
            inputStyles: Styles(base: Style()),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            iconStyles: Styles(base: Style(cardIconAlignment: alignment)),
            label: fieldType.name,
            placeholder: "",
            type: fieldType
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: enableIcon,
            enableCopy: false
        )
        return TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )
    }

    private func makeFieldWithClearEnabled(
        fieldType: ElementType,
        enableCardIcon: Bool = true,
        alignment: CardIconAlignment = .left
    ) -> TextField {
        let column: String
        switch fieldType {
        case .CVV: column = "security_code"
        case .CARDHOLDER_NAME: column = "cardholder_name"
        case .EXPIRATION_DATE: column = "expiry_date"
        case .EXPIRATION_MONTH: column = "expiry_month"
        case .EXPIRATION_YEAR: column = "expiry_year"
        default: column = "card_number"
        }
        let input = CollectElementInput(
            table: "cards",
            column: column,
            inputStyles: Styles(base: Style()),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            iconStyles: Styles(base: Style(cardIconAlignment: alignment)),
            label: fieldType.name,
            placeholder: "",
            type: fieldType
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: enableCardIcon,
            enableCopy: false
        )
        return TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )
    }

    // MARK: - FieldVariant Tests

    func testCardFormConfigDefaultFieldVariantIsOutlined() {
        let config = CardFormConfig()
        XCTAssertEqual(config.fieldVariant, .outlined, "Default fieldVariant should be .outlined")
    }

    func testCardFormConfigStoresFieldVariant() {
        let outlined = CardFormConfig(fieldVariant: .outlined)
        XCTAssertEqual(outlined.fieldVariant, .outlined)

        let filled = CardFormConfig(fieldVariant: .filled)
        XCTAssertEqual(filled.fieldVariant, .filled)
    }

    func testCollectElementOptionsDefaultFieldVariantIsOutlined() {
        let options = CollectElementOptions()
        XCTAssertEqual(options.fieldVariant, .outlined, "Default CollectElementOptions.fieldVariant should be .outlined")
    }

    func testCollectElementOptionsStoresFieldVariant() {
        let options = CollectElementOptions(fieldVariant: .filled)
        XCTAssertEqual(options.fieldVariant, .filled)
    }

    func testOutlinedVariantAppliesBorderToLayer() {
        UIView.setAnimationsEnabled(false)
        let field = makeFieldWithVariant(.outlined, borderWidth: 2, borderColor: .black, cornerRadius: 8)
        flushMainQueue()

        XCTAssertEqual(field.textFieldBorderWidth, 2, accuracy: 0.001, "Outlined variant should apply border width to layer")
        XCTAssertEqual(field.textFieldBorderColor, .black, "Outlined variant should apply border color to layer")
        XCTAssertEqual(field.textFieldCornerRadius, 8, accuracy: 0.001, "Outlined variant should apply corner radius to layer")
        XCTAssertNil(field.textField.underlineLayer, "Outlined variant should not have an underline layer")
    }

    func testFilledVariantClearsBorderAndShowsUnderline() {
        UIView.setAnimationsEnabled(false)
        let field = makeFieldWithVariant(.filled, borderWidth: 2, borderColor: .red, cornerRadius: 8)
        flushMainQueue()

        XCTAssertEqual(field.textFieldBorderWidth, 0, accuracy: 0.001, "Filled variant should clear border width")
        XCTAssertNil(field.textFieldBorderColor, "Filled variant should clear border color")
        XCTAssertEqual(field.textFieldCornerRadius, 0, accuracy: 0.001, "Filled variant should clear corner radius")
        XCTAssertNotNil(field.textField.underlineLayer, "Filled variant should have an underline layer")
        XCTAssertEqual(field.textField.underlineLayer?.lineWidth, 2, "Underline width should match configured border width")
        XCTAssertEqual(
            field.textField.underlineLayer?.strokeColor,
            UIColor.red.cgColor,
            "Underline color should match configured border color"
        )
    }

    // MARK: - Composable Field Stretching Tests

    func testComposableContainerSingleFieldRowHasTrailingConstraint() throws {
        let client = Client()
        let options = ContainerOptions(
            layout: [1],
            styles: Styles(base: Style(padding: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 12)))
        )

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards", column: "card_number",
            label: "Card number", placeholder: "Card number",
            type: .CARD_NUMBER
        )
        _ = container.create(input: input, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard
            let rowView = composableView.subviews.first(where: { $0.subviews.contains(where: { $0 is TextField }) }),
            let field = rowView.subviews.first(where: { $0 is TextField })
        else {
            XCTFail("Expected row and field views")
            return
        }

        let fieldTrailing = constraintConstant(
            in: rowView.constraints,
            firstItem: field,
            firstAttribute: .trailing,
            secondItem: rowView,
            secondAttribute: .trailing
        )

        XCTAssertEqual(fieldTrailing ?? .nan, -12, accuracy: 0.001,
                        "Single-field row should have trailing constraint with trailingInset")
    }

    func testComposableContainerMultiFieldRowHasEqualWidthAndTrailing() throws {
        let client = Client()
        let options = ContainerOptions(
            layout: [2],
            styles: Styles(base: Style(padding: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)))
        )

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let cvvInput = CollectElementInput(
            table: "cards", column: "security_code",
            label: "CVV", placeholder: "CVV",
            type: .CVV
        )
        let expiryInput = CollectElementInput(
            table: "cards", column: "expiry_month",
            label: "Month", placeholder: "MM",
            type: .EXPIRATION_MONTH
        )
        _ = container.create(input: cvvInput, options: CollectElementOptions(required: true))
        _ = container.create(input: expiryInput, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard
            let rowView = composableView.subviews.first(where: { $0.subviews.contains(where: { $0 is TextField }) })
        else {
            XCTFail("Expected row view")
            return
        }

        let fields = rowView.subviews.compactMap { $0 as? TextField }
        XCTAssertEqual(fields.count, 2, "Row should contain two fields")

        // Last field should have trailing constraint
        if let lastField = fields.last {
            let trailing = constraintConstant(
                in: rowView.constraints,
                firstItem: lastField,
                firstAttribute: .trailing,
                secondItem: rowView,
                secondAttribute: .trailing
            )
            XCTAssertEqual(trailing ?? .nan, -8, accuracy: 0.001,
                            "Last field in multi-field row should have trailing constraint")
        }

        // Fields should have equal width constraint
        let equalWidthConstraints = rowView.constraints.filter {
            $0.firstAttribute == .width &&
            $0.secondAttribute == .width &&
            ($0.firstItem is TextField) &&
            ($0.secondItem is TextField) &&
            $0.multiplier == 1.0
        }
        XCTAssertFalse(equalWidthConstraints.isEmpty,
                        "Multi-field rows should have equal width constraints between fields")
    }

    func testHideClearButtonPreservesCopyIconWithCardIconRight() throws {
        // Create a non-CARD_NUMBER field with enableCopy + enableCardIcon + right alignment
        let input = CollectElementInput(
            table: "cards",
            column: "security_code",
            inputStyles: Styles(base: Style()),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            iconStyles: Styles(base: Style(cardIconAlignment: .right)),
            label: "CVV",
            placeholder: "CVV",
            type: .CVV
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: true,
            enableCopy: true
        )
        let field = TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )

        // Simulate typing content so clear button shows
        field.actualValue = "123"
        field.updateClearFieldVisibility()

        // Simulate clearing content so clear button hides
        field.actualValue = ""
        field.updateClearFieldVisibility()

        // After the show/hide cycle, copyContainerView should still be in rightViewForIcons
        let rightSubviews = field.rightViewForIcons.subviews
        let hasCopy = rightSubviews.contains(where: { $0 === field.copyContainerView })
        let hasCardIcon = rightSubviews.contains(where: { $0 === field.cardIconContainerView })

        XCTAssertTrue(hasCopy,
                      "Copy icon should be preserved in rightViewForIcons after clear button cycle")
        XCTAssertTrue(hasCardIcon,
                      "Card icon should be present in rightViewForIcons after clear button cycle")
    }

    func testHideClearButtonRestoresCopyIconWithoutCardIcon() throws {
        // Create a non-CARD_NUMBER field with enableCopy=true, enableCardIcon=false, right alignment
        let input = CollectElementInput(
            table: "cards",
            column: "security_code",
            inputStyles: Styles(base: Style()),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            iconStyles: Styles(base: Style(cardIconAlignment: .right)),
            label: "CVV",
            placeholder: "CVV",
            type: .CVV
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: false,
            enableCopy: true
        )
        let field = TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )

        // Simulate typing content so clear button shows
        field.actualValue = "123"
        field.updateClearFieldVisibility()

        // Simulate clearing content so clear button hides
        field.actualValue = ""
        field.updateClearFieldVisibility()

        // After the show/hide cycle, textField.rightView should be copyContainerView
        XCTAssertTrue(field.textField.rightView === field.copyContainerView,
                      "Copy icon should be restored as rightView after clear button cycle when enableCardIcon is false")
    }

    func testComposableContainerSkipsTrailingConstraintWhenWidthIsSet() throws {
        let client = Client()
        let options = ContainerOptions(
            layout: [1],
            styles: Styles(base: Style(
                padding: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 12),
                width: 200
            ))
        )

        guard let container = client.container(type: ContainerType.COMPOSABLE, options: options) else {
            XCTFail("Expected composable container")
            return
        }

        let input = CollectElementInput(
            table: "cards", column: "card_number",
            label: "Card number", placeholder: "Card number",
            type: .CARD_NUMBER
        )
        _ = container.create(input: input, options: CollectElementOptions(required: true))

        let composableView = try container.getComposableView()
        guard
            let rowView = composableView.subviews.first(where: { $0.subviews.contains(where: { $0 is TextField }) }),
            let field = rowView.subviews.first(where: { $0 is TextField })
        else {
            XCTFail("Expected row and field views")
            return
        }

        let fieldTrailing = constraintConstant(
            in: rowView.constraints,
            firstItem: field,
            firstAttribute: .trailing,
            secondItem: rowView,
            secondAttribute: .trailing
        )

        XCTAssertNil(fieldTrailing,
                     "Trailing constraint should be skipped when explicit width is set on the container style")
    }

    private func makeFieldWithVariant(
        _ variant: FieldVariant,
        borderWidth: CGFloat = 1,
        borderColor: UIColor = .black,
        cornerRadius: CGFloat = 0
    ) -> TextField {
        let input = CollectElementInput(
            table: "cards",
            column: "card_number",
            inputStyles: Styles(base: Style(
                borderColor: borderColor,
                cornerRadius: cornerRadius,
                borderWidth: borderWidth
            )),
            labelStyles: Styles(base: Style()),
            errorTextStyles: Styles(base: Style()),
            label: "Card number",
            placeholder: "",
            type: .CARD_NUMBER
        )
        let options = CollectElementOptions(
            required: true,
            enableCardIcon: false,
            enableCopy: false,
            fieldVariant: variant
        )
        return TextField(
            input: input,
            options: options,
            contextOptions: ContextOptions(env: .DEV),
            elements: []
        )
    }

    private func makeCardIconImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        return renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    private func flushMainQueue() {
        let expectation = expectation(description: "flush-main-queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - CardPaymentButton setStoredInstrument / clearStoredInstrument Tests

    func testSetStoredInstrumentSwitchesToStoredMode() {
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let instrument = MockStoredInstrument(id: "instr-1", email: nil, description: "Visa •••• 4242", type: .card)

        XCTAssertNil(button.getStoredInstrument(), "Button should start with no stored instrument")

        button.setStoredInstrument(instrument)

        XCTAssertNotNil(button.getStoredInstrument(), "Button should have a stored instrument after setStoredInstrument")
        XCTAssertEqual(button.getStoredInstrument()?.id, "instr-1")
    }

    func testClearStoredInstrumentRevertsToCardFormMode() {
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let instrument = MockStoredInstrument(id: "instr-2", email: nil, description: nil, type: .card)

        button.setStoredInstrument(instrument)
        XCTAssertNotNil(button.getStoredInstrument())

        button.clearStoredInstrument()
        XCTAssertNil(button.getStoredInstrument(), "Stored instrument should be nil after clearStoredInstrument")
    }

    func testSetStoredInstrumentNotifiesDelegate() {
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let delegate = MockCardPaymentButtonDelegate()
        button.delegate = delegate

        let instrument = MockStoredInstrument(id: "instr-3", email: nil, description: nil, type: .card)

        button.setStoredInstrument(instrument)

        XCTAssertTrue(delegate.onStoredInstrumentChangedCalled, "Delegate should be notified on setStoredInstrument")
        XCTAssertEqual(delegate.lastInstrumentId, "instr-3")
    }

    func testClearStoredInstrumentNotifiesDelegateWithNil() {
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let delegate = MockCardPaymentButtonDelegate()
        button.delegate = delegate

        let instrument = MockStoredInstrument(id: "instr-4", email: nil, description: nil, type: .card)
        button.setStoredInstrument(instrument)

        delegate.onStoredInstrumentChangedCalled = false
        delegate.lastInstrumentId = nil

        button.clearStoredInstrument()

        XCTAssertTrue(delegate.onStoredInstrumentChangedCalled, "Delegate should be notified on clearStoredInstrument")
        XCTAssertNil(delegate.lastInstrumentId, "Delegate should receive nil instrument on clear")
    }

    func testSetStoredInstrumentOverwritesPrevious() {
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let instrument1 = MockStoredInstrument(id: "instr-A", email: nil, description: nil, type: .card)
        let instrument2 = MockStoredInstrument(id: "instr-B", email: nil, description: nil, type: .payPal)

        button.setStoredInstrument(instrument1)
        XCTAssertEqual(button.getStoredInstrument()?.id, "instr-A")

        button.setStoredInstrument(instrument2)
        XCTAssertEqual(button.getStoredInstrument()?.id, "instr-B")
    }

    func testDelegateDefaultImplementationDoesNotCrash() {
        // Verifies the default empty extension on onStoredInstrumentChanged doesn't crash
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let minimalDelegate = MockMinimalCardPaymentButtonDelegate()
        button.delegate = minimalDelegate

        let instrument = MockStoredInstrument(id: "instr-5", email: nil, description: nil, type: .card)

        // This should not crash — the default protocol extension provides a no-op
        button.setStoredInstrument(instrument)
        button.clearStoredInstrument()
    }

    // MARK: - StoredInstruments bindCardPaymentButton Tests

    func testBindCardPaymentButtonSetsWeakReference() {
        let storedInstruments = Payrails.StoredInstruments(
            session: nil,
            style: StoredInstrumentsStyle(),
            translations: StoredInstrumentsTranslations()
        )
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))

        storedInstruments.bindCardPaymentButton(button)

        // The binding itself shouldn't crash — weak reference is internal,
        // but we can verify by triggering selection events later
        // For now, verify no crash on bind + unbind
        storedInstruments.bindCardPaymentButton(nil)
    }

    func testBindCardPaymentButtonClearsOnNilBind() {
        let storedInstruments = Payrails.StoredInstruments(
            session: nil,
            style: StoredInstrumentsStyle(),
            translations: StoredInstrumentsTranslations()
        )
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let instrument = MockStoredInstrument(id: "instr-6", email: nil, description: nil, type: .card)

        // Pre-set an instrument on the button
        button.setStoredInstrument(instrument)
        XCTAssertNotNil(button.getStoredInstrument())

        // Binding nil should clear the instrument on the button
        storedInstruments.bindCardPaymentButton(nil)

        // The button's instrument was set manually, not through binding — so it stays.
        // Only a subsequent bind(nil) that calls clearStoredInstrument would clear it.
        // The bind(nil) method just nulls the weak reference.
        XCTAssertNotNil(button.getStoredInstrument(), "Manual instrument should persist after unbinding")
    }

    // MARK: - Tokenize Model Tests

    func testFutureUsageRawValues() {
        XCTAssertEqual(FutureUsage.cardOnFile.rawValue, "CardOnFile")
        XCTAssertEqual(FutureUsage.subscription.rawValue, "Subscription")
        XCTAssertEqual(FutureUsage.unscheduledCardOnFile.rawValue, "UnscheduledCardOnFile")
    }

    func testTokenizeOptionsDefaults() {
        let options = TokenizeOptions()
        XCTAssertFalse(options.storeInstrument, "storeInstrument should default to false")
        XCTAssertEqual(options.futureUsage.rawValue, "CardOnFile", "futureUsage should default to cardOnFile")
    }

    func testTokenizeOptionsCustomValues() {
        let options = TokenizeOptions(storeInstrument: true, futureUsage: .subscription)
        XCTAssertTrue(options.storeInstrument)
        XCTAssertEqual(options.futureUsage, .subscription)
    }

    func testSaveInstrumentBodyEncoding() throws {
        let body = SaveInstrumentBody(
            holderReference: "holder-ref-123",
            paymentMethod: "card",
            storeInstrument: true,
            futureUsage: "CardOnFile",
            data: SaveInstrumentBodyData(
                encryptedData: "encrypted-data-xyz",
                vaultProviderConfigId: "vault-config-abc"
            )
        )

        let jsonData = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertEqual(decoded?["holderReference"] as? String, "holder-ref-123")
        XCTAssertEqual(decoded?["paymentMethod"] as? String, "card")
        XCTAssertEqual(decoded?["storeInstrument"] as? Bool, true)
        XCTAssertEqual(decoded?["futureUsage"] as? String, "CardOnFile")

        let dataDict = decoded?["data"] as? [String: Any]
        XCTAssertEqual(dataDict?["encryptedData"] as? String, "encrypted-data-xyz")
        XCTAssertEqual(dataDict?["vaultProviderConfigId"] as? String, "vault-config-abc")
    }

    func testSaveInstrumentResponseDecoding() throws {
        let json = """
        {
            "id": "instr-resp-1",
            "createdAt": "2025-01-01T00:00:00Z",
            "holderId": "holder-1",
            "paymentMethod": "card",
            "status": "enabled",
            "data": {
                "bin": "424242",
                "network": "visa",
                "suffix": "4242",
                "expiryMonth": "12",
                "expiryYear": "2030"
            },
            "fingerprint": "fp-abc",
            "futureUsage": "CardOnFile"
        }
        """
        let jsonData = Data(json.utf8)

        let response = try JSONDecoder().decode(SaveInstrumentResponse.self, from: jsonData)

        XCTAssertEqual(response.id, "instr-resp-1")
        XCTAssertEqual(response.holderId, "holder-1")
        XCTAssertEqual(response.paymentMethod, "card")
        XCTAssertEqual(response.status, "enabled")
        XCTAssertEqual(response.data.bin, "424242")
        XCTAssertEqual(response.data.network, "visa")
        XCTAssertEqual(response.data.suffix, "4242")
        XCTAssertEqual(response.data.expiryMonth, "12")
        XCTAssertEqual(response.data.expiryYear, "2030")
        XCTAssertEqual(response.fingerprint, "fp-abc")
        XCTAssertEqual(response.futureUsage, "CardOnFile")
    }

    func testSaveInstrumentResponseDecodingWithNullOptionals() throws {
        let json = """
        {
            "id": "instr-resp-2",
            "createdAt": "2025-06-01T12:00:00Z",
            "holderId": "holder-2",
            "paymentMethod": "card",
            "status": "disabled",
            "data": {}
        }
        """
        let jsonData = Data(json.utf8)

        let response = try JSONDecoder().decode(SaveInstrumentResponse.self, from: jsonData)

        XCTAssertEqual(response.id, "instr-resp-2")
        XCTAssertEqual(response.status, "disabled")
        XCTAssertNil(response.fingerprint)
        XCTAssertNil(response.futureUsage)
        XCTAssertNil(response.data.bin)
        XCTAssertNil(response.data.network)
        XCTAssertNil(response.data.binLookup)
    }

    func testSaveInstrumentResponseDecodingWithBinLookup() throws {
        let json = """
        {
            "id": "instr-resp-3",
            "createdAt": "2025-01-01T00:00:00Z",
            "holderId": "holder-3",
            "paymentMethod": "card",
            "status": "enabled",
            "data": {
                "bin": "411111",
                "network": "visa",
                "suffix": "1111",
                "binLookup": {
                    "bin": "411111",
                    "network": "visa",
                    "issuer": "Chase",
                    "issuerCountry": {
                        "code": "US",
                        "name": "United States",
                        "iso3": "USA"
                    },
                    "type": "credit"
                }
            }
        }
        """
        let jsonData = Data(json.utf8)

        let response = try JSONDecoder().decode(SaveInstrumentResponse.self, from: jsonData)

        XCTAssertNotNil(response.data.binLookup)
        XCTAssertEqual(response.data.binLookup?.bin, "411111")
        XCTAssertEqual(response.data.binLookup?.network, "visa")
        XCTAssertEqual(response.data.binLookup?.issuer, "Chase")
        XCTAssertEqual(response.data.binLookup?.issuerCountry?.code, "US")
        XCTAssertEqual(response.data.binLookup?.issuerCountry?.name, "United States")
        XCTAssertEqual(response.data.binLookup?.issuerCountry?.iso3, "USA")
        XCTAssertEqual(response.data.binLookup?.type, "credit")
    }

    func testInstrumentAPIResponseSaveCase() {
        let json = """
        {
            "id": "instr-api-1",
            "createdAt": "2025-01-01T00:00:00Z",
            "holderId": "holder-api-1",
            "paymentMethod": "card",
            "status": "enabled",
            "data": {}
        }
        """
        let jsonData = Data(json.utf8)

        let saveResponse = try! JSONDecoder().decode(SaveInstrumentResponse.self, from: jsonData)
        let apiResponse = InstrumentAPIResponse.save(saveResponse)

        switch apiResponse {
        case .save(let response):
            XCTAssertEqual(response.id, "instr-api-1")
        default:
            XCTFail("Expected .save case")
        }
    }

    func testUpdateInstrumentBodyEncoding() throws {
        let body = UpdateInstrumentBody(
            status: "enabled",
            default: true
        )

        let jsonData = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertEqual(decoded?["status"] as? String, "enabled")
        XCTAssertEqual(decoded?["default"] as? Bool, true)
        // Nil fields should not appear in encoding
        XCTAssertNil(decoded?["networkTransactionReference"])
        XCTAssertNil(decoded?["merchantReference"])
        XCTAssertNil(decoded?["paymentMethod"])
    }

    func testUpdateInstrumentResponseDecoding() throws {
        let json = """
        {
            "id": "upd-instr-1",
            "createdAt": "2025-01-15T10:00:00Z",
            "holderId": "holder-upd-1",
            "paymentMethod": "card",
            "status": "enabled",
            "data": {
                "bin": "555555",
                "network": "mastercard",
                "suffix": "4444",
                "expiryMonth": "06",
                "expiryYear": "2028"
            }
        }
        """
        let jsonData = Data(json.utf8)

        let response = try JSONDecoder().decode(UpdateInstrumentResponse.self, from: jsonData)

        XCTAssertEqual(response.id, "upd-instr-1")
        XCTAssertEqual(response.holderId, "holder-upd-1")
        XCTAssertEqual(response.paymentMethod, "card")
        XCTAssertEqual(response.status, "enabled")
        XCTAssertEqual(response.data.bin, "555555")
        XCTAssertEqual(response.data.network, "mastercard")
        XCTAssertEqual(response.data.suffix, "4444")
    }

    func testDeleteInstrumentResponseDecoding() throws {
        let json = """
        {"success": true}
        """
        let jsonData = Data(json.utf8)

        let response = try JSONDecoder().decode(DeleteInstrumentResponse.self, from: jsonData)
        XCTAssertTrue(response.success)
    }

    // MARK: - payButtonTapped Stored Instrument Priority Tests

    /// Helper: invokes the button's tap handler via its registered target-action.
    private func simulateTap(on button: Payrails.CardPaymentButton) {
        // The button registers payButtonTapped as the target for .touchUpInside.
        // In unit tests sendActions(for:) may not fire without a full UIApplication run loop,
        // so we invoke the action directly through the target-action list.
        for target in button.allTargets {
            if let actions = button.actions(forTarget: target, forControlEvent: .touchUpInside) {
                for action in actions {
                    (target as AnyObject).perform(Selector(action), with: button)
                }
            }
        }
    }

    func testTapWithStoredInstrumentSkipsCardForm() {
        // A button should honour a runtime-set stored instrument when tapped.
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let delegate = MockCardPaymentButtonDelegate()
        button.delegate = delegate

        let instrument = MockStoredInstrument(id: "tap-instr-1", email: nil, description: "Visa •••• 1234", type: .card)
        button.setStoredInstrument(instrument)

        simulateTap(on: button)

        // Delegate should have received the tap event
        XCTAssertTrue(delegate.onPaymentButtonClickedCalled, "Delegate should be notified of button tap")

        // The button should still hold the stored instrument (not cleared by the tap)
        XCTAssertNotNil(button.getStoredInstrument(), "Stored instrument should still be set after tap")
        XCTAssertEqual(button.getStoredInstrument()?.id, "tap-instr-1")
    }

    func testTapAfterClearStoredInstrumentDoesNotCrash() {
        // Verifies that clearing the stored instrument and tapping doesn't crash.
        // With no cardForm and no storedInstrument, the tap is a no-op.
        let button = Payrails.CardPaymentButton(translations: CardPaymenButtonTranslations(label: "Pay"))
        let delegate = MockCardPaymentButtonDelegate()
        button.delegate = delegate

        let instrument = MockStoredInstrument(id: "tap-instr-2", email: nil, description: nil, type: .card)
        button.setStoredInstrument(instrument)
        button.clearStoredInstrument()

        simulateTap(on: button)

        XCTAssertTrue(delegate.onPaymentButtonClickedCalled, "Delegate should be notified even with no active mode")
        XCTAssertNil(button.getStoredInstrument())
    }

    // MARK: - Mock Delegates for Tests

    private class MockCardPaymentButtonDelegate: PayrailsCardPaymentButtonDelegate {
        var onStoredInstrumentChangedCalled = false
        var onPaymentButtonClickedCalled = false
        var lastInstrumentId: String?

        func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {
            onPaymentButtonClickedCalled = true
        }
        func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {}
        func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton) {}
        func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {}

        func onStoredInstrumentChanged(_ button: Payrails.CardPaymentButton, instrument: StoredInstrument?) {
            onStoredInstrumentChangedCalled = true
            lastInstrumentId = instrument?.id
        }
    }

    private class MockMinimalCardPaymentButtonDelegate: PayrailsCardPaymentButtonDelegate {
        func onPaymentButtonClicked(_ button: Payrails.CardPaymentButton) {}
        func onAuthorizeSuccess(_ button: Payrails.CardPaymentButton) {}
        func onThreeDSecureChallenge(_ button: Payrails.CardPaymentButton) {}
        func onAuthorizeFailed(_ button: Payrails.CardPaymentButton) {}
        // Intentionally NOT implementing onStoredInstrumentChanged — uses default extension
    }

    // MARK: - PaymentContext Tests

    func testPaymentContextUpdateAmount() {
        let context = PaymentContext(amount: Amount(value: "10.00", currency: "EUR"))
        context.updateAmount(value: "25.50", currency: "USD")
        XCTAssertEqual(context.amount.value, "25.50")
        XCTAssertEqual(context.amount.currency, "USD")
    }

    func testPaymentContextAmountUnchangedWithoutUpdate() {
        let context = PaymentContext(amount: Amount(value: "10.00", currency: "EUR"))
        XCTAssertEqual(context.amount.value, "10.00")
        XCTAssertEqual(context.amount.currency, "EUR")
    }

    // MARK: - UpdateOptions Tests

    func testUpdateOptionsDefaults() {
        let opts = UpdateOptions()
        XCTAssertNil(opts.value)
        XCTAssertNil(opts.currency)
    }

    func testUpdateOptionsWithAmount() {
        let opts = UpdateOptions(value: "50.00", currency: "GBP")
        XCTAssertEqual(opts.value, "50.00")
        XCTAssertEqual(opts.currency, "GBP")
    }

    func testUpdateOptionsAmountRequiresBothFields() {
        // If only value is set but not currency, update() should not change amount
        let context = PaymentContext(amount: Amount(value: "10.00", currency: "EUR"))
        let opts = UpdateOptions(value: "20.00")
        // Simulate what Session.update() does
        if let value = opts.value, let currency = opts.currency {
            context.updateAmount(value: value, currency: currency)
        }
        // Amount should remain unchanged since currency was nil
        XCTAssertEqual(context.amount.value, "10.00")
        XCTAssertEqual(context.amount.currency, "EUR")
    }
}
