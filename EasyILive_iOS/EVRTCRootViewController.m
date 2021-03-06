//
//  EVRTCRootViewController.m
//  EVRTC
//
//  Created by Lcrnice on 2017/7/28.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

#import "EVRTCRootViewController.h"
#import "CCAlertManager.h"
#import "EVMediaAuth.h"
#import <EVSDKBaseFramework/EVSDKManager.h>
#import "EVRTCViewController.h"
#import "EVScanQRViewController.h"
#import "EVRTCSettingViewController.h"

#define CHANNEL_ACCEPTABLE_CHARACTERS @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
#define UID_ACCEPTABLE_CHARACTERS @"0123456789"
static NSString * const kShowRTC = @"ShowRTC";

@interface EVRTCRootViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UITextField *channelTF;
@property (weak, nonatomic) IBOutlet UITextField *uidTF;

@property (nonatomic, assign) EVRtcVideoProfile currentProfile;

@end

@implementation EVRTCRootViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self addObserver];
    [EVSDKManager initSDKWithAppID:@"" appKey:@"" appSecret:@"" userID:@"rtcTester"];
    
    self.currentProfile = EVRtcVideoProfile_640x360;
    self.versionLabel.text = [NSString stringWithFormat:@"Versoin:%@", [EVSDKManager SDKVersion]];
    self.channelTF.delegate = self;
    self.uidTF.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - regist SDK
- (void)addObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSDKError:) name:EVSDKInitErrorNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSDKSuccess) name:EVSDKInitSuccessNotification object:nil];
}

- (void)initSDKError:(NSNotification *)notification{
    NSLog(@"---notification:%@", notification);
    NSString *message = [NSString stringWithFormat:@"%@", notification.object];
    [[CCAlertManager shareInstance] performComfirmTitle:notification.name message:message comfirmTitle:@"确定" WithComfirm:nil];
}

- (void)initSDKSuccess{
    NSLog(@"SDK 初始化成功");
}

#pragma mark - actions
- (IBAction)unwindSeguToRootViewController:(UIStoryboardSegue *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (IBAction)unwindSeguConfigToRootViewController:(UIStoryboardSegue *)sender {
    UIViewController *sourceVC = sender.sourceViewController;
    
    if ([sourceVC isKindOfClass:[EVRTCSettingViewController class]]) {
        EVRTCSettingViewController *settingVC = (EVRTCSettingViewController *)sourceVC;
        self.currentProfile = settingVC.currentProfile;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)scanQR:(id)sender {
    EVScanQRViewController *scanVC = [EVScanQRViewController new];
    __weak typeof(self) wSelf = self;
    scanVC.getQrCode = ^(NSString *string) {
        __strong typeof(wSelf) sSelf = wSelf;
        if (string.length > 0) {
            sSelf.channelTF.text = string;
        }
    };
    [self presentViewController:scanVC animated:YES completion:nil];
}

- (IBAction)joinChannel:(id)sender {
    if (![self p_isValidSDK]) {
        return;
    }
    
    if (![self p_isValidChannel]) {
        return;
    }
    
    [EVMediaAuth checkAndRequestMicPhoneAndCameraUserAuthed:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showDetailVCWithRole:EVRtc_ClientRole_LiveGuest];
        });
    } userDeny:nil];
}

- (IBAction)createChannel:(id)sender {
    if (![self p_isValidSDK]) {
        return;
    }
    
    [EVMediaAuth checkAndRequestMicPhoneAndCameraUserAuthed:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showDetailVCWithRole:EVRtc_ClientRole_Master];
        });
    } userDeny:nil];
}

- (IBAction)watchLiveInChannel:(id)sender {
    if (![self p_isValidSDK]) {
        return;
    }
    
    if (![self p_isValidChannel]) {
        return;
    }
    
    [self showDetailVCWithRole:EVRtc_ClientRole_Guest];
}

- (IBAction)easyvass:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://easyvaas.com"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (void)showDetailVCWithRole:(EVRtcClientRole)role {
    [self performSegueWithIdentifier:kShowRTC sender:@(role)];
}


#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    NSString *identifier = segue.identifier;
    [self resignTextFileds];
    
    if ([identifier isEqualToString:kShowRTC]) {
        EVRTCViewController *rtcVC = segue.destinationViewController;
        rtcVC.roomName = self.channelTF.text;
        rtcVC.uidString = self.uidTF.text;
        rtcVC.role = [sender integerValue];
        rtcVC.profile = self.currentProfile;
    }
    
    if ([segue.destinationViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = segue.destinationViewController;;
        EVRTCSettingViewController *settingVC = (EVRTCSettingViewController *)[nav.viewControllers firstObject];
        settingVC.currentProfile = self.currentProfile;
    }
    
}

#pragma mark - Delegates
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string  {
    if (textField == self.channelTF) {
        NSCharacterSet *cs = [[NSCharacterSet characterSetWithCharactersInString:CHANNEL_ACCEPTABLE_CHARACTERS] invertedSet];
        
        NSString *filtered = [[string componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
        
        return [string isEqualToString:filtered];
    } else if (textField == self.uidTF) {
        NSCharacterSet *cs = [[NSCharacterSet characterSetWithCharactersInString:UID_ACCEPTABLE_CHARACTERS] invertedSet];
        
        NSString *filtered = [[string componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
        
        return [string isEqualToString:filtered];
    } else {
        return true;
    }
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self resignTextFileds];
}

#pragma mark - helper

- (BOOL)p_isValidSDK {
    if ([EVSDKManager isSDKInitedSuccess] == NO) {
        [[CCAlertManager shareInstance] performComfirmTitle:@"提示" message:@"SDK 尚未初始化" comfirmTitle:@"ok" WithComfirm:nil];
        return NO;
    }
    
    return YES;
}

- (BOOL)p_isValidChannel {
    if (self.channelTF.text.length == 0 || self.channelTF.text == nil) {
        [[CCAlertManager shareInstance] performComfirmTitle:@"提示" message:@"请输入频道名" comfirmTitle:@"好的" WithComfirm:nil];
        return NO;
    }
    
    return YES;
}

- (void)resignTextFileds {
    [self.channelTF resignFirstResponder];
    [self.uidTF resignFirstResponder];
}

@end
