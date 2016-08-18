//
//  AppDelegate.m
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "YTPlayerView.h"
#import "YTPlayerModel.h"

typedef void(^PlayBtnCallBackBlock)(void);

@interface YTPlayerCell : UITableViewCell

@property (weak, nonatomic  ) IBOutlet UIImageView       *picView;
@property (weak, nonatomic  ) IBOutlet UIButton          *playBtn;
@property (weak, nonatomic  ) IBOutlet UILabel           *titleLabel;
/** model */
@property (nonatomic, strong) YTPlayerModel              *model;
/** 播放按钮block */
@property (nonatomic, copy  ) PlayBtnCallBackBlock       playBlock;

@end
