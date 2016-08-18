//
//  AppDelegate.h
//  Player
//
//  Created by 李银涛 on 16/8/18.
//  Copyright © 2016年 李银涛. All rights reserved.
//

#import "YTPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "Masonry.h"
#import "XXNibBridge.h"
#import "YTPlayerControlView.h"
#import "AppDelegate.h"

#define kYTPlayerViewContentOffset @"contentOffset"
#define iPhone4s ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 960), [[UIScreen mainScreen] currentMode].size) : NO)
#define ApplicationDelegate   ((AppDelegate *)[[UIApplication sharedApplication] delegate])
#define ScreenWidth                         [[UIScreen mainScreen] bounds].size.width
#define ScreenHeight                        [[UIScreen mainScreen] bounds].size.height
#define YTPlayerTableHeight                 (ScreenWidth * 9 / 16)

static const CGFloat YTPlayerAnimationTimeInterval             = 7.0f;
static const CGFloat YTPlayerControlBarAutoFadeOutTimeInterval = 0.5f;

// 枚举值，包含水平移动方向和垂直移动方向
typedef NS_ENUM(NSInteger, PanDirection){
    PanDirectionHorizontalMoved, //横向移动
    PanDirectionVerticalMoved    //纵向移动
};

//播放器的几种状态
typedef NS_ENUM(NSInteger, YTPlayerState) {
    YTPlayerStateBuffering,  //缓冲中
    YTPlayerStatePlaying,    //播放中
    YTPlayerStateStopped,    //停止播放
    YTPlayerStatePause       //暂停播放
};

static YTPlayerView* playerView = nil;

@interface YTPlayerView () <XXNibBridge,UIGestureRecognizerDelegate>

/** 快进快退label */
@property (weak, nonatomic  ) IBOutlet UILabel                 *horizontalLabel;
/** 系统菊花 */
@property (weak, nonatomic  ) IBOutlet UIActivityIndicatorView *activity;
/** 返回按钮*/
@property (weak, nonatomic  ) IBOutlet UIButton                *backBtn;
/** 播放属性 */
@property (nonatomic, strong) AVPlayer            *player;
/** 播放属性 */
@property (nonatomic, strong) AVPlayerItem        *playerItem;
/** playerLayer */
@property (nonatomic, strong) AVPlayerLayer       *playerLayer;
/** 滑杆 */
@property (nonatomic, strong) UISlider            *volumeViewSlider;
/** 计时器 */
@property (nonatomic, strong) NSTimer             *timer;
/** 蒙版View */
@property (nonatomic, strong) YTPlayerControlView *controlView;
/** 用来保存快进的总时长 */
@property (nonatomic, assign) CGFloat             sumTime;
/** 定义一个实例变量，保存枚举值 */
@property (nonatomic, assign) PanDirection        panDirection;
/** 播发器的几种状态 */
@property (nonatomic, assign) YTPlayerState       state;
/** 是否为全屏 */
@property (nonatomic, assign) BOOL                isFullScreen;
/** 是否锁定屏幕方向 */
@property (nonatomic, assign) BOOL                isLocked;
/** 是否在调节音量*/
@property (nonatomic, assign) BOOL                isVolume;
/** 是否显示controlView*/
@property (nonatomic, assign) BOOL                isMaskShowing;
/** 是否被用户暂停 */
@property (nonatomic, assign) BOOL                isPauseByUser;
/** 是否播放本地文件 */
@property (nonatomic, assign) BOOL                isLocalVideo;
/** slider上次的值 */
@property (nonatomic, assign) CGFloat             sliderLastValue;
/** 是否缩小视频在底部 */
@property (nonatomic, assign) BOOL                isBottomVideo;

@end

@implementation YTPlayerView

/**
 *  类方法创建，该方法适用于代码创建View
 *
 *  @return YTPlayer
 */
+ (instancetype)setupYTPlayer
{
    return [[NSBundle mainBundle] loadNibNamed:@"YTPlayerView" owner:nil options:nil].lastObject;
}

/**
 *  单例，用于列表cell上多个视频
 *
 *  @return YTPlayer
 */
+ (instancetype)playerView
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        playerView = [[[NSBundle mainBundle] loadNibNamed:@"YTPlayerView" owner:nil options:nil] lastObject];
    });
    return playerView;
}

