# "ios/prebuilt/facades/graphs/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/facades

load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "facades_mobile_gpu_calculators",
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/tflite:tflite_converter_calculator",
        "//mediapipe/calculators/tflite:tflite_inference_calculator",
        "//mediapipe/calculators/image:image_transformation_calculator",
        "//mediapipe/calculators/image:image_properties_calculator",
        "//mediapipe/calculators/image:image_cropping_calculator",
        "//mediapipe/gpu:image_frame_to_gpu_buffer_calculator",
        # Custom calculators below.
        "//mediapipe/examples/ios/prebuilt/facades/graphs/calculators:tflite_tensors_to_image_frame_calculator",
    ],
)

mediapipe_binary_graph(
    name = "facades_mobile_gpu_binary_graph",
    graph = "facades_mobile_gpu.pbtxt",
    output_name = "facades_mobile_gpu.binarypb",
    deps = [
        ":facades_mobile_gpu_calculators",
    ],
)