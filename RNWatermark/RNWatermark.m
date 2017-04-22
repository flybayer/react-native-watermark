//
//  RNWatermark.m
//  RNWatermark
//
//  Created by watzak on 16/11/15.
//

#import "RNWatermark.h"

@implementation RNWatermark

// Expose this module to the React Native bridge
RCT_EXPORT_MODULE()


- (void)exportDidFinish:(AVAssetExportSession*)session :(RCTResponseSenderBlock)callback {
    NSLog(@"WATERMARK finished => %tu", session.status);

    if (session.status == AVAssetExportSessionStatusCompleted) {
        callback(@[[NSNull null], [session.outputURL absoluteString]]);

        /* NSURL *outputURL = session.outputURL; */
        /* ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init]; */
        /* if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) { */
        /*     [library writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error){ */
        /*         dispatch_async(dispatch_get_main_queue(), ^{ */
        /*             if (error) { */
        /*                 callback(@[error, [NSNull null]]); */
        /*             } else { */
        /*                 callback(@[[NSNull null], [assetURL absoluteString]]); */
        /*             } */
        /*         }); */
        /*     }]; */
        /* } */
    } else {
        callback(@[session.error, [NSNull null]]);
    }
}


RCT_EXPORT_METHOD(add:(NSString*)path :(RCTResponseSenderBlock)callback) {
    NSURL *assetsLibraryURL = [NSURL URLWithString:path];
    AVAsset *videoAsset = [AVAsset assetWithURL:assetsLibraryURL];
    NSLog(@"videoAsset => %@", videoAsset);
    //callback(@[[NSNull null], asset]);

    // 2 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];

    // 3 - Video & audio track
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = nil;


    NSLog(@"videoTrack => %@", videoTrack);
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                        ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];
    [videoTrack setPreferredTransform:[[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] preferredTransform]];

    if ([[videoAsset tracksWithMediaType:AVMediaTypeAudio] count] > 0) {
      audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];

      [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                          ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                           atTime:kCMTimeZero error:nil];
      [audioTrack setPreferredTransform:[[[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] preferredTransform]];
    }

    // 3.1 - Create AVMutableVideoCompositionInstruction
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);

    // 3.2 - Create an AVMutableVideoCompositionLayerInstruction for the video track and fix the orientation.
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation_ =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation_ = UIImageOrientationDown;
    }
    [videolayerInstruction setTransform:videoAssetTrack.preferredTransform atTime:kCMTimeZero];
    [videolayerInstruction setOpacity:0.0 atTime:videoAsset.duration];

    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];

    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];

    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake(videoAssetTrack.naturalSize.height, videoAssetTrack.naturalSize.width);
    } else {
        naturalSize = videoAssetTrack.naturalSize;
    }

    float renderWidth, renderHeight;
    renderWidth = naturalSize.width;
    renderHeight = naturalSize.height;
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);

    [self applyVideoEffectsToComposition:mainCompositionInst size:naturalSize];

    // 4 - Get path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];

    // 5 - Create exporter
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainCompositionInst;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:exporter :callback];
        });
    }];
}


- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition size:(CGSize)size
{
    // 1 - set up the overlay

    // >> TEXT
    /* CATextLayer *textOfvideo=[[CATextLayer alloc] init]; */
    /* textOfvideo.string= @"Storeo"; //[NSString stringWithFormat:@"%@",text];//text is shows the text that you want add in video. */
    /*  [textOfvideo setFont:(__bridge CFTypeRef)([UIFont fontWithName:[NSString stringWithFormat:@"%@",fontUsed] size:13])];//fontUsed is the name of font */
    /* [textOfvideo setFrame:CGRectMake(0, 0, size.width, size.height/6)]; */
    /* [textOfvideo setAlignmentMode:kCAAlignmentCenter]; */
    /* [textOfvideo setForegroundColor:[[UIColor blueColor] CGColor]]; */
    /* CALayer *overlayLayer = [CALayer layer]; */
    /* [overlayLayer addSublayer:textOfvideo]; */
    /* overlayLayer.frame = CGRectMake(0, 0, size.width, size.height); */
    /* [overlayLayer setMasksToBounds:YES]; */

    CALayer *overlayLayer = [CALayer layer];
    UIImage *overlayImage = nil;
    overlayImage = [UIImage imageNamed:@"watermark"];

    [overlayLayer setContents:(id)[overlayImage CGImage]];
    float videoHeight = size.height;
    float overlayWidth = 9.0 / 16.0 * videoHeight;
    float overlayHeight = overlayWidth * overlayImage.size.height / overlayImage.size.width + 2;
    float xOffset = (size.width/2) - (overlayWidth/2);
    NSLog(@"WATERMARK video height => %f", size.height);
    NSLog(@"WATERMARK video width => %f", size.width);
    NSLog(@"WATERMARK overlayWidth => %f", overlayWidth);
    NSLog(@"WATERMARK overlayHeight => %f", overlayHeight);
    NSLog(@"WATERMARK xOffset => %f", xOffset);

    float hMargin = 0;
    float vMargin = 0;
    overlayLayer.frame = CGRectMake(xOffset+hMargin, vMargin, overlayWidth-(hMargin*2), overlayHeight+vMargin);
    overlayLayer.compositingFilter = @"overlayBlendMode";
    overlayLayer.contentsGravity = kCAGravityResizeAspect;
    [overlayLayer setOpacity:0.5];
    [overlayLayer setMasksToBounds:YES];


    // 2 - set up the parent layer
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];

    // 3 - apply magic
    composition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}


@end
