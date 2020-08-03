/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import Foundation

final class PostPresentationResponseOperation: NetworkOperation {
    typealias ResponseBody = PresentationServiceResponse
    
    let successHandler: SuccessHandler = SimpleSuccessHandler()
    let failureHandler: FailureHandler = SimpleFailureHandler()
    let retryHandler: RetryHandler = NoRetry()
    let urlSession: URLSession
    let urlRequest: URLRequest
    
    init(withUrl urlStr: String, withBody body: PresentationRequest, serializer: Serializer = Serializer(), urlSession: URLSession = URLSession.shared) throws {
        
        guard let url = URL(string: urlStr) else {
            throw NetworkingError.invalidUrl(withUrl: urlStr)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = Constants.POST
        urlRequest.httpBody = serializer.serialize(object: body)
        urlRequest.addValue(Constants.FORM_URLENCODED, forHTTPHeaderField: Constants.CONTENT_TYPE)
        self.urlRequest = urlRequest
        self.urlSession = urlSession
    }
}
