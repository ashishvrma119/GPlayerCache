////
////  VideoDownloader.swift
////
////  GluedInCache
////
//
//import Foundation
//import AVFoundation
//
//protocol VideoDownloaderType: NSObjectProtocol {
//    
//    var delegate: VideoDownloaderDelegate? { get set }
//    
//    var url: VideoURLType { get }
//    
//    var loadingRequest: AVAssetResourceLoadingRequest { get }
//    
//    var id: Int { get }
//    
//    var task: URLSessionDataTask? { get }
//    var dataReceiver: URLSessionDataDelegate? { get }
//    
//    func finish()
//    func cancel()
//    func execute()
//}
//
//protocol VideoDownloaderDelegate: NSObjectProtocol {
//    
//    func downloaderAllowWriteData(_ downloader: VideoDownloader) -> Bool
//    func downloaderFinish(_ downloader: VideoDownloader)
//    func downloader(_ downloader: VideoDownloader, finishWith error: Error?)
//}
//
//extension VideoDownloader: VideoDownloaderType {
//    
//    var dataReceiver: URLSessionDataDelegate? {
//        return dataDelegate
//    }
//    
//    func finish() {
//        VLog(.info, "downloader id: \(id), finish")
//        NSObject.cancelPreviousPerformRequests(withTarget: self)
//        delegate = nil
//        if !loadingRequest.isFinished {
//            loadingRequest.finishLoading(with: VideoCacheErrors.cancelled.error)
//        }
//        dataDelegate?.delegate = nil
//        if task?.state ~= .running || task?.state ~= .suspended {
//            task?.cancel()
//        }
//        isCancelled = true
//    }
//    
//    func cancel() {
//        VLog(.info, "downloader id: \(id), cancelled")
//        NSObject.cancelPreviousPerformRequests(withTarget: self)
//        if task?.state ~= .running || task?.state ~= .suspended {
//            task?.cancel()
//        }
//        dataDelegate?.delegate = nil
//        isCancelled = true
//    }
//    
//    func execute() {
//        
//        guard let dataRequest = loadingRequest.dataRequest else {
//            finishLoading(error: VideoCacheErrors.dataRequestNull.error)
//            return
//        }
//        
//        loadingRequest.contentInformationRequest?.update(contentInfo: fileHandle.contentInfo)
//        
//        if fileHandle.configuration.contentInfo.totalLength > 0 {
//            fileHandle.configuration.synchronize(to: paths.configurationPath(for: url))
//        }
//        //        else if dataRequest.requestsAllDataToEndOfResource {
//        //            toEnd = true
//        //        }
//        
//        if toEnd {
//            let offset: Int64 = 0
//            let length: Int64 = 2
//            let range = VideoRange(offset, length)
//            VLog(.info, "downloader id: \(id), wants: \(offset) to end")
//            actions = fileHandle.actions(for: range)
//            VLog(.request, "downloader id: \(id), actions: \(actions)")
//        } else {
//            let offset = Int64(dataRequest.requestedOffset)
//            let length = Int64(dataRequest.requestedLength)
//            let range = VideoRange(offset, offset + length)
//            VLog(.info, "downloader id: \(id), wants: \(range)")
//            actions = fileHandle.actions(for: range)
//            VLog(.data, "downloader id: \(id), actions: \(actions)")
//        }
//        actionLoop()
//    }
//}
//
//private var private_id: Int = 0
//private var accId: Int { private_id += 1; return private_id }
//
//class VideoDownloader: NSObject {
//    
//    weak var delegate: VideoDownloaderDelegate?
//    let paths: VideoCachePaths
//    let url: VideoURLType
//    let loadingRequest: AVAssetResourceLoadingRequest
//    let fileHandle: VideoFileHandle
//    var totalCachedData: Int64 = 0
//    let cacheLimit: Int64 = 2 * 1024 * 1024 // 1 MB
//    
//    deinit {
//        VLog(.info, "downloader id: \(id), VideoDownloader deinit\n")
//        NSObject.cancelPreviousPerformRequests(withTarget: self)
//    }
//    
//    init(paths: VideoCachePaths,
//         session: URLSession?,
//         url: VideoURLType,
//         loadingRequest: AVAssetResourceLoadingRequest,
//         fileHandle: VideoFileHandle) {
//        self.paths = paths
//        self.session = session
//        self.url = url
//        self.loadingRequest = loadingRequest
//        self.fileHandle = fileHandle
//        super.init()
//        dataDelegate = DownloaderSessionDelegate(delegate: self)
//    }
//    
//    let id: Int = accId
//    
//    private var actions: [Action] = []
//    
//    private var failedRetryCount: Int = 0
//    private var currentAction: Action? {
//        didSet { failedRetryCount = 0 }
//    }
//    
//    internal private(set) var dataDelegate: DownloaderSessionDelegateType?
//    
//    internal private(set) weak var session: URLSession?
//    
//    internal private(set) var task: URLSessionDataTask?
//    
//    private var toEnd: Bool = false
//    
//    private var isCancelled: Bool = false
//    
//    private var writeOffset: Int64 = 0
//}
//
//extension VideoDownloader {
//    
//    func update(contentInfo: ContentInfo) {
//        loadingRequest.contentInformationRequest?.update(contentInfo: contentInfo)
//        fileHandle.contentInfo = contentInfo
//    }
//    
//    @objc
//    func actionLoop() {
//        if isCancelled {
//            VLog(.info, "this downloader is cancelled, callback cancelled message and return")
//            finishLoading(error: VideoCacheErrors.cancelled.error)
//            return
//        }
//        guard actions.count > 0 else {
//            loopFinished()
//            return
//        }
//        let action = actions.removeFirst()
//        currentAction = action
//        switch action {
//        case .local(let range): read(from: range)
//        case .remote(let range): download(for: range)
//        }
//    }
//}
//
//extension VideoDownloader {
//    
//    func read(from range: VideoRange) {
//        VLog(.data, "downloader id: \(id), read data range: (\(range)) length: \(range.length)")
//        do {
//            
//            let data = try fileHandle.readData(for: range)
//            guard range.lowerBound > 0 else {
//                receivedLocal(data: data)
//                return
//            }
//            
//            guard data.count == range.length else {
//                VLog(.error, "read local data length is error, re-download range: \(range)")
//                download(for: range)
//                return
//            }
//            
//            guard data.checksum() else {
//                VLog(.error, "check sum is failure, re-download range: \(range)")
//                download(for: range)
//                return
//            }
//            
//            receivedLocal(data: data)
//            
//        } catch {
//            VLog(.error, "downloader id: \(id), read local data failure: \(error)")
//            finishLoading(error: error)
//        }
//    }
//    
//    func download(for range: VideoRange) {
//        guard let originUrl = loadingRequest.request.url?.originUrl else {
//            finishLoading(error: VideoCacheErrors.badUrl.error)
//            return
//        }
//        
//        writeOffset = range.lowerBound
//        let fromOffset = range.lowerBound
//        let toOffset = range.upperBound - 1
//        
//        VLog(.request, "downloader id: \(id), download offsets: \(fromOffset) - \(toOffset)")
//        
//        let cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
//        let timeoutInterval = loadingRequest.request.timeoutInterval
//        
//        var request = URLRequest(url: originUrl, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
//        request.setValue("bytes=\(fromOffset)-\(toOffset)", forHTTPHeaderField: "Range")
//        task = session?.dataTask(with: request)
//        task?.resume()
//    }
//    
//    func write(data: Data) {
//        
//        guard let allow = delegate?.downloaderAllowWriteData(self), allow else { return }
//        
//        let range = VideoRange(writeOffset, writeOffset + Int64(data.count))
////        do {
////            try fileHandle.writeData(data: data, for: range)
////        } catch {
////            VLog(.error, "downloader id: \(id), write data failure: \(error)")
////        }
////        writeOffset += range.length
//        do {
//            try fileHandle.writeData(data: data, for: range)
//            totalCachedData += Int64(data.count)
//            if totalCachedData >= cacheLimit {
//                print("URL where data is being printed \(url.key)")
//                print("URL where data is being printed \(paths.cacheFileName(for: url))")
//                print("URL where data is being printed getPlayingAssetId \(GlobalManager.shareInstance.getPlayingAssetId() ?? "")")
//                if url.key != GlobalManager.shareInstance.getPlayingAssetId() {
//                    finishLoading(error: nil) // Stop further download
//                }
//            }
//        } catch {
//            VLog(.error, "downloader id: \(id), write data failure: \(error)")
//        }
//        writeOffset += range.length
//    }
//}
//
//extension VideoDownloader {
//    
//    func receivedLocal(data: Data) {
//        loadingRequest.dataRequest?.respond(with: data)
//        if data.count < PacketLimit {
//            actionLoop()
//        } else {
//            perform(#selector(actionLoop), with: nil, afterDelay: 0.1)
//        }
//    }
//    
//    func finishLoading(error: Error?) {
//        VLog(.error, "finish loading error: \(String(describing: error))")
//        do {
//            try fileHandle.synchronize(notify: true)
//        } catch {
//            VLog(.error, "finish loading error, fileHandle synchronize failure: \(error)")
//        }
//        loadingRequest.finishLoading(with: error)
//        delegate?.downloader(self, finishWith: error)
//    }
//    
//    func downloadFinishLoading() {
//        if toEnd {
//            toEnd.toggle()
//            actions = fileHandle.actions(for: VideoRange(0, fileHandle.contentInfo.totalLength))
//        }
//        do {
//            try fileHandle.synchronize(notify: true)
//        } catch {
//            VLog(.error, "finish loading, fileHandle synchronize failure: \(error)")
//        }
//        actionLoop()
//    }
//    
//    func loopFinished() {
//        VLog(.info, "actions is empty, finished")
//        do {
//            try fileHandle.synchronize(notify: true)
//        } catch {
//            VLog(.error, "actions is empty, finish loading, fileHandle synchronize failure: \(error)")
//        }
//        loadingRequest.finishLoading()
//        delegate?.downloaderFinish(self)
//    }
//}
//
//extension VideoDownloader: DownloaderSessionDelegateDelegate {
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
//                           didReceive response: URLResponse) {
//        if response.isMediaSource, fileHandle.isNeedUpdateContentInfo {
//            update(contentInfo: ContentInfo(response: response))
//        }
//    }
//    
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
//                           didReceive data: Data) {
//        if isCancelled { return }
//        write(data: data)
//        loadingRequest.dataRequest?.respond(with: data)
//    }
//    
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
//                           didCompleteWithError error: Error?) {
//        guard let `error` = error else {
//            downloadFinishLoading()
//            return
//        }
//        if (error as NSError).code == NSURLErrorCancelled { return }
//        if case .remote(let range) = currentAction, failedRetryCount < 3 {
//            failedRetryCount += 1
//            download(for: range)
//        } else {
//            finishLoading(error: error)
//        }
//    }
//}
//
//
//protocol DownloaderSessionDelegateType: URLSessionDataDelegate {
//    var delegate: DownloaderSessionDelegateDelegate? { get set }
//}
//
//protocol DownloaderSessionDelegateDelegate: NSObjectProtocol {
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive response: URLResponse)
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive data: Data)
//    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didCompleteWithError error: Error?)
//}
//
//private let DownloadBufferLimit: Int = 1.MB
//
//private class DownloaderSessionDelegate: NSObject, DownloaderSessionDelegateType {
//    weak var delegate: DownloaderSessionDelegateDelegate?
//    private var bufferData = NSMutableData()
//    
//    deinit {
//        VLog(.info, "DownloaderSessionDelegate deinit\n")
//    }
//    
//    init(delegate: DownloaderSessionDelegateDelegate?) {
//        super.init()
//        self.delegate = delegate
//    }
//    
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive response: URLResponse,
//                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        VLog(.data, "task: \(dataTask) did receive response: \(response)")
//        guard response.isMediaSource else {
//            delegate?.downloaderSession(self, didCompleteWithError: VideoCacheErrors.notMedia.error)
//            completionHandler(.cancel)
//            return
//        }
//        delegate?.downloaderSession(self, didReceive: response)
//        completionHandler(.allow)
//    }
//    
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive data: Data) {
//        
//        VLog(.data, "task: \(dataTask) did receive data: \(data.count)")
//        bufferData.append(data)
//        let multiple = bufferData.count / DownloadBufferLimit
//        guard multiple >= 1 else { return }
//        let length = DownloadBufferLimit * multiple
//        let chunkRange = NSRange(location: bufferData.startIndex, length: length)
//        VLog(.data, "task: buffer data count: \(bufferData.count), subdata: \(chunkRange)")
//        let chunkData = bufferData.subdata(with: chunkRange)
//        let dataRange = NSRange(location: bufferData.startIndex, length: bufferData.count)
//        if let intersectionRange = dataRange.intersection(chunkRange), intersectionRange.length > 0 {
//            VLog(.data, "task: buffer data remove subrange: \(intersectionRange)")
//            bufferData.replaceBytes(in: intersectionRange, withBytes: nil, length: 0)
//        }
//        delegate?.downloaderSession(self, didReceive: chunkData)
//    }
//    
//    func urlSession(_ session: URLSession,
//                    task: URLSessionTask,
//                    didCompleteWithError error: Error?) {
//        VLog(.request, "task: \(task) did complete with error: \(String(describing: error))")
//        let bufferCount = bufferData.count
//        if bufferCount > 0 {
//            let chunkRange = NSRange(location: bufferData.startIndex, length: bufferCount)
//            let chunkData = bufferData.subdata(with: chunkRange)
//            bufferData.setData(Data())
//            delegate?.downloaderSession(self, didReceive: chunkData)
//        }
//        bufferData.setData(Data()) // Clear bufferData to release memory
//        delegate?.downloaderSession(self, didCompleteWithError: error)
//        delegate = nil // Explicitly nil out the delegate to break any potential strong reference cycles
//    }
//}
//

import Foundation
import AVFoundation

protocol VideoDownloaderType: NSObjectProtocol {
    var url: VideoURLType { get }
    var loadingRequest: AVAssetResourceLoadingRequest { get }
    var id: Int { get }
    var task: URLSessionDataTask? { get }
    var dataReceiver: URLSessionDataDelegate? { get }
    
    func finish()
    func cancel()
    func execute()
}

protocol VideoDownloaderDelegate: NSObjectProtocol {
    func downloaderAllowWriteData(_ downloader: VideoDownloader) -> Bool
    func downloaderFinish(_ downloader: VideoDownloader)
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?)
}

