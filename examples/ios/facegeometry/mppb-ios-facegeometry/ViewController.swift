//
//  ViewController.swift
//  mppb-ios-facegeometry
//
//  Created by minseopark on 2022/07/27.
//

import UIKit
import AVFoundation
import SceneKit

class ViewController: UIViewController {

//    let tracker = MPPBFaceGeometry(string: ViewController.FACE_GEOMETRY_WITH_TRANSFORM_CALCULATORS_SOURCE)!
    let tracker = MPPBFaceGeometry()!
    
    let cameraFacing: AVCaptureDevice.Position = .front
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "com.mediapipe.prebuilt.example.videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var backgroundTextureCache: CVMetalTextureCache!
    let metalDevice = MTLCreateSystemDefaultDevice()!
    let scene = SCNScene()
    let originNode = SCNNode(geometry: SCNBox(width: 15, height: 15, length: 15, chamferRadius: 0))
    
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

extension ViewController: MPPBFaceGeometryDelegate {
    func tracker(_ tracker: MPPBFaceGeometry!, didOutputTransform transform: simd_float4x4, withFace index: Int) {
        // The matrix is col-majored
        originNode.simdTransform = transform
        
        // This callback demonstrates how the output face geometry packet can be obtained and used in an
        // iOS app. As an example, the Z-translation component of the face pose transform matrix is logged
        // for each face being equal to the approximate distance away from the camera in centimeters.
        print("Approx. distance away from camera for face\(index): \(-transform.columns.3.z) cm");
        print("pos: \(originNode.simdPosition) rot: \(originNode.simdEulerAngles)")
    }
    
    func tracker(_ tracker: MPPBFaceGeometry!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async { [unowned self] in
            scene.background.contents = processPixelBuffer(pixelBuffer: pixelBuffer)
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
    
    fileprivate static let FACE_GEOMETRY_WITH_TRANSFORM_CALCULATORS_SOURCE = """
# MediaPipe graph that extract transformation data from detected faces
# on a live video stream.
# Used in the examples in mediapipe/examples/ios/prebuilt/facegeometry.

# GPU image. (ImageFrame)
input_stream: "input_video"

# GPU image. (ImageFrame)
output_stream: "output_video"

output_stream: "MULTI_FACE_GEOMETRY:multi_face_geometry"

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
    input_stream: "FINISHED:multi_face_geometry"
    input_stream_info: {
        tag_index: "FINISHED"
        back_edge: true
    }
    output_stream: "throttled_input_video"
}

# Calculate size of the image.
node {
    calculator: "ImagePropertiesCalculator"
    input_stream: "IMAGE_GPU:throttled_input_video"
    output_stream: "SIZE:input_image_size"
}

# Defines how many faces to detect. Iris tracking currently only handles one
# face (left and right eye), and therefore this should always be set to 1.
node {
    calculator: "ConstantSidePacketCalculator"
    output_side_packet: "PACKET:0:num_faces"
    node_options: {
        [type.googleapis.com/mediapipe.ConstantSidePacketCalculatorOptions]: {
            packet { int_value: 1 }
        }
    }
}

# Detects faces and corresponding landmarks.
node {
    calculator: "FaceLandmarkFrontGpu"
    input_stream: "IMAGE:throttled_input_video"
    input_side_packet: "NUM_FACES:num_faces"
    output_stream: "LANDMARKS:multi_face_landmarks"
    output_stream: "ROIS_FROM_LANDMARKS:face_rects_from_landmarks"
    output_stream: "DETECTIONS:face_detections"
    output_stream: "ROIS_FROM_DETECTIONS:face_rects_from_detections"
}

# Generates an environment that describes the current virtual scene.
node {
    calculator: "FaceGeometryEnvGeneratorCalculator"
    output_side_packet: "ENVIRONMENT:environment"
    node_options: {
        [type.googleapis.com/mediapipe.FaceGeometryEnvGeneratorCalculatorOptions] {
            environment: {
                origin_point_location: TOP_LEFT_CORNER
                perspective_camera: {
                    vertical_fov_degrees: 63.0  # 63 degrees
                    near: 1.0  # 1cm
                    far: 10000.0  # 100m
                }
            }
        }
    }
}

# Extracts a single set of face landmarks associated with the most prominent
# face detected from a collection.
node {
  calculator: "SplitNormalizedLandmarkListVectorCalculator"
  input_stream: "multi_face_landmarks"
  output_stream: "face_landmarks"
  node_options: {
    [type.googleapis.com/mediapipe.SplitVectorCalculatorOptions] {
      ranges: { begin: 0 end: 1 }
      element_only: true
    }
  }
}

# Applies smoothing to the single set of face landmarks.
node {
  calculator: "FaceLandmarksSmoothing"
  input_stream: "NORM_LANDMARKS:face_landmarks"
  input_stream: "IMAGE_SIZE:input_image_size"
  output_stream: "NORM_FILTERED_LANDMARKS:smoothed_face_landmarks"
}

# Puts the single set of smoothed landmarks back into a collection to simplify
# passing the result into the `FaceGeometryFromLandmarks` subgraph.
node {
  calculator: "ConcatenateNormalizedLandmarkListVectorCalculator"
  input_stream: "smoothed_face_landmarks"
  output_stream: "multi_smoothed_face_landmarks"
}

# Subgraph that renders face-landmark annotation onto the input image.
node {
    calculator: "FaceRendererGpu"
    input_stream: "IMAGE:throttled_input_video"
    input_stream: "LANDMARKS:multi_smoothed_face_landmarks"
    input_stream: "NORM_RECTS:face_rects_from_landmarks"
    input_stream: "DETECTIONS:face_detections"
    output_stream: "IMAGE:output_video"
}

# Computes face geometry from face landmarks for a single face.
node {
    calculator: "FaceGeometryFromLandmarks"
    input_stream: "MULTI_FACE_LANDMARKS:multi_smoothed_face_landmarks"
    input_stream: "IMAGE_SIZE:input_image_size"
    input_side_packet: "ENVIRONMENT:environment"
    output_stream: "MULTI_FACE_GEOMETRY:multi_face_geometry"
}

"""
}


