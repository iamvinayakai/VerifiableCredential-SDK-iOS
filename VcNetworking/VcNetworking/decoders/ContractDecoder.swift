/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import Foundation

struct ContractDecoder: Decoding {
    typealias Decodable = Contract
    
    let decoder = JSONDecoder()
    
    func decode(data: Data) throws -> Contract {
        return try decoder.decode(Contract.self, from: data)
    }
}
