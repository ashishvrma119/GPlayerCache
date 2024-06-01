//
//  AVPlayerItem+Cache.swift
//  GluedInCache
//

import AVFoundation
import ObjectiveC.runtime

private var resourceLoaderDelegateKey: UInt8 = 0

extension AVPlayerItem {
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public convenience init(manager: VideoCacheManager = VideoCacheManager.default,
                            remote url: URL,
                            cacheKey key: VideoCacheKeyType? = nil,
                            cacheFragments: [VideoCacheFragment] = [.prefix(VideoRangeBounds.max)]) {
        
        let `key` = key ?? url.absoluteString.videoCacheMD5
        let player: AVPlayer = AVPlayer(url: url)
        let videoUrl = VideoURL(cacheKey: key, originUrl: url)
        manager.visit(url: videoUrl)
        let concerentDespectQueue = DispatchQueue(label: "com.GluedIn.gluedinconcerent", attributes: .concurrent)
        let loaderDelegate = VideoResourceLoaderDelegate(manager: manager, url: videoUrl, cacheFragments: cacheFragments, player: player)
        let urlAsset = AVURLAsset(url: loaderDelegate.url.includeVideoCacheSchemeUrl, options: nil)
        urlAsset.resourceLoader.setDelegate(loaderDelegate, queue: concerentDespectQueue)
        
        self.init(asset: urlAsset)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        videoResourceLoaderDelegate = loaderDelegate
    }
    
    
    public func cacheCancel() {
        videoResourceLoaderDelegate?.cancel()
        videoResourceLoaderDelegate = nil
    }
    
    /// default is true
    public var allowsCellularAccess: Bool {
        get { return videoResourceLoaderDelegate?.allowsCellularAccess ?? true }
        set { videoResourceLoaderDelegate?.allowsCellularAccess = newValue }
    }
    
    private weak var videoResourceLoaderDelegate: VideoResourceLoaderDelegate? {
        get {
            return objc_getAssociatedObject(self, &resourceLoaderDelegateKey) as? VideoResourceLoaderDelegate
        }
        set {
            objc_setAssociatedObject(self, &resourceLoaderDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

import Foundation
import SystemConfiguration

public let ReachabilityStatusChangedNotification = "ReachabilityStatusChangedNotification"

public enum ReachabilityType: CustomStringConvertible {
    case wwan
    case wiFi
    
    public var description: String {
        switch self {
        case .wwan: return "WWAN"
        case .wiFi: return "WiFi"
        }
    }
}

public enum ReachabilityStatus: CustomStringConvertible  {
    case offline
    case online(ReachabilityType)
    case unknown
    
    public var description: String {
        switch self {
        case .offline: return "Offline"
        case .online(let type): return "Online (\(type))"
        case .unknown: return "Unknown"
        }
    }
}

public class Reach {
    
    public init() {}
    
    public func connectionStatus() -> ReachabilityStatus {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return .unknown
        }
        
        var flags : SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return .unknown
        }
        
        return ReachabilityStatus(reachabilityFlags: flags)
    }
    
    
    public func monitorReachabilityChanges() {
        let host = "google.com"
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let reachability = SCNetworkReachabilityCreateWithName(nil, host)!
        
        SCNetworkReachabilitySetCallback(reachability, { (_, flags, _) in
            let status = ReachabilityStatus(reachabilityFlags: flags)
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: ReachabilityStatusChangedNotification),
                                            object: nil,
                                            userInfo: ["Status": status.description])
            
            }, &context)
        
        SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), RunLoop.Mode.common as CFString)
    }
    
}

extension ReachabilityStatus {
    public init(reachabilityFlags flags: SCNetworkReachabilityFlags) {
        let connectionRequired = flags.contains(.connectionRequired)
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)
        
        if !connectionRequired && isReachable {
            if isWWAN {
                self = .online(.wwan)
            } else {
                self = .online(.wiFi)
            }
        } else {
            self =  .offline
        }
    }
}
