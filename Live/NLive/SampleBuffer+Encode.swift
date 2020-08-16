//
//  SampleBuffer+Encode.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

import Foundation
import VideoToolbox
import AVFoundation

enum NCMVideoCodecType {
    case H264
    case H265
}

fileprivate var NALUHeader: [UInt8] = [0, 0, 0, 1]

var EncodeType = NCMVideoCodecType.H264

func compressionOutputCallback(outputCallbackRefCon: UnsafeMutableRawPointer?,
                               sourceFrameRefCon: UnsafeMutableRawPointer?,
                               status: OSStatus,
                               infoFlags: VTEncodeInfoFlags,
                               sampleBuffer: CMSampleBuffer?) -> Swift.Void {
    guard status == noErr else {
        print("error: \(status)")
        return
    }
    
    if infoFlags == .frameDropped {
        print("frame dropped")
        return
    }
    
    guard let sampleBuffer = sampleBuffer else {
        print("sampleBuffer is nil")
        return
    }
    
    if CMSampleBufferDataIsReady(sampleBuffer) != true {
        print("sampleBuffer data is not ready")
        return
    }

    // 调试信息
//    let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
//    let extensions = CMFormatDescriptionGetExtensions(desc!)
//    print("extensions: \(extensions!)")
//
//    let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
//    print("sample count: \(sampleCount)")
//
//    let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)!
//    var length: Int = 0
//    var dataPointer: UnsafeMutablePointer<Int8>?
//    CMBlockBufferGetDataPointer(dataBuffer, 0, nil, &length, &dataPointer)
//    print("length: \(length), dataPointer: \(dataPointer!)")
    // 调试信息结束
    
    let encoder: CMSampleBufferEncode = Unmanaged.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
    
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
        print("attachments: \(attachments)")
        
        let rawDic: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
        let dic: CFDictionary = Unmanaged.fromOpaque(rawDic).takeUnretainedValue()
        
        // if not contains means it's an IDR frame
        let keyFrame = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        if keyFrame {
            print("IDR frame")
            
            // sps
            let format = CMSampleBufferGetFormatDescription(sampleBuffer)
            var spsSize: Int = 0
            var spsCount: Int = 0
            var nalHeaderLength: Int32 = 0
            var sps: UnsafePointer<UInt8>?
            var status: OSStatus
            if EncodeType == .H265 {
                // HEVC
                
                // HEVC比H264多一个VPS
                var vpsSize: Int = 0
                var vpsCount: Int = 0
                var vps: UnsafePointer<UInt8>?
                var ppsSize: Int = 0
                var ppsCount: Int = 0
                var pps: UnsafePointer<UInt8>?

                status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format!, parameterSetIndex: 0, parameterSetPointerOut: &vps, parameterSetSizeOut: &vpsSize, parameterSetCountOut: &vpsCount, nalUnitHeaderLengthOut: &nalHeaderLength)
                if status == noErr {
                    print("HEVC vps: \(String(describing: vps)), vpsSize: \(vpsSize), vpsCount: \(vpsCount), NAL header length: \(nalHeaderLength)")
                    status =           CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format!, parameterSetIndex: 1, parameterSetPointerOut: &sps, parameterSetSizeOut: &spsSize, parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: &nalHeaderLength)
                    if status == noErr {
                        print("HEVC sps: \(String(describing: sps)), spsSize: \(spsSize), spsCount: \(spsCount), NAL header length: \(nalHeaderLength)")
                        status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format!, parameterSetIndex: 2, parameterSetPointerOut: &pps, parameterSetSizeOut: &ppsSize, parameterSetCountOut: &ppsCount, nalUnitHeaderLengthOut: &nalHeaderLength)
                        if status == noErr {
                            print("HEVC pps: \(String(describing: pps)), ppsSize: \(ppsSize), ppsCount: \(ppsCount), NAL header length: \(nalHeaderLength)")

                            let vpsData: NSData = NSData(bytes: vps, length: vpsSize)
                            let spsData: NSData = NSData(bytes: sps, length: spsSize)
                            let ppsData: NSData = NSData(bytes: pps, length: ppsSize)
                            
                                encoder.handle(sps: spsData, pps: ppsData, vps: vpsData)

                        }
                    }

                }
                
            } else {
                // H.264
                if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                      parameterSetIndex: 0,
                                                                      parameterSetPointerOut: &sps,
                                                                      parameterSetSizeOut: &spsSize,
                                                                      parameterSetCountOut: &spsCount,
                                                                      nalUnitHeaderLengthOut: &nalHeaderLength) == noErr {
                    print("sps: \(String(describing: sps)), spsSize: \(spsSize), spsCount: \(spsCount), NAL header length: \(nalHeaderLength)")
                    
                    // pps
                    var ppsSize: Int = 0
                    var ppsCount: Int = 0
                    var pps: UnsafePointer<UInt8>?
                    
                    if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                          parameterSetIndex: 1,
                                                                          parameterSetPointerOut: &pps,
                                                                          parameterSetSizeOut: &ppsSize,
                                                                          parameterSetCountOut: &ppsCount,
                                                                          nalUnitHeaderLengthOut: &nalHeaderLength) == noErr {
                        print("sps: \(String(describing: pps)), spsSize: \(ppsSize), spsCount: \(ppsCount), NAL header length: \(nalHeaderLength)")
                        
                        let spsData: NSData = NSData(bytes: sps, length: spsSize)
                        let ppsData: NSData = NSData(bytes: pps, length: ppsSize)
                        
                        // save sps/pps to file
                        // NOTE: 事实上，大多数情况下 sps/pps 不变/变化不大 或者 变化对视频数据产生的影响很小，
                        // 因此，多数情况下你都可以只在文件头写入或视频流开头传输 sps/pps 数据
                        encoder.handle(sps: spsData, pps: ppsData)
                    }
                }
            }
        } // end of handle sps/pps
        
        // handle frame data
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr {
            var bufferOffset: Int = 0
            let AVCCHeaderLength = 4
            
            while bufferOffset < (totalLength - AVCCHeaderLength) {
                var NALUnitLength: UInt32 = 0
                // first four character is NALUnit length
                memcpy(&NALUnitLength, dataPointer?.advanced(by: bufferOffset), AVCCHeaderLength)
                
                // big endian to host endian. in iOS it's little endian
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                
                let data: NSData = NSData(bytes: dataPointer?.advanced(by: bufferOffset + AVCCHeaderLength), length: Int(NALUnitLength))
                // 关键帧
//                vc.encode(data: data, isKeyFrame: keyFrame)
                
                // move forward to the next NAL Unit
                bufferOffset += Int(AVCCHeaderLength)
                bufferOffset += Int(NALUnitLength)
            }
        }
    }
}

