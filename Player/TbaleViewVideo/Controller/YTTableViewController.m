//
//  AppDelegate.m
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//


#import "YTTableViewController.h"
#import "YTPlayerCell.h"
#import "YTPlayerModel.h"
#import "Masonry.h"

@interface YTTableViewController ()

@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) YTPlayerView   *playerView;

@end

@implementation YTTableViewController

#pragma mark - life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 44.0f;
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.dataSource = [YTPlayerModel playerModels];
//    self.dataSource = @[].mutableCopy;
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"videoData" ofType:@"json"];
//    NSData *data = [NSData dataWithContentsOfFile:path];
//    NSDictionary *rootDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
//    
//    
//    NSArray *dailyList = [rootDict objectForKey:@"dailyList"];
//    // 使用KVC解析json
//    for (NSDictionary *dic in dailyList) {
//        NSArray *videoList = [dic objectForKey:@"videoList"];
//        NSMutableArray *sectionArray = @[].mutableCopy;
//        for (NSDictionary *dataDic in videoList) {
//            YTPlayerModel *model = [[YTPlayerModel alloc] init];
//            [model setValuesForKeysWithDictionary:dataDic];
//            [sectionArray addObject:model];
//        }
//        [self.dataSource addObject:sectionArray];
//    }
}

// 页面消失时候
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.playerView resetPlayer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
        self.view.backgroundColor = [UIColor whiteColor];
    }else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        self.view.backgroundColor = [UIColor blackColor];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSource.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray * arr = self.dataSource[section];
    return arr.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *identifier = @"playerCell";
    YTPlayerCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    __block YTPlayerModel *model = self.dataSource[indexPath.section][indexPath.row];

    cell.model = model;
    
    __block NSIndexPath *weakIndexPath = indexPath;
    __block YTPlayerCell *weakCell = cell;
    __weak typeof(self) weakSelf = self;
    cell.playBlock = ^{
        weakSelf.playerView = [YTPlayerView playerView];
        NSURL *videoURL = [NSURL URLWithString:model.playUrl];
        // 设置player相关参数
        [weakSelf.playerView setVideoURL:videoURL withTableView:weakSelf.tableView AtIndexPath:weakIndexPath];
        [weakSelf.playerView addPlayerToCell:weakCell];
    };
    
    return cell;
}



/*
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray * modelArray = self.dataSource[section];
    YTPlayerModel *model = modelArray[0];
    return [self getDateFromTimeInterval:model.date];
}
*/
/**
 *  转换时间戳
 *
 *  @param timeInterval 时间戳
 *
 *  @return 时间字符串
 */
- (NSString *)getDateFromTimeInterval:(long)timeInterval {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy月MM日dd";
    NSDate *createDate = [NSDate dateWithTimeIntervalSince1970:timeInterval/1000];
    NSString *createStr = [formatter stringFromDate:createDate];
    return createStr;
}


@end
