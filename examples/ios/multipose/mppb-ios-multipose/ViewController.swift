//
//  ViewController.swift
//  mppb-ios-multipose
//
//  Created by minseopark on January 3, 2023.
//

import AVFoundation
import SceneKit
import UIKit

class ViewController: UIViewController {

    let tracker = MPPBMultiPose()!
//    let tracker = MPPBMultiPose(
//        string: ViewController.MULTI_POSE_TRACKING_GPU_CALCULATORS_SOURCE)!

    let metalDevice = MTLCreateSystemDefaultDevice()!
    var backgroundTextureCache: CVMetalTextureCache!

    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(
        label: "com.mediapipe.prebuilt.example.videoQueue", qos: .userInitiated,
        attributes: [], autoreleaseFrequency: .workItem)
    let cameraFacing: AVCaptureDevice.Position = .back
    var aspectRatio: Float = 1.0

    let scene = SCNScene()
    let transformNode = SCNNode()

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

        let cameraNode = SCNNode()
        cameraNode.camera = camera

        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(transformNode)

        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.frame = view.frame
        sceneView.rendersContinuously = true
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showWireframe, .renderAsWireframe]
        view.addSubview(sceneView)

        if CVMetalTextureCacheCreate(
            kCFAllocatorDefault, nil, metalDevice, nil, &backgroundTextureCache)
            != kCVReturnSuccess
        {
            assertionFailure("Unable to allocate texture cache")
        }
    }

    func configureCamera() {
        let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: cameraFacing)!

        if camera.isFocusModeSupported(.locked) {
            try! camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            camera.unlockForConfiguration()
        }

        let cameraInput = try! AVCaptureDeviceInput(device: camera)
        session.sessionPreset = .vga640x480
        session.addInput(cameraInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        session.addOutput(videoOutput)

        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        videoConnection?.isVideoMirrored = camera.position == .front

        let videoWidth =
            videoOutput.videoSettings[kCVPixelBufferWidthKey as String] as! Float
        let videoHeight =
            videoOutput.videoSettings[kCVPixelBufferHeightKey as String] as! Float

        let screenWidth = Float(UIScreen.main.bounds.width)
        let screenHeight = Float(UIScreen.main.bounds.height)

        // Aspect fit for the background texture
        aspectRatio = (screenHeight * videoWidth) / (screenWidth * videoHeight)
        let videoTransform =
            aspectRatio < 1.0
            ? SCNMatrix4MakeScale(1, aspectRatio, 1)
            : SCNMatrix4MakeScale(1 / aspectRatio, 1, 1)

        scene.background.contentsTransform = videoTransform
        scene.background.wrapS = .clampToBorder
        scene.background.wrapT = .clampToBorder
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            let timestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            tracker.processVideoFrame(imageBuffer, timestamp: timestamp)
        }
    }
}

extension ViewController: MPPBMultiPoseDelegate {

    // Update video texture
    func tracker(_ tracker: MPPBMultiPose!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
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

        let _ = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, backgroundTextureCache, pixelBuffer, nil,
            .bgra8Unorm_srgb, bufferWidth, bufferHeight, 0, &textureRef)

        guard let concreteTextureRef = textureRef else { return nil }

        let texture = CVMetalTextureGetTexture(concreteTextureRef)

        return texture
    }

    fileprivate static let MULTI_POSE_TRACKING_GPU_CALCULATORS_SOURCE = """
        input_stream: "input_video"

        output_stream: "output_video"

        output_stream: "pose_detections"

        node {
          calculator: "FlowLimiterCalculator"
          input_stream: "input_video"
          input_stream: "FINISHED:output_video"
          input_stream_info: {
            tag_index: "FINISHED"
            back_edge: true
          }
          output_stream: "throttled_input_video"
        }

        node {
          calculator: "MultiPoseLandmarkGpu"
          input_stream: "IMAGE:throttled_input_video"
          output_stream: "DETECTIONS:pose_detections"
          output_stream: "detections_render_data"
          output_stream: "roi_render_data_list"
          output_stream: "landmarks_render_data_list"
        }

        node {
          calculator: "AnnotationOverlayCalculator"
          input_stream: "IMAGE_GPU:throttled_input_video"
          input_stream: "detections_render_data"
          input_stream: "VECTOR:0:roi_render_data_list"
          input_stream: "VECTOR:1:landmarks_render_data_list"
          output_stream: "IMAGE_GPU:output_video"
        }

        """
}
