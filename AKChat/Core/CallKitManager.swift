import Foundation
import PushKit
import CallKit

/// VoIP 推送 + 系统来电界面（锁屏/后台也能弹）
final class CallKitManager: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
    static let shared = CallKitManager()

    private var registry: PKPushRegistry?
    private var provider: CXProvider?
    private var pending: IncomingCall?
    private var currentUUID: UUID?

    func setup() {
        let r = PKPushRegistry(queue: .main)
        r.delegate = self
        r.desiredPushTypes = [.voIP]
        registry = r

        let cfg = CXProviderConfiguration(localizedName: "AK商聊")
        cfg.supportsVideo = true
        cfg.maximumCallGroups = 1
        cfg.maximumCallsPerCallGroup = 1
        cfg.supportedHandleTypes = [.generic]
        let p = CXProvider(configuration: cfg)
        p.setDelegate(self, queue: .main)
        provider = p
    }

    // MARK: - PushKit

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ) {
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else { return }
        Task { await APIClient.shared.saveVoipToken(token) }
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        let d = payload.dictionaryPayload
        func num(_ k: String) -> Int64 {
            if let n = d[k] as? NSNumber { return n.int64Value }
            if let s = d[k] as? String { return Int64(s) ?? 0 }
            return 0
        }
        let call = IncomingCall(
            id: num("call_id"),
            callerId: num("caller_id"),
            name: (d["caller_name"] as? String) ?? "来电",
            avatar: d["caller_avatar"] as? String,
            callType: Int(num("call_type")) == 2 ? 2 : 1
        )
        guard call.id > 0 else { completion(); return }
        pending = call
        reportIncoming(call)
        completion()
    }

    private func reportIncoming(_ call: IncomingCall) {
        guard let provider else { return }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.name)
        update.localizedCallerName = call.name
        update.hasVideo = call.callType == 2
        let uuid = UUID()
        currentUUID = uuid
        provider.reportNewIncomingCall(with: uuid, update: update) { _ in }
    }

    // MARK: - CallKit

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let c = pending {
            Task {
                await CallManager.shared.accept(
                    callId: c.id,
                    name: c.name,
                    avatar: c.avatar,
                    type: c.callType
                )
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let c = pending {
            Task { await APIClient.shared.callHangup(callId: c.id) }
        }
        Task { @MainActor in CallManager.shared.hangup() }
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in CallManager.shared.reset() }
        pending = nil
    }
}
