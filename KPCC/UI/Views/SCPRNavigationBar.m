//
//  SCPRNavigationBar.m
//  KPCC
//
//  Created by John Meeker on 6/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationBar.h"

@implementation SCPRNavigationBar

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialization code
        UISwipeGestureRecognizer *swipeDown;
        swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown)];
        [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
        [swipeDown setNumberOfTouchesRequired:1];
        [swipeDown setEnabled:YES];
        [self addGestureRecognizer:swipeDown];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        UISwipeGestureRecognizer *swipeDown;
        swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown)];
        [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
        [swipeDown setNumberOfTouchesRequired:1];
        [swipeDown setEnabled:YES];
        [self addGestureRecognizer:swipeDown];
    }
    return self;
}

- (void)didSwipeDown {
    NSLog(@"didSwipeDown");
}

- (IBAction)handleTap {
    NSLog(@"didTap");
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
