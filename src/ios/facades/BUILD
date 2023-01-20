# "ios/prebuilt/facades/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/facades

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",   
)

ios_framework(
    name = "MPPBFacades",
    hdrs = [
        "MPPBFacades.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.facades",
    families = ["iphone", "ipad"],
    minimum_os_version = "13.0",
    deps = [
        ":MPPBFacadesFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBFacadesFramework",
    srcs = [
        "MPPBFacades.mm",
    ],
    hdrs = [
        "MPPBFacades.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/examples/ios/prebuilt/facades/models:facades_mobile_quant.tflite",
        "//mediapipe/examples/ios/prebuilt/facades/graphs:facades_mobile_gpu.binarypb",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
        # "AssetsLibrary",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/framework/port:parse_text_proto",
            "//mediapipe/examples/ios/prebuilt/facades/graphs:facades_mobile_gpu_calculators",
        ],
    }),
)