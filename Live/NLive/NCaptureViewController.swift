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

class NCaptureViewController: UIViewController {
    
    private var captureManager = NCaptrueManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    @objc func changeCamera() {
        captureManager.changeCamera()
    }
}


extension NCaptureViewController {
    
    private func setUI() {
        view.backgroundColor = UIColor.black
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.frame = self.view.bounds
        previewLayer.session = captureManager.session
        self.view.layer.addSublayer(previewLayer)
        
        let cameraBtn = UIButton(type: .custom)
        cameraBtn.addTarget(self, action: #selector(self.changeCamera), for: .touchUpInside)
        cameraBtn.frame = CGRect(x: view.frame.size.width-60, y: 0, width: 60, height: 60)
        cameraBtn.setTitle("摄像头", for: .normal)
        cameraBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        view.addSubview(cameraBtn)
    }
}
