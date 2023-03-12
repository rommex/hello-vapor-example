//
//  File.swift
//  
//
//  Created by Roman Medvid on 12.03.2023.
//

import Foundation
import Vapor

public struct Debugger {
    static func printInfo(_ s: String) {
        print ("🟩 \(s)")
    }
    
    public static func printFailure(_ s: String, critical: Bool = false) {
        printInfo("🚨 \(s)")
    }
    
    static func printWarning(_ s: String) {
        print("🟨🔸 WARNING: \(s)")
    }
}


struct NetworkConfig {
    enum NetworkType: String, Codable {
        case mainnet
        case testnet
    }
    
    static var migratedEndpoint: String {
        let isTestnetUsed = false
        if isTestnetUsed {
            return "mobile-staging.api.ud-staging.com"
        } else {
            return "unstoppabledomains.com"
        }
    }
}

enum RequestType: String {
//    case authenticate = "/authenticate"
//    case fetchAllUnclaimedDomains = "/domains/unclaimed"
//    case claim = "/domains/claim"
//    case fetchSiteWallets = "/wallets"
    case transactions = "/txs"
//    case messagesToSign = "/txs/messagesToSign"
//    case meta = "/txs/meta"
//    case domains = "/domains"
//    case version = "/version"
}

struct Endpoint {
    var host: String = NetworkConfig.migratedEndpoint
    let path: String
    let queryItems: [URLQueryItem]
    let body: String
    var headers: [String: String] = [:]
    
    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}

extension Endpoint {
    struct DomainArray: Encodable {
        let domain: [String]
    }
    
    struct TxsArrayRequest: Encodable {
        let txs: DomainArray
    }
    
    static func transactionsByDomainsPost(domains: [String], page: Int, perPage: Int) -> Endpoint? {
        var paramQueryItems: [URLQueryItem] = []
        paramQueryItems.append( URLQueryItem(name: "page", value: "\(page)") )
        paramQueryItems.append( URLQueryItem(name: "perPage", value: "\(perPage)") )
        
        let req = TxsArrayRequest(txs: DomainArray(domain: domains.map({ $0 })))
        guard let json = try? JSONEncoder().encode(req) else { return nil }
        guard let body = String(data: json, encoding: .utf8) else { return nil }

        return composeResolutionEndpoint(paramQueryItems: paramQueryItems,
                                         apiType: .resellers,
                                         requestType: .transactions,
                                         body: body)
    }
    
    static private func composeResolutionEndpoint(paramQueryItems: [URLQueryItem],
                                                  apiType: UDApiType = .resolution,
                                                  requestType: RequestType,
                                                  body: String) -> Endpoint {
        return Endpoint(
            path: "\(apiType.pathRoot)\(requestType.rawValue)",
            queryItems: paramQueryItems,
            body: body,
            headers: NetworkService.headers.appending(dict2: [NetworkService.appVersionHeaderKey: "4.3.0"])
        )
    }
}

extension Dictionary where Key == String, Value == String {
    func appending(dict2: Dictionary<String, String>) -> Dictionary<String, String> {
        self.merging(dict2) { $1 }
    }
}

enum UDApiType: String {
    case resellers = "/api/v1/resellers/mobile-app-v1"
    case resellersV2 = "/api/v2/resellers/mobile_app_v1"
    case resolution = "/api/v1/resolution"
    case webhook = "/api/webhook"

    var pathRoot: String { self.rawValue }
    
}

//struct APIRequest {
//    let url: URL
//    let headers: [String: String]
//    let body: String
//    let method: NetworkService.HttpRequestMethod
//    
//    init (url: URL,
//          headers: [String: String] = [:],
//          body: String,
//          method: NetworkService.HttpRequestMethod = .get) {
//        self.url = url
//        self.headers = headers//.appending(dict2: NetworkConfig.stagingAccessKeyIfNecessary)
//        self.body = body
//        self.method = method
//    }
//}


