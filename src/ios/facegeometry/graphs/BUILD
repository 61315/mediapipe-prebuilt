load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "face_geometry_with_transform_calculators",
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/modules/face_geometry:env_generator_calculator",
        "//mediapipe/graphs/face_effect/subgraphs:single_face_geometry_from_landmarks_gpu",
        "//mediapipe/graphs/face_mesh/subgraphs:face_renderer_gpu",
    ],
)

mediapipe_binary_graph(
    name = "face_geometry_with_transform_binary_graph",
    graph = "face_geometry_with_transform.pbtxt",
    output_name = "face_geometry_with_transform.binarypb",
    deps = [
        ":face_geometry_with_transform_calculators",
    ],
)