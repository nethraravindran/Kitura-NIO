import NIO
import NIOHTTP1
import Dispatch
import NIOOpenSSL
import SSLService

public class HTTPServer : Server {
    
    public typealias ServerType = HTTPServer

    public var delegate: ServerDelegate?

    public private(set) var port: Int?

    public private(set) var state: ServerState = .unknown

    fileprivate let lifecycleListener = ServerLifecycleListener()

    public var keepAliveState: KeepAliveState = .unlimited

    var ipv4ServerChannel: Channel!

    var ipv6ServerChannel: Channel!

    public var allowPortReuse = false

    let eventLoopGroup = MultiThreadedEventLoopGroup(numThreads: System.coreCount)

    public init() { }

    public var sslConfig: SSLService.Configuration? {
        didSet {
            if let sslConfig = sslConfig {
                // Bridge SSLConfiguration and TLSConfiguration
                let config = SSLConfiguration(sslConfig: sslConfig)
                tlsConfig = config.tlsServerConfig()
            }
        }
    }

    private var tlsConfig: TLSConfiguration?

    private var sslContext: SSLContext?

    public func listen(on port: Int) throws {
        self.port = port

        if let tlsConfig = tlsConfig {
            self.sslContext = try! SSLContext(configuration: tlsConfig)
        }

        //TODO: Add a dummy delegate
        guard let _ = self.delegate else { fatalError("No delegate registered") }
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 100)
            //TODO: always setting to SO_REUSEADDR for now
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.add(handler: IdleStateHandler(allTimeout: TimeAmount.seconds(Int(HTTPHandler.keepAliveTimeout)))).then {
                    channel.pipeline.configureHTTPServerPipeline().then {
                        if let sslCtxt = self.sslContext {
                            _ = channel.pipeline.add(handler: try! OpenSSLServerHandler(context: sslCtxt), first: true)
                        }
                        return channel.pipeline.add(handler: HTTPHandler(for: self))
                    }
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)


        do {
            //To support both IPv4 and IPv6
            ipv4ServerChannel = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
            ipv6ServerChannel = try bootstrap.bind(host: "::1", port: port).wait()

            self.state = .started
            self.lifecycleListener.performStartCallbacks()
        } catch let error {
            self.state = .failed
            self.lifecycleListener.performFailCallbacks(with: error)
            throw error
        }

        let queuedBlock = DispatchWorkItem(block: { 
            try! self.ipv4ServerChannel.closeFuture.wait()
            try! self.ipv6ServerChannel.closeFuture.wait()
            self.state = .stopped
            self.lifecycleListener.performStopCallbacks()
        })
        ListenerGroup.enqueueAsynchronously(on: DispatchQueue.global(), block: queuedBlock)
    }

    public static func listen(on port: Int, delegate: ServerDelegate?) throws -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        try server.listen(on: port)
        return server
    }

    @available(*, deprecated, message: "use 'listen(on:) throws' with 'server.failed(callback:)' instead")
    public func listen(port: Int, errorHandler: ((Swift.Error) -> Void)?) {
        do {
            try listen(on: port)
        } catch let error {
            if let callback = errorHandler {
                callback(error)
            } else {
                //Log.error("Error listening on port \(port): \(error)")
            }
        }
    }

    @available(*, deprecated, message: "use 'listen(on:delegate:) throws' with 'server.failed(callback:)' instead")
    public static func listen(port: Int, delegate: ServerDelegate, errorHandler: ((Swift.Error) -> Void)?) -> ServerType {
        let server = HTTP.createServer()
        server.delegate = delegate
        server.listen(port: port, errorHandler: errorHandler)
        return server
    }
    
    deinit { 
        try! eventLoopGroup.syncShutdownGracefully()
    }

    public func stop() {
        guard ipv4ServerChannel != nil && ipv6ServerChannel != nil else { return }
        try! ipv4ServerChannel.close().wait()
        try! ipv6ServerChannel.close().wait()
        self.state = .stopped
    }

    @discardableResult
    public func started(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStartCallback(perform: self.state == .started, callback)
        return self
    }

    @discardableResult
    public func stopped(callback: @escaping () -> Void) -> Self {
        self.lifecycleListener.addStopCallback(perform: self.state == .stopped, callback)
        return self
    }

    @discardableResult
    public func failed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addFailCallback(callback) 
        return self
    }

    @discardableResult
    public func clientConnectionFailed(callback: @escaping (Swift.Error) -> Void) -> Self {
        self.lifecycleListener.addClientConnectionFailCallback(callback)
        return self
    }
}
