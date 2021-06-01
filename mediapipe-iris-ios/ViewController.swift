//
//  ViewController.swift
//  mediapipe-iris-ios
//
//  Created by minseopark on 2021/06/01.
//

import UIKit
import AVFoundation
import SceneKit

class ViewController: UIViewController {

    let irisTracker = IrisTracker()!
    let renderView = UIImageView()
    let cameraFacing: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.frame = view.frame
        view.addSubview(renderView)
        
        configureCamera()
        session.startRunning()
        
        irisTracker.startGraph()
        irisTracker.delegate = self
    }
    
    func configureCamera() {
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraFacing)!
        
        if camera.isFocusModeSupported(.locked) {
            try! camera.lockForConfiguration()
            camera.focusMode = .locked
            camera.unlockForConfiguration()
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: camera)
        
        session.sessionPreset = .hd1280x720
        session.addInput(cameraInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        session.addOutput(videoOutput)

        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        videoConnection?.isVideoMirrored = camera.position == .front
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            irisTracker.processVideoFrame(imageBuffer)
        }
    }
}

extension ViewController: IrisTrackerDelegate {
    func irisTracker(_ irisTracker: IrisTracker!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        DispatchQueue.main.async { [unowned self] in
            self.renderView.image = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
        }
    }
}
