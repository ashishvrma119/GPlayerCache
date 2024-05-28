//
//  AVPlayerItem+Cache.swift
//  GluedInCache
//

import AVFoundation
import ObjectiveC.runtime

extension AVPlayerItem {
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public convenience init(manager: VideoCacheManager = VideoCacheManager.default,
                            remote url: URL,
                            cacheKey key: VideoCacheKeyType? = nil,
                            cacheFragments: [VideoCacheFragment] = [.prefix(VideoRangeBounds.max)]) {
        
        let `key` = key ?? url.absoluteString.videoCacheMD5
        
        let videoUrl = VideoURL(cacheKey: key, originUrl: url)
        manager.visit(url: videoUrl)
        let concerentDespectQueue = DispatchQueue(label: "com.GluedIn.gluedinconcerent", attributes: .concurrent)
        let loaderDelegate = VideoResourceLoaderDelegate(manager: manager, url: videoUrl, cacheFragments: cacheFragments)
        let urlAsset = AVURLAsset(url: loaderDelegate.url.includeVideoCacheSchemeUrl, options: nil)
        urlAsset.resourceLoader.setDelegate(loaderDelegate, queue: concerentDespectQueue)
        
        self.init(asset: urlAsset)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        resourceLoaderDelegate = loaderDelegate
    }
    
    public func cacheCancel() {
        resourceLoaderDelegate?.cancel()
        resourceLoaderDelegate = nil
    }
    
    /// default is true
    public var allowsCellularAccess: Bool {
        get { return resourceLoaderDelegate?.allowsCellularAccess ?? true }
        set { resourceLoaderDelegate?.allowsCellularAccess = newValue }
    }
}