private var private_id: Int = 0
private var accId: Int { private_id += 1; return private_id }

class VideoDownloader: NSObject, VideoDownloaderType {
    weak var delegate: VideoDownloaderDelegate?
    let paths: VideoCachePaths
    let url: VideoURLType
    let loadingRequest: AVAssetResourceLoadingRequest
    let fileHandle: VideoFileHandle
    var totalCachedData: Int64 = 0
    let cacheLimit: Int64 = 1 * 1024 * 1024 // 1 MB
    var isPaused: Bool = false
    var hasBuffered: Bool = false // Add a flag to indicate if buffering is complete
    var networkStatus = Reach().connectionStatus()
    private var reach: Reach!

    var player: AVPlayer? // Add a reference to the AVPlayer
    
    init(paths: VideoCachePaths,
         session: URLSession?,
         url: VideoURLType,
         loadingRequest: AVAssetResourceLoadingRequest,
         fileHandle: VideoFileHandle,
         player: AVPlayer?) {
        self.paths = paths
        self.session = session
        self.url = url
        self.loadingRequest = loadingRequest
        self.fileHandle = fileHandle
        self.player = player

        super.init()
        dataDelegate = DownloaderSessionDelegate(delegate: self)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.networkDownloadStatusChanged(_:)),
            name: NSNotification.Name(rawValue: ReachabilityStatusChangedNotification),
            object: nil)
        Reach().monitorReachabilityChanges()
    }

    @objc func networkDownloadStatusChanged(_ notification: Notification) {
        networkStatus = Reach().connectionStatus()
        switch networkStatus {
        case .offline:
            pauseDownloads()
        case .online:
            resumeDownloads()
        case .unknown:
            break
        @unknown default:
            fatalError("NetworkStatusChanged:: - \"Unknown \"")
        }
    }

    
    deinit {
        VLog(.info, "downloader id: \(id), VideoDownloader deinit\n")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
//        self.player?.removeObserver(self, forKeyPath: #keyPath(NSNotification.Name(rawValue: ReachabilityStatusChangedNotification)))
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: ReachabilityStatusChangedNotification),
                                                  object: nil)
    }

    let id: Int = accId
    
    private var actions: [Action] = []
    private var failedRetryCount: Int = 0
    private var currentAction: Action? {
        didSet { failedRetryCount = 0 }
    }
    
    internal private(set) var dataDelegate: DownloaderSessionDelegateType?
    internal private(set) weak var session: URLSession?
    internal private(set) var task: URLSessionDataTask?
    private var toEnd: Bool = false
    private var isCancelled: Bool = false
    private var writeOffset: Int64 = 0
    
    weak var dataReceiver: URLSessionDataDelegate? {
        return dataDelegate
    }
    
    /*
     Download session pause and resume method
     */
    
    private func pauseDownloads() {
        guard !isPaused else { return }
        VLog(.info, "downloader id: \(id), paused")
        isPaused = true
        task?.cancel()
    }

    private func resumeDownloads() {
        guard isPaused else { return }
        VLog(.info, "downloader id: \(id), resumed")
        isPaused = false
        execute()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "rate" else { return }
        if let player = player, player.rate > 0 {
            // Resume download if the video is playing
            if isPaused {
                resume()
            }
        } else {
            // Pause download if the video is not playing
            if !isPaused && hasBuffered {
                pause()
            }
        }
    }
    
    func finish() {
        VLog(.info, "downloader id: \(id), finish")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        delegate = nil
        if !loadingRequest.isFinished {
            loadingRequest.finishLoading(with: VideoCacheErrors.cancelled.error)
        }
        dataDelegate?.delegate = nil
        if task?.state == .running || task?.state == .suspended {
            task?.cancel()
        }
        isCancelled = true
    }
    
    func cancel() {
        VLog(.info, "downloader id: \(id), cancelled")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if task?.state == .running || task?.state == .suspended {
            task?.cancel()
        }
        dataDelegate?.delegate = nil
        isCancelled = true
    }
    
    func execute() {
        guard let dataRequest = loadingRequest.dataRequest else {
            finishLoading(error: VideoCacheErrors.dataRequestNull.error)
            return
        }

        networkStatus = Reach().connectionStatus()
        switch networkStatus {
        case .offline:
            VLog(.info, "downloader id: \(id), network unavailable, delaying execution")
            isPaused = true
            return
        case .online(_):
            print("Online status")
        case .unknown:
            print("unknown status")
        @unknown default:
            fatalError("NetworkStatusChanged:: - \"Unknown \"")
        }
        
//        if  reachability.connection == .unavailable {
//            VLog(.info, "downloader id: \(id), network unavailable, delaying execution")
//            isPaused = true
//            return
//        }
        
        loadingRequest.contentInformationRequest?.update(contentInfo: fileHandle.contentInfo)
        
        if fileHandle.configuration.contentInfo.totalLength > 0 {
            fileHandle.configuration.synchronize(to: paths.configurationPath(for: url))
        }
        
        if toEnd {
            let offset: Int64 = 0
            let length: Int64 = 2
            let range = VideoRange(offset, length)
            VLog(.info, "downloader id: \(id), wants: \(offset) to end")
            actions = fileHandle.actions(for: range)
            VLog(.request, "downloader id: \(id), actions: \(actions)")
        } else {
            let offset = Int64(dataRequest.requestedOffset)
            let length = Int64(dataRequest.requestedLength)
            let range = VideoRange(offset, offset + length)
            VLog(.info, "downloader id: \(id), wants: \(range)")
            actions = fileHandle.actions(for: range)
            VLog(.data, "downloader id: \(id), actions: \(actions)")
        }
        actionLoop()
    }
    
    func pause() {
        guard !isPaused else { return }
        VLog(.info, "downloader id: \(id), paused")
        isPaused = true
        task?.cancel()
    }
    
    func resume() {
        guard isPaused else { return }
        VLog(.info, "downloader id: \(id), resumed")
        isPaused = false
        execute()
    }
    
    func isFileInCache() -> Bool {
        let filePath = paths.videoPath(for: url)
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    func getFileSize() -> Int64? {
        let filePath = paths.videoPath(for: url)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Int64
        } catch {
            VLog(.error, "Failed to get file size for path: \(filePath), error: \(error)")
            return nil
        }
    }
}

