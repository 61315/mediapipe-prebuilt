# "ios/prebuilt/multipose/graphs/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/multipose/

load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "multi_pose_tracking_gpu_calculators",
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/core:pass_through_calculator",
        "//mediapipe/calculators/tensor:tensors_to_floats_calculator",
        "//mediapipe/examples/ios/prebuilt/multipose/graphs/subgraphs:multi_pose_renderer_gpu",
        "//mediapipe/examples/ios/prebuilt/multipose/modules:multi_pose_landmark_gpu",
        "//mediapipe/framework/formats:landmark_cc_proto",
    ],
)

mediapipe_binary_graph(
    name = "multi_pose_tracking_gpu_binary_graph",
    graph = "multi_pose_tracking_gpu.pbtxt",
    output_name = "multi_pose_tracking_gpu.binarypb",
    deps = [
        ":multi_pose_tracking_gpu_calculators",
    ],
)