//
//  SCPRProgramsListViewController.m
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramsListViewController.h"
#import "SCPRProgramTableViewCell.h"
#import "SCPRProgramDetailViewController.h"
#import "DesignManager.h"

/**
 * Programs with these slugs will be hidden from this table view.
 */
#define HIDDEN_PROGRAMS @[ @"take-two-evenings", @"filmweek-marquee" ]


@interface SCPRProgramsListViewController ()
@property NSArray *programsList;
@property Program *currentProgram;
@end


@implementation SCPRProgramsListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (id)initWithBackgroundProgram:(Program *)program {
    self = [self initWithNibName:nil bundle:nil];
    self.currentProgram = program;
    self.title = @"Programs";
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = @"Programs";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.blurView.tintColor = [UIColor clearColor];
    self.blurView.blurRadius = 20.f;
    self.blurView.dynamic = NO;

    [[DesignManager shared] loadProgramImage:_currentProgram.program_slug
                                andImageView:self.programBgImage
                                  completion:^(BOOL status) {
                                      [self.blurView setNeedsDisplay];
                                  }];

    // Fetch all Programs from CoreData and filter, given HIDDEN_PROGRAMS.
    NSArray *storedPrograms = [Program fetchAllProgramsInContext:[[ContentManager shared] managedObjectContext]];
    NSMutableArray *filteredPrograms = [[NSMutableArray alloc] initWithArray:storedPrograms];
    for (Program *program in storedPrograms) {
        for (NSString *hiddenSlug in HIDDEN_PROGRAMS) {
            if ([program.program_slug isEqualToString:hiddenSlug]) {
                [filteredPrograms removeObject:program];
                break;
            }
        }
    }

    self.programsList = filteredPrograms;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 14)];
    self.programsTable.tableHeaderView = headerView;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.programsList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    SCPRProgramTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"programTableCell"];
    if (cell == nil) {
        cell = [[SCPRProgramTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"programTableCell"];
    }

    cell.backgroundColor = [UIColor clearColor];
    cell.programLabel.text = [NSString stringWithFormat:@"%@", [[self.programsList objectAtIndex:indexPath.row] title]];

    NSString *iconNamed = [[self.programsList objectAtIndex:indexPath.row] program_slug];
    if (iconNamed) {
        UIImage *iconImg = [UIImage imageNamed:[NSString stringWithFormat:@"program_avatar_%@", iconNamed]];
        [cell.iconImageView setImage:iconImg];
        cell.iconImageView.frame = CGRectMake(cell.iconImageView.frame.origin.x, 31 - iconImg.size.height/2,
                                              iconImg.size.width, iconImg.size.height);
    }

    return cell;
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SCPRProgramDetailViewController *programDetailViewController = [[SCPRProgramDetailViewController alloc]
                                                                    initWithProgram:[self.programsList objectAtIndex:indexPath.row]];

    programDetailViewController.program = [self.programsList objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:programDetailViewController animated:YES];
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