#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBFaceMesh;

@protocol MPPBFaceMeshDelegate <NSObject>
- (void)tracker: (MPPBFaceMesh *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)tracker: (MPPBFaceMesh *)tracker didOutputTransform: (simd_float4x4)transform;
@end

@interface MPPBFaceMesh : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBFaceMeshDelegate> delegate;
@end