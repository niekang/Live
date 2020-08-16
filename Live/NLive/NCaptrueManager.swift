//
//  CaptrueManager.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

//
//  NCaptureManager.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import VideoToolbox


class NCaptrueManager: NSObject {
    
    var session = AVCaptureSession()
    
    private var frontCamera:AVCaptureDeviceInput?
    
    private var backCamera: AVCaptureDeviceInput?
    
    private var videoInput: AVCaptureDeviceInput?
    
    private var audioInput: AVCaptureDeviceInput?
    
    private var videoOutPut: AVCaptureVideoDataOutput?
    
    private var audioOutPut: AVCaptureAudioDataOutput?
    
    private var delegateQueue = DispatchQueue.init(label: "receive_sample_buffer")

    private var preset = AVCaptureSession.Preset.medium
    
    var fileHandler: FileHandle?
    
    override init() {
        super.init()
        setup()
        
        let path = NSTemporaryDirectory() + (EncodeType == NCMVideoCodecType.H264 ? "/temp.h264" : "/temp.h265")
        try? FileManager.default.removeItem(atPath: path)
        if FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) {
            fileHandler = FileHandle(forWritingAtPath: path)
        }

    }
    
    private func setup() {
        guard let front = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.front).devices.first,
            let frontCamera = try? AVCaptureDeviceInput(device: front) else {
            return
        }
        
        self.frontCamera = frontCamera

        guard let back = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back).devices.first,
            let backCamera = try? AVCaptureDeviceInput(device: back) else {
            return
        }
        self.backCamera = backCamera;
        
        guard let audio = AVCaptureDevice.default(for: .audio),
            let audioInput = try? AVCaptureDeviceInput(device: audio) else {
            return
        }
        self.audioInput = audioInput
                        
        self.videoOutPut = AVCaptureVideoDataOutput()
        self.videoOutPut?.setSampleBufferDelegate(self, queue: delegateQueue)
        self.videoOutPut?.alwaysDiscardsLateVideoFrames = true
        self.videoOutPut?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        
        self.audioOutPut = AVCaptureAudioDataOutput()
        self.audioOutPut?.setSampleBufferDelegate(self, queue: delegateQueue)
        
        self.session.beginConfiguration()
        
        if self.session.canAddInput(backCamera) {
            self.session.addInput(backCamera)
            self.videoInput = backCamera
        }
        if self.session.canAddInput(audioInput) {
            self.session.addInput(audioInput)
        }
        if self.session.canAddOutput(videoOutPut!) {
            self.session.addOutput(videoOutPut!)
        }
        if self.session.canAddOutput(self.audioOutPut!) {
            self.session.addOutput(self.audioOutPut!)
        }
        if self.session.canSetSessionPreset(self.preset) {
            self.session.sessionPreset = self.preset
        }
        self.session.commitConfiguration()
        
        
        self.session.startRunning()
        
    }
    
    func changeCamera() {
        self.session.stopRunning()
        self.session.beginConfiguration()
        if let videoInput = self.videoInput {
            self.session.removeInput(videoInput)
        }
        self.videoInput = self.videoInput == self.backCamera ? self.frontCamera : self.backCamera
        self.session.addInput(self.videoInput!)
        self.session.commitConfiguration()
        self.session.startRunning()
    }
    
}


// 处理CMSampleBuffer
extension NCaptrueManager {
    
    func yuvData(_ sampleBuffer: CMSampleBuffer) -> Data? {
        // 获取yuv数据
        // 可以通过CMSampleBufferGetImageBuffer方法，获得CVImageBufferRef。
        // 这里面就包含了yuv420(NV12)数据的指针
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }
        
        //开始操作数据
        let flag = CVPixelBufferLockFlags.init(rawValue: 0)
        CVPixelBufferLockBaseAddress(pixelBuffer, flag)
        //图像宽度（像素）
        let pixelWidth = CVPixelBufferGetWidth(pixelBuffer)
        //图像高度（像素）
        let pixelHeight = CVPixelBufferGetHeight(pixelBuffer)
        //yuv中的y所占字节数
        let y_size = pixelWidth * pixelHeight
        //yuv中的uv所占的字节数
        let uv_size = y_size / 2;
        
        let yuv_frame = malloc(y_size+uv_size)!
        
        let y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        memcpy(yuv_frame, y_frame, y_size)
        
        let uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        memcpy(yuv_frame, uv_frame, uv_size)

        CVPixelBufferUnlockBaseAddress(pixelBuffer,flag)
        
        let data = Data(bytesNoCopy: yuv_frame, count: y_size + uv_size, deallocator: Data.Deallocator.none)
        
        free(yuv_frame)
        
        return data

    }
    
    func pcmData(_ sampleBuffer: CMSampleBuffer) -> Data? {
        //获取pcm数据大小
       let size = CMSampleBufferGetTotalSampleSize(sampleBuffer)
       
       //分配空间
       let audioData = malloc(size)!
       
       //获取CMBlockBufferRef
       //这个结构里面就保存了 PCM数据 (CMSampleBufferGetDataBuffer)
        
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return nil
        }
       //直接将数据copy至我们自己分配的内存中
        CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: size, destination: audioData)
       
        //返回数据
        let data = Data(bytesNoCopy: audioData, count: size, deallocator: Data.Deallocator.none)
        
        free(audioData)

       return data
    }
}

extension NCaptrueManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection == self.audioOutPut?.connections.first {
            //音频处理
           
        }else {
            // 视频处理
            let encoder = CMSampleBufferEncode()
            encoder.handler = {(sps, pps, vps) in
                print(sps)
            }
            encoder.encode(sampleBuffer, type: .H265)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print(output)
    }
    
}

