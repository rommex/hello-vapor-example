import Vapor

struct HashRecord {
    let token: String
    var domains: [String]
    var lastUpdated: Date?
    var lastRequested: Date?
    var hash: String?
}

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
        return token
    }
        
    app.get("ud", "txs", "unsubscribe", ":token") { req -> String in
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest)
        }
        
        subscriptions.remove(token: token)
        return "OK"
    }
    
    app.get("ud", "txs", "hash", ":token") { req -> String in
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest)
        }
        await refreshHash(for: token, request: req)
        guard let hashRecord = subscriptions.find(byToken: token) else {
            throw Abort(.notFound)
        }
        return hashRecord.hash ?? ""
    }
}

func parseDomainList(_ req: Request) throws -> [String] {
    let data = try req.content.decode(DomainList.self)
    return data.domains
}

struct DomainList: Content {
    let domains: [String]
}