extension VideoDownloader {
    func update(contentInfo: ContentInfo) {
        loadingRequest.contentInformationRequest?.update(contentInfo: contentInfo)
        fileHandle.contentInfo = contentInfo
    }
    
    @objc
    func actionLoop() {
        if isCancelled {
            VLog(.info, "this downloader is cancelled, callback cancelled message and return")
            finishLoading(error: VideoCacheErrors.cancelled.error)
            return
        }
        guard actions.count > 0 else {
            loopFinished()
            return
        }
        let action = actions.removeFirst()
        currentAction = action
        switch action {
        case .local(let range): read(from: range)
        case .remote(let range): download(for: range)
        }
    }
}

extension VideoDownloader {
    func read(from range: VideoRange) {
        VLog(.data, "downloader id: \(id), read data range: (\(range)) length: \(range.length)")
        do {
            let data = try fileHandle.readData(for: range)
            guard range.lowerBound > 0 else {
                receivedLocal(data: data)
                return
            }
            guard data.count == range.length else {
                VLog(.error, "read local data length is error, re-download range: \(range)")
                download(for: range)
                return
            }
            guard data.checksum() else {
                VLog(.error, "check sum is failure, re-download range: \(range)")
                download(for: range)
                return
            }
            receivedLocal(data: data)
        } catch {
            VLog(.error, "downloader id: \(id), read local data failure: \(error)")
            finishLoading(error: error)
        }
    }
    
