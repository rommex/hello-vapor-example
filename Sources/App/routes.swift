import Vapor

struct HashRecord {
    let token: String
    var wallets: [String]
    var lastUpdated: Date?
    var lastRequested: Date?
    var hash: String?
}

struct TxsSubscriptions {
    private var subs: [HashRecord] = []
    
    mutating func addNew(subscription: [String]) -> String {
        let newToken = UUID().uuidString
        subs.append(HashRecord(token: newToken, wallets: subscription, lastRequested: nil))
        return newToken
    }
    
    mutating func remove(token: String) {
        subs.removeAll(where: {$0.token == token})
    }
    
    private var hashes: [HashRecord] = []
}

struct WalletList: Content {
    let wallets: [String]
}

var subscriptions: TxsSubscriptions = TxsSubscriptions()

func routes(_ app: Application) throws {
    
    // API for UD:
    // POST /ud/txs/subscribe { wallets: ["0x193497394"] } -> token
    // GET GET ud/txs/unsubscribe/<:token>
    // GET ud/txs/hash/<:token>
    
    app.post("ud", "txs", "subscribe") { req -> String in
        guard let wallets = try? parseWalletList(req) else {
            throw Abort(.badRequest)
        }
        let token = subscriptions.addNew(subscription: wallets)
        
        DispatchQueue.global().async {
            refreshHash(for: token)
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
    
    func parseWalletList(_ req: Request) throws -> [String] {
        let data = try req.content.decode(WalletList.self)
        return data.wallets
    }
    
    func refreshHash(for token: String) {
        // TODO:
    }
    
    func refreshAllHashes() {
        // TODO:
    }

}
