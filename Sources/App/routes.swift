import Vapor

struct HashRecord {
    let token: String
    var domains: [String]
    var lastUpdated: Date?
    var lastRequested: Date?
    var hash: String?
}

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

struct DomainList: Content {
    let domains: [String]
}

var subscriptions: TxsSubscriptions = TxsSubscriptions()

func routes(_ app: Application) throws {
    
    // API for UD:
    // POST /ud/txs/subscribe { domains: ["0x193497394"] } -> token
    // GET GET ud/txs/unsubscribe/<:token>
    // GET ud/txs/hash/<:token>
    
    app.post("ud", "txs", "subscribe") { req -> String in
        guard let domains = try? parseDomainList(req) else {
            throw Abort(.badRequest)
        }
        let token = subscriptions.addNew(subscription: domains)
        
        Task {
            await refreshHash(for: token)
        }
        
        return token
    }
        
    app.get("ud", "txs", "unsubscribe", ":token") { req -> String in
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest)
        }
        
        subscriptions.remove(token: token)
        return "OK"
    }
    
    //
    
    app.webSocket("ud", "subscribe", ":token") { req, ws in
        // Connected WebSocket.
        print(ws)
        
        ws.onText { ws, text in
            // String received by this WebSocket.
            print(text)
            Task {
                let result = try await ws.send("OMG he sent me: \(text)")
                print(result)
            }
        }

        ws.onBinary { ws, binary in
            // [UInt8] received by this WebSocket.
            print(binary)
        }
    }
    
    func parseDomainList(_ req: Request) throws -> [String] {
        let data = try req.content.decode(DomainList.self)
        return data.domains
    }
    
    @Sendable func refreshHash(for token: String) async {
        guard let hashRecord = subscriptions.find(byToken: token) else { return }
        guard let endpoint = Endpoint.transactionsByDomainsPost(domains: hashRecord.domains, page: 1, perPage: 1000) else { return }
        guard let data = try? await NetworkService().fetchData(for: endpoint.url!, body: endpoint.body, method: .post, extraHeaders: endpoint.headers) else { return }
        let hashed = SHA256.hash(data: data).hex
        subscriptions.update(hash: hashed, for: token)
    }
    
    func refreshAllHashes() {
        subscriptions.allTokens.forEach { token in
            Task {
                await refreshHash(for: token)
            }
        }
    }

}
