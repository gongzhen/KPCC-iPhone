//
//  SCPRNavigationBar.m
//  KPCC
//
//  Created by John Meeker on 6/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationBar.h"
#import "SCPRMenuButton.h"
#import <POP/POP.h>

@interface SCPRNavigationBar()
- (void)touchUpInsideHandler:(SCPRNavigationBar *)sender;
@end

@implementation SCPRNavigationBar

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialization code

    }
    return self;
}

- (void)touchUpInsideHandler:(SCPRNavigationBar *)sender {

}

- (void)layoutSubviews{
    self.backItem.title = @"";
    [super layoutSubviews];
}

@end