    func download(for range: VideoRange) {
        guard let originUrl = loadingRequest.request.url?.originUrl else {
            finishLoading(error: VideoCacheErrors.badUrl.error)
            return
        }
        writeOffset = range.lowerBound
        let fromOffset = range.lowerBound
        let toOffset = range.upperBound - 1
        VLog(.request, "downloader id: \(id), download offsets: \(fromOffset) - \(toOffset)")
        let cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeoutInterval = loadingRequest.request.timeoutInterval
        var request = URLRequest(url: originUrl, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        request.setValue("bytes=\(fromOffset)-\(toOffset)", forHTTPHeaderField: "Range")
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    func write(data: Data) {
        guard let allow = delegate?.downloaderAllowWriteData(self), allow else { return }
        let range = VideoRange(writeOffset, writeOffset + Int64(data.count))
        VLog(.data, "downloader id: \(id), write data range: (\(range)) length: \(range.length)")
        do {
            try fileHandle.writeData(data: data, for: range)
            totalCachedData += Int64(data.count)
            if totalCachedData >= cacheLimit {
                //if url.key != GlobalManager.shareInstance.getPlayingAssetId() {
                    //finishLoading(error: nil) // Stop further download
                //}
            }
        } catch {
            VLog(.error, "downloader id: \(id), write data failure: \(error)")
        }
        writeOffset += range.length
    }
}

extension VideoDownloader {
    func receivedLocal(data: Data) {
        loadingRequest.dataRequest?.respond(with: data)
        if data.count < PacketLimit {
            actionLoop()
        } else {
            perform(#selector(actionLoop), with: nil, afterDelay: 0.1)
        }
    }
    
    func finishLoading(error: Error?) {
        VLog(.error, "finish loading error: \(String(describing: error))")
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "finish loading error, fileHandle synchronize failure: \(error)")
        }
        loadingRequest.finishLoading(with: error)
        delegate?.downloader(self, finishWith: error)
        dataDelegate = nil // Ensure the dataDelegate is released
    }
    
    func downloadFinishLoading() {
        if toEnd {
            toEnd.toggle()
            actions = fileHandle.actions(for: VideoRange(0, fileHandle.contentInfo.totalLength))
        }
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "finish loading, fileHandle synchronize failure: \(error)")
        }
        actionLoop()
    }
    
    func loopFinished() {
        VLog(.info, "actions is empty, finished")
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "actions is empty, finish loading, fileHandle synchronize failure: \(error)")
        }
        loadingRequest.finishLoading()
        delegate?.downloaderFinish(self)
        dataDelegate = nil // Ensure the dataDelegate is released
    }
}

