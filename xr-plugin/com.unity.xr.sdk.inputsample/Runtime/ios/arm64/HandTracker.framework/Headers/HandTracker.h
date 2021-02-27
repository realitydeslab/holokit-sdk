#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@class Landmark;
@class HandTracker;
@class Handedness;

@protocol TrackerDelegate <NSObject>
@optional
- (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<NSArray<Landmark *> *> *) landmarks;
- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses;
- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface HandTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;
@property (weak, nonatomic) id <TrackerDelegate> delegate;
@end

@interface Landmark: NSObject
@property(nonatomic, readonly) float x;
@property(nonatomic, readonly) float y;
@property(nonatomic, readonly) float z;
@end

@interface Handedness: NSObject
@property(nonatomic, readonly) int index;
@property(nonatomic, readonly) float score;
@end
