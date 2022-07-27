#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBFaceGeometry;

@protocol MPPBFaceGeometryDelegate <NSObject>
- (void)tracker: (MPPBFaceGeometry *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)tracker: (MPPBFaceGeometry *)tracker didOutputTransform: (simd_float4x4)transform withFace: (NSInteger)index;
@end

@interface MPPBFaceGeometry : NSObject
- (instancetype)init;
- (instancetype)initWithString: (NSString *)string;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBFaceGeometryDelegate> delegate;
@end
