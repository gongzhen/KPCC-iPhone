//
//  UXmanager.h
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Settings.h"

@interface UXmanager : NSObject

@property (nonatomic,strong) Settings *settings;

+ (instancetype)shared;
- (void)load;
- (void)persist;

@end
