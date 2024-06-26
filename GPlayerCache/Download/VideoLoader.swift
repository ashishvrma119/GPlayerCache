//
//  VideoLoader.swift
//
//  GluedInCache
//

import Foundation
import AVFoundation

protocol VideoLoaderType: NSObjectProtocol {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest)
    func remove(loadingRequest: AVAssetResourceLoadingRequest)
    func cancel()
}

protocol VideoLoaderDelegate: NSObjectProtocol {
    
    func loaderAllowWriteData(_ loader: VideoLoader) -> Bool
}

extension VideoLoader: VideoLoaderType {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest) {
        let downloader = VideoDownloader(paths: paths,
                                         session: session,
                                         url: url,
                                         loadingRequest: loadingRequest,
                                         fileHandle: fileHandle,
                                         player: player)
        downloader.delegate = self
        accessQueue.sync {[weak self] in
            guard let weakSelf = self else { return }
            weakSelf.downLoaders.append(downloader)
        }
        downloader.execute()
        print("Total loading request so far \(downLoaders.count)")
        print("Total item in Queue so far \(DownloadQueue.shared.queue)")
    }
    
    func remove(loadingRequest: AVAssetResourceLoadingRequest) {
        downLoaders.removeAll {
            guard $0.loadingRequest == loadingRequest else { return false }
            $0.finish()
            return true
        }
    }
    
    func cancel() {
        VLog(.info, "VideoLoader cancel\n")
        downLoaders.forEach { $0.cancel() }
        downLoaders.removeAll()
    }
}

extension VideoLoader: VideoDownloaderDelegate {
    
    func downloaderAllowWriteData(_ downloader: VideoDownloader) -> Bool {
        return delegate?.loaderAllowWriteData(self) ?? false
    }
    
    func downloaderFinish(_ downloader: VideoDownloader) {
            downloader.finish()
            downLoaders.removeAll { $0.loadingRequest == downloader.loadingRequest }
    }
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?) {
        VLog(.error, "loader download failure: \(String(describing: error))")
        cancel()
    }
}

fileprivate struct DownloadQueue {
    
    static let shared = DownloadQueue()
    
    let queue: OperationQueue = OperationQueue()
    init() {
        queue.name = "com.Gluedin.download.queue"
        queue.maxConcurrentOperationCount = 10
    }
}

class VideoLoader: NSObject {
    
    weak var delegate: VideoLoaderDelegate?
    
    let paths: VideoCachePaths
    let url: VideoURLType
    let cacheFragments: [VideoCacheFragment]
    var player: AVPlayer? // Add a reference to the AVPlayer
    var session: URLSession?
    private let accessQueue = DispatchQueue(label: "com.Gluedin.VideoLoader.accessQueue")

    deinit {
        print("message: VideoLoader cache deinit")
        VLog(.info, "VideoLoader deinit\n")
        cancel()
        session?.invalidateAndCancel()
        session = nil
        player = nil
        delegate = nil
    }
   
    init(paths: VideoCachePaths,
         url: VideoURLType,
         cacheFragments: [VideoCacheFragment],
         allowsCellularAccess: Bool,
         delegate: VideoLoaderDelegate?,
         player: AVPlayer?) {
        
        self.paths = paths
        self.url = url
        self.cacheFragments = cacheFragments
        self.delegate = delegate
        
        super.init()
        
        let configuration = URLSessionConfiguration.default
//        configuration.timeoutIntervalForRequest = 30
//        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.networkServiceType = .video
        configuration.allowsCellularAccess = allowsCellularAccess
        session = URLSession(configuration: configuration,
                             delegate: self,
                             delegateQueue: DownloadQueue.shared.queue)
    }
    
    private lazy var fileHandle: VideoFileHandle = VideoFileHandle(paths: paths,
                                                                   url: url,
                                                                   cacheFragments: cacheFragments)
    
    private var downLoaders_: [VideoDownloaderType] = []
    private let lock = NSLock()
    private let downloadQueue = DispatchQueue(label: "com.Gluedin.VideoLoader.downloadQueue", attributes: .concurrent)

    private var downLoaders: [VideoDownloaderType] {
        get { lock.lock(); defer { lock.unlock() }; return downLoaders_ }
        set { lock.lock(); defer { lock.unlock() }; downLoaders_ = newValue }
    }
}

extension VideoLoader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.useCredential, nil)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        accessQueue.sync {[weak self] in
            guard let weakSelf = self else { return }
            weakSelf.downLoaders.forEach {
                if $0.task == dataTask {
                    $0.dataReceiver?.urlSession?(session,
                                                 dataTask: dataTask,
                                                 didReceive: response,
                                                 completionHandler: completionHandler)
                }
            }
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        accessQueue.sync {[weak self] in
            guard let weakSelf = self else { return }
            weakSelf.downLoaders.forEach {
                if $0.task == dataTask {
                    $0.dataReceiver?.urlSession?(session,
                                                 dataTask: dataTask,
                                                 didReceive: data)
                }
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        accessQueue.sync {[weak self] in
            guard let weakSelf = self else { return }
            weakSelf.downLoaders.forEach {
                if $0.task == task {
                    $0.dataReceiver?.urlSession?(session,
                                                 task: task,
                                                 didCompleteWithError: error)
                }
            }
        }
    }
}
