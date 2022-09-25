load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

ios_framework(
    name = "MPPBFaceMesh",
    hdrs = [
        "MPPBFaceMesh.h",
    ],
    infoplists = ["Info.plist"],
    bundle_id = "com.mediapipe.prebuilt.facemesh",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    deps = [
        ":MPPBFaceMeshFramework",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MPPBFaceMeshFramework",
    srcs = [
        "MPPBFaceMesh.mm",
    ],
    hdrs = [
        "MPPBFaceMesh.h",
    ],
    copts = ["-std=c++17"],
    data = [
        "//mediapipe/modules/face_detection:face_detection_short_range.tflite",
        "//mediapipe/modules/face_landmark:face_landmark_with_attention.tflite",
        "//mediapipe/examples/ios/prebuilt/facemesh/graphs:custom_face_mesh_ios.binarypb",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/examples/ios/prebuilt/facemesh/graphs:custom_face_mesh_ios_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)