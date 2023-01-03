# "ios/prebuilt/multipose/graphs/subgraphs/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/multipose/

load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_simple_subgraph",
)

package(default_visibility = ["//visibility:public"])

mediapipe_simple_subgraph(
    name = "multi_pose_renderer_gpu",
    graph = "multi_pose_renderer_gpu.pbtxt",
    register_as = "MultiPoseRendererGpu",
    deps = [
        "//mediapipe/calculators/core:split_proto_list_calculator",
        "//mediapipe/calculators/util:annotation_overlay_calculator",
        "//mediapipe/calculators/util:detections_to_render_data_calculator",
        "//mediapipe/calculators/util:landmarks_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_scale_calculator",
    ],
)