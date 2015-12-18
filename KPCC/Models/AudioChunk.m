//
//  AudioChunk.m
//  KPCC
//
//  Created by John Meeker on 10/28/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioChunk.h"
#import "KPCC-Swift.h"

@implementation AudioChunk

- (instancetype)initWithEpisode:(Episode *)episode {
    if ((self = [super init])) {
        if (episode.audio != nil) {
            self.audioUrl = episode.audio.url;
            self.audioDuration = episode.audio.duration;
            self.audioTitle = episode.title;
            self.programTitle = episode.programName;
            self.contentShareUrl = episode.publicUrl;
            self.audioTimeStamp = episode.airDate;
            self.type = AudioTypeEpisode;
        }
    }
    return self;
}

- (instancetype)initWithSegment:(Segment *)segment {
    if ((self = [super init])) {
        if (segment.audio != nil) {
            self.audioUrl = segment.audio.url;
            self.audioDuration = segment.audio.duration;
            self.audioTitle = segment.title;
            self.programTitle = segment.programName;
            self.contentShareUrl = segment.publicUrl;
            self.audioTimeStamp = segment.publishedAt;
            self.type = AudioTypeSegment;
        }
    }
    return self;
}

- (instancetype)initWithScheduleOccurrence:(ScheduleOccurrence *)sched {
    if ((self = [super init])) {
        self.audioDuration = [[NSNumber alloc] initWithDouble:sched.duration ];
        self.audioTitle = sched.title;
        self.programTitle = @"89.3 KPCC";
        self.audioTimeStamp = sched.starts_at;
        self.type = AudioTypeLiveStream;
    }

    return self;
}

@end
