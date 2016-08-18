//
//  AppDelegate.m
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//


#import <Foundation/Foundation.h>

@interface YTPlayerModel : NSObject

/** 标题 */
@property (nonatomic, copy) NSString *title;
/** 描述 */
@property (nonatomic, copy) NSString *video_descriptions;
/** 视频地址 */
@property (nonatomic, copy) NSString *playUrl;
/** 封面图 */
@property (nonatomic, copy) NSString *coverForFeed;
/** 时间戳 */
@property (nonatomic, assign) long   date;

+ (NSMutableArray *)playerModels;

@end
