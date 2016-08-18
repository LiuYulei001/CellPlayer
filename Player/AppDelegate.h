//
//  AppDelegate.h
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

// 调用AppDelegate单例记录播放状态是否锁屏
@property (nonatomic, assign) BOOL     isLockScreen;
/** cell上添加player时候，不允许横屏,只运行竖屏状态状态*/
@property (nonatomic, assign) BOOL     isAllowLandscape;

@end

