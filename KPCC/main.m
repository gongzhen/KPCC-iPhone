
//  main.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SCPRAppDelegate.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        @try {
            return UIApplicationMain(argc, argv, nil, NSStringFromClass([SCPRAppDelegate class]));
        }
        @catch (NSException *exception) {
            NSLog(@"Exception - %@",exception);
            exit(EXIT_FAILURE);
        }
    }
}
