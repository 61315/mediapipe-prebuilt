//
//  ViewController.swift
//  mppb-ios-facades
//
//  Created by minseopark on January 20, 2023.
//

import AVFoundation
import SceneKit
import UIKit

class ViewController: UIViewController {

    let tracker = MPPBFacades()!
//    let tracker = MPPBFacades(
//        string: ViewController.FACADES_MOBILE_GPU_CALCULATORS_SOURCE)!

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

extension ViewController: MPPBFacadesDelegate {

    // Update video texture
    func tracker(_ tracker: MPPBFacades!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer) {
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

    fileprivate static let FACADES_MOBILE_GPU_CALCULATORS_SOURCE = """
        # MediaPipe graph that runs pix2pix variant with TensorFlow Lite on GPU.

        # Input image. (ImageFrame)
        input_stream: "IMAGE_GPU:input_video"

        # Output image with rendered results. (ImageFrame)
        output_stream: "IMAGE_GPU:output_video"

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

        # Calculate size of the image.
        node {
            calculator: "ImagePropertiesCalculator"
            input_stream: "IMAGE_GPU:throttled_input_video"
            output_stream: "SIZE:image_size"
        }

        node {
            calculator: "ImageCroppingCalculator"
            input_stream: "IMAGE_GPU:throttled_input_video"
            output_stream: "IMAGE_GPU:cropped_input_video"
            node_options: {
                [type.googleapis.com/mediapipe.ImageCroppingCalculatorOptions] {
                    width: 256
                    height: 256
                    norm_center_x: 0.5
                    norm_center_y: 0.5
                }
            }
        }

        # Converts the transformed input image on GPU into an image tensor stored in
        # TfLiteTensor. The zero_center option is set to true to normalize the
        # pixel values to [-1.f, 1.f] as opposed to [0.f, 1.f]. With the
        # max_num_channels option set to 4, all 4 RGBA channels are contained in the
        # image tensor.
        node {
            calculator: "TfLiteConverterCalculator"
            input_stream: "IMAGE_GPU:cropped_input_video"
            output_stream: "TENSORS_GPU:image_tensor"
            node_options: {
                [type.googleapis.com/mediapipe.TfLiteConverterCalculatorOptions] {
                    zero_center: true
                    max_num_channels: 4
                }
            }
        }

        # Runs a TensorFlow Lite model on GPU that takes an image tensor and outputs a
        # tensor representing the bitmap, which has the same width and height
        # as the input image tensor.
        node {
            calculator: "TfLiteInferenceCalculator"
            input_stream: "TENSORS_GPU:image_tensor"
            output_stream: "TENSORS:bitmap_tensor"
            node_options: {
                [type.googleapis.com/mediapipe.TfLiteInferenceCalculatorOptions] {
                    model_path: "mediapipe/examples/ios/prebuilt/facades/models/facades_mobile_quant.tflite"
                    delegate { gpu {} }
                }
            }
        }

        # Decodes the bitmap tensor generated by the TensorFlow Lite model into a
        # image of values in [0, 255], stored in a CPU buffer.
        node {
            calculator: "TfLiteTensorsToImageFrameCalculator"
            input_stream: "TENSORS:bitmap_tensor"
            output_stream: "IMAGE:translated_image_cpu"
            node_options: {
                [type.googleapis.com/mediapipe.TfLiteTensorsToImageFrameCalculatorOptions] {
                    tensor_width: 256
                    tensor_height: 256
                    tensor_channels: 3
                    scale_factor: 255.0
                }
            }
        }

        node {
            calculator: "ImageFrameToGpuBufferCalculator"
            input_stream: "translated_image_cpu"
            output_stream: "translated_image"
        }

        node: {
            calculator: "ImageTransformationCalculator"
            input_stream: "IMAGE_GPU:translated_image"
            input_stream: "OUTPUT_DIMENSIONS:image_size"
            output_stream: "IMAGE_GPU:output_video"
            node_options: {
                [type.googleapis.com/mediapipe.ImageTransformationCalculatorOptions] {
                    scale_mode: FIT
                }
            }
        }


        """
}