- (void)awakeFromNib
{
    self.backgroundColor                 = [UIColor blackColor];
    // 设置快进快退label
    self.horizontalLabel.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Management_Mask"]];
}

- (void)dealloc
{
    //NSLog(@"%@释放了",self.class);
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 移除观察者
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self removeTableViewObserver];
}

/**
 *  重置player
 */
- (void)resetPlayer
{
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 移除观察者
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self removeTableViewObserver];
    // 关闭定时器
    [self.timer invalidate];
    // 暂停
    [self pause];
    // 移除原来的layer
    [self.playerLayer removeFromSuperlayer];
    // 替换PlayerItem
    [self.player replaceCurrentItemWithPlayerItem:nil];
    // 底部播放video改为NO
    self.isBottomVideo = NO;
    // 重置控制层View
    [self.controlView resetControlView];
    [self removeFromSuperview];
    // vicontroller中页面消失
    self.viewDisappear = YES;
    self.tableView = nil;
}

#pragma mark - 观察者、通知

/**
 *  添加观察者
 */
- (void)addObserverAndNotification {
    // AVPlayer播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // slider开始滑动事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    // slider滑动中事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    // slider结束滑动事件
    [self.controlView.videoSlider addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
    
    // 播放按钮点击事件
    [self.controlView.startBtn addTarget:self action:@selector(startAction:) forControlEvents:UIControlEventTouchUpInside];
    // cell上播放视频的话，该返回按钮为×
    if (self.isCellVideo) {
        [self.backBtn setImage:[UIImage imageNamed:@"kr-video-player-close"] forState:UIControlStateNormal];
    }else {
        [self.backBtn setImage:[UIImage imageNamed:@"play_back_full"] forState:UIControlStateNormal];
    }
    // 返回按钮点击事件
    [self.backBtn addTarget:self action:@selector(backButtonAction) forControlEvents:UIControlEventTouchUpInside];
    // 全屏按钮点击事件
    [self.controlView.fullScreenBtn addTarget:self action:@selector(fullScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    // 锁定屏幕方向点击事件
    [self.controlView.lockBtn addTarget:self action:@selector(lockScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    
    // 监听播放状态
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    // 监听loadedTimeRanges属性
    [self.player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    // Will warn you when your buffer is empty
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    // Will warn you when your buffer is good to go again.
    [self.player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
    // 添加Tableview观察者
    [self addTableViewObserver];
    // 监测设备方向
    [self listeningRotating];
}

/**
 *  添加Tableview观察者
 */
- (void)addTableViewObserver {
    if (self.tableView) {
        // 监听tab偏移量
        [self.tableView addObserver:self forKeyPath:kYTPlayerViewContentOffset options:NSKeyValueObservingOptionNew context:nil];
    }
}
/**
 *  移除TableView观察者
 */
- (void)removeTableViewObserver {
    if (self.tableView) {
        [self.tableView removeObserver:self forKeyPath:kYTPlayerViewContentOffset];
    }
}

/**
 *  监听设备旋转通知
 */
- (void)listeningRotating{
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil
     ];
    
}

#pragma mark - layoutSubviews

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;

    // 屏幕方向一发生变化就会调用这里
    [UIApplication sharedApplication].statusBarHidden = NO;
    self.isMaskShowing = NO;
    // 延迟隐藏controlView
    [self animateShow];
    
    // 解决4s，屏幕宽高比不是16：9的问题,player加到控制器上时候
    if (iPhone4s && !self.isCellVideo) {
        [self mas_updateConstraints:^(MASConstraintMaker *make) {
            CGFloat width = [UIScreen mainScreen].bounds.size.width;
            make.height.mas_equalTo(width*320/480);
        }];
    }
}

#pragma mark - 设置视频URL

/**
 *  用于cell上播放player
 *
 *  @param videoURL  视频的URL
 *  @param tableView tableView
 *  @param indexPath indexPath
 */
- (void)setVideoURL:(NSURL *)videoURL withTableView:(UITableView *)tableView AtIndexPath:(NSIndexPath *)indexPath
{
    // 在cell上播放视频
    self.isCellVideo = YES;
    self.tableView = tableView;
    self.indexPath = indexPath;
    [self setVideoURL:videoURL];
}

/**
 *  videoURL的setter方法
 *
 *  @param videoURL videoURL
 */
- (void)setVideoURL:(NSURL *)videoURL
{
    self.horizontalLabel.hidden = YES;//先隐藏
    // 每次播放视频都解锁屏幕锁定
    [self unLockTheScreen];
    self.state = YTPlayerStateStopped;
    
    // 如果页面没有消失过，并且playerItem有值
    if (!self.viewDisappear && self.playerItem) {
        [self resetPlayer];
    }
    self.viewDisappear = NO;
    
    // 初始化playerItem
    self.playerItem  = [AVPlayerItem playerItemWithURL:videoURL];
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    // 初始化playerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    if([self.playerLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]){
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }else{
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
    // 添加playerLayer到self.layer
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
    // 添加观察者、通知
    [self addObserverAndNotification];
    
    // 初始化显示controlView为YES
    self.isMaskShowing = YES;
    // 延迟隐藏controlView
    [self autoFadeOutControlBar];
    
    // 计时器
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(playerTimerAction) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    // 根据屏幕的方向设置相关UI
    [self onDeviceOrientationChange];
    
    // 添加手势
    [self createGesture];
    
    //获取系统音量
    [self configureVolume];
    
    // 本地文件不设置YTPlayerStateBuffering状态
    if ([videoURL.scheme isEqualToString:@"file"]) {
        self.state = YTPlayerStatePlaying;
        self.isLocalVideo = YES;
    } else {
        self.state = YTPlayerStateBuffering;
        self.isLocalVideo = NO;
    }
    
    // 开始播放
    [self play];
    self.controlView.startBtn.selected = YES;
    self.isPauseByUser = NO;
    [self.activity startAnimating];
    
}

//创建手势
- (void)createGesture
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    
    [self addGestureRecognizer:tap];
}

//获取系统音量
- (void)configureVolume
{
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    _volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    
    // 使用这个category的应用不会随着手机静音键打开而静音，可在手机静音下播放声音
    NSError *setCategoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance]
                    setCategory: AVAudioSessionCategoryPlayback
                    error: &setCategoryError];
    
    if (!success) { /* handle the error in setCategoryError */ }
}

#pragma mark - ShowOrHideControlView

- (void)autoFadeOutControlBar
{
    if (!self.isMaskShowing) {
        return;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControlView) object:nil];
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:YTPlayerAnimationTimeInterval];

}

