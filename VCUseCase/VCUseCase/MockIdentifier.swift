/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import VCJwt
import VCCrypto
import VCNetworking

public struct MockIdentifier {
    let keyId: VCCryptoSecret
    let id: String = "did:ion:EiDwmXz3VPQYlv0qODOJVovBsumYLO5Y9DrmgwRS1s-FPg?-ion-initial-state=eyJkZWx0YV9oYXNoIjoiRWlCVWNXM2ZnNDNUbGk2LTZabDdSdWVTeFdvY3FrYnlwU3ZMTjdPdHZ0Q1VnUSIsInJlY292ZXJ5X2NvbW1pdG1lbnQiOiJFaUFNektEdFNhem8yc3lXVTFiWTFDakdvNFhsei1lNWRLSk92dUNRN0gxRFB3In0.eyJ1cGRhdGVfY29tbWl0bWVudCI6IkVpQU16S0R0U2F6bzJzeVdVMWJZMUNqR280WGx6LWU1ZEtKT3Z1Q1E3SDFEUHciLCJwYXRjaGVzIjpbeyJhY3Rpb24iOiJyZXBsYWNlIiwiZG9jdW1lbnQiOnsicHVibGljX2tleXMiOlt7ImlkIjoieXl3X3NpZ25fVWhOb2h0TWhfMSIsInR5cGUiOiJFY2RzYVNlY3AyNTZrMVZlcmlmaWNhdGlvbktleTIwMTkiLCJqd2siOnsia3R5IjoiRUMiLCJjcnYiOiJzZWNwMjU2azEiLCJ4IjoiSXI1bHFUMnlEQ1hkV0k4SGdNajJlcno5SFZDaEZGdjRCZDcwb0RxY2x2cyIsInkiOiJfdVNRYjJOTk8zTU1uc1M4M0J5TXhheUdiazNPRFl4QWxNeC1fWU93NW9jIn0sInB1cnBvc2UiOlsiYXV0aCIsImdlbmVyYWwiXX1dfX1dfQ"
    let algorithm: String = "ES256K"
    let keyReference: String = "#yyw_sign_UhNohtMh_1"
    
    public init(keyId: VCCryptoSecret = KeyId(id: UUID())) {
        self.keyId = keyId
    }
}
