import Foundation
import WebRTC
import SwiftUI

enum CallPhase {
    case idle, calling, connected, ended
}

/// 一对一通话：非 trickle ICE，offer/answer 都等 candidate 收集完成后整段提交
@MainActor
final class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()

    @Published var phase: CallPhase = .idle
    @Published var callId: Int64 = 0
    @Published var peerName = ""
    @Published var peerAvatar: String?
    @Published var callType = 1
    @Published var muted = false
    @Published var cameraOn = true
    @Published var error: String?
    @Published var remoteTrack: RTCVideoTrack?

    private var factory: RTCPeerConnectionFactory?
    private var pc: RTCPeerConnection?
    private var audioTrack: RTCAudioTrack?
    private var videoTrack: RTCVideoTrack?
    private var capturer: RTCCameraVideoCapturer?
    private var pollTask: Task<Void, Never>?
    private var pendingOffer: String?

    var isActive: Bool { phase == .calling || phase == .connected }

    func reset() {
        pollTask?.cancel()
        pollTask = nil
        capturer?.stopCapture()
        capturer = nil
        pc?.close()
        pc = nil
        factory = nil
        audioTrack = nil
        videoTrack = nil
        remoteTrack = nil
        pendingOffer = nil
        callId = 0
        error = nil
        muted = false
        cameraOn = true
        phase = .idle
    }

    func start(peerUid: Int64, name: String, avatar: String?, type: Int) async {
        reset()
        peerName = name
        peerAvatar = avatar
        callType = type
        do {
            let d = try await APIClient.shared.callCreate(toUid: peerUid, callType: type)
            callId = d.callId
            try buildPeer()
            addLocalTracks()
            phase = .calling
            try await makeOffer()
            startPolling()
        } catch {
            self.error = error.localizedDescription
            phase = .ended
        }
    }

    func accept(callId: Int64, name: String, avatar: String?, type: Int) async {
        reset()
        self.callId = callId
        peerName = name
        peerAvatar = avatar
        callType = type
        do {
            try buildPeer()
            addLocalTracks()
            guard let info = try? await APIClient.shared.callInfo(callId: callId),
                  let offer = info.offer, !offer.isEmpty else {
                throw NSError(domain: "call", code: 2, userInfo: [NSLocalizedDescriptionKey: "通话已取消"])
            }
            try await setRemote(offer)
            try await makeAnswer()
            phase = .calling
            startPolling()
        } catch {
            self.error = error.localizedDescription
            phase = .ended
        }
    }

    func hangup() {
        let cid = callId
        pollTask?.cancel()
        pollTask = nil
        capturer?.stopCapture()
        capturer = nil
        pc?.close()
        pc = nil
        phase = .ended
        if cid > 0 {
            Task { await APIClient.shared.callHangup(callId: cid) }
        }
    }

    func toggleMute() {
        muted.toggle()
        audioTrack?.isEnabled = !muted
    }

    func toggleCamera() {
        cameraOn.toggle()
        if let v = videoTrack {
            v.isEnabled = cameraOn
        }
    }

    // MARK: - 内部

    private func buildPeer() throws {
        RTCInitializeSSL()
        let f = RTCPeerConnectionFactory()
        factory = f
        let cfg = RTCConfiguration()
        cfg.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let p = f.peerConnection(with: cfg, constraints: constraints, delegate: self) else {
            throw NSError(domain: "call", code: 3, userInfo: [NSLocalizedDescriptionKey: "创建通话连接失败"])
        }
        pc = p
    }

    private func addLocalTracks() {
        guard let f = factory, let p = pc else { return }
        let audioSource = f.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let a = f.audioTrack(with: audioSource, trackId: "audio0")
        p.add(a, streamIds: ["stream0"])
        audioTrack = a

        if callType == 2 {
            let vs = f.videoSource()
            let v = f.videoTrack(with: vs, trackId: "video0")
            p.add(v, streamIds: ["stream0"])
            videoTrack = v
            let cap = RTCCameraVideoCapturer(delegate: vs)
            capturer = cap
            let devices = RTCCameraVideoCapturer.captureDevices()
            if let device = devices.first(where: { $0.position == .front }) ?? devices.first,
               let format = RTCCameraVideoCapturer.supportedFormats(for: device).last {
                cap.startCapture(with: device, format: format, fps: 30) { _ in }
            }
        }
    }

    private func makeOffer() async throws {
        guard let p = pc else { return }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": callType == 2 ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        let sdp = try await p.offer(for: constraints)
        try await p.setLocalDescription(sdp)
        pendingOffer = sdp.sdp
    }

    private func makeAnswer() async throws {
        guard let p = pc else { return }
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": callType == 2 ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        let sdp = try await p.answer(for: constraints)
        try await p.setLocalDescription(sdp)
    }

    private func setRemote(_ sdp: String) async throws {
        guard let p = pc else { return }
        let desc = RTCSessionDescription(type: .answer, sdp: sdp)
        if pendingOffer != nil || p.remoteDescription == nil {
            try await p.setRemoteDescription(desc)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { return }
                await self.poll()
            }
        }
    }

    private func poll() async {
        guard callId > 0 else { return }
        guard let info = try? await APIClient.shared.callInfo(callId: callId) else { return }
        if let status = info.status, status >= 2 {
            phase = .ended
            pollTask?.cancel()
            return
        }
        guard let p = pc else { return }
        if p.remoteDescription == nil, let answer = info.answer, !answer.isEmpty {
            try? await setRemote(answer)
        }
        if let offer = info.offer, !offer.isEmpty, phase == .calling {
            _ = offer
        }
        if p.remoteDescription != nil, phase != .ended {
            phase = .connected
        }
    }
}

extension CallManager: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        guard newState == .complete, let sdp = peerConnection.localDescription?.sdp else { return }
        Task { @MainActor in
            guard let p = self.pc, let local = p.localDescription else { return }
            if local.type == .offer {
                await APIClient.shared.callOffer(callId: self.callId, sdp: sdp)
            } else if local.type == .answer {
                await APIClient.shared.callAnswer(callId: self.callId, sdp: sdp)
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        guard let track = rtpReceiver.track as? RTCVideoTrack else { return }
        Task { @MainActor in
            self.remoteTrack = track
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor in
            if newState == .failed || newState == .disconnected {
                self.phase = .ended
            } else if newState == .connected || newState == .completed {
                self.phase = .connected
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
}
