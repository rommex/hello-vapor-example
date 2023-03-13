//
//  File.swift
//  
//
//  Created by Roman Medvid on 13.03.2023.
//

import Foundation
import Vapor

/*
app.webSocket("ud", "subscribe", ":token") { req, ws in
    // Connected WebSocket.
    print(ws)
    
    ws.onText { ws, text in
        // String received by this WebSocket.
        print(text)
        Task {
            try await ws.send("OMG he sent me: \(text)")
        }
    }

    ws.onBinary { ws, binary in
        // [UInt8] received by this WebSocket.
        print(binary)
    }
}
*/