/**
 *  取消延时隐藏controlView的方法
 */
- (void)cancelAutoFadeOutControlBar
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

/**
 *  隐藏控制层
 */
- (void)hideControlView
{
    if (!self.isMaskShowing) {
        return;
    }
    [UIView animateWithDuration:YTPlayerControlBarAutoFadeOutTimeInterval animations:^{
        self.controlView.alpha = 0;
        if (self.isCellVideo) {
            self.backBtn.alpha = 0;
        }
        if (self.isFullScreen) {
            self.backBtn.alpha  = 0;
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        }
    }completion:^(BOOL finished) {
        self.isMaskShowing = NO;
    }];
}

/**
 *  显示控制层
 */
- (void)animateShow
{
    if (self.isMaskShowing) {
        return;
    }
    [UIView animateWithDuration:YTPlayerControlBarAutoFadeOutTimeInterval animations:^{
        self.backBtn.alpha = 1;
        // 视频在bottom小屏,并且不是全屏状态
        if (self.isBottomVideo && !self.isFullScreen) {
            self.controlView.alpha = 0;
        }else {
            self.controlView.alpha = 1;
        }
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    } completion:^(BOOL finished) {
        self.isMaskShowing = YES;
        [self autoFadeOutControlBar];
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == self.playerItem) {
        if ([keyPath isEqualToString:@"status"]) {
            
            if (self.player.status == AVPlayerStatusReadyToPlay) {
                
                self.state = YTPlayerStatePlaying;
                // 加载完成后，再添加拖拽手势
                // 添加平移手势，用来控制音量、亮度、快进快退
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
                pan.delegate                = self;
                [self addGestureRecognizer:pan];
                
            } else if (self.player.status == AVPlayerStatusFailed){
                
                [self.activity startAnimating];
            }
            
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            
            NSTimeInterval timeInterval = [self availableDuration];// 计算缓冲进度
            CMTime duration             = self.playerItem.duration;
            CGFloat totalDuration       = CMTimeGetSeconds(duration);
            [self.controlView.progressView setProgress:timeInterval / totalDuration animated:NO];
            
        }else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            
            // 当缓冲是空的时候
            if (self.playerItem.playbackBufferEmpty) {
                //NSLog(@"playbackBufferEmpty");
                self.state = YTPlayerStateBuffering;
                [self bufferingSomeSecond];
            }
            
        }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            
            // 当缓冲好的时候
            if (self.playerItem.playbackLikelyToKeepUp){
                //NSLog(@"playbackLikelyToKeepUp");
                self.state = YTPlayerStatePlaying;
            }
            
        }
    }else if (object == self.tableView) {
        if ([keyPath isEqualToString:kYTPlayerViewContentOffset]) {
            if (([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft) || ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeRight)) { return; }
            // 当tableview滚动时处理playerView的位置
            [self handleScrollOffsetWithDict:change];
        }
    }
}

