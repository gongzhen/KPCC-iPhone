//
//  SCPRProgramsListViewController.m
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramsListViewController.h"
#import "SCPRProgramTableViewCell.h"
#import "SCPRProgramTableViewHeader.h"
#import "SCPRProgramDetailViewController.h"
#import "DesignManager.h"
#import "AnalyticsManager.h"
#import "AudioManager.h"
#import "FXBlurView.h"
#import "SCPRGenericAvatarViewController.h"
#import "GenericProgram.h"
#import "UIImageView+AFNetworking.h"

/**
 * Programs with these slugs will be hidden from this table view.
 */
#define HIDDEN_PROGRAMS @[ @"take-two-evenings", @"filmweek-marquee", @"reveal" ]


@interface SCPRProgramsListViewController ()
@property NSArray *programsList;
@property id<GenericProgram> currentProgram;
@property SCPRProgramTableViewHeader* kpccHeader;
@property SCPRProgramTableViewHeader* otherHeader;
@property NSArray* kpccPrograms;
@property NSArray* otherPrograms;

@property (nonatomic, weak)	IBOutlet UIView		*backgroundCoverView;
@end


@implementation SCPRProgramsListViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (instancetype)initWithBackgroundProgram:(id<GenericProgram>)program {
    self = [self initWithNibName:nil bundle:nil];
    self.currentProgram = program;
    self.title = @"Programs";
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = @"Programs";
    
    [[AnalyticsManager shared] screen:@"programsListView"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[DesignManager shared] setProtectBlurredImage:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];

	self.view.backgroundColor = [UIColor blackColor];

    self.blurView.tintColor = [UIColor clearColor];
    self.blurView.blurRadius = 20.f;
    self.blurView.dynamic = NO;

    /*
    self.genAvatar = [[SCPRGenericAvatarViewController alloc]
                                               initWithNibName:@"SCPRGenericAvatarViewController"
                                               bundle:nil];
    self.genAvatar.view.frame = CGRectMake(0.0,64.0,
                                           self.genAvatar.view.frame.size.width,
                                           self.genAvatar.view.frame.size.height);
    self.genAvatar.view.alpha = 0.0f;
    [self.view addSubview:self.genAvatar.view];*/

//    [[DesignManager shared] loadProgramImage:_currentProgram.program_slug
//                                andImageView:self.programBgImage
//                                  completion:^(BOOL status) {
//                                      [self.blurView setNeedsDisplay];
//                                  }];
	
	UIImage *backgroundImage = [[DesignManager shared] currentBlurredLiveImage];
	if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
		UIImage *backgroundImageShow = [[DesignManager shared] currentBlurredImage];
		if (backgroundImageShow) {
			backgroundImage = backgroundImageShow;
		}
	}

	self.programBgImage.image = backgroundImage;

	[self.backgroundCoverView setBackgroundColor:[[UIColor virtualBlackColor] translucify:0.7f]];

	self.view.backgroundColor = [UIColor clearColor];

    // Fetch all Programs from CoreData and filter, given HIDDEN_PROGRAMS.
    NSArray *storedPrograms = [Program fetchAllProgramsInContext:[[ContentManager shared] managedObjectContext]];
    NSMutableArray* kpccPrograms = [[NSMutableArray alloc] init];
    NSMutableArray* otherPrograms = [[NSMutableArray alloc] init];

    for (Program *program in storedPrograms) {
        BOOL matches = NO;
        for (NSString *hiddenSlug in HIDDEN_PROGRAMS) {
            if ([program.program_slug isEqualToString:hiddenSlug]) {
                matches = YES;
                break;
            }
        }

        if (matches == NO) {
            if ([[program is_kpcc] isEqual:@(YES)]) {
                [kpccPrograms addObject:program];
            } else {
                [otherPrograms addObject:program];
            }
        }
    }

    // Sort Programs by KPCC first, then alphabetically.
    NSSortDescriptor *strDescr = [[NSSortDescriptor alloc] initWithKey:@"sortTitle" ascending:YES];
    NSArray *sortDescriptors = @[strDescr];
    self.kpccPrograms = [kpccPrograms sortedArrayUsingDescriptors:sortDescriptors];
    self.otherPrograms = [otherPrograms sortedArrayUsingDescriptors:sortDescriptors];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 14)];
    self.programsTable.tableHeaderView = headerView;

    // create our section headers

    self.kpccHeader = [[SCPRProgramTableViewHeader alloc] initWithNibName:@"SCPRProgramTableViewHeader" bundle:nil];
    self.kpccHeader.view.frame = self.kpccHeader.view.frame;
    [self.kpccHeader setupWithText:@"KPCC Programs"];

    self.otherHeader = [[SCPRProgramTableViewHeader alloc] initWithNibName:@"SCPRProgramTableViewHeader" bundle:nil];
    self.otherHeader.view.frame = self.otherHeader.view.frame;
    [self.otherHeader setupWithText:@"Other Programs"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return [self.kpccPrograms count];
    } else {
        return [self.otherPrograms count];
    }
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return self.kpccHeader.view;
    } else {
        return self.otherHeader.view;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 31.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCPRProgramTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"programTableCell"];
    if (cell == nil) {
        NSArray *obj = [[NSBundle mainBundle] loadNibNamed:@"SCPRProgramTableViewCell" owner:nil options:nil];
        cell = (SCPRProgramTableViewCell*)obj[0];
    }

    Program* program;
    if (indexPath.section == 0) {
		program = self.kpccPrograms[indexPath.row];
    } else {
		program = self.otherPrograms[indexPath.row];
    }

    cell.backgroundColor = [UIColor clearColor];
    cell.programLabel.text = [NSString stringWithFormat:@"%@", [program title]];

    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, cell.frame.size.width, cell.frame.size.height)];
    cell.selectedBackgroundView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.2];

    NSString *iconNamed = [program program_slug];
    if (iconNamed) {
		[cell.gav setupWithProgram:program];
		cell.gav.view.alpha = 1.0f;
		cell.iconImageView.alpha = 0.0f;

		__weak SCPRProgramTableViewCell *weakCell = cell;
		
		NSString *densitySuffixString = nil;
		if ([[UIScreen mainScreen] scale] >= 2.0) {
			densitySuffixString = @"@2x";
		}
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://media.scpr.org/iphone/avatar-images/program_avatar_%@%@.png", iconNamed, densitySuffixString]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];

		[weakCell.iconImageView setImageWithURLRequest:request
									  placeholderImage:nil
											   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
												   weakCell.iconImageView.image	= image;
												   weakCell.iconImageView.alpha	= 1.0f;
												   weakCell.gav.view.alpha		= 0.0f;
											   } failure:nil];

//        } else {
//
//            [cell.iconImageView setImage:iconImg];
//            cell.gav.view.alpha = 0.0f;
//            cell.iconImageView.alpha = 1.0f;
//
//        }
//		}
    }

    return cell;
}

#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    Program* program;
    if ( indexPath.section == 0 ) {
        program = self.kpccPrograms[ indexPath.row ];
    } else {
        program = self.otherPrograms[ indexPath.row ];
    }

    SCPRProgramDetailViewController *programDetailViewController = [[SCPRProgramDetailViewController alloc]
                                                                    initWithProgram:program];

    programDetailViewController.program = program;
    [self.navigationController pushViewController:programDetailViewController animated:YES];
    
//    NSString *title = [NSString stringWithFormat:@"%@", [program title]];
//    if ( !title ) {
//        title = @"[UNKNOWN]";
//    }

    /*[[AnalyticsManager shared] logEvent:@"programSelected"
                         withParameters:@{ @"programTitle" : title }];*/
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    SCPRProgramTableViewCell *tCell = (SCPRProgramTableViewCell*)cell;
    [tCell.contentView layoutIfNeeded];
    
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
