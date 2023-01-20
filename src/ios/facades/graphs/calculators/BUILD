# "ios/prebuilt/facades/graphs/calculators/BUILD"
# https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/facades

load("//mediapipe/framework/port:build_config.bzl", "mediapipe_proto_library")
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = ["//visibility:public"])

selects.config_setting_group(
    name = "gpu_inference_disabled",
    match_any = [
        "//mediapipe/gpu:disable_gpu",
    ],
)

mediapipe_proto_library(
    name = "tflite_tensors_to_image_frame_calculator_proto",
    srcs = ["tflite_tensors_to_image_frame_calculator.proto"],
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/framework:calculator_options_proto",
        "//mediapipe/framework:calculator_proto",
    ],
)

cc_library(
    name = "tflite_tensors_to_image_frame_calculator",
    srcs = ["tflite_tensors_to_image_frame_calculator.cc"],
    visibility = ["//visibility:public"],
    deps = [
        ":tflite_tensors_to_image_frame_calculator_cc_proto",
        "@com_google_absl//absl/strings:str_format",
        "@com_google_absl//absl/types:span",
        "//mediapipe/framework/formats:image_frame",
        "//mediapipe/framework/formats:image_frame_opencv",
        "//mediapipe/framework/port:opencv_imgcodecs",
        "//mediapipe/framework/port:opencv_imgproc",
        "//mediapipe/framework/port:ret_check",
        "//mediapipe/framework:calculator_context",
        "//mediapipe/framework:calculator_framework",
        "//mediapipe/util:resource_util",
        "@org_tensorflow//tensorflow/lite:framework",
    ] + selects.with_or({
        ":gpu_inference_disabled": [],
        "//mediapipe:ios": [],
        "//conditions:default": [
            "//mediapipe/gpu:gl_calculator_helper",
            "//mediapipe/gpu:gl_simple_shaders",
            "//mediapipe/gpu:gpu_buffer",
            "//mediapipe/gpu:shader_util",
            "@org_tensorflow//tensorflow/lite/delegates/gpu:gl_delegate",
            "@org_tensorflow//tensorflow/lite/delegates/gpu/gl:gl_buffer",
            "@org_tensorflow//tensorflow/lite/delegates/gpu/gl:gl_program",
            "@org_tensorflow//tensorflow/lite/delegates/gpu/gl:gl_shader",
            "@org_tensorflow//tensorflow/lite/delegates/gpu/gl:gl_texture",
        ],
    }),
    alwayslink = 1,
)
