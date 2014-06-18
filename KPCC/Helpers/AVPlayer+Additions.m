//
//  AVPlayer+Additions.m
//  KPCC
//
//  Created by John Meeker on 6/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AVPlayer+Additions.h"

@implementation AVPlayer (Additions)

- (double)indicatedBitrate {
    if (self.currentItem.accessLog.events.lastObject){
        return [self.currentItem.accessLog.events.lastObject indicatedBitrate];
    }
    return 0.0;
}

- (double)observedMaxBitrate {
    if (self.currentItem.accessLog.events.lastObject){
        return [self.currentItem.accessLog.events.lastObject observedMaxBitrate];
    }
    return 0.0;
}

- (double)observedMinBitrate {
    if (self.currentItem.accessLog.events.lastObject){
        return [self.currentItem.accessLog.events.lastObject observedMinBitrate];
    }
    return 0.0;
}

@end
