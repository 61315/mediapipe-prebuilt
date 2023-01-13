// "desktop/prebuilt/cartoon/graphs/calculators/tflite_tensors_to_image_frame_calculator.cc"
// https://github.com/61315/mediapipe-prebuilt/tree/master/src/desktop/cartoon

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

#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
#include "mediapipe/gpu/gl_calculator_helper.h"
#include "mediapipe/gpu/gl_simple_shaders.h"
#include "mediapipe/gpu/shader_util.h"
#include "tensorflow/lite/delegates/gpu/gl/gl_buffer.h"
#include "tensorflow/lite/delegates/gpu/gl/gl_program.h"
#include "tensorflow/lite/delegates/gpu/gl/gl_shader.h"
#include "tensorflow/lite/delegates/gpu/gl/gl_texture.h"
#include "tensorflow/lite/delegates/gpu/gl_delegate.h"
#endif  // !MEDIAPIPE_DISABLE_GPU

#include "mediapipe/examples/desktop/prebuilt/cartoon/graphs/calculators/tflite_tensors_to_image_frame_calculator.pb.h"

namespace {
constexpr int kWorkgroupSize = 8;  // Block size for GPU shader.
enum { ATTRIB_VERTEX, ATTRIB_TEXTURE_POSITION, NUM_ATTRIBUTES };
// Commonly used to compute the number of blocks to launch in a kernel.
int NumGroups(const int size, const int group_size) {  // NOLINT
  return (size + group_size - 1) / group_size;
}
float Clamp(float val, float min, float max) {
  return std::min(std::max(val, min), max);
}

constexpr char kTensorsTag[] = "TENSORS";
constexpr char kTensorsGpuTag[] = "TENSORS_GPU";
constexpr char kImageTag[] = "IMAGE";
constexpr char kImageGpuTag[] = "IMAGE_GPU";

}  // namespace

namespace mediapipe {

#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
using ::tflite::gpu::gl::CopyBuffer;
using ::tflite::gpu::gl::CreateReadWriteRgbaImageTexture;
using ::tflite::gpu::gl::CreateReadWriteShaderStorageBuffer;
using ::tflite::gpu::gl::GlBuffer;
using ::tflite::gpu::gl::GlProgram;
using ::tflite::gpu::gl::GlShader;
#endif  // !MEDIAPIPE_DISABLE_GPU

// Converts TFLite tensors from a tflite model to an image.
//
// Produces result as an RGBA image, with the pixel data in R or RGB channels.
//
// Inputs:
//   One of the following TENSORS tags:
//   TENSORS: Vector of TfLiteTensor of type kTfLiteFloat32.
//            The tensor dimensions are specified in this calculator's options.
//   TENSORS_GPU: Vector of GlBuffer.
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
  absl::Status InitGpu(CalculatorContext* cc);
  absl::Status ProcessGpu(CalculatorContext* cc);
  absl::Status ProcessCpu(CalculatorContext* cc);
  void GlRender();

  ::mediapipe::TfLiteTensorsToImageFrameCalculatorOptions options_;

  int tensor_width_ = 0;
  int tensor_height_ = 0;
  int tensor_channels_ = 0;
  float scale_factor_ = 1;

  bool use_gpu_ = false;
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  mediapipe::GlCalculatorHelper gpu_helper_;
  std::unique_ptr<GlProgram> swizzling_program_;
  std::unique_ptr<GlBuffer> tensor_buffer_;
  GLuint pass_through_program_;
#endif  // !MEDIAPIPE_DISABLE_GPU
};

REGISTER_CALCULATOR(TfLiteTensorsToImageFrameCalculator);

