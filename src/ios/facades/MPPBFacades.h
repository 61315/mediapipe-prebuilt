// "ios/prebuilt/facades/MPPBFacades.h"
// https://github.com/61315/mediapipe-prebuilt/tree/master/src/ios/facades/

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include <simd/simd.h>

@class MPPBFacades;

@protocol MPPBFacadesDelegate <NSObject>
- (void)tracker: (MPPBFacades *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface MPPBFacades : NSObject
- (instancetype)init;
- (instancetype)initWithString: (NSString *)string;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBFacadesDelegate> delegate;
@end
