//
//  ViewController.swift
//  Live
//
//  Created by MC on 2020/8/15.
//  Copyright © 2020 聂康. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    

    override func viewDidLoad() {
        super.viewDidLoad()
       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            let capture = NCaptureViewController()
            capture.modalPresentationStyle = .fullScreen
            self.present(capture, animated: true, completion: nil)
        }
    }
       
}

