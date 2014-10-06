//
//  Segment.m
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Segment.h"

@implementation Segment

-(id)initWithDict:(NSDictionary *)dict {

    if((self = [super init])) {
        self.segmentId      = dict[@"id"];
        self.title          = dict[@"title"];
        self.publishedAt    = [Utils dateFromRFCString:dict[@"published_at"]];
        self.byline         = dict[@"byline"];
        self.teaser         = dict[@"teaser"];
        self.permalink      = dict[@"permalink"];
        self.publicUrl      = dict[@"public_url"];

        if (dict[@"audio"] && [dict[@"audio"] count] > 0 ) {
            self.audio = [[EpisodeAudio alloc] initWithDict:[dict[@"audio"] objectAtIndex:0]];
        }
    }
    return self;
}



@end