struct NetworkService {
    struct DebugOptions {
#if TESTFLIGHT
        static let shouldCrashIfBadResponse = false // FALSE if ignoring API errors
#else
        static let shouldCrashIfBadResponse = false // always FALSE
#endif
    }
    
    
    static let startBlockNumberMainnet = "0x8A958B" // Registry Contract creation block
    static let startBlockNumberMRinkeby = "0x7232BC"
    
    enum HttpRequestMethod: String {
        case post = "POST"
        case get = "GET"
        case patch = "PATCH"
        
        var string: String { self.rawValue }
    }
    static let httpSuccessRange = 200...299
    static let headers = [
        "Accept": "application/json",
        "Content-Type": "application/json"]
    
    static let appVersionHeaderKey = "X-IOS-APP-VERSION"
    
    
//        func fetchData(for url: URL,
//                       body: String = "",
//                       method: HttpRequestMethod = .post,
//                       extraHeaders: [String: String]  = [:]) async throws -> Data {
//            let urlRequest = urlRequest(for: url, body: body, method: method, extraHeaders: extraHeaders)
//
//            do {
//                let (data, response) = try await URLSession.shared.data(for: urlRequest, delegate: nil)
//                guard let response = response as? HTTPURLResponse else {
//                    throw NetworkLayerError.badResponseOrStatusCode
//                }
//
//                if response.statusCode < 300 {
//                    return data
//                } else {
//                    if response.statusCode == Constants.backEndThrottleErrorCode {
//                        Debugger.printWarning("Request failed due to backend throttling issue")
//                        throw NetworkLayerError.backendThrottle
//                    }
//                    let message = extractErrorMessage(from: data)
//                    throw NetworkLayerError.badResponseOrStatusCode
//                }
//            } catch {
//                let error = error as NSError
//                switch error.code {
//                case NSURLErrorNetworkConnectionLost, NSURLErrorCancelled:
//                    throw NetworkLayerError.connectionLost
//                case NSURLErrorNotConnectedToInternet:
//                    throw NetworkLayerError.notConnectedToInternet
//                default:
//                    if let networkError = error as? NetworkLayerError {
//                        throw networkError
//                    }
//                    Debugger.printFailure("Error \(error.code) - \(error.localizedDescription)", critical: false)
//                    throw NetworkLayerError.noMessageError
//                }
//            }
//        }
    
    func fetchDataPost(for endpoint: Endpoint, req: Request) async throws -> Data? {
        let tupleArray = endpoint.headers.map { (key, value) -> (String, String) in
            return (key, value)
        }
        let response: ClientResponse = try await req.client.post("https://unstoppabledomains.com/api/v1/resellers/mobile-app-v1/txs?page=1&perPage=1000",
                                                 headers: HTTPHeaders(tupleArray), // tupleArray
                                                                 content: endpoint.body)
        
        let r1 = try await req.client.get("https://unstoppabledomains.com/api/v1/resellers/mobile-app-v1/version")
        switch response.status {
        case .ok: print("OK")
            return response.body?.getData(at: 0, length: response.body?.capacity ?? 0, byteTransferStrategy: .automatic)
        default:
                throw NetworkLayerError.badResponseOrStatusCode
        }
    }
    
}

enum NetworkLayerError: LocalizedError {
    
    case creatingURLFailed
    case badResponseOrStatusCode
    case parsingTxsError
    case responseFailedToParse
    case parsingDomainsError
    case authorizationError
    case noMessageError
    case invalidMessageError
    case noTxHashError
    case noBytesError
    case noNonceError
    case tooManyResponses
    case wrongNamingService
    case failedParseUnsRegistryAddress
    case failedToValidateResolver
    case failedParseProfileData
    case connectionLost
    case notConnectedToInternet
    case failedFetchBalance
    case backendThrottle
    case failedToFindOwnerWallet
    case emptyParameters
    case invalidBlockchainAbbreviation
    case failedBuildSignRequest

