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
    let cameraFacing: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var backgroundTextureCache: CVMetalTextureCache!
    let metalDevice = MTLCreateSystemDefaultDevice()!
    let scene = SCNScene()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.frame = view.frame
        sceneView.rendersContinuously = true
        sceneView.showsStatistics = true
        view.addSubview(sceneView)
        
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &backgroundTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate texture cache")
        }
        
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
        videoOutput.alwaysDiscardsLateVideoFrames = true
        session.addOutput(videoOutput)

        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        videoConnection?.isVideoMirrored = camera.position == .front
        
        let videoWidth = videoOutput.videoSettings[kCVPixelBufferWidthKey as String] as! Float
        let videoHeight = videoOutput.videoSettings[kCVPixelBufferHeightKey as String] as! Float
        
        let screenWidth = Float(UIScreen.main.bounds.width)
        let screenHeight = Float(UIScreen.main.bounds.height)
        
        // Aspect fit for the background texture
        let aspectRatio: Float = (screenHeight * videoWidth) / (screenWidth * videoHeight)
        let transform = aspectRatio >= 1.0 ? SCNMatrix4MakeScale(1, aspectRatio, 1) : SCNMatrix4MakeScale(1 / aspectRatio, 1, 1)

        // Equivalent to setting vertex position to match aspect ratio
        scene.background.contentsTransform = transform
        scene.background.wrapS = .clampToBorder
        scene.background.wrapT = .clampToBorder
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool { // Redundent autorelease?
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            irisTracker.processVideoFrame(imageBuffer)
        }
    }
}

extension ViewController: IrisTrackerDelegate {
    func irisTracker(_ irisTracker: IrisTracker, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async { [unowned self] in
            scene.background.contents = processPixelBuffer(pixelBuffer: pixelBuffer)
        }
    }
}

extension ViewController {
    func processPixelBuffer(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        var textureRef: CVMetalTexture? = nil
        
        let _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, backgroundTextureCache, pixelBuffer, nil, .bgra8Unorm_srgb, bufferWidth, bufferHeight, 0, &textureRef)
        
        guard let concreteTextureRef = textureRef else { return nil }
        
        let texture = CVMetalTextureGetTexture(concreteTextureRef)
        
        return texture
    }
}
