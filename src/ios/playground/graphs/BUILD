load(
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_binary_graph",
)

package(default_visibility = ["//visibility:public"])


cc_library(
    name = "our_first_calculators",
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/core:pass_through_calculator",
        "//mediapipe/calculators/image:color_convert_calculator",
        "//mediapipe/calculators/image:image_transformation_calculator",
        "//mediapipe/calculators/image:scale_image_calculator",
    ],
)

mediapipe_binary_graph(
    name = "our_first_binary_graph",
    graph = "our_first.pbtxt",
    output_name = "our_first.binarypb",
    deps = [
        ":our_first_calculators",
    ],
)

# TODO: You can add new calculators to the project like above.

# Same as //mediapipe/graphs/edge_detection:mobile_calculators
# cc_library(
#     name = "our_second_calculator",
#     visibility = ["//visibility:public"],
#     deps = [
#         "//mediapipe/calculators/image:luminance_calculator",
#         "//mediapipe/calculators/image:sobel_edges_calculator",
#     ],
# )

# mediapipe_binary_graph(
#     name = "our_second_binary_graph",
#     graph = "our_second.pbtxt",
#     output_name = "our_second.binarypb",
#     deps = [
#         ":our_second_calculator",
#     ],
# )

# cc_library(
#     name = "our_third_calculators",
#     visibility = ["//visibility:public"],
#     deps = [
#         "//mediapipe/calculators/image:luminance_calculator",
#         "//mediapipe/calculators/image:sobel_edges_calculator",
#     ],
# )

# mediapipe_binary_graph(
#     name = "our_third_binary_graph",
#     graph = "our_third.pbtxt",
#     output_name = "our_third.binarypb",
#     deps = [
#         ":our_third_calculators",
#     ],
# )