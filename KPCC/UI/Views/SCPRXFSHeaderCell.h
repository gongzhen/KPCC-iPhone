//
//  SCPRXFSHeaderCell.h
//  KPCC
//
//  Created by Ben Hochberg on 5/29/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRXFSHeaderCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIView *stackedView;
@property (nonatomic, strong) IBOutlet UIView *dividerView;
@property (nonatomic, strong) IBOutlet UILabel *captionLabel;

- (void)prep;

@end
