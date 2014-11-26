//
//  QueueManager.m
//  KPCC
//
//  Created by John Meeker on 10/28/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "QueueManager.h"
#import "Utils.h"
#import "SCPRMasterViewController.h"

static QueueManager *singleton = nil;


@implementation QueueManager

+ (QueueManager*)shared {
    if (!singleton) {
        static dispatch_once_t isDispatched;
        dispatch_once(&isDispatched, ^{
            singleton = [[QueueManager alloc] init];
            singleton.queue = [[NSMutableArray alloc] init];
        });
    }
    return singleton;
}

#pragma mark - Playback actions

- (void)enqueueEpisode:(Episode *)episode {

    if (episode.audio) {
        AudioChunk *chunk = [[AudioChunk alloc] initWithEpisode:episode];
        [self enqueue:chunk];
    } else {
        if (episode.segments && [episode.segments count] > 0) {
            for (Segment *segment in episode.segments) {
                AudioChunk *chunk = [[AudioChunk alloc] initWithSegment:segment];
                [self enqueue:chunk];
            }
        }
    }
}

- (NSArray*)enqueueEpisodes:(NSArray *)episodes withCurrentIndex:(NSInteger)index {
    [self clearQueue];

    for (int i = 0; i < [episodes count]; i++) {
        AudioChunk *chunk;
        if ([episodes[i] class] == [Episode class]) {
            chunk = [[AudioChunk alloc] initWithEpisode:episodes[i]];
        } else if ([episodes[i] class] == [Segment class]) {
            chunk = [[AudioChunk alloc] initWithSegment:episodes[i]];
        }
        [self enqueue:chunk];

        if (i == index && chunk != nil) {
            [[AudioManager shared] playQueueItemWithUrl:chunk.audioUrl];
            self.currentChunk = chunk;
            self.currentlyPlayingIndex = index;
        }
    }

    NSArray *audioChunks = self.queue;
    return audioChunks;
}

- (void)playNext {
#ifdef DEBUG
    NSLog(@"playNext fired");
#endif
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex + 1 < [self.queue count]) {
            AudioChunk *chunk = (self.queue)[self.currentlyPlayingIndex + 1];
            self.currentChunk = chunk;
            [[AudioManager shared] playQueueItemWithUrl:chunk.audioUrl];
            self.currentlyPlayingIndex += 1;
            [[[Utils del] masterViewController] setPositionForQueue:(int)self.currentlyPlayingIndex animated:YES];
        }
    }
}

- (void)playPrev {
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex > 0) {
            AudioChunk *chunk = (self.queue)[self.currentlyPlayingIndex - 1];
            self.currentChunk = chunk;
            [[AudioManager shared] playQueueItemWithUrl:chunk.audioUrl];
            self.currentlyPlayingIndex -= 1;
            [[[Utils del] masterViewController] setPositionForQueue:(int)self.currentlyPlayingIndex animated:YES];
        }
    }
}

- (void)playItemAtPosition:(int)index {
    if (![self isQueueEmpty]) {
        if (index >= 0 && index < [self.queue count]) {
            AudioChunk *chunk = (self.queue)[index];
            self.currentChunk = chunk;
            [[AudioManager shared] playQueueItemWithUrl:chunk.audioUrl];
            self.currentlyPlayingIndex = index;
        }
    }
}

- (void)dequeueForPlayback {
    AudioChunk *chunk = [self dequeue];
    if (chunk) {
        [[AudioManager shared] playQueueItemWithUrl:chunk.audioUrl];
        self.currentChunk = chunk;
    }
}


#pragma mark - Queue internal

- (void)enqueue:(AudioChunk *)audio {
    [self.queue addObject:audio];
}

- (AudioChunk*)dequeue {
    id toDequeue = nil;

    if ([self.queue lastObject]) {
        toDequeue = (self.queue)[0];
        [self.queue removeObjectAtIndex:0];
    }

    return toDequeue;
}

- (BOOL)isQueueEmpty {
    return ([self.queue lastObject] == nil);
}

- (void)clearQueue {
    [self.queue removeAllObjects];
    self.currentChunk = nil;
}

@end
