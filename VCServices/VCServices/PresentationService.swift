/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import PromiseKit
import VCNetworking
import VCEntities

enum PresentationServiceError: Error {
    case inputStringNotUri
    case noQueryParametersOnUri
    case noValueForRequestUriQueryParameter
    case noRequestUriQueryParameter
    case unableToCastToPresentationResponseContainer
    case unableToFetchIdentifier
    case noKeyIdInRequestHeader
    case noPublicKeysInIdentifierDocument
    case noIssuerIdentifierInRequest
}

public class PresentationService {
    
    let formatter: PresentationResponseFormatting
    let presentationApiCalls: PresentationNetworking
    let didDocumentDiscoveryApiCalls: DiscoveryNetworking
    let requestValidator: RequestValidating
    let linkedDomainService: LinkedDomainService
    let identifierService: IdentifierService
    let pairwiseService: PairwiseService
    let sdkLog: VCSDKLog
    
    public convenience init(correlationVector: CorrelationHeader? = nil,
                            urlSession: URLSession = URLSession.shared) {
        self.init(formatter: PresentationResponseFormatter(),
                  presentationApiCalls: PresentationNetworkCalls(correlationVector: correlationVector,
                                                                 urlSession: urlSession),
                  didDocumentDiscoveryApiCalls: DIDDocumentNetworkCalls(correlationVector: correlationVector,
                                                                        urlSession: urlSession),
                  requestValidator: PresentationRequestValidator(),
                  linkedDomainService: LinkedDomainService(correlationVector: correlationVector,
                                                           urlSession: urlSession),
                  identifierService: IdentifierService(),
                  pairwiseService: PairwiseService(correlationVector: correlationVector,
                                                   urlSession: urlSession),
                  sdkLog: VCSDKLog.sharedInstance)
    }
    
    init(formatter: PresentationResponseFormatting,
         presentationApiCalls: PresentationNetworking,
         didDocumentDiscoveryApiCalls: DiscoveryNetworking,
         requestValidator: RequestValidating,
         linkedDomainService: LinkedDomainService,
         identifierService: IdentifierService,
         pairwiseService: PairwiseService,
         sdkLog: VCSDKLog = VCSDKLog.sharedInstance) {
        self.formatter = formatter
        self.presentationApiCalls = presentationApiCalls
        self.didDocumentDiscoveryApiCalls = didDocumentDiscoveryApiCalls
        self.requestValidator = requestValidator
        self.linkedDomainService = linkedDomainService
        self.identifierService = identifierService
        self.pairwiseService = pairwiseService
        self.sdkLog = sdkLog
    }
    
    public func getRequest(usingUrl urlStr: String) -> Promise<PresentationRequest> {
        return logTime(name: "Presentation getRequest") {
            firstly {
                self.getRequestUriPromise(from: urlStr)
            }.then { requestUri in
                self.fetchValidatedRequest(usingUrl: requestUri)
            }.then { presentationRequestToken in
                self.formPresentationRequest(from: presentationRequestToken)
            }
        }
    }
    
    public func send(response: PresentationResponseContainer, isPairwise: Bool = false) -> Promise<String?> {
        return logTime(name: "Presentation sendResponse") {
            firstly {
                /// turn off pairwise until we have a better solution.
                self.exchangeVCsIfPairwise(response: response, isPairwise: false)
            }.then { response in
                self.formatPresentationResponse(response: response, isPairwise: false)
            }.then { signedToken in
                self.presentationApiCalls.sendResponse(usingUrl:  response.audienceUrl, withBody: signedToken)
            }
        }
    }
    
    private func getRequestUriPromise(from urlStr: String) -> Promise<String> {
        return Promise { seal in
            do {
                seal.fulfill(try self.getRequestUri(from: urlStr))
            } catch {
                seal.reject(error)
            }
        }
    }
    
    private func getRequestUri(from urlStr: String) throws -> String {
        
        guard let urlComponents = URLComponents(string: urlStr) else { throw PresentationServiceError.inputStringNotUri }
        guard let queryItems = urlComponents.percentEncodedQueryItems else { throw PresentationServiceError.noQueryParametersOnUri }
        
        for queryItem in queryItems {
            if queryItem.name == Constants.REQUEST_URI {
                guard let value = queryItem.value?.removingPercentEncoding
                else { throw PresentationServiceError.noValueForRequestUriQueryParameter }
                return value
            }
        }
        
        throw PresentationServiceError.noRequestUriQueryParameter
    }
    
    private func formPresentationRequest(from token: PresentationRequestToken) -> Promise<PresentationRequest> {
        
        return firstly {
            self.validateLinkedDomainOfRequest(token)
        }.then { result in
            Promise { seal in
                seal.fulfill(PresentationRequest(from: token, linkedDomainResult: result))
            }
        }
    }
    
