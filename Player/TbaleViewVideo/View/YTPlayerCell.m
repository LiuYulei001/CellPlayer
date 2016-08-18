//
//  AppDelegate.m
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//


#import "YTPlayerCell.h"
#import <AVFoundation/AVFoundation.h>
#import "UIImageView+WebCache.h"
#import "Masonry.h"

@interface YTPlayerCell ()

@end

@implementation YTPlayerCell

- (void)awakeFromNib {
    // Initialization code
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setModel:(YTPlayerModel *)model
{
    [self.picView sd_setImageWithURL:[NSURL URLWithString:model.coverForFeed] placeholderImage:[UIImage imageNamed:@"loading_bgView"]];
    self.titleLabel.text = model.title;
}

- (IBAction)play:(UIButton *)sender {
    if (self.playBlock) {
        self.playBlock();
    }
}

@end
