//
//  SCPRQueueScrollableView.h
//  KPCC
//
//  Created by John Meeker on 10/30/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioChunk.h"

@interface SCPRQueueScrollableView : UIView

- (void)setAudioChunk:(AudioChunk *)audioChunk;
- (void)setAudioTitle:(NSString *)audioTitle;

@end
