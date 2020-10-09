/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import XCTest
import VCCrypto
import VCJwt

@testable import VCEntities

class IdentifierCreatorTests: XCTestCase {
    
    var cryptoOperations: CryptoOperating!
    let expectedResult = "result2353"
    
    override func setUpWithError() throws {
        self.cryptoOperations = MockCryptoOperations(secretStore: SecretStoreMock())
        
        MockCryptoOperations.generateKeyCallCount = 0
    }

    func testCreateIdentifier() throws {
        let creator = IdentifierCreator(cryptoOperations: self.cryptoOperations, identifierFormatter: MockIdentifierFormatter(returningString: self.expectedResult))
        let actualResult = try creator.create()
        XCTAssertEqual(MockCryptoOperations.generateKeyCallCount, 3)
        XCTAssertEqual(actualResult.longFormDid, expectedResult)
    }
    
    func testCreateIdentifierWithCryptoOperations() throws {
        let creator = IdentifierCreator(cryptoOperations: self.cryptoOperations)
        let _ = try creator.create()
        XCTAssertEqual(MockCryptoOperations.generateKeyCallCount, 3)
    }
}
