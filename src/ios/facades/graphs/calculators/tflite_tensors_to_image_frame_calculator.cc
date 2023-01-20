// "ios/prebuilt/facades/graphs/calculators/tflite_tensors_to_image_frame_calculator.cc"
// https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/facades

#include <string>
#include <vector>

#include "absl/strings/str_format.h"
#include "absl/types/span.h"
#include "mediapipe/framework/calculator_context.h"
#include "mediapipe/framework/calculator_framework.h"
#include "mediapipe/framework/formats/image_frame.h"
#include "mediapipe/framework/formats/image_frame_opencv.h"
#include "mediapipe/framework/port/opencv_imgcodecs_inc.h"
#include "mediapipe/framework/port/opencv_imgproc_inc.h"
#include "mediapipe/framework/port/ret_check.h"
#include "mediapipe/util/resource_util.h"
#include "tensorflow/lite/interpreter.h"

#include "mediapipe/examples/ios/prebuilt/facades/graphs/calculators/tflite_tensors_to_image_frame_calculator.pb.h"

namespace {

constexpr char kTensorsTag[] = "TENSORS";
constexpr char kImageTag[] = "IMAGE";

}  // namespace

namespace mediapipe {

// Converts TFLite tensors from a tflite style transfer model to an image.
//
// Produces result as an RGBA image.
//
// Inputs:
//   One of the following TENSORS tags:
//   TENSORS: Vector of TfLiteTensor of type kTfLiteFloat32.
//            The tensor dimensions are specified in this calculator's options.
// Output:
//   One of the following IMAGE tags:
//   IMAGE: An ImageFrame output image, RGBA.
//   IMAGE_GPU: A GpuBuffer output image, RGBA.
//
// Options:
//   See tflite_tensors_to_image_frame_calculator.proto
//
// Usage example:
// node {
//   calculator: "TfLiteTensorsToImageFrameCalculator"
//   input_stream: "TENSORS:tensors"
//   output_stream: "IMAGE:stylized_image"
//   node_options: {
//     [mediapipe.TfLiteTensorsToImageFrameCalculatorOptions] {
//       tensor_in_width: 224
//       tensor_in_height: 224
//       tensor_in_channels: 3
//     }
//   }
// }
//
class TfLiteTensorsToImageFrameCalculator : public CalculatorBase {
 public:
  static absl::Status GetContract(CalculatorContract* cc);

  absl::Status Open(CalculatorContext* cc) override;
  absl::Status Process(CalculatorContext* cc) override;
  absl::Status Close(CalculatorContext* cc) override;

 private:
  absl::Status LoadOptions(CalculatorContext* cc);
  absl::Status ProcessCpu(CalculatorContext* cc);

  ::mediapipe::TfLiteTensorsToImageFrameCalculatorOptions options_;

  int tensor_width_ = 0;
  int tensor_height_ = 0;
  int tensor_channels_ = 0;
  float scale_factor_ = 1;
};

REGISTER_CALCULATOR(TfLiteTensorsToImageFrameCalculator);

absl::Status TfLiteTensorsToImageFrameCalculator::GetContract(
    CalculatorContract* cc) {
  RET_CHECK(!cc->Inputs().GetTags().empty());
  RET_CHECK(!cc->Outputs().GetTags().empty());

  // Inputs.
  if (cc->Inputs().HasTag(kTensorsTag)) {
    cc->Inputs().Tag(kTensorsTag).Set<std::vector<TfLiteTensor>>();
  }

  // Outputs.
  if (cc->Outputs().HasTag(kImageTag)) {
    cc->Outputs().Tag(kImageTag).Set<ImageFrame>();
  }

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Open(
    CalculatorContext* cc) {
  cc->SetOffset(TimestampDiff(0));

  MP_RETURN_IF_ERROR(LoadOptions(cc));

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Process(
    CalculatorContext* cc) {
  MP_RETURN_IF_ERROR(ProcessCpu(cc));

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Close(
    CalculatorContext* cc) {

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::ProcessCpu(
    CalculatorContext* cc) {
  if (cc->Inputs().Tag(kTensorsTag).IsEmpty()) {
    return absl::OkStatus();
  }

  // Get input streams.
  const auto& input_tensors =
      cc->Inputs().Tag(kTensorsTag).Get<std::vector<TfLiteTensor>>();

  RET_CHECK_EQ(input_tensors.size(), 1)
      << "The size of std::vector<TfLiteTensor> should be 1.";

  const TfLiteTensor tensor = input_tensors[0];
  const float* raw_input_data = tensor.data.f;
  
  const int output_width = tensor_width_, output_height = tensor_height_;
  const int depth = 4;
  const int total_size = output_height * output_width * depth;
  const auto format = ImageFormat::SRGBA;

  std::unique_ptr<uint8_t[]> buffer(new uint8_t[total_size]);
  
  // Convert [-1.0, 1.0] float values to [0.0, 255.0].
  auto scale_and_clamp = [](const auto a) {
    float b = 127.5 * (a + 1);
    if (b < 0) b = 0;
    if (b > 255) b = 255;
    return b;
  };

  size_t pos = 0;

  // Map three channel (RGB) float data to four channel (RGBA) uint8 data.
  for (int i = 0; i < total_size; i += 4) {
    buffer[i + 0] = static_cast<uchar>(scale_and_clamp(raw_input_data[pos++]));
    buffer[i + 1] = static_cast<uchar>(scale_and_clamp(raw_input_data[pos++]));
    buffer[i + 2] = static_cast<uchar>(scale_and_clamp(raw_input_data[pos++]));
    buffer[i + 3] = static_cast<uchar>(scale_and_clamp(1)); // Set alpha to max
  }

  ::std::unique_ptr<const ImageFrame> output;
  
  output = ::absl::make_unique<ImageFrame>(
      format, output_width, output_height, output_width * depth, buffer.release(),
      [total_size](uint8* ptr) { ::operator delete[](ptr, total_size); });

  cc->Outputs().Tag(kImageTag).Add(output.release(), cc->InputTimestamp());

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::LoadOptions(
    CalculatorContext* cc) {
  // Get calculator options specified in the graph.
  options_ =
      cc->Options<::mediapipe::TfLiteTensorsToImageFrameCalculatorOptions>();

  if (!options_.has_tensor_width() || !options_.has_tensor_height() ||
      !options_.has_tensor_channels())
    RET_CHECK_FAIL() << "Missing tensor dimensions in options.";

  tensor_width_ = options_.tensor_width();
  tensor_height_ = options_.tensor_height();
  tensor_channels_ = options_.tensor_channels();
  scale_factor_ = options_.scale_factor();

  if (tensor_channels_ != 1) {
    RET_CHECK_EQ(tensor_channels_, 3)
        << "Only 1 or 3 channel bitmap tensor currently supported";
  }

  return absl::OkStatus();
}

}  // namespace mediapipe