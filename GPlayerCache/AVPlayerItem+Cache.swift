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
