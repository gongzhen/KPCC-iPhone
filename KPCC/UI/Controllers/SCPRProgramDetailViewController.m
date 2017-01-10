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
#import "AnalyticsManager.h"
#import "SCPRSpinnerViewController.h"

@interface SCPRProgramDetailViewController ()
@property NSMutableArray *episodesList;
@property IBOutlet FXBlurView *blurView;
@end

@implementation SCPRProgramDetailViewController

@synthesize episodesList;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (instancetype)initWithProgram:(Program *)program {
    self = [self initWithNibName:nil bundle:nil];
    self.program = program;
    self.title = program.title;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.episodesTable.separatorColor = [UIColor clearColor];
    self.blurView.tintColor = [UIColor clearColor];
    self.blurView.blurRadius = 20.f;
    self.blurView.dynamic = NO;
    self.blurView.alpha = 0.0f;
    self.programBgImage.contentMode = UIViewContentModeScaleAspectFill;
    self.curtainView.backgroundColor = [UIColor clearColor];

    
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];
    
    
    
    //[[NetworkManager shared] fetchEpisodesForProgram:_program.program_slug dispay:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [SCPRSpinnerViewController spinInCenterOfView:self.curtainView offset:110.0 delay:0.33 appeared:^{
        [[DesignManager shared] loadProgramImage:_program.program_slug
                                    andImageView:self.programBgImage
                                      completion:^(BOOL status) {
                                          
                                          self.programBgImage.clipsToBounds = YES;
                                          [self.blurView setNeedsDisplay];
                                          UIImage *blurred = [self.programBgImage.image blurredImageWithRadius:20.0f
                                                                                                    iterations:3
                                                                                                     tintColor:[UIColor clearColor]];
                                          [[DesignManager shared] setCurrentBlurredImage:blurred];
                                          
                                          [[NetworkManager shared] fetchEpisodesForProgram:_program.program_slug
                                                                                completion:^(id object) {
                                                                                    
                                                                                    NSAssert([object isKindOfClass:[NSArray class]],@"Expecting an Array here");
                                                                                    NSArray *content = (NSArray*)object;
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
                                                                                                    if ( segment.audio ) {
                                                                                                        [episodesArray addObject:segment];
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                    
                                                                                    self.episodesList = episodesArray;
                                                                                    
                                                                                    [self.episodesTable reloadData];
                                                                                    self.episodesTable.separatorColor = [[UIColor virtualWhiteColor] translucify:0.5];
                                                                                    
                                                                                    
                                                                                    [SCPRSpinnerViewController finishSpinning];
                                                                                    [UIView animateWithDuration:0.25 animations:^{
                                                                                        self.curtainView.alpha = 0.0f;
                                                                                    } completion:^(BOOL finished) {
                                                                                        [self.curtainView removeFromSuperview];
                                                                                    }];
                                                                                    
                                                                                }];
                                          
                                      }];
        
        
    }];

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
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                           cell.frame.size.width,
                                                                           cell.frame.size.height)];
    
    cell.selectedBackgroundView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.2];
    
    [cell setEpisode:(self.episodesList)[indexPath.row]];
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

    NSArray *audioChunks = [[QueueManager shared] enqueueEpisodes:self.episodesList
                                                 withCurrentIndex:indexPath.row
                                                  playImmediately:NO];
    
    [[[Utils del] masterViewController] setOnDemandUI:YES
                                           forProgram:self.program
                                            withAudio:audioChunks
                                       atCurrentIndex:(int)indexPath.row];
    
//    id episode = self.episodesList[indexPath.row];
//    NSString *title = @"[UNKNOWN]";
//    NSString *programTitle = @"[UNKNOWN]";
//    if ([episode isKindOfClass:[Episode class]]) {
//        Episode *ep = (Episode *) episode;
//        title = [ep.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        programTitle = ep.programName;
//    } else {
//        Segment *seg = (Segment *) episode;
//        title = seg.title;
//        programTitle = seg.programName;
//    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.blurView.alpha = (scrollView.contentOffset.y) / 150;
}


# pragma mark - ContentProcessor delegate

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {

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
