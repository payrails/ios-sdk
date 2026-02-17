//
//  PayrailsTests.swift
//  PayrailsTests
//
//  Created by Lukasz Lenkiewicz on 03/08/2023.
//

import XCTest
@testable import Payrails

final class PayrailsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    }

    func testCardFormStylesConfigDefaults() throws {
        let defaults = CardFormStylesConfig.defaultConfig
        XCTAssertEqual(defaults.fieldSpacing, 10, "Default fieldSpacing should be 10")
        XCTAssertEqual(defaults.sectionSpacing, 16, "Default sectionSpacing should be 16")
        XCTAssertNil(defaults.buttonStyle?.height, "Default button height should be nil (falls back to 44)")
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
}

