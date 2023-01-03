//
//  ViewController.swift
//  mppb-ios-multipose
//
//  Created by minseopark on 2022/12/30.
//

import AVFoundation
import SceneKit
import UIKit

class ViewController: UIViewController {

    let tracker = MPPBMultiPose()!
//    let tracker = MPPBMultiPose(
//        string: ViewController.CUSTOM_POSE_TRACKING_IOS_CALCULATORS_SOURCE)!

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
    let multiposeNode = SCNNode()

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
        transformNode.addChildNode(multiposeNode)

        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.frame = view.frame
        sceneView.rendersContinuously = true
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showWireframe, .renderAsWireframe]
        view.addSubview(sceneView)

        transformNode.geometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        transformNode.simdScale = .one
//        transformNode.eulerAngles = SCNVector3(x: .pi, y: .pi * 0.75, z: 0)
        transformNode.position.z = -2
//        transformNode.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 10)))

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

    // You can modify the graph without rebuilding the package.
    // Try edit `bool_value: false` to `bool_value: true`. It will enable segmentation pass.
    fileprivate static let CUSTOM_POSE_TRACKING_IOS_CALCULATORS_SOURCE = """
        # MediaPipe graph that performs pose tracking with TensorFlow Lite on GPU.

        # GPU buffer. (GpuBuffer)
        input_stream: "input_video"

        # Output image with rendered results. (GpuBuffer)
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

        # Extracts image size.
        node {
          calculator: "ImagePropertiesCalculator"
          input_stream: "IMAGE_GPU:throttled_input_video"
          output_stream: "SIZE:image_size"
        }

        node: {
          calculator: "ImageToTensorCalculator"
          input_stream: "IMAGE_GPU:throttled_input_video"
          output_stream: "TENSORS:input_tensors"
          output_stream: "LETTERBOX_PADDING:letterbox_padding"
          options: {
            [mediapipe.ImageToTensorCalculatorOptions.ext] {
              output_tensor_width: 224
              output_tensor_height: 224
              keep_aspect_ratio: true
              output_tensor_float_range {
                min: -1.0
                max: 1.0
              }
              border_mode: BORDER_ZERO
              gpu_origin: TOP_LEFT
            }
          }
        }

        # Runs a TensorFlow Lite model on CPU that takes an image tensor and outputs a
        # vector of tensors representing, for instance, detection boxes/keypoints and
        # scores.
        node {
          calculator: "InferenceCalculator"
          input_stream: "TENSORS:input_tensors"
          output_stream: "TENSORS:detection_tensors"
          options: {
            [mediapipe.InferenceCalculatorOptions.ext] {
              model_path: "mediapipe/modules/pose_detection/pose_detection.tflite"
              #
              delegate: { gpu { use_advanced_gpu_api: true } }
            }
          }
        }

        # Generates a single side packet containing a vector of SSD anchors based on
        # the specification in the options.
        node {
          calculator: "SsdAnchorsCalculator"
          output_side_packet: "anchors"
          options: {
            [mediapipe.SsdAnchorsCalculatorOptions.ext] {
              num_layers: 5
              min_scale: 0.1484375
              max_scale: 0.75
              input_size_height: 224
              input_size_width: 224
              anchor_offset_x: 0.5
              anchor_offset_y: 0.5
              strides: 8
              strides: 16
              strides: 32
              strides: 32
              strides: 32
              aspect_ratios: 1.0
              fixed_anchor_size: true
            }
          }
        }

        # Decodes the detection tensors generated by the TensorFlow Lite model, based on
        # the SSD anchors and the specification in the options, into a vector of
        # detections. Each detection describes a detected object.
        node {
          calculator: "TensorsToDetectionsCalculator"
          input_stream: "TENSORS:detection_tensors"
          input_side_packet: "ANCHORS:anchors"
          output_stream: "DETECTIONS:unfiltered_detections"
          options: {
            [mediapipe.TensorsToDetectionsCalculatorOptions.ext] {
              num_classes: 1
              num_boxes: 2254
              num_coords: 12
              box_coord_offset: 0
              keypoint_coord_offset: 4
              num_keypoints: 4
              num_values_per_keypoint: 2
              sigmoid_score: true
              score_clipping_thresh: 100.0
              reverse_output_order: true
              x_scale: 224.0
              y_scale: 224.0
              h_scale: 224.0
              w_scale: 224.0
              min_score_thresh: 0.15
              max_results: 50
            }
          }
        }

        # Performs non-max suppression to remove excessive detections.
        node {
          calculator: "NonMaxSuppressionCalculator"
          input_stream: "unfiltered_detections"
          output_stream: "filtered_detections"
          options: {
            [mediapipe.NonMaxSuppressionCalculatorOptions.ext] {
              min_suppression_threshold: 0.35
              max_num_detections: 3
              overlap_type: JACCARD
              # overlap_type: MODIFIED_JACCARD
              # overlap_type: INTERSECTION_OVER_UNION
              # algorithm: DEFAULT
              algorithm: WEIGHTED
            }
          }
        }

        # Adjusts detection locations (already normalized to [0.f, 1.f]) on the
        # letterboxed image (after image transformation with the FIT scale mode) to the
        # corresponding locations on the same image with the letterbox removed (the
        # input image to the graph before image transformation).
        node {
          calculator: "DetectionLetterboxRemovalCalculator"
          input_stream: "DETECTIONS:filtered_detections"
          input_stream: "LETTERBOX_PADDING:letterbox_padding"
          output_stream: "DETECTIONS:pose_detections"
        }

        # Converts detections to drawing primitives for annotation overlay.
        node {
          calculator: "DetectionsToRenderDataCalculator"
          input_stream: "DETECTIONS:pose_detections"
          output_stream: "RENDER_DATA:detections_render_data"
          node_options: {
            [type.googleapis.com/mediapipe.DetectionsToRenderDataCalculatorOptions] {
              thickness: 1.0
              color { r: 0 g: 255 b: 0 }
            }
          }
        }

        ###### detection above, landmarks below

        node {
          calculator: "BeginLoopDetectionCalculator"
          input_stream: "ITERABLE:pose_detections"
          input_stream: "CLONE:image_size"
          output_stream: "ITEM:pose_detection"
          output_stream: "CLONE:image_size_for_poses"
          output_stream: "BATCH_END:pose_detections_timestamp"
        }

        # Calculates region of interest (ROI) base on the specified poses.
        node {
          calculator: "PoseDetectionToRoi"
          input_stream: "DETECTION:pose_detection"
          input_stream: "IMAGE_SIZE:image_size_for_poses"
          output_stream: "ROI:pose_rect_from_pose_detection"
        }

        # Collects a NormalizedRect for each hand into a vector. Upon receiving the
        # BATCH_END timestamp, outputs the vector of NormalizedRect at the BATCH_END
        # timestamp.
        node {
          name: "EndLoopForPoseDetections"
          calculator: "EndLoopNormalizedRectCalculator"
          input_stream: "ITEM:pose_rect_from_pose_detection"
          input_stream: "BATCH_END:pose_detections_timestamp"
          output_stream: "ITERABLE:pose_rects_from_detections"
        }

        node {
          calculator: "BeginLoopNormalizedRectCalculator"
          input_stream: "ITERABLE:pose_rects_from_detections"
          input_stream: "CLONE:0:throttled_input_video"
          input_stream: "CLONE:1:image_size"
          output_stream: "ITEM:pose_rect"
          output_stream: "CLONE:0:image_for_landmarks"
          output_stream: "CLONE:1:image_size_for_landmarks"
          output_stream: "BATCH_END:pose_rects_timestamp"
        }

        # Generates side packet to select model complexity (heavy).
        node {
            calculator: "ConstantSidePacketCalculator"
            output_side_packet: "PACKET:model_complexity"
            node_options: {
                [type.googleapis.com/mediapipe.ConstantSidePacketCalculatorOptions]: {
                    packet { int_value: 0 }
                }
            }
        }

        # Detects pose landmarks within specified region of interest of the image.
        node {
          calculator: "PoseLandmarkByRoiGpu"
          input_side_packet: "MODEL_COMPLEXITY:model_complexity"
          input_side_packet: "ENABLE_SEGMENTATION:enable_segmentation"
          input_stream: "IMAGE:image_for_landmarks"
          input_stream: "ROI:pose_rect"
          output_stream: "LANDMARKS:unfiltered_pose_landmarks"
          output_stream: "AUXILIARY_LANDMARKS:unfiltered_auxiliary_landmarks"
          output_stream: "WORLD_LANDMARKS:unfiltered_world_landmarks"
          output_stream: "SEGMENTATION_MASK:unfiltered_segmentation_mask"
        }

        # Smoothes landmarks to reduce jitter.
        node {
          calculator: "PoseLandmarkFiltering"
          input_side_packet: "ENABLE:smooth_landmarks"
          input_stream: "IMAGE_SIZE:image_size_for_landmarks"
          input_stream: "NORM_LANDMARKS:unfiltered_pose_landmarks"
          input_stream: "AUX_NORM_LANDMARKS:unfiltered_auxiliary_landmarks"
          input_stream: "WORLD_LANDMARKS:unfiltered_world_landmarks"
          output_stream: "FILTERED_NORM_LANDMARKS:pose_landmarks"
          output_stream: "FILTERED_AUX_NORM_LANDMARKS:auxiliary_landmarks"
          output_stream: "FILTERED_WORLD_LANDMARKS:pose_world_landmarks"
        }

        # Calculates region of interest based on the auxiliary landmarks, to be used in
        # the subsequent image.
        node {
          calculator: "PoseLandmarksToRoi"
          input_stream: "LANDMARKS:auxiliary_landmarks"
          input_stream: "IMAGE_SIZE:image_size_for_landmarks"
          output_stream: "ROI:pose_rect_from_landmarks"
        }

        # Converts normalized rects to drawing primitives for annotation overlay.
        node {
          calculator: "RectToRenderDataCalculator"
          input_stream: "NORM_RECT:pose_rect_from_landmarks"
          output_stream: "RENDER_DATA:roi_render_data"
          node_options: {
            [type.googleapis.com/mediapipe.RectToRenderDataCalculatorOptions] {
              filled: false
              color { r: 255 g: 0 b: 0 }
              thickness: 2.0
            }
          }
        }

        # Calculates rendering scale based on the pose roi.
        node {
          calculator: "RectToRenderScaleCalculator"
          input_stream: "NORM_RECT:pose_rect"
          input_stream: "IMAGE_SIZE:image_size_for_landmarks"
          output_stream: "RENDER_SCALE:render_scale"
          node_options: {
            [type.googleapis.com/mediapipe.RectToRenderScaleCalculatorOptions] {
              multiplier: 0.0012
            }
          }
        }

        # Converts landmarks to drawing primitives for annotation overlay.
        node {
          calculator: "LandmarksToRenderDataCalculator"
          input_stream: "NORM_LANDMARKS:auxiliary_landmarks"
          input_stream: "RENDER_SCALE:render_scale"
          output_stream: "RENDER_DATA:landmarks_render_data"
          node_options: {
            [type.googleapis.com/mediapipe.LandmarksToRenderDataCalculatorOptions] {
              landmark_connections: 0
              landmark_connections: 1
              landmark_connections: 1
              landmark_connections: 2
              landmark_connections: 2
              landmark_connections: 3
              landmark_connections: 3
              landmark_connections: 7
              landmark_connections: 0
              landmark_connections: 4
              landmark_connections: 4
              landmark_connections: 5
              landmark_connections: 5
              landmark_connections: 6
              landmark_connections: 6
              landmark_connections: 8
              landmark_connections: 9
              landmark_connections: 10
              landmark_connections: 11
              landmark_connections: 12
              landmark_connections: 11
              landmark_connections: 13
              landmark_connections: 13
              landmark_connections: 15
              landmark_connections: 15
              landmark_connections: 17
              landmark_connections: 15
              landmark_connections: 19
              landmark_connections: 15
              landmark_connections: 21
              landmark_connections: 17
              landmark_connections: 19
              landmark_connections: 12
              landmark_connections: 14
              landmark_connections: 14
              landmark_connections: 16
              landmark_connections: 16
              landmark_connections: 18
              landmark_connections: 16
              landmark_connections: 20
              landmark_connections: 16
              landmark_connections: 22
              landmark_connections: 18
              landmark_connections: 20
              landmark_connections: 11
              landmark_connections: 23
              landmark_connections: 12
              landmark_connections: 24
              landmark_connections: 23
              landmark_connections: 24
              landmark_connections: 23
              landmark_connections: 25
              landmark_connections: 24
              landmark_connections: 26
              landmark_connections: 25
              landmark_connections: 27
              landmark_connections: 26
              landmark_connections: 28
              landmark_connections: 27
              landmark_connections: 29
              landmark_connections: 28
              landmark_connections: 30
              landmark_connections: 29
              landmark_connections: 31
              landmark_connections: 30
              landmark_connections: 32
              landmark_connections: 27
              landmark_connections: 31
              landmark_connections: 28
              landmark_connections: 32

              landmark_color { r: 255 g: 255 b: 255 }
              connection_color { r: 255 g: 255 b: 255 }
              thickness: 1.0
              visualize_landmark_depth: false
              utilize_visibility: true
              visibility_threshold: 0.5
            }
          }
        }

        node {
          calculator: "EndLoopRenderDataCalculator"
          input_stream: "ITEM:roi_render_data"
          input_stream: "BATCH_END:pose_rects_timestamp"
          output_stream: "ITERABLE:rois_render_data"
        }

        node {
          calculator: "EndLoopRenderDataCalculator"
          input_stream: "ITEM:landmarks_render_data"
          input_stream: "BATCH_END:pose_rects_timestamp"
          output_stream: "ITERABLE:landmarks_render_data_list"
        }

        # Collects a set of landmarks for each hand into a vector. Upon receiving the
        # BATCH_END timestamp, outputs the vector of landmarks at the BATCH_END
        # timestamp.
        node {
          calculator: "EndLoopNormalizedLandmarkListVectorCalculator"
          input_stream: "ITEM:pose_landmarks"
          input_stream: "BATCH_END:pose_rects_timestamp"
          output_stream: "ITERABLE:multi_pose_landmarks"
        }

        # Collects a set of world landmarks for each hand into a vector. Upon receiving
        # the BATCH_END timestamp, outputs the vector of landmarks at the BATCH_END
        # timestamp.
        node {
          calculator: "EndLoopLandmarkListVectorCalculator"
          input_stream: "ITEM:pose_world_landmarks"
          input_stream: "BATCH_END:pose_rects_timestamp"
          output_stream: "ITERABLE:multi_pose_world_landmarks"
        }

        # Collects a NormalizedRect for each hand into a vector. Upon receiving the
        # BATCH_END timestamp, outputs the vector of NormalizedRect at the BATCH_END
        # timestamp.
        node {
          calculator: "EndLoopNormalizedRectCalculator"
          input_stream: "ITEM:pose_rect_from_landmarks"
          input_stream: "BATCH_END:pose_rects_timestamp"
          output_stream: "ITERABLE:pose_rects_from_landmarks"
        }

        #### annotations below

        # Detections from landmarks



        # Draws annotations and overlays them on top of the input images.
        node {
          calculator: "AnnotationOverlayCalculator"
          input_stream: "IMAGE_GPU:throttled_input_video"
          input_stream: "VECTOR:0:rois_render_data"
          input_stream: "VECTOR:1:landmarks_render_data_list"
          # input_stream: "detections_render_data"
          output_stream: "IMAGE_GPU:output_video"
        }


        """

    // See mediapipe/graphs/multipose_tracking/subgraphs/multipose_landmarks_to_render_data.pbtxt#L47-L116
    fileprivate static let EDGE_TOPOLOGY: [UInt32] = [
        0, 1, 1, 2, 2, 3, 3, 7, 0, 4, 4, 5, 5, 6, 6, 8, 9, 10, 11, 12, 11, 13, 13, 15, 15, 17, 15,
        19, 15, 21, 17, 19, 12, 14, 14, 16, 16, 18, 16, 20, 16, 22, 18, 20, 11, 23, 12, 24, 23, 24,
        23, 25, 24, 26, 25, 27, 26, 28, 27, 29, 28, 30, 29, 31, 30, 32, 27, 31, 28, 32,
    ]
}
