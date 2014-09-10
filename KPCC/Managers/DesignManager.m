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
 * User by SCPRMasterViewController to set program background image, given a program slug and image view.
 *
 */
- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView {
    
    // Load JSON with program image urls.
    NSError *fileError = nil;
    NSString *filePath = [[NSBundle mainBundle] pathForResource:[@"program_image_urls" stringByDeletingPathExtension] ofType:@"json"];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    
    NSDictionary *dict = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data
                                                                        options:kNilOptions
                                                                          error:&fileError];
    
    
    // TODO: Account for @3x.
    NSString *slugWithScale;
    if ([Utils isRetina]) {
        slugWithScale = [NSString stringWithFormat:@"%@-2x", slug];
    } else {
        slugWithScale = slug;
    }
    
    // Async request to fetch image and set in background tile view. Via AFNetworking.
    if ([dict objectForKey:slugWithScale]) {
        NSURL *imageUrl = [NSURL URLWithString:[dict objectForKey:slugWithScale]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
        
        [UIView animateWithDuration:0.3 animations:^{
            [imageView setAlpha:0.0];
        }];
        
        UIImageView *iv = imageView;
        [iv setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
            imageView.image = image;
            [UIView animateWithDuration:0.15 animations:^{
                [imageView setAlpha:1.0];
            }];
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
            [imageView setImage:[UIImage imageNamed:@"program_tile_generic.jpg"]];
            [UIView animateWithDuration:0.15 animations:^{
                [imageView setAlpha:1.0];
            }];
        }];
    } else {
        [imageView setImage:[UIImage imageNamed:@"program_tile_generic.jpg"]];
    }
}

@end
