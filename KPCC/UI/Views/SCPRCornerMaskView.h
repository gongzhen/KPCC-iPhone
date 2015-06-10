//
//  SCPRCornerMaskView.h
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRCornerMaskView : UIView

- (void)maskWithRects:(NSArray*)rects;

@property (nonatomic, strong) NSArray *rectsArray;
@property (nonatomic, strong) UIColor *bgColor;

@end



