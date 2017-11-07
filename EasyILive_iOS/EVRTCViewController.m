//
//  EVRTCViewController.m
//  EVSDKDemo
//
//  Created by Lcrnice on 2017/7/11.
//  Copyright © 2017年 cloudfocous. All rights reserved.
//

#import "EVRTCViewController.h"
#import "VideoSession.h"
#import "EVGenerateQRViewController.h"
#import "CCAlertManager.h"
#import "EVScreenManager.h"
//#import "EVPlayer.h"
#import <EVMediaFramework/EVPlayer.h>
#import <EVRTCFramework/EVRTCVideoRegion.h>
#import <EVRTCFramework/EVRTCKit.h>
#import "EVShareViewController.h"

#define kScreenWidth    [UIScreen mainScreen].bounds.size.width
#define kScreenHeight   [UIScreen mainScreen].bounds.size.height

@interface EVRTCViewController () <EVRTCDelegate, EVPlayerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *remoteContainerView;
@property (weak, nonatomic) IBOutlet UIButton *closeBtn;
@property (weak, nonatomic) IBOutlet UIButton *muteBtn;
@property (weak, nonatomic) IBOutlet UIButton *cameraBtn;
@property (weak, nonatomic) IBOutlet UIButton *switchModeBtn;
@property (weak, nonatomic) IBOutlet UIButton *localVideoBtn;
@property (weak, nonatomic) IBOutlet UIButton *shareBtn;

@property (strong, nonatomic) EVRTCKit *rtcKit;
@property (strong, nonatomic) NSMutableArray<VideoSession *> *videoSessions;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *mutedAudioUsers;
@property (strong, nonatomic) EVPlayer *player;
@property (strong, nonatomic) UIView *muteVideoView;
@property (strong, nonatomic) UIImageView *muteVideoIV;
@property (strong, nonatomic) VideoSession *fullSession;

@end

