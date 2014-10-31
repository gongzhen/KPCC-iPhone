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

    NSArray *audioChunks;
    for (int i = 0; i < [episodes count]; i++) {
        if ([[episodes objectAtIndex:i] audio]) {
            AudioChunk *chunk = [[AudioChunk alloc] initWithEpisode:[episodes objectAtIndex:i]];
            if (i == index) {
                [[AudioManager shared] playAudioWithURL:chunk.audioUrl];
                self.currentlyPlayingIndex = index;
            }
            [self enqueue:chunk];
        }
    }
    audioChunks = self.queue;
    return audioChunks;
}

- (void)playNext {
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex + 1 < [self.queue count]) {
            AudioChunk *chunk = [self.queue objectAtIndex:self.currentlyPlayingIndex + 1];
            [[AudioManager shared] playAudioWithURL:chunk.audioUrl];
            self.currentlyPlayingIndex += 1;
            //[[[Utils del] masterViewController] setOnDemandUI:YES withProgram:nil andAudioChunk:chunk];
        }
    }
}

- (void)playPrev {
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex > 0) {
            AudioChunk *chunk = [self.queue objectAtIndex:self.currentlyPlayingIndex - 1];
            [[AudioManager shared] playAudioWithURL:chunk.audioUrl];
            self.currentlyPlayingIndex -= 1;
            //[[[Utils del] masterViewController] setOnDemandUI:YES withProgram:nil andAudioChunk:chunk];
        }
    }
}

- (void)dequeueForPlayback {
    AudioChunk *chunk = [self dequeue];
    if (chunk) {
        [[AudioManager shared] playAudioWithURL:chunk.audioUrl];
    }
}


#pragma mark - Queue mechanism

- (void)enqueue:(AudioChunk *)audio {
    [self.queue addObject:audio];
}

- (AudioChunk*)dequeue {
    id toDequeue = nil;

    if ([self.queue lastObject]) {
        toDequeue = [self.queue objectAtIndex:0];
        [self.queue removeObjectAtIndex:0];
    }

    return toDequeue;
}

- (AudioChunk*)peek:(int)index {
    id peekObject = nil;

    if ([self.queue lastObject]) {
        if (index < [self.queue count]) {
            peekObject = [self.queue objectAtIndex:index];
        }
    }

    return peekObject;
}

- (AudioChunk*)peekHead {
    return [self peek:0];
}

- (AudioChunk*)peekTail {
    return [self.queue lastObject];
}

- (BOOL)isQueueEmpty {
    return ([self.queue lastObject] == nil);
}

- (void)clearQueue {
    [self.queue removeAllObjects];
}

@end
