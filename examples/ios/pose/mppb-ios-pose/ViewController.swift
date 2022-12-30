//
//  ViewController.swift
//  mppb-ios-pose
//
//  Created by minseopark on 2022/12/30.
//

import AVFoundation
import SceneKit
import UIKit

class ViewController: UIViewController {

    // let tracker = MPPBPose()!
    let tracker = MPPBPose(
        string: ViewController.CUSTOM_POSE_TRACKING_IOS_CALCULATORS_SOURCE)!

    let metalDevice = MTLCreateSystemDefaultDevice()!
    var backgroundTextureCache: CVMetalTextureCache!

    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(
        label: "com.mediapipe.prebuilt.example.videoQueue", qos: .userInitiated,
        attributes: [], autoreleaseFrequency: .workItem)
    let cameraFacing: AVCaptureDevice.Position = .front
    var aspectRatio: Float = 1.0

    let scene = SCNScene()
    let transformNode = SCNNode()
    let poseNode = SCNNode()

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
        // camera.fieldOfView = 63.0

        let cameraNode = SCNNode()
        cameraNode.camera = camera

        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(transformNode)
        transformNode.addChildNode(poseNode)

        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.frame = view.frame
        sceneView.rendersContinuously = true
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showWireframe, .renderAsWireframe]
        view.addSubview(sceneView)

        transformNode.geometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        transformNode.simdScale = .one
        transformNode.eulerAngles = SCNVector3(x: .pi, y: .pi * 0.75, z: 0)
        transformNode.position.z = -2
        transformNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 10)))

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
            camera.focusMode = .locked
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

extension ViewController: MPPBPoseDelegate {
    
    func tracker(
        _ tracker: MPPBPose!, didOutputLandmarks landmarks: [NSNumber]!,
        with index: Int
    ) {
        /*
        See mediapipe/modules/pose_landmark/pose_landmark_gpu.pbtxt#L99-L105
        
        let left_hip = simd_float3(
           x: landmarks[5 * 23].floatValue,
           y: landmarks[5 * 23 + 1].floatValue,
           z: landmarks[5 * 23 + 2].floatValue
        )
        let right_hip = simd_float3(
           x: landmarks[5 * 24].floatValue,
           y: landmarks[5 * 24 + 1].floatValue,
           z: landmarks[5 * 24 + 2].floatValue
        )
        let center_between_hips = (left_hip + right_hip) / 2
        */
    }

    func tracker(
        _ tracker: MPPBPose!, didOutputWorldLandmarks landmarks: [NSNumber]!,
        with index: Int
    ) {
        let vertexData = landmarks.map { $0.floatValue }.withUnsafeBufferPointer {
            Data(buffer: $0)
        }

        // See https://developer.apple.com/documentation/scenekit/scngeometrysource
        let vertexSource = SCNGeometrySource(
            data: vertexData, semantic: .vertex, vectorCount: landmarks.count / 5,
            usesFloatComponents: true, componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.stride * 0,
            dataStride: MemoryLayout<Float>.size * 5)

        let colorSource = SCNGeometrySource(
            data: vertexData, semantic: .color, vectorCount: landmarks.count / 5,
            usesFloatComponents: true, componentsPerVector: 1,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.stride * 3,
            dataStride: MemoryLayout<Float>.size * 5)

        let jointData = (0..<33).map { UInt32($0) }.withUnsafeBufferPointer {
            Data(buffer: $0)
        }

        let jointDescriptor = SCNGeometryElement(
            data: jointData, primitiveType: .point,
            primitiveCount: 33, bytesPerIndex: MemoryLayout<UInt32>.size)
        jointDescriptor.pointSize = 5.0
        jointDescriptor.minimumPointScreenSpaceRadius = 5.0
        jointDescriptor.maximumPointScreenSpaceRadius = 15.0

        let edgeData = ViewController.EDGE_TOPOLOGY.map { UInt32($0) }.withUnsafeBufferPointer {
            Data(buffer: $0)
        }

        let edgeDescriptor = SCNGeometryElement(
            data: edgeData, primitiveType: .line,
            primitiveCount: 35, bytesPerIndex: MemoryLayout<UInt32>.size)

        let skeletonGeometry = SCNGeometry(
            sources: [vertexSource, colorSource], elements: [jointDescriptor, edgeDescriptor])

        poseNode.geometry = skeletonGeometry
    }

