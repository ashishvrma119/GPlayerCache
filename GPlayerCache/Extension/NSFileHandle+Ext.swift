//
//  NSFileHandle+Ext.swift
//  GluedInFeedSDK
//
//  Created by Amit Choudhary on 28/05/24.
//

//import UIKit
//
//import Foundation
//
//extension FileHandle {
//    
//    func try_readData(ofLength length: Int) throws -> Data {
//        do {
//            return self.readData(ofLength: length)
//        } catch {
//            throw NSError(domain: "com.gluedin.domain", code: 99920, userInfo: nil)
//        }
//    }
//    
//    func try_write(data: Data) throws {
//        self.write(data)
//    }
//    
//    func try_seekToEnd() throws -> UInt64 {
//        return self.seekToEndOfFile()
//    }
//
//    func try_seek(toOffset offset: UInt64) throws {
//        self.seek(toFileOffset: offset)
//    }
//    
//    func try_truncate(atOffset offset: UInt64) throws {
//        self.truncateFile(atOffset: offset)
//    }
//
//    func try_synchronize() throws {
//        self.synchronizeFile()
//    }
//    
//    func try_close() throws {
//        self.closeFile()
//    }
//}
//
