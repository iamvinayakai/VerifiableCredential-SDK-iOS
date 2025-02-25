/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import Foundation
import VCCrypto

struct MockCryptoSecret: VCCryptoSecret {
    
    var accessGroup: String?
    
    var id: UUID
    
    init(id: UUID) {
        self.id = id
    }
    
    func isValidKey() -> Bool {
        return true
    }
    
    func migrateKey(fromAccessGroup oldAccessGroup: String?) throws { }
}