/**
 *  KVO TableviewContentOffset
 *
 *  @param dict void
 */
- (void)handleScrollOffsetWithDict:(NSDictionary*)dict
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.indexPath];
    NSArray *visableCells =self.tableView.visibleCells;
    if ([visableCells containsObject:cell]) {
        //在显示中
        [self updataPlayerViewToCell];
    }else {
        //在底部
        [self updataPlayerViewToBottom];
    }
}

/**
 *  缩小到底部，显示小视频
 */
- (void)updataPlayerViewToBottom
{
    if (self.isBottomVideo) {
        return ;
    }
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    // 解决4s，屏幕宽高比不是16：9的问题
    if (iPhone4s) {
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            CGFloat width = ScreenWidth*0.5-20;
            make.width.mas_equalTo(width);
            make.trailing.mas_equalTo(-10);
            make.bottom.mas_equalTo(-self.tableView.contentInset.bottom-10);
            make.height.mas_equalTo(width*320/480).with.priority(750);
        }];
    }else {
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            CGFloat width = ScreenWidth*0.5-20;
            make.width.mas_equalTo(width);
            make.trailing.mas_equalTo(-10);
            make.bottom.mas_equalTo(-self.tableView.contentInset.bottom-10);
            make.height.equalTo(self.mas_width).multipliedBy(9.0f/16.0f).with.priority(750);
        }];
    }
    self.isBottomVideo = YES;
    // 不显示控制层
    self.controlView.alpha = 0;
}

/**
 *  回到cell显示
 */
- (void)updataPlayerViewToCell
{
    if (!self.isBottomVideo) {
        return;
    }
    [self setOrientationPortrait];
    self.isBottomVideo = NO;
     // 显示控制层
    self.controlView.alpha = 1;
}

/**
 *  设置横屏的约束
 */
- (void)setOrientationLandscape
{
    if (self.tableView) {
        [self.backBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.mas_equalTo(15);
            make.width.height.mas_equalTo(30);
            make.top.mas_equalTo(20);
        }];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
        [[UIApplication sharedApplication].keyWindow addSubview:self];
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.insets(UIEdgeInsetsMake(0, 0, 0, 0));
        }];
    }
}

/**
 *  设置竖屏的约束
 */
- (void)setOrientationPortrait
{
    if (self.tableView) {
        [self.backBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.mas_equalTo(5);
            make.width.height.mas_equalTo(30);
            make.top.mas_equalTo(5);
        }];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        [self removeFromSuperview];
        UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:self.indexPath];
        NSArray *visableCells = [self.tableView visibleCells];
        if (![visableCells containsObject:cell]) {
            self.isBottomVideo = NO;
            [self updataPlayerViewToBottom];
        }else {
            [self addPlayerToCell:cell];
        }
    }
}

#pragma mark 屏幕转屏相关

/**
 *  强制屏幕转屏
 *
 *  @param orientation 屏幕方向
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation
{
    // arc下
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector             = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val                  = orientation;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
    
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        
        [self setOrientationLandscape];
    }else if (orientation == UIInterfaceOrientationPortrait) {
       
        [self setOrientationPortrait];
        
    }
    /*
     // 非arc下
     if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
     [[UIDevice currentDevice] performSelector:@selector(setOrientation:)
     withObject:@(orientation)];
     }
     
     // 直接调用这个方法通不过apple上架审核
     [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
     
     */
}

