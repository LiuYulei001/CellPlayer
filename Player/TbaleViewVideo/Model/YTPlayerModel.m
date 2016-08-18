//
//  AppDelegate.m
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//


#import "YTPlayerModel.h"

@implementation YTPlayerModel

+ (NSMutableArray *)playerModels {
    
    NSMutableArray *arrayM = [NSMutableArray array];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"videoData" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *rootDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    
    
    NSArray *dailyList = [rootDict objectForKey:@"dailyList"];
    // 使用KVC解析json
    for (NSDictionary *dic in dailyList) {
        NSArray *videoList = [dic objectForKey:@"videoList"];
        NSMutableArray *sectionArray = @[].mutableCopy;
        for (NSDictionary *dataDic in videoList) {
            YTPlayerModel *model = [[YTPlayerModel alloc] init];
            [model setValuesForKeysWithDictionary:dataDic];
            [sectionArray addObject:model];
        }
        [arrayM addObject:sectionArray];
    }
    
    return arrayM;
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    // 转换系统关键字description
    if ([key isEqualToString:@"description"]) {
        self.video_descriptions = [NSString stringWithFormat:@"%@",value];
    }
}

@end
