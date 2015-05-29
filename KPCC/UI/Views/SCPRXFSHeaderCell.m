//
//  SCPRXFSHeaderCell.m
//  KPCC
//
//  Created by Ben Hochberg on 5/29/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRXFSHeaderCell.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"

@implementation SCPRXFSHeaderCell

- (void)prep {
    [self.captionLabel proLightFontize];
    self.stackedView.backgroundColor = [UIColor kpccOrangeColor];
    self.dividerView.backgroundColor = [[UIColor kpccOrangeColor] translucify:0.75f];
    
}

@end