/**
 *  全屏按钮事件
 *
 *  @param sender 全屏Button
 */
- (void)fullScreenAction:(UIButton *)sender
{
    if (self.isLocked) {
        [self unLockTheScreen];
        return;
    }
    UIDeviceOrientation orientation             = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    switch (interfaceOrientation) {
            
        case UIInterfaceOrientationPortraitUpsideDown:{
            ApplicationDelegate.isAllowLandscape = NO;
            [self interfaceOrientation:UIInterfaceOrientationPortrait];
        }
            break;
        case UIInterfaceOrientationPortrait:{
            ApplicationDelegate.isAllowLandscape = YES;
            [self interfaceOrientation:UIInterfaceOrientationLandscapeRight];
        }
            break;
        case UIInterfaceOrientationLandscapeLeft:{
            ApplicationDelegate.isAllowLandscape = NO;
            [self interfaceOrientation:UIInterfaceOrientationPortrait];
        }
            break;
        case UIInterfaceOrientationLandscapeRight:{
            ApplicationDelegate.isAllowLandscape = NO;
            [self interfaceOrientation:UIInterfaceOrientationPortrait];
        }
            break;
            
        default:
            break;
    }
}

/**
 *  屏幕方向发生变化会调用这里
 */
- (void)onDeviceOrientationChange{
    if (self.isLocked) {
        self.isFullScreen = YES;
        return;
    }
    UIDeviceOrientation orientation             = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"kr-video-player-shrinkscreen"] forState:UIControlStateNormal];
            if (self.isCellVideo) {
                [self.backBtn setImage:[UIImage imageNamed:@"play_back_full"] forState:UIControlStateNormal];
            }
            self.isFullScreen = YES;
        }
            break;
        case UIInterfaceOrientationPortrait:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"kr-video-player-fullscreen"] forState:UIControlStateNormal];
            if (self.isCellVideo) {
                // 当设备转到竖屏时候，设置为竖屏约束
                [self setOrientationPortrait];
                // 改为只允许竖屏播放
                ApplicationDelegate.isAllowLandscape = NO;
                [self.backBtn setImage:[UIImage imageNamed:@"kr-video-player-close"] forState:UIControlStateNormal];
            }
            self.isFullScreen = NO;
        }
            break;
        case UIInterfaceOrientationLandscapeLeft:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"kr-video-player-shrinkscreen"] forState:UIControlStateNormal];
            if (self.isCellVideo) {
                [self.backBtn setImage:[UIImage imageNamed:@"play_back_full"] forState:UIControlStateNormal];
            }
            self.isFullScreen = YES;
        }
            break;
        case UIInterfaceOrientationLandscapeRight:{
            [self.controlView.fullScreenBtn setImage:[UIImage imageNamed:@"kr-video-player-shrinkscreen"] forState:UIControlStateNormal];
            if (self.isCellVideo) {
                [self.backBtn setImage:[UIImage imageNamed:@"play_back_full"] forState:UIControlStateNormal];
            }
            self.isFullScreen = YES;
        }
            break;
            
        default:
            break;
    }
    
}

/**
 *  锁定屏幕方向按钮
 *
 *  @param sender UIButton
 */
- (void)lockScreenAction:(UIButton *)sender
{
    sender.selected              = !sender.selected;
    self.isLocked                = sender.selected;
    // 调用AppDelegate单例记录播放状态是否锁屏，在TabBarController设置哪些页面支持旋转
    ApplicationDelegate.isLockScreen = sender.selected;
}

/**
 *  解锁屏幕方向锁定
 */
- (void)unLockTheScreen
{
    // 调用AppDelegate单例记录播放状态是否锁屏
    ApplicationDelegate.isLockScreen = NO;
    self.controlView.lockBtn.selected = NO;
    [self interfaceOrientation:UIInterfaceOrientationPortrait];
}

/**
 *  player添加到cell上
 *
 *  @param cell 添加player的cell
 */
- (void)addPlayerToCell:(UITableViewCell *)cell
{
    [cell addSubview:self];
    [self mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.trailing.leading.mas_equalTo(0);
        make.height.mas_equalTo(ScreenWidth*9/16);
    }];
    
}

