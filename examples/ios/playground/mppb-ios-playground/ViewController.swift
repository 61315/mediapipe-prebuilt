//
//  ViewController.swift
//  mppb-ios-playground
//
//  Created by minseopark on 2022/07/26.
//

import UIKit
import AVFoundation
import SceneKit

class ViewController: UIViewController {

    let tracker = MPPBPlayground(string: ViewController.OUR_SECOND_CALCULATORS)!
//    let tracker = MPPBPlayground()!
    
    let cameraFacing: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "com.mediapipe.prebuilt.example.videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var backgroundTextureCache: CVMetalTextureCache!
    let metalDevice = MTLCreateSystemDefaultDevice()!
    let scene = SCNScene()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScene()
        configureCamera()
        
        tracker.startGraph()
        tracker.delegate = self
        
        session.startRunning()
    }
    
    func configureScene() {
        let camera = SCNCamera()
        camera.zNear = 1.0
        camera.zFar = 10000.0
        //camera.yFov = 63.0
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        scene.rootNode.addChildNode(cameraNode)
        
        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.frame = view.frame
        sceneView.rendersContinuously = true
        sceneView.showsStatistics = true
        view.addSubview(sceneView)
        
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &backgroundTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate texture cache")
        }
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
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let timestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            tracker.processVideoFrame(imageBuffer, timestamp: timestamp)
        }
    }
}

extension ViewController: MPPBPlaygroundDelegate {
    func tracker(_ tracker: MPPBPlayground!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
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
    
    /**
        Available calculators in this bundle or framework:
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/core:pass_through_calculator",
        "//mediapipe/calculators/image:color_convert_calculator",
        "//mediapipe/calculators/image:image_transformation_calculator",
        "//mediapipe/calculators/image:scale_image_calculator",
 
    @See mediapipe/examples/ios/prebuilt/playground/graph/BUILD
     */
    fileprivate static let OUR_SECOND_CALCULATORS = """
input_stream: "input_video"
output_stream: "output_video"

node: {
    calculator: "PassThroughCalculator"
    input_stream: "input_video"
    output_stream: "passed_video"
}

node: {
    calculator: "ImageTransformationCalculator"
    input_stream: "IMAGE_GPU:passed_video"
    output_stream: "IMAGE_GPU:output_video"
    node_options: {
        [type.googleapis.com/mediapipe.ImageTransformationCalculatorOptions] {
            flip_vertically: true
        }
    }
}

"""
}


