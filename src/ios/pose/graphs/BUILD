load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "custom_pose_tracking_ios_calculators",
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/graphs/pose_tracking/subgraphs:pose_renderer_gpu",
        "//mediapipe/modules/pose_landmark:pose_landmark_gpu",
        "//mediapipe/framework/formats:landmark_cc_proto",
    ],
)

mediapipe_binary_graph(
    name = "custom_pose_tracking_ios_binary_graph",
    graph = "custom_pose_tracking_ios.pbtxt",
    output_name = "custom_pose_tracking_ios.binarypb",
    deps = [
        ":custom_pose_tracking_ios_calculators",
    ],
)