    private func validateLinkedDomainOfRequest(_ token: PresentationRequestToken) -> Promise<LinkedDomainResult> {
        
        guard let issuer = token.content.clientID else {
            return Promise(error: PresentationServiceError.noIssuerIdentifierInRequest)
        }
        return self.linkedDomainService.validateLinkedDomain(from: issuer)
    }
    
    private func fetchValidatedRequest(usingUrl url: String) -> Promise<PresentationRequestToken> {
        return firstly {
            return self.presentationApiCalls.getRequest(withUrl: url)
        }.then { requestToken in
            self.validateRequest(requestToken)
        }
    }
    
    private func validateRequest(_ request: PresentationRequestToken) -> Promise<PresentationRequestToken> {
        return firstly {
            self.getDIDFromHeader(request: request)
        }.then { did in
            self.didDocumentDiscoveryApiCalls.getDocument(from: did)
        }.then { document in
            self.wrapValidationInPromise(request: request, usingKeys: document.verificationMethod)
        }
    }
    
    private func getDIDFromHeader(request: PresentationRequestToken) -> Promise<String> {
        return Promise { seal in
            
            guard let kid = request.headers.keyId?.split(separator: Constants.FRAGMENT_SEPARATOR),
                  let did = kid.first else {
                
                seal.reject(PresentationServiceError.noKeyIdInRequestHeader)
                return
            }
            
            seal.fulfill(String(did))
        }
    }
    
    private func wrapValidationInPromise(request: PresentationRequestToken, usingKeys keys: [IdentifierDocumentPublicKey]?) -> Promise<PresentationRequestToken> {
        
        guard let publicKeys = keys else {
            return Promise { seal in
                seal.reject(PresentationServiceError.noPublicKeysInIdentifierDocument)
            }
        }
        
        return Promise { seal in
            do {
                try self.requestValidator.validate(request: request, usingKeys: publicKeys)
                seal.fulfill(request)
            } catch {
                seal.reject(error)
            }
        }
    }
    
    private func exchangeVCsIfPairwise(response: PresentationResponseContainer, isPairwise: Bool) -> Promise<PresentationResponseContainer> {
        if isPairwise {
            return firstly {
                pairwiseService.createPairwiseResponse(response: response)
            }.then { response in
                self.castToPresentationResponse(from: response)
            }
        } else {
            return Promise { seal in
                seal.fulfill(response)
            }
        }
    }
    
    private func formatPresentationResponse(response: PresentationResponseContainer, isPairwise: Bool) -> Promise<PresentationResponse> {
        return Promise { seal in
            do {
                
                var identifier: Identifier?
                
                if isPairwise {
                    // TODO: will change when deterministic key generation is implemented.
                    identifier = try identifierService.fetchIdentifier(forId: VCEntitiesConstants.MASTER_ID, andRelyingParty: response.audienceDid)
                } else {
                    identifier = try identifierService.fetchMasterIdentifier()
                }
                
                guard let identifier = identifier else {
                    throw PresentationServiceError.unableToFetchIdentifier
                }
                
                try validateAndHandleKeys(for: identifier)
                
                sdkLog.logVerbose(message: "Signing Presentation Response with Identifier")
                
                seal.fulfill(try self.formatter.format(response: response, usingIdentifier: identifier))
            } catch {
                seal.reject(error)
            }
        }
    }
    
    private func castToPresentationResponse(from response: ResponseContaining) -> Promise<PresentationResponseContainer> {
        return Promise<PresentationResponseContainer> { seal in
            
            guard let presentationResponse = response as? PresentationResponseContainer else {
                seal.reject(PresentationServiceError.unableToCastToPresentationResponseContainer)
                return
            }
            
            seal.fulfill(presentationResponse)
        }
    }
    
    private func validateAndHandleKeys(for identifier: Identifier) throws
    {
        do {
            /// Step 1: Check to see if keys are valid.
            try identifierService.areKeysValid(for: identifier)
        } catch {
            
            /// Step 2: If keys are not valid, check to see if we need to migrate keys.
            if case IdentifierServiceError.keyNotFoundInKeyStore = error
            {
                try migrateKeys()
            }
            
            /// Else, throw error.
            throw error
        }
    }
    
    /// Migrate keys from default access group to new access group.
    private func migrateKeys() throws
    {
        do {
            /// Step 3: migrate keys.
            try VerifiableCredentialSDK.identifierService.migrateKeys(fromAccessGroup: nil)
            sdkLog.logInfo(message: "Keys successfully migrated to new access group.")
        } catch {
            sdkLog.logError(message: "failed to migrate keys to new access group.")
            /// Step 4: If failed to migrate keys, refresh master identifier to get user out of broken state.
            try identifierService.refreshIdentifiers()
            sdkLog.event(name: "test")
            sdkLog.logInfo(message: "New identifier created after failed to migrate key.")
        }
    }
}
