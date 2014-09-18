//
//  SCPRProgramDetailViewController.m
//  KPCC
//
//  Created by John Meeker on 9/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramDetailViewController.h"
#import "FXBlurView.h"
#import "DesignManager.h"
#import "Program.h"
#import "Episode.h"

@interface SCPRProgramDetailViewController ()
@property NSMutableArray *episodesList;
@property IBOutlet FXBlurView *blurView;
@end

@implementation SCPRProgramDetailViewController

@synthesize episodesList;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (id)initWithProgram:(Program *)program {
    self = [self initWithNibName:nil bundle:nil];
    self.program = program;
    self.title = program.title;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSLog(@"program DetailVC after push %@", NSStringFromCGRect(self.view.frame));
    NSLog(@"programIV frame %@", NSStringFromCGRect(self.programBgImage.frame));

    [[DesignManager shared] loadProgramImage:_program.program_slug andImageView:self.programBgImage];
    [[NetworkManager shared] fetchEpisodesForProgram:_program.program_slug dispay:self];
    
    self.blurView.tintColor = [UIColor clearColor];
    self.blurView.alpha = (self.episodesTable.contentOffset.y + 25) / 150;
    self.blurView.blurRadius = 20.f;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 250)];
    self.episodesTable.tableHeaderView = headerView;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.episodesList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"episodeTableCell"];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"episodeTableCell"];
    }

    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.text = [NSString stringWithFormat:@"%@", [[self.episodesList objectAtIndex:indexPath.row] title]];
    return cell;
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"scrollViewDidScroll %f", scrollView.contentOffset.y);
    self.blurView.alpha = (scrollView.contentOffset.y + 25) / 150;
}


# pragma mark - ContentProcessor delegate

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    if ([content count] == 0) {
        return;
    }

    NSMutableArray *episodesArray = [@[] mutableCopy];
    for (NSMutableDictionary *episodeDict in content) {
        Episode *episode = [[Episode alloc] initWithDict:episodeDict];
        [episodesArray addObject:episode];
    }
    self.episodesList = episodesArray;

    [self.episodesTable reloadData];
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
