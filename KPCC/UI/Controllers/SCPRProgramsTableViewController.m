//
//  SCPRProgramsTableViewController.m
//  KPCC
//
//  Created by John Meeker on 9/15/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramsTableViewController.h"
#import "SCPRProgramDetailViewController.h"
#import "ContentManager.h"
#import "DesignManager.h"

@interface SCPRProgramsTableViewController ()
@property Program *currentProgram;
@property UIImageView *programBgImage;
@property NSArray *programsList;
@end

@implementation SCPRProgramsTableViewController

@synthesize currentProgram;

- (id)init {
    self = [super init];
    return self;
}

- (id)initWithBackgroundProgram:(Program*)program {
    self = [self init];
    self.currentProgram = program;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];
    self.programBgImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    
    self.tableView.backgroundColor = [UIColor clearColor];

    [[DesignManager shared] loadProgramImage:currentProgram.program_slug andImageView:self.programBgImage];

    self.programsList = [Program fetchAllProgramsInContext:[[ContentManager shared] managedObjectContext]];
    NSLog(@"programsList? %lu", (unsigned long)[self.programsList count]);
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

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"programTableCell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"programTableCell"];
    }

    cell.textLabel.text = [NSString stringWithFormat:@"%@", [[self.programsList objectAtIndex:indexPath.row] title]];
    return cell;
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCPRProgramDetailViewController *programDetailViewController = [[SCPRProgramDetailViewController alloc]
                                                                    initWithProgram:[self.programsList objectAtIndex:indexPath.row]];
    NSLog(@"curr program %@", [[self.programsList objectAtIndex:indexPath.row] program_slug]);
    
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