extension VideoDownloader: DownloaderSessionDelegateDelegate {
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didReceive response: URLResponse) {
        if response.isMediaSource, fileHandle.isNeedUpdateContentInfo {
            update(contentInfo: ContentInfo(response: response))
        }
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didReceive data: Data) {
        if isCancelled || isPaused { return }
        write(data: data)
        loadingRequest.dataRequest?.respond(with: data)
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didCompleteWithError error: Error?) {
        guard let error = error else {
            downloadFinishLoading()
            return
        }
        if (error as NSError).code == NSURLErrorCancelled {
            if isPaused { return } // If paused, do not treat as an error
        } else {
            if case .remote(let range) = currentAction, failedRetryCount < 6 {
                failedRetryCount += 1
                VLog(.info, "Retrying download for range: \(range), attempt: \(failedRetryCount)")
                download(for: range)
            } else {
                finishLoading(error: error)
            }
        }
    }
}

protocol DownloaderSessionDelegateType: URLSessionDataDelegate {
    var delegate: DownloaderSessionDelegateDelegate? { get set }
}

protocol DownloaderSessionDelegateDelegate: NSObjectProtocol {
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive response: URLResponse)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive data: Data)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didCompleteWithError error: Error?)
}

private let DownloadBufferLimit: Int = 1.MB
private let DownloadBufferLimit500: Int = 500.KB

