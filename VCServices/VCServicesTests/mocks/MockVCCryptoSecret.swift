/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import VCCrypto

struct MockVCCryptoSecret: VCCryptoSecret {
    
    var accessGroup: String? = nil
    
    func isValidKey() -> Bool {
        return true
    }
    
    func migrateKey(fromAccessGroup oldAccessGroup: String?) throws { }
    
    var id: UUID = UUID()
}
