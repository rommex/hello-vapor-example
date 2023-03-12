import Vapor

var count = 1

// Define a Book struct to hold book data
struct Book: Content {
    let id: Int
    let title: String
    let author: String
}

// Define an Author struct to hold author data
struct Author: Content {
    let name: String
    let bio: String
}

// Create a list of example books
var books = [
    Book(id: 1, title: "To Kill a Mockingbird", author: "Harper Lee"),
    Book(id: 2, title: "1984", author: "George Orwell"),
    Book(id: 3, title: "The Catcher in the Rye", author: "J.D. Salinger")
]

// Create a list of example authors
var authors = [
    Author(name: "Harper Lee", bio: "Nelle Harper Lee was an American novelist best known for her 1960 novel To Kill a Mockingbird."),
    Author(name: "George Orwell", bio: "Eric Arthur Blair, better known by his pen name George Orwell, was an English novelist and essayist."),
    Author(name: "J.D. Salinger", bio: "Jerome David Salinger was an American writer best known for his 1951 novel The Catcher in the Rye.")
]

func routes(_ app: Application) throws {
    app.get("book", ":id") { req -> Book in
        // Get the book ID from the request parameters
        guard let idString = req.parameters.get("id"),
              let id = Int(idString)
        else {
            throw Abort(.badRequest)
        }
        
        // Find the book with the matching ID
        guard let book = books.first(where: { $0.id == id })
        else {
            throw Abort(.notFound)
        }
        
        // Return the book
        return book
    }
    
    app.get("book", ":id", "author") { req -> Author in
        // Get the book ID from the request parameters
        guard let idString = req.parameters.get("id"),
              let id = Int(idString)
        else {
            throw Abort(.badRequest)
        }
        
        // Find the book with the matching ID
        guard let book = books.first(where: { $0.id == id })
        else {
            throw Abort(.badRequest)
        }
        
        guard let author = authors.first(where: { $0.name == book.author })
        else {
            throw Abort(.notFound)
        }
        
        let readBody = try? getDomain(req)
        print(readBody ?? "didn't parse the body")
        
        // Return the book
        return author
    }
    
    struct MyData: Content {
        let pages: [String]
    }

    func getDomain(_ req: Request) throws -> [String] {
        let data = try req.content.decode(MyData.self)
        let response = Response(status: .ok)
        try response.content.encode("Pages received: \(data.pages)")
        return data.pages
    }
    
    app.webSocket("") { req, ws in
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
}
