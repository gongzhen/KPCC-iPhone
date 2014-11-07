//
//  SCPRProgramDetailViewController.m
//  KPCC
//
//  Created by John Meeker on 9/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramDetailViewController.h"
#import "SCPRProgramDetailHeaderView.h"
#import "SCPRProgramDetailTableViewCell.h"
#import "SCPRMasterViewController.h"
#import "FXBlurView.h"
#import "DesignManager.h"
#import "AudioManager.h"
#import "QueueManager.h"
#import "Program.h"
#import "Episode.h"
#import "Segment.h"

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

    self.blurView.tintColor = [UIColor clearColor];
    self.blurView.alpha = (self.episodesTable.contentOffset.y + 25) / 150;
    self.blurView.blurRadius = 20.f;
    self.blurView.dynamic = NO;

    [[DesignManager shared] loadProgramImage:_program.program_slug
                                andImageView:self.programBgImage
                                  completion:^(BOOL status) {
                                      [self.blurView setNeedsDisplay];
                                  }];

    [[NetworkManager shared] fetchEpisodesForProgram:_program.program_slug dispay:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    SCPRProgramDetailHeaderView *headerView = [[SCPRProgramDetailHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 250)];
    self.episodesTable.tableHeaderView = headerView;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.blurView setNeedsDisplay];
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

    SCPRProgramDetailTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"programDetailTableCell"];
    if (cell == nil) {
        cell = [[SCPRProgramDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"programDetailTableCell"];
    }

    cell.backgroundColor = [UIColor clearColor];
    [cell setEpisode:[self.episodesList objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{

    if ([tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [tableView setSeparatorInset:UIEdgeInsetsMake(0, 8, 0, 8)];
    }

    if ([tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [tableView setLayoutMargins:UIEdgeInsetsMake(0, 8, 0, 8)];
    }

    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsMake(0, 8, 0, 8)];
    }
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray *audioChunks = [[QueueManager shared] enqueueEpisodes:self.episodesList withCurrentIndex:indexPath.row];
    [[[Utils del] masterViewController] setOnDemandUI:YES forProgram:self.program withAudio:audioChunks atCurrentIndex:(int)indexPath.row];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
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
        if (episode.audio != nil) {
            [episodesArray addObject:episode];
        } else {
            if (episode.segments != nil && [episode.segments count] > 0) {
                for (Segment *segment in episode.segments) {
                    [episodesArray addObject:segment];
                }
            }
        }
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
