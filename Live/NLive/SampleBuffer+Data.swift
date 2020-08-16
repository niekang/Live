//
//  SampleBuffer+Data.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox

extension CMSampleBuffer {
    
    func yuvData() -> Data? {
        // 获取yuv数据
        // 可以通过CMSampleBufferGetImageBuffer方法，获得CVImageBufferRef。
        // 这里面就包含了yuv420(NV12)数据的指针
        guard let pixelBuffer = self.imageBuffer else { return nil }
        
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

    func pcmData() -> Data? {
        //获取pcm数据大小
        //CMSampleBufferGetTotalSampleSize(self)
       let size = totalSampleSize
       
       //分配空间
       let audioData = malloc(size)!
       
       //获取CMBlockBufferRef
       //这个结构里面就保存了 PCM数据 (CMSampleBufferGetDataBuffer)
        
        guard let dataBuffer = self.dataBuffer else {
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

