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
    case noKeyIdInRequestHeader
    case requestDoesNotContainIssuerIdentifier
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
        return firstly {
            self.getRequestUriPromise(from: urlStr)
        }.then { requestUri in
            self.fetchValidatedRequest(usingUrl: requestUri)
        }.then { presentationRequestToken in
            self.formPresentationRequest(from: presentationRequestToken)
        }
    }
    
    public func send(response: PresentationResponseContainer, isPairwise: Bool = false) -> Promise<String?> {
        return firstly {
            self.exchangeVCsIfPairwise(response: response, isPairwise: isPairwise)
        }.then { response in
            self.formatPresentationResponse(response: response, isPairwise: isPairwise)
        }.then { signedToken in
            self.presentationApiCalls.sendResponse(usingUrl:  response.audienceUrl, withBody: signedToken)
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
        
        guard let issuer = token.content.issuer else {
            return Promise { seal in
                seal.reject(PresentationServiceError.requestDoesNotContainIssuerIdentifier)
            }
        }
        
        return firstly {
            self.linkedDomainService.validateLinkedDomain(from: issuer)
        }.then { result in
            Promise { seal in
                seal.fulfill(PresentationRequest(from: token, linkedDomainResult: result))
            }
        }
    }
    
    private func fetchValidatedRequest(usingUrl url: String) -> Promise<PresentationRequestToken> {
        return firstly {
            self.presentationApiCalls.getRequest(withUrl: url)
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
    
    private func wrapValidationInPromise(request: PresentationRequestToken, usingKeys keys: [IdentifierDocumentPublicKey]) -> Promise<PresentationRequestToken> {
        return Promise { seal in
            do {
                try self.requestValidator.validate(request: request, usingKeys: keys)
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
                
                guard let id = identifier else {
                    throw PresentationServiceError.inputStringNotUri
                }
                
                sdkLog.logInfo(message: "Signing Presentation Response with Identifier")
                
                seal.fulfill(try self.formatter.format(response: response, usingIdentifier: id))
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
}
