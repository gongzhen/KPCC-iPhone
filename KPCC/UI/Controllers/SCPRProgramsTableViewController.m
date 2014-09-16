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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

    //cell.backgroundColor = [UIColor clearColor];
    //cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.text = [NSString stringWithFormat:@"%@", [[self.programsList objectAtIndex:indexPath.row] title]];

    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here, for example:
    // Create the next view controller.
    SCPRProgramDetailViewController *programDetailViewController = [[SCPRProgramDetailViewController alloc] initWithNibName:nil bundle:nil];
    
    // Pass the selected object to the new view controller.
    programDetailViewController.program = [self.programsList objectAtIndex:indexPath.row];
    
    // Push the view controller.
    [self.navigationController pushViewController:programDetailViewController animated:YES];
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
