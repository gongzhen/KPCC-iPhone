//
//  QueueManager.h
//  KPCC
//
//  Created by John Meeker on 10/28/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioManager.h"
#import "AudioChunk.h"

@protocol QueueManagerDelegate <NSObject>

@end

@interface QueueManager : NSObject

+ (QueueManager*)shared;

@property (nonatomic,weak) id<QueueManagerDelegate> delegate;
@property (nonatomic,strong) NSMutableArray *queue;

// Playback actions
- (void)enqueueEpisode:(Episode *)episode;
- (void)dequeueForPlayback;


// Internal queue
- (void)enqueue:(AudioChunk*)audio;
- (AudioChunk*)dequeue;
- (AudioChunk*)peek:(int)index;
- (AudioChunk*)peekHead;
- (AudioChunk*)peekTail;
- (BOOL)isQueueEmpty;

@end
