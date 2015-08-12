//
//  SCPRSSOInputFieldCellTableViewCell.h
//  KPCC
//
//  Created by Ben Hochberg on 7/30/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SSOInputFieldType) {
    SSOInputFieldTypeEmail = 0,
    SSOInputFieldTypePassword,
    SSOInputFieldTypePasswordConfirmation
};

@interface SCPRSSOInputFieldCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *captionLabel;
@property (nonatomic, strong) IBOutlet UIImageView *iconImageView;
@property (nonatomic, strong) IBOutlet UITextField *emailTextField;
@property (nonatomic, strong) IBOutlet UIView *inputSeatView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *fieldLeftAnchor;

@property (nonatomic) BOOL signup;
@property (nonatomic) BOOL inputting;

@property SSOInputFieldType type;

- (void)primeWithType:(SSOInputFieldType)type andFieldDelegate:(id<UITextFieldDelegate>)delegate;
- (void)activate;
- (void)deactivate;

@end