    static let tooManyResponsesCode = -32005
    
//    static func parse (errorResponse: ErrorResponseHolder) -> NetworkLayerError? {
//        let error = errorResponse.error
//        if error.code == tooManyResponsesCode {
//            return .tooManyResponses
//        }
//        return nil
//    }
    
    var rawValue: String {
        switch self {
        case .creatingURLFailed: return "creatingURLFailed"
        case .badResponseOrStatusCode: return "BadResponseOrStatusCode"
        case .parsingTxsError: return "parsingTxsError"
        case .responseFailedToParse: return "responseFailedToParse"
        case .parsingDomainsError: return "Failed to get domains from server"
        case .authorizationError: return "The code is wrong or expired. Please retry"
        case .noMessageError: return "noMessageError"
        case .noTxHashError: return "noTxHashError"
        case .noBytesError: return "noBytesError"
        case .noNonceError: return "noNonceError"
        case .tooManyResponses: return "tooManyResponses"
        case .wrongNamingService: return "wrongNamingService"
        case .failedParseUnsRegistryAddress: return "failedParseUnsRegistryAddress"
        case .failedToValidateResolver: return "failedToValidateResolver"
        case .connectionLost: return "connectionLost"
        case .notConnectedToInternet: return "notConnectedToInternet"
        case .failedFetchBalance: return "failedFetchBalance"
        case .backendThrottle: return "backendThrottle"
        case .failedParseProfileData: return "failedParseProfileData"
        case .failedToFindOwnerWallet: return "failedToFindOwnerWallet"
        case .emptyParameters: return "emptyParameters"
        case .invalidMessageError: return "invalidMessageError"
        case .invalidBlockchainAbbreviation: return "invalidBlockchainAbbreviation"
        case .failedBuildSignRequest: return "failedBuildSignRequest"
        }
    }
    
    public var errorDescription: String? {
        return rawValue
    }
}


struct Constants {
    
    static let updateInterval: TimeInterval = 60
        
    static let distanceFromButtonToKeyboard: CGFloat = 16
    static let scrollableContentBottomOffset: CGFloat = 32
    static let ETHRegexPattern = "^0x[a-fA-F0-9]{40}$"
    static let UnstoppableSupportMail = "support@unstoppabledomains.com"
    static let UnstoppableTwitterName = "unstoppableweb"

    static let nonRemovableDomainCoins = ["ETH", "MATIC"]
    static let domainNameMinimumScaleFactor: CGFloat = 0.625
    static let maximumConcurrentNetworkRequestsLimit = 3
    static let backEndThrottleErrorCode = 429
    static let setupRRPromptRepeatInterval = 7
    static var wcConnectionTimeout: TimeInterval = 5
    static let wcNoResponseFromExternalWalletTimeout: TimeInterval = 0.5
    static var deprecatedTLDs: Set<String> = []
    static let imageProfileMaxSize: Int = 4_000_000 // 4 MB
    static let standardWebHosts = ["https://", "http://"]
    static let downloadedImageMaxSize: CGFloat = 512
    static let downloadedIconMaxSize: CGFloat = 128
    static let defaultUNSReleaseVersion = "v0.6.19"
    static let defaultInitials: String = "N/A"
    static let appStoreAppId = "1544748602"
    static let refreshDomainBadgesInterval: TimeInterval = 60 * 3 // 3 min
    
}

private func extractErrorMessage(from taskData: Data?) -> String {
    guard let responseData = taskData,
          let errorResponse = try? JSONDecoder().decode(MobileAPiErrorResponse.self, from: responseData) else {
        return ""
    }
    
    let message = errorResponse.errors
        .map({($0.code ?? "") + " / " + ($0.message ?? "")})
        .joined(separator: " ")
    return message
}

struct ErrorEntry: Decodable {
    let code: String?
    let message: String?
    let field: String?
    let value: String?
    let status: Int?
}

struct MobileAPiErrorResponse: Decodable {
    let errors: [ErrorEntry]
}
