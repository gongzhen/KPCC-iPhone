//
//  SCPRProgramDetailViewController.m
//  KPCC
//
//  Created by John Meeker on 9/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramDetailViewController.h"
#import "DesignManager.h"
#import "Program.h"

@interface SCPRProgramDetailViewController ()

@end

@implementation SCPRProgramDetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (id)initWithProgram:(Program *)program {
    self = [self initWithNibName:nil bundle:nil];
    self.program = program;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    NSLog(@"detail curr program: %@", _program.program_slug);
    NSLog(@"program DetailVC after push %@", NSStringFromCGRect(self.view.frame));

    NSLog(@"programIV frame %@", NSStringFromCGRect(self.programBgImage.frame));
    //self.programBgImage.frame = CGRectMake(0, 64, self.programBgImage.frame.size.width, self.programBgImage.frame.size.height - 64);
    NSLog(@"programIV frame now %@", NSStringFromCGRect(self.programBgImage.frame));
    [[DesignManager shared] loadProgramImage:_program.program_slug andImageView:self.programBgImage];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
