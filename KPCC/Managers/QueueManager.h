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
#import "Bookmark.h"

@protocol QueueManagerDelegate <NSObject>

@end

@interface QueueManager : NSObject

+ (QueueManager*)shared;

@property (nonatomic,weak) id<QueueManagerDelegate> delegate;
@property (nonatomic,strong) NSMutableArray *queue;
@property (nonatomic) NSInteger currentlyPlayingIndex;
@property (nonatomic,strong) AudioChunk *currentChunk;
@property (nonatomic,strong) Bookmark *currentBookmark;

// Playback actions
- (void)enqueueEpisode:(Episode *)episode;
- (NSArray*)enqueueEpisodes:(NSArray *)episodes withCurrentIndex:(NSInteger)index;
- (NSArray*)enqueueEpisodes:(NSArray *)episodes withCurrentIndex:(NSInteger)index playImmediately:(BOOL)playImmediately;
- (void)playNext;
- (void)playPrev;
- (void)playItemAtPosition:(int)index;
- (void)dequeueForPlayback;

- (void)handleBookmarkingActivity;

// Internal queue
- (void)enqueue:(AudioChunk*)audio;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) AudioChunk *dequeue;
@property (NS_NONATOMIC_IOSONLY, getter=isQueueEmpty, readonly) BOOL queueEmpty;
- (void)clearQueue;

@end