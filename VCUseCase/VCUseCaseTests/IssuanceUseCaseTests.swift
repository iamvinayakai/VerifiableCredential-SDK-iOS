/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import XCTest
import VCRepository
import VCEntities

@testable import VCUseCase

class IssuanceUseCaseTests: XCTestCase {
    
    var usecase: IssuanceUseCase!
    var contract: Contract!
    let expectedUrl = "https://test3523.com"

    override func setUpWithError() throws {
        let repo = IssuanceRepository(apiCalls: MockApiCalls())
        let formatter = MockIssuanceResponseFormatter()
        self.usecase = IssuanceUseCase(formatter: formatter, repo: repo)
        
        let encodedContract = TestData.aiContract.rawValue.data(using: .utf8)!
        self.contract = try JSONDecoder().decode(Contract.self, from: encodedContract)
        
        MockIssuanceResponseFormatter.wasFormatCalled = false
    }
    
    func testPublicInit() {
        let usecase = IssuanceUseCase()
        XCTAssertNotNil(usecase.formatter)
        XCTAssertNotNil(usecase.repo)
    }

    func testGetRequest() throws {
        let expec = self.expectation(description: "Fire")
        usecase.getRequest(usingUrl: expectedUrl).done {
            request in
            print(request)
            XCTFail()
            expec.fulfill()
        }.catch { error in
            XCTAssert(MockApiCalls.wasGetCalled)
            XCTAssert(error is MockError)
            expec.fulfill()
        }
        
        wait(for: [expec], timeout: 5)
    }
    
    func testSendResponse() throws {
        let expec = self.expectation(description: "Fire")
        let response = try IssuanceResponseContainer(from: contract, contractUri: expectedUrl)
        usecase.send(response: response, identifier: MockIdentifier()).done {
            response in
            print(response)
            XCTFail()
            expec.fulfill()
        }.catch { error in
            XCTAssert(MockIssuanceResponseFormatter.wasFormatCalled)
            XCTAssert(MockApiCalls.wasPostCalled)
            XCTAssert(error is MockError)
            expec.fulfill()
        }
        
        wait(for: [expec], timeout: 20)
    }
}
