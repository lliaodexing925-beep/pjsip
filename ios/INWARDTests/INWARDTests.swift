import XCTest
@testable import INWARD

final class INWARDTests: XCTestCase {
    func testServerNormalization() throws {
        XCTAssertEqual(try APIClient.normalizedBaseURL("https://example.com/").absoluteString, "https://example.com")
        XCTAssertThrowsError(try APIClient.normalizedBaseURL("http://example.com"))
        XCTAssertThrowsError(try APIClient.normalizedBaseURL("not a url"))
    }
    func testCatalogMapping() {
        let catalog = Catalog(["rentals": [["id": 1, "name": "测试房源", "rent": 80000, "tags": "留学生可,即入居"]], "products": [], "helpRequests": []])
        XCTAssertEqual(catalog.rentals.first?.name, "测试房源")
        XCTAssertEqual(catalog.rentals.first?.rent, 80000)
        XCTAssertEqual(catalog.rentals.first?.tags.count, 2)
    }
    func testPublicProfileDoesNotRequirePrivateFields() {
        let profile = SocialProfile(["profile": ["publicId": "IW23456789AB", "name": "A"], "followers": 2, "following": 1])
        XCTAssertEqual(profile.publicId, "IW23456789AB")
        XCTAssertEqual(profile.followers, 2)
    }
    func testYenFormatting() { XCTAssertEqual(yen(128000), "¥128,000") }

    func testSendCodeSuccessResponse() throws {
        let data = Data(#"{"result":{"data":{"json":{"ok":true,"expiresIn":600,"resendAfter":60}}}}"#.utf8)
        let value = try APIClient.decodeResponse(data: data, statusCode: 200)
        XCTAssertEqual(value["ok"] as? Bool, true)
        XCTAssertEqual(value["expiresIn"] as? Int, 600)
    }

    func testSendCodeServerErrorIsRecoverable() {
        let data = Data(#"{"error":{"json":{"message":"验证码发送失败，请稍后重试。","code":"INTERNAL_SERVER_ERROR"}}}"#.utf8)
        XCTAssertThrowsError(try APIClient.decodeResponse(data: data, statusCode: 500)) { error in
            XCTAssertEqual(error.localizedDescription, "验证码发送失败，请稍后重试。")
        }
    }

    func testSendCodeRejectsEmptyAndMalformedResponses() {
        XCTAssertThrowsError(try APIClient.decodeResponse(data: Data(), statusCode: 200))
        XCTAssertThrowsError(try APIClient.decodeResponse(data: Data("not json".utf8), statusCode: 200))
        XCTAssertThrowsError(try APIClient.decodeResponse(data: Data(#"{"result":{"data":{}}}"#.utf8), statusCode: 200))
    }

    func testSendCodeAcceptsNullPayload() throws {
        let data = Data(#"{"result":{"data":{"json":null}}}"#.utf8)
        let value = try APIClient.decodeResponse(data: data, statusCode: 200)
        XCTAssertTrue(value["value"] is NSNull)
    }
}