#pragma mark - 缓冲较差时候

/**
 *  缓冲较差时候回调这里
 */
- (void)bufferingSomeSecond
{
    [self.activity startAnimating];
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (self.isPauseByUser) {
            isBuffering = NO;
            return;
        }
        
        [self play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        isBuffering = NO;
        if (!self.playerItem.isPlaybackLikelyToKeepUp) {
            [self bufferingSomeSecond];
        }
    });
}

#pragma mark - 计时器事件
/**
 *  计时器事件
 */
- (void)playerTimerAction
{
    if (_playerItem.duration.timescale != 0) {
        self.controlView.videoSlider.maximumValue = 1;//音乐总共时长
        self.controlView.videoSlider.value        = CMTimeGetSeconds([_playerItem currentTime]) / (_playerItem.duration.value / _playerItem.duration.timescale);//当前进度

        //当前时长进度progress
        NSInteger proMin                       = (NSInteger)CMTimeGetSeconds([_player currentTime]) / 60;//当前秒
        NSInteger proSec                       = (NSInteger)CMTimeGetSeconds([_player currentTime]) % 60;//当前分钟

        //duration 总时长
        NSInteger durMin                       = (NSInteger)_playerItem.duration.value / _playerItem.duration.timescale / 60;//总秒
        NSInteger durSec                       = (NSInteger)_playerItem.duration.value / _playerItem.duration.timescale % 60;//总分钟

        self.controlView.currentTimeLabel.text    = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        self.controlView.totalTimeLabel.text      = [NSString stringWithFormat:@"%02zd:%02zd", durMin, durSec];
    }
}

/**
 *  计算缓冲进度
 *
 *  @return 缓冲进度
 */
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

#pragma mark - slider事件

/**
 *  slider开始滑动事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderTouchBegan:(UISlider *)slider
{
    [self cancelAutoFadeOutControlBar];
    // 暂停timer
    [self.timer setFireDate:[NSDate distantFuture]];
}

/**
 *  slider滑动中事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderValueChanged:(UISlider *)slider
{
    NSString *style = @"";
    CGFloat value = slider.value - self.sliderLastValue;
    if (value > 0) {
        style = @">>";
    } else if (value < 0) {
        style = @"<<";
    }
     self.sliderLastValue = slider.value;
    //拖动改变视频播放进度
    if (self.player.status == AVPlayerStatusReadyToPlay) {
        
        [self pause];
        //计算出拖动的当前秒数
        CGFloat total                       = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;

        NSInteger dragedSeconds             = floorf(total * slider.value);

        //转换成CMTime才能给player来控制播放进度

        CMTime dragedCMTime                 = CMTimeMake(dragedSeconds, 1);
        // 拖拽的时长
        NSInteger proMin                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) / 60;//当前秒
        NSInteger proSec                    = (NSInteger)CMTimeGetSeconds(dragedCMTime) % 60;//当前分钟

        //duration 总时长
        NSInteger durMin                    = (NSInteger)total / 60;//总秒
        NSInteger durSec                    = (NSInteger)total % 60;//总分钟

        NSString *currentTime               = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        NSString *totalTime                 = [NSString stringWithFormat:@"%02zd:%02zd", durMin, durSec];

        self.controlView.currentTimeLabel.text = currentTime;
        self.horizontalLabel.hidden         = NO;
        self.horizontalLabel.text           = [NSString stringWithFormat:@"%@ %@ / %@",style, currentTime, totalTime];
        
    }
}

/**
 *  slider结束滑动事件
 *
 *  @param slider UISlider
 */
- (void)progressSliderTouchEnded:(UISlider *)slider
{
    // 继续开启timer
    [self.timer setFireDate:[NSDate date]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.horizontalLabel.hidden = YES;
    });
    // 结束滑动时候把开始播放按钮改为播放状态
    self.controlView.startBtn.selected = YES;
    self.isPauseByUser              = NO;
    
    // 滑动结束延时隐藏controlView
    [self autoFadeOutControlBar];
    
    //计算出拖动的当前秒数
    CGFloat total           = (CGFloat)_playerItem.duration.value / _playerItem.duration.timescale;

    NSInteger dragedSeconds = floorf(total * slider.value);

    //转换成CMTime才能给player来控制播放进度

    CMTime dragedCMTime     = CMTimeMake(dragedSeconds, 1);
    
    [self endSlideTheVideo:dragedCMTime];
}

