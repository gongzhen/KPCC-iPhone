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
    return [self enqueueEpisodes:episodes
                withCurrentIndex:index
                 playImmediately:NO];
}

- (NSArray*)enqueueEpisodes:(NSArray *)episodes withCurrentIndex:(NSInteger)index playImmediately:(BOOL)playImmediately {
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
            
            self.currentChunk = chunk;
            self.currentlyPlayingIndex = index;
            if ( playImmediately ) {
                [[AudioManager shared] playQueueItem:chunk];
            }
            
        }
    }
    
    NSArray *audioChunks = self.queue;
    return audioChunks;
}

- (void)handleBookmarkingActivity {
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnDemand ) return;
    CMTime currentTime = [[AudioManager shared].audioPlayer.currentItem currentTime];
    NSInteger seconds = CMTimeGetSeconds(currentTime);
    if ( seconds > kBookmarkingTolerance ) {
        if ( !self.currentBookmark ) {
            Bookmark *b = [[ContentManager shared] bookmarkForAudioChunk:self.currentChunk];
            if ( !b ) {
                b = [[ContentManager shared] createBookmarkFromAudioChunk:self.currentChunk];
            }
            
            b.resumeTimeInSeconds = @(seconds);
            self.currentBookmark = b;
            
        } else {
            self.currentBookmark.resumeTimeInSeconds = @(seconds);
        }
    }
}

- (void)playNext {
#ifdef DEBUG
    NSLog(@"playNext fired");
#endif
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex + 1 < [self.queue count]) {
            AudioChunk *chunk = (self.queue)[self.currentlyPlayingIndex + 1];
            self.currentChunk = chunk;
            self.currentlyPlayingIndex += 1;
            [[[Utils del] masterViewController] setPositionForQueue:(int)self.currentlyPlayingIndex animated:YES];
            [[AudioManager shared] playQueueItem:chunk];
        }
    }
}

- (void)playPrev {
    if (![self isQueueEmpty]) {
        if (self.currentlyPlayingIndex > 0) {
            AudioChunk *chunk = (self.queue)[self.currentlyPlayingIndex - 1];
            self.currentChunk = chunk;
            self.currentlyPlayingIndex -= 1;
            [[[Utils del] masterViewController] setPositionForQueue:(int)self.currentlyPlayingIndex animated:YES];
            [[AudioManager shared] playQueueItem:chunk];
        }
    }
}

- (void)playItemAtPosition:(int)index {
    [[AudioManager shared] invalidateTimeObserver];
    
    if (![self isQueueEmpty]) {
        if (index >= 0 && index < [self.queue count]) {
            AudioChunk *chunk = (self.queue)[index];
            self.currentChunk = chunk;
            [[AudioManager shared] playQueueItem:chunk];
            self.currentlyPlayingIndex = index;
        }
    }
}

- (void)dequeueForPlayback {
    AudioChunk *chunk = [self dequeue];
    if (chunk) {
        [[AudioManager shared] playQueueItem:chunk];
        self.currentChunk = chunk;
    }
}



#pragma mark - Queue internal
- (void)enqueue:(AudioChunk *)audio {
    if ( audio ) {
        [self.queue addObject:audio];
    }
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
    if ( !self.queue ) return YES;
    if ( self.queue.count == 0 ) return YES;
    return NO;
}

- (void)clearQueue {
    [self.queue removeAllObjects];
    self.currentChunk = nil;
}

@end