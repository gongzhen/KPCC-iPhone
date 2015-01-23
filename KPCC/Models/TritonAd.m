//
//  TritonAd.m
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "TritonAd.h"

@implementation TritonAd

- (instancetype)initWithDict:(NSDictionary *)dictionary {
    if ((self = [super init])) {

        if (dictionary[@"_id"]) {
            self.adId = dictionary[@"_id"];
        }

        if (dictionary[@"InLine"]) {
            NSDictionary *inlineDict = [[NSDictionary alloc] initWithDictionary:dictionary[@"InLine"]];

            // Impression URL
            if (inlineDict[@"Impression"] && inlineDict[@"Impression"][@"__text"]) {
                self.impressionUrl = inlineDict[@"Impression"][@"__text"];
            }

            // Ad assets
            if (inlineDict[@"Creatives"] && inlineDict[@"Creatives"][@"Creative"]) {
                NSArray *creatives = inlineDict[@"Creatives"][@"Creative"];
                if (creatives && [creatives count] > 0) {

                    // Audio component
                    NSDictionary *firstCreative = creatives[0];
                    if (firstCreative[@"Linear"]) {
                        NSDictionary *audioAsset = firstCreative[@"Linear"];

                        // File duration
                        if (audioAsset[@"Duration"]) {
                            NSArray* tokens = [audioAsset[@"Duration"] componentsSeparatedByString:@":"];
                            double lengthInSeconds = 0;
                            for (int i = 0 ; i != tokens.count ; i++) {
                                lengthInSeconds = 60 *lengthInSeconds + [tokens[i] doubleValue];
                            }
                            self.audioCreativeDuration = @(lengthInSeconds);
                        }

                        // Audio file url
                        if (audioAsset[@"MediaFiles"] && audioAsset[@"MediaFiles"][@"MediaFile"]) {
                            NSDictionary *audioFile = audioAsset[@"MediaFiles"][@"MediaFile"];
                            if (audioFile[@"__text"]) {
                                self.audioCreativeUrl = audioFile[@"__text"];
                            }
                        }
                    }

                    // Image component
                    if (creatives[1]) {
                        NSDictionary *secondCreative = creatives[1];
                        if (secondCreative[@"CompanionAds"][@"Companion"]) {
                            NSArray *imageAssets = secondCreative[@"CompanionAds"][@"Companion"];
                            NSDictionary *staticResource;

                            for (NSDictionary *imgAsset in imageAssets) {
                                if (imgAsset[@"StaticResource"]) {
                                    staticResource = imgAsset;
                                    break;
                                }
                            }

                            if (staticResource) {
                                
                                // Clickthrough
                                if ( staticResource[@"CompanionClickThrough"] ) {
                                    self.clickthroughUrl = staticResource[@"CompanionClickThrough"];
                                }
                                
                                // Image file url
                                if (staticResource[@"StaticResource"][@"__text"]) {
                                    self.imageCreativeUrl = staticResource[@"StaticResource"][@"__text"];
                                }

                                // Image dimensions
                                if (staticResource[@"_height"]) {
                                    self.imageCreativeHeight = @([staticResource[@"_height"] doubleValue]);
                                }
                                if (staticResource[@"_width"]) {
                                    self.imageCreativeWidth = @([staticResource[@"_width"] doubleValue]);
                                }

                                // URL for tracking clicks?
                                if (staticResource[@"TrackingEvents"] && staticResource[@"TrackingEvents"][@"Tracking"]) {
                                    if (staticResource[@"TrackingEvents"][@"Tracking"][@"__text"]) {
                                        self.creativeTrackingUrl = staticResource[@"TrackingEvents"][@"Tracking"][@"__text"];
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
