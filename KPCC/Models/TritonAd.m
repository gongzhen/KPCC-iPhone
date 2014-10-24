//
//  TritonAd.m
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "TritonAd.h"

@implementation TritonAd

- (id)initWithDict:(NSDictionary *)dictionary {
    if ((self = [super init])) {

        if ([dictionary objectForKey:@"_id"]) {
            self.adId = [dictionary objectForKey:@"_id"];
        }

        if ([dictionary objectForKey:@"InLine"]) {
            NSDictionary *inlineDict = [[NSDictionary alloc] initWithDictionary:[dictionary objectForKey:@"InLine"]];

            // Impression URL
            if ([inlineDict objectForKey:@"Impression"] && [[inlineDict objectForKey:@"Impression"] objectForKey:@"__text"]) {
                self.impressionUrl = [[inlineDict objectForKey:@"Impression"] objectForKey:@"__text"];
            }

            // Ad assets
            if ([inlineDict objectForKey:@"Creatives"] && [[inlineDict objectForKey:@"Creatives"] objectForKey:@"Creative"]) {
                NSArray *creatives = [[inlineDict objectForKey:@"Creatives"] objectForKey:@"Creative"];
                if (creatives && [creatives count] > 0) {

                    // Audio component
                    NSDictionary *firstCreative = [creatives objectAtIndex:0];
                    if ([firstCreative objectForKey:@"Linear"]) {
                        NSDictionary *audioAsset = [firstCreative objectForKey:@"Linear"];

                        // File duration
                        if ([audioAsset objectForKey:@"Duration"]) {
                            NSArray* tokens = [[audioAsset objectForKey:@"Duration"] componentsSeparatedByString:@":"];
                            double lengthInSeconds = 0;
                            for (int i = 0 ; i != tokens.count ; i++) {
                                lengthInSeconds = 60 *lengthInSeconds + [[tokens objectAtIndex:i] doubleValue];
                            }
                            self.audioCreativeDuration = [NSNumber numberWithDouble:lengthInSeconds];
                        }

                        // Audio file url
                        if ([audioAsset objectForKey:@"MediaFiles"] && [[audioAsset objectForKey:@"MediaFiles"] objectForKey:@"MediaFile"]) {
                            NSDictionary *audioFile = [[audioAsset objectForKey:@"MediaFiles"] objectForKey:@"MediaFile"];
                            if ([audioFile objectForKey:@"__text"]) {
                                self.audioCreativeUrl = [audioFile objectForKey:@"__text"];
                            }
                        }
                    }

                    // Image component
                    if ([creatives objectAtIndex:1]) {
                        NSDictionary *secondCreative = [creatives objectAtIndex:1];
                        if ([[secondCreative objectForKey:@"CompanionAds"] objectForKey:@"Companion"]) {
                            NSArray *imageAssets = [[secondCreative objectForKey:@"CompanionAds"] objectForKey:@"Companion"];
                            NSDictionary *staticResource;

                            for (NSDictionary *imgAsset in imageAssets) {
                                if ([imgAsset objectForKey:@"StaticResource"]) {
                                    staticResource = imgAsset;
                                    break;
                                }
                            }

                            if (staticResource) {
                                // Image file url
                                if ([[staticResource objectForKey:@"StaticResource"] objectForKey:@"__text"]) {
                                    self.imageCreativeUrl = [[staticResource objectForKey:@"StaticResource"] objectForKey:@"__text"];
                                }

                                // Image dimensions
                                if ([staticResource objectForKey:@"_height"]) {
                                    self.imageCreativeHeight = [NSNumber numberWithDouble:[[staticResource objectForKey:@"_height"] doubleValue]];
                                }
                                if ([staticResource objectForKey:@"_width"]) {
                                    self.imageCreativeWidth = [NSNumber numberWithDouble:[[staticResource objectForKey:@"_width"] doubleValue]];
                                }

                                // URL for tracking clicks?
                                if ([staticResource objectForKey:@"TrackingEvents"] && [[staticResource objectForKey:@"TrackingEvents"] objectForKey:@"Tracking"]) {
                                    if ([[[staticResource objectForKey:@"TrackingEvents"] objectForKey:@"Tracking"] objectForKey:@"__text"]) {
                                        self.creativeTrackingUrl = [[[staticResource objectForKey:@"TrackingEvents"] objectForKey:@"Tracking"] objectForKey:@"__text"];
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return self;
}

@end
