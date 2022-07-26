load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",   
)

ios_framework(
    name = "MPPBPlayground",
    hdrs = [
        "MPPBPlayground.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.playground",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPBPlaygroundFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBPlaygroundFramework",
    srcs = [
        "MPPBPlayground.mm",
    ],
    hdrs = [
        "MPPBPlayground.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/examples/ios/prebuilt/playground/graphs:our_first.binarypb",
        # "//mediapipe/examples/ios/prebuilt/playground/graphs:our_second.binarypb",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
        "AssetsLibrary",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        # "//mediapipe/objc:mediapipe_input_sources_ios",
        # "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/framework/port:parse_text_proto",
            "//mediapipe/examples/ios/prebuilt/playground/graphs:our_first_calculators",
            # "//mediapipe/graphs/hand_tracking:mobile_calculators",
            # "//mediapipe/examples/ios/prebuilt/playground/graphs:our_second_calculator",
            # "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)