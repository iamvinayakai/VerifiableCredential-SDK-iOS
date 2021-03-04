/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/


import PromiseKit
import VCNetworking
import VCEntities

enum IssuanceServiceError: Error {
    case unableToCastToPresentationResponseContainer
    case unableToFetchIdentifier
    case contractDoesNotContainIssuerIdentifier
}

public class IssuanceService {
    
    let formatter: IssuanceResponseFormatting
    let apiCalls: IssuanceNetworking
    let identifierService: IdentifierService
    let pairwiseService: PairwiseService
    let linkedDomainService: LinkedDomainService
    let sdkLog: VCSDKLog
    
    public convenience init(correlationVector: CorrelationHeader? = nil) {
        self.init(formatter: IssuanceResponseFormatter(),
                  apiCalls: IssuanceNetworkCalls(correlationVector: correlationVector),
                  identifierService: IdentifierService(),
                  linkedDomainService: LinkedDomainService(correlationVector: correlationVector),
                  pairwiseService: PairwiseService(correlationVector: correlationVector),
                  sdkLog: VCSDKLog.sharedInstance)
    }
    
    init(formatter: IssuanceResponseFormatting,
         apiCalls: IssuanceNetworking,
         identifierService: IdentifierService,
         linkedDomainService: LinkedDomainService,
         pairwiseService: PairwiseService,
         sdkLog: VCSDKLog = VCSDKLog.sharedInstance) {
        self.formatter = formatter
        self.apiCalls = apiCalls
        self.identifierService = identifierService
        self.pairwiseService = pairwiseService
        self.linkedDomainService = linkedDomainService
        self.sdkLog = sdkLog
    }
    
    
    /// TODO: add DNS Binding for contracts
    public func getRequest(usingUrl url: String) -> Promise<IssuanceRequest> {
        return firstly {
            self.apiCalls.getRequest(withUrl: url)
        }.then { signedContract in
            self.formIssuanceRequest(from: signedContract)
        }
    }
    
    private func formIssuanceRequest(from signedContract: SignedContract) -> Promise<IssuanceRequest> {
        let contract = signedContract.content
        
        guard let issuerDid = contract.input?.issuer else {
            return Promise { seal in
                seal.reject(IssuanceServiceError.contractDoesNotContainIssuerIdentifier)
            }
        }
        
        return firstly {
            linkedDomainService.validateLinkedDomain(from: issuerDid)
        }.then { linkedDomainResult in
            Promise { seal in
                seal.fulfill(IssuanceRequest(contract: contract, linkedDomainResult: linkedDomainResult))
            }
        }
    }
    
    public func send(response: IssuanceResponseContainer, isPairwise: Bool = false) -> Promise<VerifiableCredential> {
        return firstly {
            self.exchangeVCsIfPairwise(response: response, isPairwise: isPairwise)
        }.then { response in
            self.formatIssuanceResponse(response: response, isPairwise: isPairwise)
        }.then { signedToken in
            self.apiCalls.sendResponse(usingUrl:  response.audienceUrl, withBody: signedToken)
        }
    }
    
    private func exchangeVCsIfPairwise(response: IssuanceResponseContainer, isPairwise: Bool) -> Promise<IssuanceResponseContainer> {
        if isPairwise {
            return firstly {
                pairwiseService.createPairwiseResponse(response: response)
            }.then { response in
                self.castToIssuanceResponse(from: response)
            }
        } else {
            return Promise { seal in
                seal.fulfill(response)
            }
        }
    }
    
    private func formatIssuanceResponse(response: IssuanceResponseContainer, isPairwise: Bool) -> Promise<IssuanceResponse> {
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
                    throw IssuanceServiceError.unableToFetchIdentifier
                }
                
                sdkLog.logInfo(message: "Signing Issuance Response with Identifier")
                
                seal.fulfill(try self.formatter.format(response: response, usingIdentifier: id))
            } catch {
                seal.reject(error)
            }
        }
    }
    
    private func castToIssuanceResponse(from response: ResponseContaining) -> Promise<IssuanceResponseContainer> {
        return Promise<IssuanceResponseContainer> { seal in
            
            guard let presentationResponse = response as? IssuanceResponseContainer else {
                seal.reject(IssuanceServiceError.unableToCastToPresentationResponseContainer)
                return
            }
            
            seal.fulfill(presentationResponse)
        }
    }
}