absl::Status TfLiteTensorsToImageFrameCalculator::GetContract(
    CalculatorContract* cc) {
  RET_CHECK(!cc->Inputs().GetTags().empty());
  RET_CHECK(!cc->Outputs().GetTags().empty());

  bool use_gpu = false;

  // Input CPU.
  if (cc->Inputs().HasTag(kTensorsTag)) {
    cc->Inputs().Tag(kTensorsTag).Set<std::vector<TfLiteTensor>>();
  }

  // Input GPU.
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  if (cc->Inputs().HasTag(kTensorsGpuTag)) {
    cc->Inputs().Tag(kTensorsGpuTag).Set<std::vector<GlBuffer>>();
    use_gpu |= true;
  }
#endif  // !MEDIAPIPE_DISABLE_GPU

  // Outputs.
  if (cc->Outputs().HasTag(kImageTag)) {
    cc->Outputs().Tag(kImageTag).Set<ImageFrame>();
  }
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  if (cc->Outputs().HasTag(kImageGpuTag)) {
    cc->Outputs().Tag(kImageGpuTag).Set<mediapipe::GpuBuffer>();
    use_gpu |= true;
  }
#endif  // !MEDIAPIPE_DISABLE_GPU

  if (use_gpu) {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
    MP_RETURN_IF_ERROR(mediapipe::GlCalculatorHelper::UpdateContract(cc));
#endif  // !MEDIAPIPE_DISABLE_GPU
  }
  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Open(
    CalculatorContext* cc) {
  cc->SetOffset(TimestampDiff(0));

  if (cc->Inputs().HasTag(kTensorsGpuTag)) {
    use_gpu_ = true;
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
    MP_RETURN_IF_ERROR(gpu_helper_.Open(cc));
#endif  // !MEDIAPIPE_DISABLE_GPU
  }

  MP_RETURN_IF_ERROR(LoadOptions(cc));

  if (use_gpu_) {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
    MP_RETURN_IF_ERROR(gpu_helper_.RunInGlContext([this, cc]() -> absl::Status {
      MP_RETURN_IF_ERROR(InitGpu(cc));
      return absl::OkStatus();
    }));
#else
    RET_CHECK_FAIL() << "GPU processing not enabled.";
#endif  // !MEDIAPIPE_DISABLE_GPU
  }

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Process(
    CalculatorContext* cc) {
  if (use_gpu_) {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
    MP_RETURN_IF_ERROR(gpu_helper_.RunInGlContext([this, cc]() -> absl::Status {
      MP_RETURN_IF_ERROR(ProcessGpu(cc));
      return absl::OkStatus();
    }));
#endif  // !MEDIAPIPE_DISABLE_GPU
  } else {
    MP_RETURN_IF_ERROR(ProcessCpu(cc));
  }

  return absl::OkStatus();
}

absl::Status TfLiteTensorsToImageFrameCalculator::Close(
    CalculatorContext* cc) {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  gpu_helper_.RunInGlContext([this] {
    if (pass_through_program_) glDeleteProgram(pass_through_program_);
    pass_through_program_ = 0;
    swizzling_program_.reset();
    tensor_buffer_.reset();
  });
#endif  // !MEDIAPIPE_DISABLE_GPU

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

// This is a simple swizzling operation.
absl::Status TfLiteTensorsToImageFrameCalculator::ProcessGpu(
    CalculatorContext* cc) {
  if (cc->Inputs().Tag(kTensorsGpuTag).IsEmpty()) {
    return absl::OkStatus();
  }
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  // Get input streams.
  const auto& input_tensors =
      cc->Inputs().Tag(kTensorsGpuTag).Get<std::vector<GlBuffer>>();
  int output_width = tensor_width_, output_height = tensor_height_;
  RET_CHECK_EQ(input_tensors.size(), 1);

  // Create an intermediary texture for tensors to be written.
  ::tflite::gpu::gl::GlTexture input_data_texture;
  MP_RETURN_IF_ERROR(CreateReadWriteRgbaImageTexture(
      tflite::gpu::DataType::UINT8,  // GL_RGBA8
      {tensor_width_, tensor_height_}, &input_data_texture));

  // Copy input tensor.
  MP_RETURN_IF_ERROR(CopyBuffer(input_tensors[0], *tensor_buffer_));

  // Run shader, process bitmap tensor.
  {
    const int output_index = 0;
    glBindImageTexture(output_index, input_data_texture.id(), 0, GL_FALSE, 0,
                       GL_WRITE_ONLY, GL_RGBA8);
    MP_RETURN_IF_ERROR(tensor_buffer_->BindToIndex(1));

    const tflite::gpu::uint3 workgroups = {
        NumGroups(tensor_width_, kWorkgroupSize),
        NumGroups(tensor_height_, kWorkgroupSize), 1};

    MP_RETURN_IF_ERROR(swizzling_program_->Dispatch(workgroups));
  }

  mediapipe::GlTexture output_texture = gpu_helper_.CreateDestinationTexture(
      output_width, output_height,
      mediapipe::GpuBufferFormat::kBGRA32);  // actually GL_RGBA8

  // Run shader, pass through result.
  {
    gpu_helper_.BindFramebuffer(output_texture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, input_data_texture.id());
    GlRender();
    glBindTexture(GL_TEXTURE_2D, 0);
    glFlush();
  }

  // Send out image as GPU packet.
  auto output_image = output_texture.GetFrame<mediapipe::GpuBuffer>();
  cc->Outputs()
      .Tag(kImageGpuTag)
      .Add(output_image.release(), cc->InputTimestamp());

  // Cleanup
  output_texture.Release();
#endif  // !MEDIAPIPE_DISABLE_GPU

  return absl::OkStatus();
}

void TfLiteTensorsToImageFrameCalculator::GlRender() {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  static const GLfloat square_vertices[] = {
      -1.0f, -1.0f,  // bottom left
      1.0f,  -1.0f,  // bottom right
      -1.0f, 1.0f,   // top left
      1.0f,  1.0f,   // top right
  };
  static const GLfloat texture_vertices[] = {
      0.0f, 0.0f,  // bottom left
      1.0f, 0.0f,  // bottom right
      0.0f, 1.0f,  // top left
      1.0f, 1.0f,  // top right
  };

  // program
  glUseProgram(pass_through_program_);

  // vertex storage
  GLuint vbo[2];
  glGenBuffers(2, vbo);
  GLuint vao;
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);

  // vbo 0
  glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
  glBufferData(GL_ARRAY_BUFFER, 4 * 2 * sizeof(GLfloat), square_vertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(ATTRIB_VERTEX);
  glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, nullptr);

  // vbo 1
  glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
  glBufferData(GL_ARRAY_BUFFER, 4 * 2 * sizeof(GLfloat), texture_vertices,
               GL_STATIC_DRAW);
  glEnableVertexAttribArray(ATTRIB_TEXTURE_POSITION);
  glVertexAttribPointer(ATTRIB_TEXTURE_POSITION, 2, GL_FLOAT, 0, 0, nullptr);

  // draw
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

  // cleanup
  glDisableVertexAttribArray(ATTRIB_VERTEX);
  glDisableVertexAttribArray(ATTRIB_TEXTURE_POSITION);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glDeleteVertexArrays(1, &vao);
  glDeleteBuffers(2, vbo);
#endif  // !MEDIAPIPE_DISABLE_GPU
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

absl::Status TfLiteTensorsToImageFrameCalculator::InitGpu(
    CalculatorContext* cc) {
#if !defined(MEDIAPIPE_DISABLE_GL_COMPUTE)
  MP_RETURN_IF_ERROR(gpu_helper_.RunInGlContext([this]() -> absl::Status {
    const std::string shader_src_template =
        R"( #version 310 es

layout(local_size_x = $0, local_size_y = $0, local_size_z = 1) in;

precision highp float;

// 1:"tensor_buffer_"
layout(std430, binding = 1) readonly buffer B0 {
  vec3 elements[];
} input_data;   // data tensor

// 0:"input_data_texture"
layout(rgba8, binding = 0) writeonly uniform highp image2D output_texture;

uniform ivec2 out_size;

// Will be replaced with either '#define SINGLE_CHANNEL' or empty string
$1 //DEFINE_SINGLE_CHANNEL

void main() {
  int out_width = out_size.x;
  int out_height = out_size.y;

  ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
  if (gid.x >= out_width || gid.y >= out_height) { return; }

  int linear_index = gid.y * out_width + gid.x;
  vec3 input_value = input_data.elements[linear_index];

  int y_coord = int($2);
  ivec2 output_coordinate = ivec2(gid.x, y_coord);

  // Set R or RGB channels in regard to channel count.
  // TODO: Add support for alpha channel. (e.g. for {1, H, W, 4} shaped tensor)
#ifdef SINGLE_CHANNEL
  vec4 out_value = vec4(input_value.rrr, 1.0);
#else
  vec4 out_value = vec4(input_value.rgb, 1.0);
#endif  // SINGLE_CHANNEL
  imageStore(output_texture, output_coordinate, out_value);
})";

    const std::string shader_src_swizzling = absl::Substitute(
        shader_src_template, kWorkgroupSize,
        options_.tensor_channels() == 1 ? "#define SINGLE_CHANNEL" : "",
        options_.flip_vertically() ? "out_height - gid.y - 1" : "gid.y");

    // Shader programs.
    GlShader shader_swizzling;
    MP_RETURN_IF_ERROR(GlShader::CompileShader(
        GL_COMPUTE_SHADER, shader_src_swizzling, &shader_swizzling));
    swizzling_program_ = absl::make_unique<GlProgram>();
    MP_RETURN_IF_ERROR(GlProgram::CreateWithShader(
        shader_swizzling, swizzling_program_.get()));
    
    // Buffer storage for input tensor.
    size_t tensor_length = tensor_width_ * tensor_height_ * tensor_channels_;
    tensor_buffer_ = absl::make_unique<GlBuffer>();
    MP_RETURN_IF_ERROR(CreateReadWriteShaderStorageBuffer<float>(
        tensor_length, tensor_buffer_.get()));

    // Parameters.
    glUseProgram(swizzling_program_->id());
    glUniform2i(glGetUniformLocation(swizzling_program_->id(), "out_size"),
                tensor_width_, tensor_height_);

    // Vertex shader attributes.
    const GLint attr_location[NUM_ATTRIBUTES] = {
        ATTRIB_VERTEX,
        ATTRIB_TEXTURE_POSITION,
    };
    const GLchar* attr_name[NUM_ATTRIBUTES] = {
        "position",
        "texture_coordinate",
    };

    // Simple pass-through shader.
    std::string upsample_shader_base = R"(
  #if __VERSION__ < 130
    #define in varying
  #endif  // __VERSION__ < 130

  #ifdef GL_ES
    #define fragColor gl_FragColor
    precision highp float;
  #else
    #define lowp
    #define mediump
    #define highp
    #define texture2D texture
    out vec4 fragColor;
  #endif  // defined(GL_ES)

  in vec2 sample_coordinate;
  uniform sampler2D input_data;

  void main() {
    vec4 pix = texture2D(input_data, sample_coordinate);
    fragColor = pix;
  }
)";

    // Program
    mediapipe::GlhCreateProgram(
        mediapipe::kBasicVertexShader, upsample_shader_base.c_str(),
        NUM_ATTRIBUTES, &attr_name[0], attr_location, &pass_through_program_);
    RET_CHECK(pass_through_program_) << "Problem initializing the program.";

    // Parameters
    glUseProgram(pass_through_program_);
    glUniform1i(glGetUniformLocation(pass_through_program_, "input_data"), 1);

    return absl::OkStatus();
  }));
#endif  // !MEDIAPIPE_DISABLE_GPU

  return absl::OkStatus();
}

}  // namespace mediapipe
