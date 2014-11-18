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
@property (nonatomic) NSInteger currentlyPlayingIndex;

// Playback actions
- (void)enqueueEpisode:(Episode *)episode;
- (NSArray*)enqueueEpisodes:(NSArray *)episodes withCurrentIndex:(NSInteger)index;
- (void)playNext;
- (void)playPrev;
- (void)playItemAtPosition:(int)index;
- (void)dequeueForPlayback;


// Internal queue
- (void)enqueue:(AudioChunk*)audio;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) AudioChunk *dequeue;
@property (NS_NONATOMIC_IOSONLY, getter=isQueueEmpty, readonly) BOOL queueEmpty;
- (void)clearQueue;

@end
