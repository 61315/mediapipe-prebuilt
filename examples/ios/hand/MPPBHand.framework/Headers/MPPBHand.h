#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBHand;

@protocol MPPBHandDelegate <NSObject>
- (void)handTracker: (MPPBHand *)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)handTracker: (MPPBHand *)handTracker didOutputTransform: (simd_float4x4)transform;
@end

@interface MPPBHand : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBHandDelegate> delegate;
@end