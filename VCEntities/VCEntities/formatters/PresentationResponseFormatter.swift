/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import VCJwt

let CREDENTIAL_PATH = "$.attestations.presentations."
let CREDENTIAL_ENCODING = "base64Url"

public protocol PresentationResponseFormatting {
    func format(response: PresentationResponseContainer, usingIdentifier identifier: Identifier) throws -> PresentationResponse
}

public class PresentationResponseFormatter: PresentationResponseFormatting {
    
    let signer: TokenSigning
    let vpFormatter: VerifiablePresentationFormatter
    
    public init(signer: TokenSigning = Secp256k1Signer()) {
        self.signer = signer
        self.vpFormatter = VerifiablePresentationFormatter(signer: signer)
    }
    
    public func format(response: PresentationResponseContainer, usingIdentifier identifier: Identifier) throws -> PresentationResponse {
        let signingKey = identifier.didDocumentKeys.first!
        return try self.createToken(from: response, usingIdentifier: identifier, andSignWith: signingKey)
    }
    
    private func createToken(from response: PresentationResponseContainer, usingIdentifier identifier: Identifier, andSignWith key: KeyContainer) throws -> PresentationResponse {
        let headers = formatHeaders(usingIdentifier: identifier, andSigningKey: key)
        let content = try self.formatClaims(from: response, usingIdentifier: identifier, andSignWith: key)
        var token = JwsToken(headers: headers, content: content)
        try token.sign(using: self.signer, withSecret: key.keyReference)
        return token
    }
    
    private func formatClaims(from response: PresentationResponseContainer, usingIdentifier identifier: Identifier, andSignWith key: KeyContainer) throws -> PresentationResponseClaims {
        
        let publicKey = try signer.getPublicJwk(from: key.keyReference, withKeyId: key.keyId)
        let timeConstraints = createTokenTimeConstraints(expiryInSeconds: response.expiryInSeconds)
        
        var presentationSubmission: PresentationSubmission? = nil
        var attestations: AttestationResponseDescriptor? = nil
        if (!response.requestVCMap.isEmpty) {
            presentationSubmission = self.formatPresentationSubmission(from: response, keyType: publicKey.keyType)
            attestations = try self.formatAttestations(from: response, usingIdentifier: identifier, andSigningKey: key)
        }
        
        return PresentationResponseClaims(publicKeyThumbprint: try publicKey.getThumbprint(),
                                          audience: response.request.content.redirectURI,
                                          did: identifier.longformId,
                                          publicJwk: publicKey,
                                          jti: UUID().uuidString,
                                          presentationSubmission: presentationSubmission,
                                          attestations: attestations,
                                          state: response.request.content.state,
                                          nonce: response.request.content.nonce,
                                          iat: timeConstraints.issuedAt,
                                          exp: timeConstraints.expiration)
    }
    
    private func formatPresentationSubmission(from response: PresentationResponseContainer, keyType: String) -> PresentationSubmission {
        let submissionDescriptor = response.requestVCMap.map { type, _ in
            SubmissionDescriptor(id: type, path: CREDENTIAL_PATH + type, format: keyType, encoding: CREDENTIAL_ENCODING)
        }
        return PresentationSubmission(submissionDescriptors: submissionDescriptor)
    }
    
    private func formatAttestations(from response: PresentationResponseContainer, usingIdentifier identifier: Identifier, andSigningKey key: KeyContainer) throws -> AttestationResponseDescriptor {
        return AttestationResponseDescriptor(presentations: try self.createPresentations(from: response, usingIdentifier: identifier, andSignWith: key))
    }
    
    private func createPresentations(from response: PresentationResponseContainer, usingIdentifier identifier: Identifier, andSignWith key: KeyContainer) throws -> [String: String] {
        return try response.requestVCMap.mapValues { verifiableCredential in
            let vp = try self.vpFormatter.format(toWrap: verifiableCredential, withAudience: response.request.content.issuer, withExpiryInSeconds: response.expiryInSeconds, usingIdentifier: identifier, andSignWith: key)
            return try vp.serialize()
        }
    }
}
