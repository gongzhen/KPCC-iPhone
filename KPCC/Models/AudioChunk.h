//
//  AudioChunk.h
//  KPCC
//
//  Created by John Meeker on 10/28/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Episode.h"
#import "EpisodeAudio.h"
#import "Segment.h"

typedef NS_ENUM(NSUInteger, AudioType) {
    AudioTypeEpisode = 0,
    AudioTypeSegment,
    AudioTypeLiveStream,
    AudioTypeUnknown
};

@class ScheduleOccurrence;

@interface AudioChunk : NSObject

@property (nonatomic,strong) NSString *audioUrl;
@property (nonatomic,strong) NSNumber *audioDuration;
@property (nonatomic,strong) NSString *audioTitle;
@property (nonatomic,strong) NSString *programTitle;
@property (nonatomic,strong) NSString *contentShareUrl;
@property (nonatomic,strong) NSDate *audioTimeStamp;

@property AudioType type;

- (instancetype)init __unavailable;
- (instancetype)initWithEpisode:(Episode *)episode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSegment:(Segment *)segment NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithScheduleOccurrence:(ScheduleOccurrence *)sched NS_DESIGNATED_INITIALIZER;

@end
