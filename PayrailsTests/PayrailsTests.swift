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
}

