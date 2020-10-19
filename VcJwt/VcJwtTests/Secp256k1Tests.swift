/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

@testable import VCJwt
import XCTest
import VCCrypto

class Secp256k1Tests: XCTestCase {
    
    private var testToken: JwsToken<MockClaims>!
    private var expectedResult: Data!
    private let expectedHeader = Header(keyId: "test")
    private let expectedContent = MockClaims(key: "value67")

    override func setUpWithError() throws {
        testToken = JwsToken(headers: expectedHeader, content: expectedContent, signature: nil)
        let hashAlgorithm = Sha256()
        let protectedMessage = try testToken.protectedMessage.data(using: .utf8)!
        expectedResult = hashAlgorithm.hash(data: protectedMessage)
    }

    func testSigner() throws {
        let signer = Secp256k1Signer(using: MockAlgorithm())
        let mockSecret = MockVCCryptoSecret(id: UUID())
        let result = try signer.sign(token: testToken, withSecret: mockSecret)
        XCTAssertEqual(result, expectedResult)
    }
    
    func testGetPublicKey() throws {
        let expectedX = Data(count: 32)
        let expectedY = Data(count: 32)
        let signer = Secp256k1Signer(using: MockAlgorithm(x: expectedX, y: expectedY))
        let expectedKeyId = "keyId354"
        let expectedPubKey = ECPublicJwk(x: expectedX.base64URLEncodedString(), y: expectedY.base64URLEncodedString(), keyId: expectedKeyId)
        let mockSecret = MockVCCryptoSecret(id: UUID())
        let result = try signer.getPublicJwk(from: mockSecret, withKeyId: expectedKeyId)
        XCTAssertEqual(result.x, expectedPubKey.x)
        XCTAssertEqual(result.y, expectedPubKey.y)
        XCTAssertEqual(result.keyId, expectedPubKey.keyId)
    }

    func testVerifierWithNoSignature() throws {
        let verifier = Secp256k1Verifier()
        testToken = JwsToken(headers: expectedHeader, content: expectedContent, signature: nil)
        let publicKey = Secp256k1PublicKey(x: Data(count: 32), y: Data(count: 32))!
        let result = try verifier.verify(token: testToken, usingPublicKey: publicKey)
        XCTAssertEqual(result, false)
    }
    
    func testVerifierWithSignatureWithPublicKey() throws {
        let verifier = Secp256k1Verifier(using: MockAlgorithm())
        testToken = JwsToken(headers: expectedHeader, content: expectedContent, signature: "testSignature".data(using: .utf8))
        let publicKey = Secp256k1PublicKey(x: Data(count: 32), y: Data(count: 32))!
        let result = try verifier.verify(token: testToken, usingPublicKey: publicKey)
        XCTAssertEqual(result, true)
    }
}
