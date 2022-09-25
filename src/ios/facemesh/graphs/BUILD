load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "custom_face_mesh_ios_calculators",
    deps = [
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/core:concatenate_detection_vector_calculator",
        "//mediapipe/calculators/core:split_vector_calculator",
        "//mediapipe/calculators/util:landmarks_smoothing_calculator",
        "//mediapipe/graphs/face_mesh/subgraphs:face_renderer_gpu",
        "//mediapipe/modules/face_landmark:face_landmark_front_gpu",
    ],
)

mediapipe_binary_graph(
    name = "custom_face_mesh_ios_binary_graph",
    graph = "custom_face_mesh_ios.pbtxt",
    output_name = "custom_face_mesh_ios.binarypb",
    deps = [":custom_face_mesh_ios_calculators"],
)
