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
}
