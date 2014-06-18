//
//  AVPlayer+Additions.h
//  KPCC
//
//  Created by John Meeker on 6/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVPlayer (Additions)
- (double)indicatedBitrate;
- (double)observedMaxBitrate;
- (double)observedMinBitrate;
@end
