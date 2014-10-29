//
//  DesignManager.m
//  KPCC
//
//  Created by John Meeker on 9/10/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "DesignManager.h"
#import "Utils.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import <POP/POP.h>
#import "SCPRAppDelegate.h"

#define kMediaServerPath @"http://media.scpr.org/iphone/program-images/"

static DesignManager *singleton = nil;

@implementation DesignManager

+ (DesignManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[DesignManager alloc] init];
        }
    }
    return singleton;
}

/**
 * Async request to fetch image and set in image view with given program slug. Via AFNetworking.
 *
 */
- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView completion:(void (^)(BOOL status))completion {

    if (![Utils pureNil:slug]) {

        // TODO: Account for @3x.
        NSString *slugWithScale;
        if ([Utils isRetina]) {
            slugWithScale = [NSString stringWithFormat:@"%@@2x", slug];
        } else {
            slugWithScale = slug;
        }

        NSURL *imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@program_tile_%@.jpg", kMediaServerPath, slugWithScale]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];

        [UIView animateWithDuration:0.15 animations:^{
            [imageView setAlpha:0.0];
        }];

        UIImageView *iv = imageView;
        [iv setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
            imageView.image = image;
            [UIView animateWithDuration:0.15 animations:^{
                [imageView setAlpha:1.0];
            }];

            completion(true);
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
            [imageView setImage:[UIImage imageNamed:@"program_tile_generic.jpg"]];
            [UIView animateWithDuration:0.15 animations:^{
                [imageView setAlpha:1.0];
            }];

            completion(true);
        }];
    } else {
        [imageView setImage:[UIImage imageNamed:@"program_tile_generic.jpg"]];
        completion(true);
    }
}



- (CGRect)screenFrame {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    UIWindow *window = [del window];
    return CGRectMake(0.0, 0.0, window.bounds.size.width,
                      window.bounds.size.height);
}

@end
