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

    func testCardLayoutCustomCombinedExpiryRejectsSplitExpiryFields() throws {
        let layout = CardLayoutConfig.custom(
            [[.CARD_NUMBER], [.EXPIRATION_MONTH, .EXPIRATION_YEAR, .CVV]],
            useCombinedExpiryDateField: true
        )

        let rows = layout.resolvedRows(showNameField: false)
        XCTAssertEqual(rows, CardLayoutConfig.defaultRows(showNameField: false))
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

    func testCollectElementOptionsShowRequiredAsteriskDefault() throws {
        let options = CollectElementOptions()
        // default should be true per implementation
        // Accessing internal var directly; test compiled with @testable import allows it if not private
        // If access control prevents this, this test can be adapted to validate via TextField behavior in an integration test.
        XCTAssertTrue(options.showRequiredAsterisk, "Default showRequiredAsterisk should be true")
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
        XCTAssertNotNil(field.textField.rightView)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "37")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .AMEX)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/amex.png")
        XCTAssertNotEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/visa.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "3528")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .JCB)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/jcb.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
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
        XCTAssertEqual(field.detectedCardNetwork, .VISA)

        field.clearValue()
        flushMainQueue()
        field.setValue(value: "9")
        flushMainQueue()

        XCTAssertEqual(field.detectedCardNetwork, .UNKNOWN)
        XCTAssertEqual(field.resolvedCardIconURL?.absoluteString, "https://assets.payrails.io/img/logos/card/ic-card.png")
        XCTAssertTrue(field.isCardIconVisibleForTesting)
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

    func testCardIconDoesNotAppearWhenDisabled() {
        UIView.setAnimationsEnabled(false)
        TextField.cardIconImageFetcher = { _, completion in
            completion(self.makeCardIconImage())
            return nil
        }

        let field = makeCardNumberField(showCardIcon: false, alignment: .right)
        field.setValue(value: "4")
        flushMainQueue()

        XCTAssertFalse(field.isCardIconVisibleForTesting)
        XCTAssertNil(field.resolvedCardIconURL)
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
