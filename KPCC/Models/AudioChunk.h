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
    AudioTypeUnknown
};

@interface AudioChunk : NSObject

@property (nonatomic,strong) NSString *audioUrl;
@property (nonatomic,strong) NSNumber *audioDuration;
@property (nonatomic,strong) NSString *audioTitle;
@property (nonatomic,strong) NSString *programTitle;

@property AudioType type;

- (id)initWithEpisode:(Episode *)episode;
- (id)initWithSegment:(Segment *)segment;

@end
