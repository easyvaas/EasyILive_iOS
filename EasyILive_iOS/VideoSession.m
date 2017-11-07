//
//  VideoSession.m
//  EVSDKDemo
//
//  Created by Lcrnice on 2017/7/12.
//  Copyright © 2017年 cloudfocous. All rights reserved.
//

#import "VideoSession.h"

static CGFloat const kMuteBtnSize = 20;

@interface VideoSession ()

@property (strong, nonatomic) UILabel *uidLabel;
@property (nonatomic, strong) UIButton *audioMuteBtn;

@end

@implementation VideoSession 

- (instancetype)initWithUID:(NSUInteger)uid {
    if (self = [super init]) {
        _uid = uid;
        
        if (uid == 0) {
            _isLocal = YES;
        }
        
        _hostingView = [[UIView alloc] init];
        _hostingView.translatesAutoresizingMaskIntoConstraints = NO;
        _hostingView.backgroundColor = [UIColor lightGrayColor];
        
        [_hostingView addSubview:({
            UILabel *label = [UILabel new];
            label.font = [UIFont systemFontOfSize:12];
            label.textColor = [UIColor blackColor];
            label.layer.zPosition = FLT_MAX;
            _uidLabel = label;
            
            label;
        })];
        
        [_hostingView addSubview:({
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setImage:[UIImage imageNamed:@"btn_mute"] forState:UIControlStateNormal];
            [btn setImage:[UIImage imageNamed:@"btn_mute_cancel"] forState:UIControlStateSelected];
            btn.layer.zPosition = FLT_MAX - 1;
            btn.userInteractionEnabled = false;
            _audioMuteBtn = btn;
            
            btn;
        })];
    }
    
    return self;
}

- (void)updateHostingViewFrame:(CGRect)frame {
    self.hostingView.frame = frame;
    
    BOOL smallDevice = NO;
    if (MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) == 320) {
        smallDevice = YES;
    }
    
    if (smallDevice) {
        _uidLabel.font = [UIFont systemFontOfSize:10];
    }
    _uidLabel.text = [NSString stringWithFormat:@"uid:%lu role:%@", (unsigned long)_uid, _isMaster ? @"主播" : @"连麦观众"];
    [_uidLabel sizeToFit];
    
    CGRect labelFrame = _uidLabel.frame;
    labelFrame.origin.x = (_hostingView.frame.size.width / 2) - (labelFrame.size.width / 2);
    if (smallDevice) {
        labelFrame.origin.x += 10;
    }
    labelFrame.origin.y = _hostingView.frame.size.height - labelFrame.size.height - 3.5;
    _uidLabel.frame = labelFrame;
    
    if (CGRectEqualToRect([UIScreen mainScreen].bounds, frame) && self.isLocal) {
        _audioMuteBtn.frame = CGRectZero;
        return;
    }
    CGRect btnFrame = CGRectMake(_uidLabel.frame.origin.x - kMuteBtnSize - 5, _hostingView.frame.size.height - kMuteBtnSize, kMuteBtnSize, kMuteBtnSize);
    _audioMuteBtn.frame = btnFrame;
}

- (void)mutedAudio:(BOOL)muted {
    _audioMuteBtn.selected = muted;
}

@end
