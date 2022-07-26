#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@class MPPBPlayground;

@protocol MPPBPlaygroundDelegate <NSObject>
- (void)tracker: (MPPBPlayground *)tracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface MPPBPlayground : NSObject
- (instancetype)init;
- (instancetype)initWithString:(NSString *)string;
- (void)startGraph;
- (void)processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp: (CMTime)timestamp;
@property (weak, nonatomic) id <MPPBPlaygroundDelegate> delegate;
@end
