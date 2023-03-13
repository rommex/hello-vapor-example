//
//  File.swift
//  
//
//  Created by Roman Medvid on 13.03.2023.
//

import Foundation
import Vapor

var subscriptions: TxsSubscriptions = TxsSubscriptions()

struct TxsSubscriptions {
    private var subs: [HashRecord] = []
    
    var allTokens: [String] { subs.map({ $0.token})}
    
    mutating func addNew(subscription: [String]) -> String {
        let newToken = UUID().uuidString
        subs.append(HashRecord(token: newToken, domains: subscription, lastRequested: nil))
        return newToken
    }
    
    mutating func remove(token: String) {
        subs.removeAll(where: {$0.token == token})
    }
    
    func find(byToken token: String) -> HashRecord?{
        subs.first(where: {$0.token == token})
    }
    
    mutating func update(hash: String, for token: String) {
        guard let enumeratedElement = subs.enumerated().first(where: {$0.element.token == token}) else { return }
        subs[enumeratedElement.offset].hash = hash
        subs[enumeratedElement.offset].lastUpdated = Date()
    }
}

@Sendable func refreshHash(for token: String, request: Request) async {
    guard let hashRecord = subscriptions.find(byToken: token) else { return }
    guard let endpoint = Endpoint.transactionsByDomainsPost(domains: hashRecord.domains, page: 1, perPage: 900) else { return }
    
    
    guard let data = try? await NetworkService().fetchDataPost(for: endpoint, domains: hashRecord.domains, req: request) else { return }
    let hashed = SHA256.hash(data: data).hex
    subscriptions.update(hash: hashed, for: token)
}
