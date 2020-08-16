//
//  CVPixelBuffer+LockFlag.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

import Foundation
import AVFoundation

extension CVPixelBuffer {
    public enum LockFlag {
        case readwrite
        case readonly
        
        func flag() -> CVPixelBufferLockFlags {
            switch self {
            case .readonly:
                return .readOnly
            default:
                return CVPixelBufferLockFlags.init(rawValue: 0)
            }
        }
    }
    
    public func lock(_ flag: LockFlag, closure: (() -> Void)?) {
        if CVPixelBufferLockBaseAddress(self, flag.flag()) == kCVReturnSuccess {
            if let c = closure {
                c()
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, flag.flag())
    }
}
