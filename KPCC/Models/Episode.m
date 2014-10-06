//
//  Episode.m
//  KPCC
//
//  Created by John Meeker on 9/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Episode.h"
#import "Segment.h"
#import "Utils.h"

@implementation Episode

- (id)initWithDict:(NSDictionary *)episodeDict {
    if((self = [super init])) {
        self.title      = episodeDict[@"title"];
        self.summary    = episodeDict[@"summary"];
        self.airDate    = [Utils dateFromRFCString:episodeDict[@"air_date"]];
        self.publicUrl  = episodeDict[@"public_url"];
        self.teaser     = episodeDict[@"teaser"];
        self.programName= [episodeDict[@"program"] objectForKey:@"title"];
//        self.assets     = episodeDict[@"assets"];

        if (episodeDict[@"audio"] && [episodeDict[@"audio"] count] > 0 ) {
            self.audio = [[EpisodeAudio alloc] initWithDict:[episodeDict[@"audio"] objectAtIndex:0]];
        }


        if (episodeDict[@"segments"] && [episodeDict[@"segments"] count] > 0) {
            NSMutableArray *tmpSegments = [@[] mutableCopy];
            for (NSDictionary *segmentDict in episodeDict[@"segments"]) {
                Segment *segment = [[Segment alloc] initWithDict:segmentDict];
                segment.programName = self.programName;
                [tmpSegments addObject:segment];
            }
            self.segments = tmpSegments;
        }

    }
    return self;
}

- (BOOL)hasEpisodeAudio {
    return self.audio != nil;
}

@end