@implementation EVRTCViewController {
    NSUInteger _currentUid;
    NSString *_currentChannel;
    BOOL _connected;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.titleLabel.text = self.roomName;
    _currentChannel = self.roomName;
    
    if (self.role == EVRtc_ClientRole_Guest) {
        self.switchModeBtn.hidden = NO;
    }
    
    [self setupRTC];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (IBAction)close:(id)sender {
    if (_connected) {
        [[CCAlertManager shareInstance] performComfirmTitle:@"提示" message:@"是否确认退出连麦？" cancelButtonTitle:@"不了" comfirmTitle:@"是的" WithComfirm:^{
            [self leaveChannel];
            [self popVC];
        } cancel:nil];
    } else {
        if (self.role == EVRtc_ClientRole_Guest) {
            [self.player shutDown];
            _player = nil;
        } else {
            [self leaveChannel];
        }
        
        [self popVC];
    }
}
- (void)leaveChannel {
    [self.rtcKit leaveChannel];
    _rtcKit = nil;
}

- (void)popVC {
    [self _rorateScreen:UIDeviceOrientationPortrait];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)tapGenerateQR:(id)sender {
    if (self.roomName) {
        EVGenerateQRViewController *QRVC = [EVGenerateQRViewController new];
        QRVC.infoString = _currentChannel;
        [self presentViewController:QRVC animated:YES completion:nil];
    }
}

- (IBAction)doDoubleTaped:(UITapGestureRecognizer *)sender {
    CGPoint location = [sender locationInView:self.remoteContainerView];
    
    VideoSession *targetSession;
    for (VideoSession *session in self.videoSessions) {
        CGRect rect = session.hostingView.frame;
        if (CGRectContainsPoint(rect, location)) {
            targetSession = session;
        }
    }
    
    if (self.fullSession && self.fullSession != targetSession) {
        [self.rtcKit configRemoteVideoStream:self.fullSession.uid type:EVRtc_VideoStream_Low];
    }
    
    self.fullSession = targetSession;
}

- (IBAction)cleanScreen:(id)sender {
    self.closeBtn.hidden =
    self.titleLabel.hidden =
    self.cameraBtn.hidden =
    self.muteBtn.hidden =
    self.localVideoBtn.hidden =
    self.shareBtn.hidden =
    !self.muteBtn.hidden;
    if (self.role == EVRtc_ClientRole_Guest) {
        self.switchModeBtn.hidden = self.muteBtn.hidden;
    }
}


- (IBAction)mute:(UIButton *)sender {
    int result = [self.rtcKit muteLocalAudioStream:!sender.selected];
    if (result == 0) {
        sender.selected = !sender.selected;
        
        VideoSession *session = [self fetchSessionOfUid:_currentUid];
        [session mutedAudio:sender.selected];
    }
}

- (IBAction)localVideo:(UIButton *)sender {
    int result = [self.rtcKit muteLocalVideoStream:!sender.selected];
    if (result == 0) {
        sender.selected = !sender.selected;
        self.cameraBtn.enabled = !sender.selected;
        
        [self updateInterface];
    }
}

- (IBAction)switchCamera:(UIButton *)sender {
    int result = [self.rtcKit switchCamera];
    if (result == 0) {
        sender.selected = !sender.selected;
    }
}

- (IBAction)switchMode:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    [self _muteAndCameraEnable:sender.selected];
    [self.remoteContainerView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    
    if (sender.selected) {
        self.muteBtn.selected = NO;
        self.localVideoBtn.selected = NO;
        [self.player shutDown];
        _player = nil;
        self.role = EVRtc_ClientRole_LiveGuest;
    } else {
        [self leaveChannel];
        self.role = EVRtc_ClientRole_Guest;
        _connected = NO;
    }
    
    [self setupRTC];
}

- (IBAction)share:(UIButton *)sender {
    UIActivityIndicatorView *hud = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    hud.center = self.remoteContainerView.center;
    [hud startAnimating];
    [self.remoteContainerView addSubview:hud];
    
    [self.rtcKit fetchShareURLWithChannel:_currentChannel callback:^(EVRtcResponseCode code, NSDictionary *info, NSError *error) {
        [hud stopAnimating];
        [hud removeFromSuperview];
        
        if (code == EVRtcResponseCode_None) {
            NSString *url = info[NSLocalizedDescriptionKey];
            EVShareViewController *shareVC = [EVShareViewController instanceVC];
            shareVC.urlString = url;
            [shareVC showInViewController:self];
        } else {
            [self alertString:[NSString stringWithFormat:@"获取分享地址失败，请稍后再试:\n%@", error.localizedDescription]];
        }
    }];
}

- (void)_muteAndCameraEnable:(BOOL)enable {
    self.muteBtn.enabled =
    self.cameraBtn.enabled =
    self.localVideoBtn.enabled =
    enable;
}

#pragma mark - helper

- (VideoSession *)fetchSessionOfUid:(NSUInteger)uid {
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            return session;
        }
    }
    return nil;
}

- (VideoSession *)videoSessionOfUid:(NSUInteger)uid {
    VideoSession *fetchedSession = [self fetchSessionOfUid:uid];
    if (fetchedSession) {
        return fetchedSession;
    } else {
        VideoSession *newSession = [[VideoSession alloc] initWithUID:uid];
        if ((uid == self.rtcKit.masterUid) ||
            (self.role == EVRtc_ClientRole_Master && uid == 0)) {
            newSession.isMaster = YES;
        } 
        [self.rtcKit configCanvasWithView:newSession.hostingView uid:newSession.uid mode:EVRtc_Render_Fit];
        [self.videoSessions addObject:newSession];
        [self updateInterface];
        return newSession;
    }
}

- (void)setIdleTimerActive:(BOOL)active {
    [UIApplication sharedApplication].idleTimerDisabled = !active;
}

- (void)alertString:(NSString *)string {
    if (!string.length) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:string preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)hudString:(NSString *)string {
    if (!string.length) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:string preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:true completion:nil];
    });
}

- (void)showLocalMuteImage:(BOOL)YorN view:(UIView *)view {
    if (YorN) {
        self.muteVideoView.frame = CGRectMake(0, 0, CGRectGetWidth(view.frame), CGRectGetHeight(view.frame));
        self.muteVideoIV.center = self.muteVideoView.center;
        [view addSubview:self.muteVideoView];
    } else {
        if ([view.subviews containsObject:self.muteVideoView]) {
            [self.muteVideoView removeFromSuperview];
        }
    }
}

