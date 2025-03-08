//
//  HTTPServer.swift
//  FigmaSimuCast
//
//  Created by Lorant Csonka on 3/8/25.
//

import Foundation
import Network

class HTTPServer {
    private var listener: NWListener?
    private let port: UInt16
    private let imageDataProvider: () -> Data?
    
    init(port: UInt16 = 8080, imageDataProvider: @escaping () -> Data?) {
        self.port = port
        self.imageDataProvider = imageDataProvider
    }
    
    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { connection in
                self.handleConnection(connection)
            }
            listener?.start(queue: .main)
            print("HTTP Server started on port \(port)")
        } catch {
            print("Failed to start HTTP server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { (data, _, _, error) in
            let imageData = self.imageDataProvider() ?? Data()
            var responseHeaders = "HTTP/1.1 200 OK\r\n"
            if !imageData.isEmpty {
                responseHeaders += "Content-Type: image/png\r\n"
                responseHeaders += "Content-Length: \(imageData.count)\r\n"
            } else {
                responseHeaders += "Content-Type: text/plain\r\n"
                responseHeaders += "Content-Length: 0\r\n"
            }
            responseHeaders += "\r\n"
            var response = Data(responseHeaders.utf8)
            response.append(imageData)
            
            connection.send(content: response, completion: .contentProcessed({ sendError in
                connection.cancel()
            }))
        }
    }
}
