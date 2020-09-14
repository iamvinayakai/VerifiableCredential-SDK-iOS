/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import VcNetworking
import PromiseKit

public protocol ApiCalling: Fetching, Posting { }

public class ApiCalls: ApiCalling {
    public let networkOperationFactory: NetworkOperationCreating
    
    public init(networkOperationFactory: NetworkOperationCreating = NetworkOperationFactory()) {
        self.networkOperationFactory = networkOperationFactory
    }
}
