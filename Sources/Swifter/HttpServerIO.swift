//
//  HttpServer.swift
//  Swifter
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

import Foundation

#if os(Linux)
    import Glibc
    import NSLinux
#endif

open class HttpServerIO {
    
    fileprivate var listenSocket: Socket = Socket(socketFileDescriptor: -1)
    fileprivate var clientSockets: Set<Socket> = []
    fileprivate let clientSocketsLock = NSLock()
    
    open func start(_ listenPort: in_port_t = Constants.DEFAULT_PORT) throws {
        stop()
        listenSocket = try Socket.tcpSocketForListen(listenPort)
        DispatchQueue.global(qos: .background).async {
            while let socket = try? self.listenSocket.acceptClientSocket() {
                HttpServerIO.lock(self.clientSocketsLock) {
                    self.clientSockets.insert(socket)
                }
                DispatchQueue.global(qos: .background).async {
                    let socketAddress = try? socket.peername()
                    let httpParser = HttpParser()                    
                    while var request = try? httpParser.readHttpRequest(socket) {
                        let keepAlive = httpParser.supportsKeepAlive(request.headers)
                        let (params, handler) = self.select(request.method, url: request.url)
                        request.address = socketAddress
                        request.params = params;
                        let response = handler(request)
                        do {
                            try HttpServerIO.respond(socket, response: response, keepAlive: keepAlive)
                        } catch {
                            print("Failed to send response: \(error)")
                            break
                        }
                        if !keepAlive { break }
                    }
                    socket.release()
                    HttpServerIO.lock(self.clientSocketsLock) {
                        self.clientSockets.remove(socket)
                    }
                }
            }
            self.stop()
        }
    }
    
    open func select(_ method: String, url: String) -> ([String: String], (HttpRequest) -> HttpResponse) {
        return ([:], { _ in HttpResponse.notFound })
    }
    
    open func stop() {
        listenSocket.release()
        HttpServerIO.lock(self.clientSocketsLock) {
            for socket in self.clientSockets {
                socket.shutdwn()
            }
            self.clientSockets.removeAll(keepingCapacity: true)
        }
    }
    
    fileprivate class func lock(_ handle: NSLock, closure: () -> ()) {
        handle.lock()
        closure()
        handle.unlock();
    }
    
    fileprivate class func respond(_ socket: Socket, response: HttpResponse, keepAlive: Bool) throws {
        try socket.writeUTF8("HTTP/1.1 \(response.statusCode()) \(response.reasonPhrase())\r\n")
        
        let length = response.body()?.count ?? 0
        try socket.writeUTF8("Content-Length: \(length)\r\n")
        
        if keepAlive {
            try socket.writeUTF8("Connection: keep-alive\r\n")
        }
        for (name, value) in response.headers() {
            try socket.writeUTF8("\(name): \(value)\r\n")
        }
        try socket.writeUTF8("\r\n")
        if let body = response.body() {
            try socket.writeUInt8(body)
        }
    }
}