- (void)handleMutedAudioUsersWithMuted:(BOOL)muted uid:(NSUInteger)uid {
    NSNumber *muteUser = @(uid);
    if (muted) {
        if (NO == [self.mutedAudioUsers containsObject:muteUser]) {
            [self.mutedAudioUsers addObject:muteUser];
        }
    } else {
        if ([self.mutedAudioUsers containsObject:muteUser]) {
            [self.mutedAudioUsers removeObject:muteUser];
        }
    }
}

- (void)checkMutedWithUid:(NSUInteger)uid {
    NSNumber *newUser = @(uid);
    if ([self.mutedAudioUsers containsObject:newUser]) {
        VideoSession *session = [self fetchSessionOfUid:uid];
        [session mutedAudio:YES];
    }
}

- (void)updateInterface {
    //  此处只需要对已有视频视图(videoSession.hostingView)进行布局，对其建立对应的约束或setFrame，并将其添加到 self.remoteContainerView 上即可。
    [self relayoutOtherVideoViews];
}

- (void)relayoutOtherVideoViews{
    // 每一列最大个数
    __block NSInteger maxVerticalCount = 3;
    // 视图间隔
    __block CGFloat kMargin = 10;
    
    CGFloat h = (kScreenHeight - (maxVerticalCount - 1) * kMargin) / maxVerticalCount;
    __block CGFloat vW = h*(16.0/9.0);
    __block CGFloat vH = h;
    
    [self.videoSessions enumerateObjectsUsingBlock:^(VideoSession * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0) {
            [obj updateHostingViewFrame:[UIScreen mainScreen].bounds];
        }
        else {
            NSInteger column = ((idx - 1) / maxVerticalCount);
            CGFloat x = kScreenWidth - (vW * (column + 1)) - (kMargin * column);
            NSInteger row = (idx - 1) % maxVerticalCount;
            CGFloat y = row * (vH + kMargin);
            [obj updateHostingViewFrame:CGRectMake(x, y, vW, vH)];
        }
        
        if (obj.isLocal) {
            [self showLocalMuteImage:self.localVideoBtn.selected view:obj.hostingView];
        }
        
        if (obj.hostingView.superview == nil) {
            [self.remoteContainerView addSubview:obj.hostingView];
        }
        
        if (self.fullSession.uid == obj.uid && [self.remoteContainerView.subviews containsObject:obj.hostingView]) {
            [self.remoteContainerView sendSubviewToBack:obj.hostingView];
        }
    }];
    
    
    // !!!:调用 -updatePublisherFrame 方法，即可保持主播本地预览和旁路推流布局一致
    //    [self updatePublisherFrame];
}

- (void)updatePublisherFrame {
    NSLog(@"current user isMaster:%@, masterUid:%lu", @(self.rtcKit.isMaster), (unsigned long)self.rtcKit.masterUid);
    
    // 只有频道主播才有权限更改旁路推流布局
    if (self.rtcKit.isMaster) {
        NSMutableArray *tempArray = @[].mutableCopy;
        
        [self.videoSessions enumerateObjectsUsingBlock:^(VideoSession * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            EVRTCVideoRegion *region = [EVRTCVideoRegion new];
            region.renderMode = EVRtc_Render_Fit;
            region.zOrder = idx;
            region.uid = obj.uid != 0 ? obj.uid : _currentUid;
            
            // x、y、width、height 取值范围均为 [0, 1]
            region.x = obj.hostingView.frame.origin.x / kScreenWidth;
            region.y = obj.hostingView.frame.origin.y / kScreenHeight;
            region.width = CGRectGetWidth(obj.hostingView.frame) / kScreenWidth;
            region.height = CGRectGetHeight(obj.hostingView.frame) / kScreenHeight;
            
            [tempArray addObject:region];
        }];
        
        
        [self.rtcKit configVideoRegion:tempArray];
    }
}

- (void)_rorateScreen:(UIDeviceOrientation)orientation {
    [[EVScreenManager share] setDeviceOrientationTo:orientation];
}

