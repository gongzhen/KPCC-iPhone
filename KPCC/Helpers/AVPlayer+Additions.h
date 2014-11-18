//
//  AVPlayer+Additions.h
//  KPCC
//
//  Created by John Meeker on 6/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVPlayer (Additions)
@property (NS_NONATOMIC_IOSONLY, readonly) double indicatedBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMaxBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMinBitrate;
@end