typealias CMSampleBufferEncodeHandler = (_ sps: NSData, _ pps: NSData, _ vps: NSData? ) -> Void

class CMSampleBufferEncode {
    
    let compressionQueue = DispatchQueue(label: "videotoolbox.compression.compression")
    
    var handler: CMSampleBufferEncodeHandler?

    
    // H265 = kCMVideoCodecType_HEVC
    func encode(_ sampleBuffer: CMSampleBuffer, type: NCMVideoCodecType = .H264) {
        EncodeType = type
        let videoCodecType = type == .H264 ? kCMVideoCodecType_H264 : kCMVideoCodecType_HEVC
        var compressionSession: VTCompressionSession?
        guard let pixelbuffer = sampleBuffer.imageBuffer else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelbuffer)
        let height = CVPixelBufferGetHeight(pixelbuffer)
        let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                width: Int32(width),
                                                height: Int32(height),
                                                codecType: videoCodecType,
                                                encoderSpecification: nil,
                                                imageBufferAttributes: nil,
                                                compressedDataAllocator: nil,
                                                outputCallback: compressionOutputCallback,
                                                refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                                compressionSessionOut: &compressionSession)
        
        guard let cs = compressionSession else {
           print("Error creating compression session: \(status)")
           return
        }
                   
        if EncodeType == .H265 {
            VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_ProfileLevel,
                                 value: kVTProfileLevel_HEVC_Main_AutoLevel)
        } else {
            VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
        }
        // capture from camera, so it's real time
        VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_RealTime, value: true as CFTypeRef)
        // 关键帧间隔
        VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 10 as CFTypeRef)
        // 比特率和速率
        VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_AverageBitRate, value: width * height * 2 * 32 as CFTypeRef)
        VTSessionSetProperty(cs, key: kVTCompressionPropertyKey_DataRateLimits, value: [width * height * 2 * 4, 1] as CFArray)
       
        VTCompressionSessionPrepareToEncodeFrames(cs)
        
        let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
        
        VTCompressionSessionEncodeFrame(cs, imageBuffer: pixelbuffer, presentationTimeStamp: presentationTimestamp, duration: duration, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
        
        compressionQueue.sync {
            pixelbuffer.lock(.readwrite) {
                let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
                VTCompressionSessionEncodeFrame(cs, imageBuffer: pixelbuffer, presentationTimeStamp: presentationTimestamp, duration: duration, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
            }
        }
    }
    
    func handle(sps: NSData, pps: NSData, vps: NSData? = nil) {
        guard let handler = self.handler else {
            return
        }
        handler(sps, pps, vps)
    }
    
    func encodKeyFrame(data: NSData, isKeyFrame: Bool) {
//           guard let fh = fileHandler else {
//               return
//           }
//           let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
//           fh.write(headerData as Data)
//           fh.write(data as Data)
    }
}