#pragma mark - setup
- (void)setupRTC {
    [self _rorateScreen:UIDeviceOrientationLandscapeLeft];
    
    self.videoSessions = [[NSMutableArray alloc] init];
    
    self.rtcKit = [[EVRTCKit alloc] initWithRTCID:@"2f1df58774d4445bb36942b954c40dfd"];
    self.rtcKit.delegate = self;
    self.rtcKit.profile = self.profile;
    
    __weak typeof(self) wSelf = self;
    
    [self videoSessionOfUid:0];
    
    if (self.role == EVRtc_ClientRole_Master) {
        NSLog(@"主播身份开播");
        [self.rtcKit createAndJoinChannel:self.roomName uid:self.uidString.integerValue hasPublisher:YES record:YES callback:^(EVRtcResponseCode code, NSDictionary *info, NSError *error) {
            if (code == EVRtcResponseCode_None) {
                [wSelf setIdleTimerActive:NO];
            } else {
                [wSelf.videoSessions removeAllObjects];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self alertString:[NSString stringWithFormat:@"Create channel failed: %@", error]];
                });
            }
        }];
    } else if (self.role == EVRtc_ClientRole_LiveGuest) {
        NSLog(@"连麦观众身份开播");
        [self.rtcKit joinChannel:self.roomName uid:self.uidString.integerValue callback:^(EVRtcResponseCode code, NSDictionary *info, NSError *error) {
            if (code == EVRtcResponseCode_None) {
                [wSelf setIdleTimerActive:NO];
            } else {
                [wSelf.videoSessions removeAllObjects];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self alertString:[NSString stringWithFormat:@"Join channel failed: %@", error]];
                });
            }
        }];
    } else if (self.role == EVRtc_ClientRole_Guest) {
        NSLog(@"观看者身份");
        [self _muteAndCameraEnable:NO];
        
        [self.rtcKit watchLiveWithChannel:self.roomName callback:^(EVRtcResponseCode code, NSDictionary *info, NSError *error) {
            if (code == EVRtcResponseCode_None) {
                NSString *url = info[NSLocalizedDescriptionKey];
                NSLog(@"播放地址信息:%@", url);
                [self setupPlayer:url];
            } else {
                [self alertString:error.description];
            }
        }];
    }
}

- (void)setupPlayer:(NSString *)url {
    self.player = [[EVPlayer alloc] init];
    self.player.playerContainerView = self.remoteContainerView;
    self.player.live = YES;
    self.player.playURLString = url;
    self.player.delegate = self;
    
    __weak typeof(self) wSelf = self;
    [self.player playPrepareComplete:^(EVPlayerResponseCode responseCode, NSDictionary *result, NSError *err) {
        __strong typeof(wSelf) sSelf = wSelf;
        if (responseCode == EVPlayerResponse_Okay) {
            [sSelf.player play];
        }
    }];
}

#pragma mark - EVRTCDelegate

- (void)evRTCKit:(EVRTCKit *)kit didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    _currentUid = uid;
    _currentChannel = channel;
    self.titleLabel.text = [NSString stringWithFormat:@"点击[ %@ ]显示二维码", channel];
    _connected = YES;
    VideoSession *localSession = [self fetchSessionOfUid:0];
    if (localSession) {
        localSession.uid = uid;
        [localSession updateHostingViewFrame:localSession.hostingView.frame];
    } 
    NSLog(@"did join channel:%@ uid:%lu", channel, (unsigned long)uid);
    
    NSString *role;
    switch (self.role) {
        case EVRtc_ClientRole_Master: {
            role = @"主播";
            break;
        }
        case EVRtc_ClientRole_LiveGuest: {
            role = @"连麦观众";
            break;
        }
        case EVRtc_ClientRole_Guest: {
            role = @"观众";
            break;
        }
            
        default:
            break;
    }
    
    [[CCAlertManager shareInstance] performComfirmTitle:@"已加入频道" message:[NSString stringWithFormat:@"\n身份：%@\nuid:%lu", role, (unsigned long)uid] comfirmTitle:@"OK" WithComfirm:nil];
}

- (void)evRTCKit:(EVRTCKit *)kit firstRemoteVideoDecodedOfUid:(NSUInteger)uid size:(CGSize)size elapsed:(NSInteger)elapsed {
    
    [self videoSessionOfUid:uid];
    [self checkMutedWithUid:uid];
}

- (void)evRTCKit:(EVRTCKit *)kit firstLocalVideoFrameWithSize:(CGSize)size elapsed:(NSInteger)elapsed {
    if (self.videoSessions.count) {
        [self updateInterface];
    }
}