/**
 *  滑动结束视频跳转
 *
 *  @param dragedCMTime 视频跳转的CMTime
 */
- (void)endSlideTheVideo:(CMTime)dragedCMTime
{
    //[_player pause];
    [self.player seekToTime:dragedCMTime completionHandler:^(BOOL finish){
        // 如果点击了暂停按钮
        if (self.isPauseByUser) {
            //NSLog(@"已暂停");
            return ;
        }
        [self play];
        if (!self.playerItem.isPlaybackLikelyToKeepUp && !self.isLocalVideo) {
            self.state = YTPlayerStateBuffering;
            //NSLog(@"显示菊花");
            [self.activity startAnimating];
        }
    }];
}

#pragma mark - Action

/**
 *   轻拍方法
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)tapAction:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        if (self.isBottomVideo && !self.isFullScreen) {
            [self fullScreenAction:self.controlView.fullScreenBtn];
            return;
        }
        if (self.isMaskShowing) {
            [self hideControlView];
        } else {
            [self animateShow];
        }
    }
}

/**
 *  播放、暂停
 *
 *  @param button UIButton
 */
- (void)startAction:(UIButton *)button
{
    button.selected = !button.selected;
    self.isPauseByUser = !button.isSelected;
    if (button.selected) {
        [self play];
        self.state = YTPlayerStatePlaying;
    } else {
        [self pause];
        self.state = YTPlayerStatePause;
    }
}
/**
 *  播放
 */
- (void)play
{
    [_player play];
}

/**
 * 暂停
 */
- (void)pause
{
    [_player pause];
}

/**
 *  返回按钮事件
 */
- (void)backButtonAction
{
    if (self.isLocked) {
        [self unLockTheScreen];
        return;
    }else {
        if (!self.isFullScreen) {
            // 在cell上播放视频
            if (self.isCellVideo) {
                // 关闭player
                [self resetPlayer];
                [self removeFromSuperview];
                return;
            }
            // player加到控制器上，只有一个player时候
            [self.timer invalidate];
            [self pause];
            if (self.goBackBlock) {
                self.goBackBlock();
            }
        }else {
            [self interfaceOrientation:UIInterfaceOrientationPortrait];
        }
    }
}

#pragma mark - NSNotification Action

/**
 *  播放完了
 *
 *  @param notification 通知
 */
- (void)moviePlayDidEnd:(NSNotification *)notification
{
    self.state = YTPlayerStateStopped;
    ApplicationDelegate.isLockScreen = NO;
    [self interfaceOrientation:UIInterfaceOrientationPortrait];
    // 关闭定时器
    [self.timer invalidate];
    // 重置Player
    [self resetPlayer];
    if (self.goBackBlock) {
        self.goBackBlock();
    }
}

/**
 *  应用退到后台
 */
- (void)appDidEnterBackground
{
    [self pause];
    self.state = YTPlayerStatePause;
    [self cancelAutoFadeOutControlBar];
}

/**
 *  应用进入前台
 */
- (void)appDidEnterPlayGround
{
    self.isMaskShowing = NO;
    // 延迟隐藏controlView
    [self animateShow];
    if (!self.isPauseByUser) {
        self.state                      = YTPlayerStatePlaying;
        self.controlView.startBtn.selected = YES;
        self.isPauseByUser              = NO;
        [self play];
    }
}

#pragma mark - UIPanGestureRecognizer手势方法

/**
 *  pan手势事件
 *
 *  @param pan UIPanGestureRecognizer
 */
