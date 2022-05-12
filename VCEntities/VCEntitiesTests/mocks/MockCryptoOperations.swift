/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import VCCrypto
import VCToken

@testable import VCEntities

struct MockCryptoOperations: CryptoOperating {

    static var generateKeyCallCount = 0
    let cryptoOperations: CryptoOperating
    let secretStore: SecretStoring
    
    init(secretStore: SecretStoring) {
        self.secretStore = secretStore
        self.cryptoOperations = CryptoOperations(secretStore: secretStore, sdkConfiguration: VCSDKConfiguration.sharedInstance)
    }
    
    func generateKey() throws -> VCCryptoSecret {
        MockCryptoOperations.generateKeyCallCount += 1
        return try self.cryptoOperations.generateKey()
    }
    
    func retrieveKeyFromStorage(withId id: UUID) -> VCCryptoSecret {
        return KeyId(id: id)
    }

    func retrieveKeyIfStored(uuid: UUID) throws -> VCCryptoSecret? {
        return KeyId(id: uuid)
    }
    
    func delete(key: VCCryptoSecret) throws {
        try secretStore.delete(secret: key)
    }
    
    func save(key: VCCryptoSecret) throws {
        try secretStore.save(secret: key)
    }
}