private class DownloaderSessionDelegate: NSObject, DownloaderSessionDelegateType {
    weak var delegate: DownloaderSessionDelegateDelegate?
    private var bufferData = NSMutableData()
    deinit {
        VLog(.info, "DownloaderSessionDelegate deinit\n")
    }
    
    init(delegate: DownloaderSessionDelegateDelegate?) {
        super.init()
        self.delegate = delegate
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        VLog(.data, "task: \(dataTask) did receive response: \(response)")
        guard response.isMediaSource else {
            delegate?.downloaderSession(self, didCompleteWithError: VideoCacheErrors.notMedia.error)
            completionHandler(.cancel)
            return
        }
        delegate?.downloaderSession(self, didReceive: response)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let downloader = delegate as? VideoDownloader, !downloader.isPaused else { return }
        VLog(.data, "task: \(dataTask) did receive data: \(data.count)")
        bufferData.append(data)
        
        var multiple: Int = 0
        var length: Int = 0
        if downloader.isFileInCache() {
            if downloader.getFileSize() ?? 0 >= 100 {
                multiple = bufferData.count / DownloadBufferLimit500
                guard multiple >= 1 else { return }
                length = DownloadBufferLimit500 * multiple
            } else {
                multiple = bufferData.count / DownloadBufferLimit
                guard multiple >= 1 else { return }
                length = DownloadBufferLimit * multiple
            }
        } else {
            multiple = bufferData.count / DownloadBufferLimit
            guard multiple >= 1 else { return }
            length = DownloadBufferLimit * multiple
        }
        
        let chunkRange = NSRange(location: bufferData.startIndex, length: length)
        VLog(.data, "task: buffer data count: \(bufferData.count), subdata: \(chunkRange)")
        let chunkData = bufferData.subdata(with: chunkRange)
        let dataRange = NSRange(location: bufferData.startIndex, length: bufferData.count)
        if let intersectionRange = dataRange.intersection(chunkRange), intersectionRange.length > 0 {
            VLog(.data, "task: buffer data remove subrange: \(intersectionRange)")
            bufferData.replaceBytes(in: intersectionRange, withBytes: nil, length: 0)
        }
        
        downloader.hasBuffered = true
        if downloader.isPaused {
            return
        }
        
        delegate?.downloaderSession(self, didReceive: chunkData)
    }

    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        VLog(.request, "task: \(task) did complete with error: \(String(describing: error))")
        let bufferCount = bufferData.count
        if bufferCount > 0 {
            let chunkRange = NSRange(location: bufferData.startIndex, length: bufferCount)
            let chunkData = bufferData.subdata(with: chunkRange)
            bufferData.setData(Data())
            delegate?.downloaderSession(self, didReceive: chunkData)
        }
        bufferData.setData(Data()) // Clear bufferData to release memory
        delegate?.downloaderSession(self, didCompleteWithError: error)
        delegate = nil // Explicitly nil out the delegate to break any potential strong reference cycles
    }
}