- (void)panDirection:(UIPanGestureRecognizer *)pan
{
    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [pan locationInView:self];
    
    // 我们要响应水平移动和垂直移动
    // 根据上次和本次移动的位置，算出一个速率的point
    CGPoint veloctyPoint = [pan velocityInView:self];
    
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                self.panDirection           = PanDirectionHorizontalMoved;
                // 取消隐藏
                self.horizontalLabel.hidden = NO;
                // 给sumTime初值
                CMTime time                 = self.player.currentTime;
                self.sumTime                = time.value/time.timescale;
                
                // 暂停视频播放
                [self pause];
                // 暂停timer
                [self.timer setFireDate:[NSDate distantFuture]];
            }
            else if (x < y){ // 垂直移动
                self.panDirection = PanDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isVolume = NO;
                }
                
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    
                    // 继续播放
                    [self play];
                    [self.timer setFireDate:[NSDate date]];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 隐藏视图
                        self.horizontalLabel.hidden = YES;
                    });
                    //快进、快退时候把开始播放按钮改为播放状态
                    self.controlView.startBtn.selected = YES;
                    self.isPauseByUser              = NO;

                    // 转换成CMTime才能给player来控制播放进度
                    CMTime dragedCMTime             = CMTimeMake(self.sumTime, 1);
                    //[_player pause];
                    
                    [self endSlideTheVideo:dragedCMTime];

                    // 把sumTime滞空，不然会越加越多
                    self.sumTime = 0;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    // 垂直移动结束后，把状态改为不再控制音量
                    self.isVolume = NO;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.horizontalLabel.hidden = YES;
                    });
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

/**
 *  pan垂直移动的方法
 *
 *  @param value void
 */
- (void)verticalMoved:(CGFloat)value
{
    if (self.isVolume) {
        // 更改系统的音量
        self.volumeViewSlider.value      -= value / 10000;// 越小幅度越小
    }else {
        //亮度
        [UIScreen mainScreen].brightness -= value / 10000;
        //NSString *brightness             = [NSString stringWithFormat:@"亮度%.0f%%",[UIScreen mainScreen].brightness/1.0*100];
        //self.horizontalLabel.hidden      = NO;
        //self.horizontalLabel.text        = brightness;
    }
}


/**
 *  pan水平移动的方法
 *
 *  @param value void
 */
- (void)horizontalMoved:(CGFloat)value
{
    // 快进快退的方法
    NSString *style = @"";
    if (value < 0) {
        style = @"<<";
    }
    else if (value > 0){
        style = @">>";
    }
    
    // 每次滑动需要叠加时间
    self.sumTime += value / 200;
    
    // 需要限定sumTime的范围
    CMTime totalTime           = self.playerItem.duration;
    CGFloat totalMovieDuration = (CGFloat)totalTime.value/totalTime.timescale;
    if (self.sumTime > totalMovieDuration) {
        self.sumTime = totalMovieDuration;
    }else if (self.sumTime < 0){
        self.sumTime = 0;
    }
    
    // 当前快进的时间
    NSString *nowTime         = [self durationStringWithTime:(int)self.sumTime];
    // 总时间
    NSString *durationTime    = [self durationStringWithTime:(int)totalMovieDuration];
    // 给label赋值
    self.horizontalLabel.text = [NSString stringWithFormat:@"%@ %@ / %@",style, nowTime, durationTime];
}

/**
 *  根据时长求出字符串
 *
 *  @param time 时长
 *
 *  @return 时长字符串
 */
- (NSString *)durationStringWithTime:(int)time
{
    // 获取分钟
    NSString *min = [NSString stringWithFormat:@"%02d",time / 60];
    // 获取秒数
    NSString *sec = [NSString stringWithFormat:@"%02d",time % 60];
    return [NSString stringWithFormat:@"%@:%@", min, sec];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    CGPoint point = [touch locationInView:self.controlView];
    // 屏幕下方slider区域不响应pan手势
    if ((point.y > self.bounds.size.height-40)) {
        return NO;
    }
    return YES;
}

#pragma mark - Setter 

/**
 *  设置播放的状态
 *
 *  @param state YTPlayerState
 */
- (void)setState:(YTPlayerState)state
{
    _state = state;
    if (state != YTPlayerStateBuffering) {
        [self.activity stopAnimating];
    }
}

#pragma mark - Getter

/**
 *  懒加载Player
 *
 *  @return AVPlayer
 */
- (AVPlayer *)player
{
    if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:self.playerItem];
        
    }
    return _player;
}

/**
 * 懒加载 控制层View
 *
 *  @return YTPlayerControlView
 */
- (YTPlayerControlView *)controlView
{
    if (!_controlView) {
        _controlView = [YTPlayerControlView setupPlayerControlView];
        [self insertSubview:self.controlView belowSubview:self.backBtn];
        
        [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.insets(UIEdgeInsetsMake(0, 0, 0, 0));
        }];
    }
    return _controlView;
}


@end