- (void)evRTCKit:(EVRTCKit *)kit didAudioMuted:(BOOL)muted byUid:(NSUInteger)uid {
    VideoSession *session = [self fetchSessionOfUid:uid];
    [session mutedAudio:muted];
    
    [self handleMutedAudioUsersWithMuted:muted uid:uid];
    
    NSString *msg;
    
    if (muted) {
        msg = [NSString stringWithFormat:@"用户:%lu\n设置静音", (unsigned long)uid];
    } else {
        msg = [NSString stringWithFormat:@"用户:%lu\n取消静音", (unsigned long)uid];
    }
    
    [self hudString:msg];
}

- (void)evRTCKit:(EVRTCKit *)kit didVideoMuted:(BOOL)muted byUid:(NSUInteger)uid {
    NSString *msg;
    
    if (muted) {
        msg = [NSString stringWithFormat:@"用户:%lu\n暂停传输视频数据", (unsigned long)uid];
    } else {
        msg = [NSString stringWithFormat:@"用户:%lu\n回来了", (unsigned long)uid];
    }
    
    [self hudString:msg];
}

- (void)evRTCKitConnectionDidInterrupted:(EVRTCKit *)kit {
    [self hudString:@"连接中断..."];
}

- (void)evRTCKitConnectionDidLost:(EVRTCKit *)kit {
    [self hudString:@"连接已丢失！"];
}

- (void)evRTCKit:(EVRTCKit *)kit didOfflineOfUid:(NSUInteger)uid reason:(EVRtcOfflineReason)reason {
    VideoSession *deleteSession;
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            deleteSession = session;
        }
    }
    
    if (deleteSession) {
        [self.videoSessions removeObject:deleteSession];
        [deleteSession.hostingView removeFromSuperview];
        [self updateInterface];
        
        if (deleteSession == self.fullSession) {
            self.fullSession = [self fetchSessionOfUid:0];
        }
    }
}

- (void)evRTCKit:(EVRTCKit *)kit didOccurErrorWithCode:(NSInteger)errorCode {
    _connected = NO;
    if (errorCode == EVRtcResponseCode_MasterExit) {
        [[CCAlertManager shareInstance] performComfirmTitle:@"当前频道主播关闭了连麦" message:nil comfirmTitle:@"OK" WithComfirm:^{
            [self leaveChannel];
            [self popVC];
        }];
    } else if (errorCode == 18) {
        [self alertString:@"离开频道操作被拒绝"];
    } else {
        [self alertString:[NSString stringWithFormat:@"did occur error with code:%ld", (long)errorCode]];
    }
}


#pragma mark - EVPlayerDelegate
- (void)EVPlayerDidFinishPlay:(EVPlayer *)player reason:(MPMovieFinishReason)reason {
    [[CCAlertManager shareInstance] performComfirmTitle:nil message:@"视频结束." comfirmTitle:@"OK" WithComfirm:^{
        [self popVC];
    }];
}

#pragma mark - setters/getters

- (void)setVideoSessions:(NSMutableArray<VideoSession *> *)videoSessions {
    _videoSessions = videoSessions;
    if (self.remoteContainerView) {
        [self updateInterface];
    }
}

- (void)setFullSession:(VideoSession *)fullSession {
    _fullSession = fullSession;
    
    if (self.videoSessions.count > 0) {
        NSInteger fullSessionIdx = [self.videoSessions indexOfObject:fullSession];
        VideoSession *firstSession = [self.videoSessions firstObject];
        [self.videoSessions replaceObjectAtIndex:fullSessionIdx withObject:firstSession];
        [self.videoSessions replaceObjectAtIndex:0 withObject:fullSession];
    }
    
    if (fullSession.isLocal == NO) {
        [self.rtcKit configRemoteVideoStream:fullSession.uid type:EVRtc_VideoStream_High];
    }
    
    if (self.remoteContainerView) {
        [self updateInterface];
    }
}

- (UIView *)muteVideoView {
    if (!_muteVideoView) {
        _muteVideoView = [UIView new];
        _muteVideoView.backgroundColor = [UIColor whiteColor];
        [_muteVideoView addSubview:self.muteVideoIV];
    }
    return _muteVideoView;
}

- (UIImageView *)muteVideoIV {
    if (!_muteVideoIV) {
        _muteVideoIV = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"btn_join_cancel"]];
        _muteVideoIV.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _muteVideoIV;
}

- (NSMutableArray *)mutedAudioUsers {
    if (!_mutedAudioUsers) {
        _mutedAudioUsers = @[].mutableCopy;
    }
    return _mutedAudioUsers;
}

@end
