//
//  ViewController.swift
//  mppb-ios-hand
//
//  Created by minseopark on 2022/07/25.
//

import UIKit
import AVFoundation
import SceneKit

class ViewController: UIViewController {

    let tracker = MPPBHand()!
    let cameraFacing: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "com.mediapipe.prebuilt.example.videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var backgroundTextureCache: CVMetalTextureCache!
    let metalDevice = MTLCreateSystemDefaultDevice()!
    let scene = SCNScene()
    let originNode = SCNNode(geometry: SCNBox(width: 15, height: 15, length: 15, chamferRadius: 0))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Reasoning from:
        // https://github.com/google/mediapipe/blob/ecb5b5f44ab23ea620ef97a479407c699e424aa7/mediapipe/graphs/face_effect/face_effect_gpu.pbtxt#L62-L64
        let camera = SCNCamera()
        camera.zNear = 1.0
        camera.zFar = 10000.0
        //camera.yFov = 63.0
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(originNode)
        
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
        
        tracker.startGraph()
        tracker.delegate = self
        
        session.startRunning()
    }
    
    func configureCamera() {
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraFacing)!
        
        if camera.isFocusModeSupported(.locked) {
            try! camera.lockForConfiguration()
            camera.focusMode = .locked
            camera.unlockForConfiguration()
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: camera)
        session.sessionPreset = .vga640x480
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
        // Redundent autorelease?
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let timestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            tracker.processVideoFrame(imageBuffer, timestamp: timestamp)
        }
    }
}

extension ViewController: MPPBHandDelegate {
    func handTracker(_ handTracker: MPPBHand, didOutputTransform transform: simd_float4x4) {
        // Apply the transform matrix as-is to the SCNNode, given that the naming
        // conventions of simd_float4x4 and SCNMatrix4 suggest they're both column-majored.
        originNode.simdTransform = transform
        
        // You can access the position/orientation values now as they're
        // just different representations of the above transform matrix or so.
        // https://www.songho.ca/opengl/gl_anglestoaxes.html
        print("pos: \(originNode.simdPosition) rot: \(originNode.simdEulerAngles)")
    }
    
    func handTracker(_ handTracker: MPPBHand, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async { [unowned self] in
            scene.background.contents = processPixelBuffer(pixelBuffer: pixelBuffer)
            
            // This makes the cool effect
            originNode.geometry?.firstMaterial?.diffuse.contents = scene.background.contents
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
