# "desktop/prebuilt/cartoon/graphs/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/desktop/cartoon

load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "mobile_calculators",
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/image:image_transformation_calculator",
        "//mediapipe/calculators/tflite:tflite_converter_calculator",
        "//mediapipe/calculators/tflite:tflite_custom_op_resolver_calculator",
        "//mediapipe/calculators/tflite:tflite_inference_calculator",
        "//mediapipe/examples/desktop/prebuilt/cartoon/graphs/calculators:tflite_tensors_to_image_frame_calculator",
        "//mediapipe/examples/desktop/prebuilt/cartoon/graphs/calculators:mediapipe_tensors_to_image_frame_calculator",
    ],
)

cc_library(
    name = "desktop_live_calculators",
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/image:image_transformation_calculator",
        "//mediapipe/calculators/tflite:tflite_converter_calculator",
        "//mediapipe/calculators/tflite:tflite_custom_op_resolver_calculator",
        "//mediapipe/calculators/tflite:tflite_inference_calculator",
        "//mediapipe/examples/desktop/prebuilt/cartoon/graphs/calculators:tflite_tensors_to_image_frame_calculator",
    ],
)

mediapipe_binary_graph(
    name = "cartoon_gan_mobile_cpu_binary_graph",
    graph = "cartoon_gan_mobile_cpu.pbtxt",
    output_name = "cartoon_gan_mobile_cpu.binarypb",
    deps = [":mobile_calculators"],
)