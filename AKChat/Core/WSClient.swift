import Foundation

/// 与安卓一致的实时通道：连接 Endpoints.wsURL，首帧发 token 鉴权，收到 ping 回 pong。
final class WSClient {
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectDelay: TimeInterval = 1
    private var stopped = true
    /// 重连延迟块可能在退出登录后才执行，用它作废旧块
    private var generation = 0

    var onMessage: ((String) -> Void)?
    var onState: ((Bool) -> Void)?

    func start() {
        stopped = false
        generation += 1
        connect()
    }

    func stop() {
        stopped = true
        generation += 1
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func connect() {
        guard !stopped, task == nil, let token = SessionStore.shared.token, !token.isEmpty else { return }

        let cfg = URLSessionConfiguration.default
        session = URLSession(configuration: cfg)
        let socket = session!.webSocketTask(with: APIClient.wsURL)
        task = socket
        socket.resume()

        send(["type": "auth", "token": token])
        onState?(true)
        startPing()
        receive()
    }

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.send(["type": "ping"])
        }
    }

    private func send(_ object: [String: Any]) {
        guard
            let task,
            let data = try? JSONSerialization.data(withJSONObject: object),
            let text = String(data: data, encoding: .utf8)
        else { return }
        task.send(.string(text)) { _ in }
    }

    private func receive() {
        guard let task else { return }
        task.receive { [weak self] result in
            /* URLSession 回调在后台线程：统一回主线程处理，避免与 stop()/重连并发改写 task */
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        if text.contains("\"type\":\"ping\"") {
                            self.send(["type": "pong"])
                        } else {
                            self.onMessage?(text)
                        }
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) { self.onMessage?(text) }
                    @unknown default:
                        break
                    }
                    self.reconnectDelay = 1
                    self.receive()
                case .failure:
                    self.onState?(false)
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard !stopped else { return }
        onState?(false)
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped, gen == self.generation else { return }
            self.connect()
        }
    }
}
