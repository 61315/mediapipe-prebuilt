load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

ios_framework(
    name = "MPPBHand",
    hdrs = [
        "MPPBHand.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.hand",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPBHandFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBHandFramework",
    srcs = [
        "MPPBHand.mm",
    ],
    hdrs = [
        "MPPBHand.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu.binarypb",
        "//mediapipe/modules/hand_landmark:hand_landmark_full.tflite",
        "//mediapipe/modules/hand_landmark:handedness.txt",
        "//mediapipe/modules/palm_detection:palm_detection_full.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/hand_tracking:mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)