    // Update video texture
    func tracker(_ tracker: MPPBPose!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
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

    // You can modify the graph without rebuilding the package.
    // Try edit `bool_value: false` to `bool_value: true`. It will enable segmentation pass.
    fileprivate static let CUSTOM_POSE_TRACKING_IOS_CALCULATORS_SOURCE = """
        # MediaPipe graph that performs pose tracking with TensorFlow Lite on GPU.

        # GPU buffer. (GpuBuffer)
        input_stream: "input_video"

        # Output image with rendered results. (GpuBuffer)
        output_stream: "output_video"
        # Pose landmarks. (NormalizedLandmarkList)
        output_stream: "pose_landmarks"
        # Pose world landmarks. (LandmarkList)
        output_stream: "pose_world_landmarks"

        # Generates side packet to enable segmentation.
        node {
            calculator: "ConstantSidePacketCalculator"
            output_side_packet: "PACKET:enable_segmentation"
            node_options: {
                [type.googleapis.com/mediapipe.ConstantSidePacketCalculatorOptions]: {
                    packet { bool_value: false }
                }
            }
        }

        # Generates side packet to select model complexity (heavy).
        node {
            calculator: "ConstantSidePacketCalculator"
            output_side_packet: "PACKET:model_complexity"
            node_options: {
                [type.googleapis.com/mediapipe.ConstantSidePacketCalculatorOptions]: {
                    packet { int_value: 2 }
                }
            }
        }

        # Throttles the images flowing downstream for flow control. It passes through
        # the very first incoming image unaltered, and waits for downstream nodes
        # (calculators and subgraphs) in the graph to finish their tasks before it
        # passes through another image. All images that come in while waiting are
        # dropped, limiting the number of in-flight images in most part of the graph to
        # 1. This prevents the downstream nodes from queuing up incoming images and data
        # excessively, which leads to increased latency and memory usage, unwanted in
        # real-time mobile applications. It also eliminates unnecessarily computation,
        # e.g., the output produced by a node may get dropped downstream if the
        # subsequent nodes are still busy processing previous inputs.
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

        # Subgraph that detects poses and corresponding landmarks.
        node {
            calculator: "PoseLandmarkGpu"
            input_side_packet: "ENABLE_SEGMENTATION:enable_segmentation"
            input_side_packet: "MODEL_COMPLEXITY:model_complexity"
            input_stream: "IMAGE:throttled_input_video"
            output_stream: "LANDMARKS:pose_landmarks"
            output_stream: "WORLD_LANDMARKS:pose_world_landmarks"
            output_stream: "SEGMENTATION_MASK:segmentation_mask"
            output_stream: "DETECTION:pose_detection"
            output_stream: "ROI_FROM_LANDMARKS:roi_from_landmarks"
        }

        # Subgraph that renders pose-landmark annotation onto the input image.
        node {
            calculator: "PoseRendererGpu"
            input_stream: "IMAGE:throttled_input_video"
            input_stream: "LANDMARKS:pose_landmarks"
            input_stream: "SEGMENTATION_MASK:segmentation_mask"
            input_stream: "DETECTION:pose_detection"
            input_stream: "ROI:roi_from_landmarks"
            output_stream: "IMAGE:output_video"
        }

        """

    // See mediapipe/graphs/pose_tracking/subgraphs/pose_landmarks_to_render_data.pbtxt#L47-L116
    fileprivate static let EDGE_TOPOLOGY: [UInt32] = [
        0, 1, 1, 2, 2, 3, 3, 7, 0, 4, 4, 5, 5, 6, 6, 8, 9, 10, 11, 12, 11, 13, 13, 15, 15, 17, 15,
        19, 15, 21, 17, 19, 12, 14, 14, 16, 16, 18, 16, 20, 16, 22, 18, 20, 11, 23, 12, 24, 23, 24,
        23, 25, 24, 26, 25, 27, 26, 28, 27, 29, 28, 30, 29, 31, 30, 32, 27, 31, 28, 32,
    ]
}
