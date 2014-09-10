//
//  DesignManager.h
//  KPCC
//
//  Created by John Meeker on 9/10/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DesignManager : NSObject

+ (DesignManager*)shared;

- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView;

@end
