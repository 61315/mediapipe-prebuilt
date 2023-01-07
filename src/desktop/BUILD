# "desktop/prebuilt/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/desktop

package(default_visibility = [
    "//visibility:public",
])

cc_library(
    name = "prebuilt_run_graph_main_cpu",
    srcs = ["prebuilt_run_graph_main_cpu.cc"],
    deps = [
        "//mediapipe/framework:calculator_framework",
        "//mediapipe/framework/formats:image_frame",
        "//mediapipe/framework/formats:image_frame_opencv",
        "//mediapipe/framework/port:file_helpers",
        "//mediapipe/framework/port:opencv_highgui",
        "//mediapipe/framework/port:opencv_imgproc",
        "//mediapipe/framework/port:opencv_video",
        "//mediapipe/framework/port:parse_text_proto",
        "//mediapipe/framework/port:status",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/flags:parse",
    ],
)
