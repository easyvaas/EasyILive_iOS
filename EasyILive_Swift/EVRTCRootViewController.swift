//
//  EVRTCRootViewController.swift
//  EasyILive_iOS
//
//  Created by Lcrnice on 2017/8/7.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

import UIKit
import EVSDKBaseFramework
import EVRTCFramework

class EVRTCRootViewController: UIViewController {
  
  @IBOutlet weak var channelTF: UITextField!
  @IBOutlet weak var uidTF: UITextField!
  @IBOutlet weak var versionLabel: UILabel!
  
  fileprivate var currentProfile: EVRtcVideoProfile = ._640x360
  static let kShowRTC = "ShowRTC"
  static let kEasyvaas = URL(string: "http://easyvaas.com")
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    
    self.addEVObserver()
    EVSDKManager.initSDK(withAppID: "", appKey: "", appSecret: "", userID: "rtcSwiftTester")
    versionLabel.text = String(format: "Version:%@", EVSDKManager.sdkVersion())
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    
    resignTextFileds()
    
    if EVRTCRootViewController.kShowRTC == segue.identifier {
      let rtcVC = segue.destination as! EVRTCViewController
      rtcVC.roomName = channelTF.text!
      if uidTF.text?.isEmpty == false {
        rtcVC.uidString = uidTF.text!
      }
      rtcVC.role = sender as! EVRtcClientRole
      rtcVC.profile = currentProfile
    }
    
    if segue.destination is UINavigationController {
      let nav = segue.destination as! UINavigationController
      let settingVC = nav.viewControllers.first as! EVRTCSettingViewController
      settingVC.currentProfile = self.currentProfile.rawValue
    }
  }
  
  
  @IBAction func swiftUnwindSegueToRootVC(segue: UIStoryboardSegue) {
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func swiftUnwindSegueConfigToRootVC(segue: UIStoryboardSegue) {
    if segue.source is EVRTCSettingViewController {
      let sourceVC = segue.source as! EVRTCSettingViewController
      currentProfile = EVRtcVideoProfile(rawValue: sourceVC.currentProfile)!
    }
    self.dismiss(animated: true, completion: nil)
  }
  
  // MARK: - Outlet actions
  @IBAction func scanQR(_ sender: Any) {
    let scanVC: EVScanQRViewController = EVScanQRViewController()
    scanVC.getQrCode = { [weak self] qr in
      guard let sSelf = self, let qrString = qr else {
        return
      }
      
      sSelf.channelTF.text = qrString
    }
    self.present(scanVC, animated: true, completion: nil)
  }
  
  @IBAction func joinChannel(_ sender: Any) {
    guard isSDKValid(), isChannelValid() else {
      return
    }
    
    EVMediaAuth.checkAndRequestMicPhoneAndCameraUserAuthed({ [weak self] in
      DispatchQueue.main.async {
        self?.showDetailVC(role: .clientRole_LiveGuest)
      }
    }, userDeny: nil)
  }
  
  @IBAction func createChannel(_ sender: Any) {
    guard isSDKValid() else {
      return
    }
    
    EVMediaAuth.checkAndRequestMicPhoneAndCameraUserAuthed({ [weak self] in
      DispatchQueue.main.async {
        self?.showDetailVC(role: .clientRole_Master)
      }
      }, userDeny: nil)
  }
  
  @IBAction func watchLivingChannel(_ sender: Any) {
    guard isSDKValid(), isChannelValid() else {
      return
    }
    
    self.showDetailVC(role: .clientRole_Guest)
  }
  
  @IBAction func easyvaas(_ sender: Any) {
    if #available(iOS 10.0, *) {
      UIApplication.shared.open(EVRTCRootViewController.kEasyvaas!, options: [:], completionHandler: { (success) in
      })
    } else {
      UIApplication.shared.openURL(EVRTCRootViewController.kEasyvaas!)
    }
  }
  
}


// MARK: - 注册SDK
extension EVRTCRootViewController {
  fileprivate func addEVObserver() {
    NotificationCenter.default.addObserver(forName: .EVSDKInitSuccess, object: nil, queue: OperationQueue.main, using: { _ in
      print("SDK 初始化成功")
    })
    
    NotificationCenter.default.addObserver(forName: .EVSDKInitError, object: nil, queue: OperationQueue.main, using: { notify in
      print("SDK 初始化失败")
      CCAlertManager.shareInstance().performComfirmTitle(notify.name.rawValue, message: String(format: "%@", notify.object as! CVarArg), comfirmTitle: "ok", withComfirm: nil)
    })
  }
}

// MARK: - Helpers
extension EVRTCRootViewController {
  fileprivate func isSDKValid() -> Bool {
    if EVSDKManager.isSDKInitedSuccess() {
      return true
    }
    
    CCAlertManager.shareInstance().performComfirmTitle("提示", message: "SDK 尚未初始化", comfirmTitle: "ok", withComfirm: nil)
    return false
  }
  
  fileprivate func isChannelValid() -> Bool {
    if (channelTF.text?.isEmpty)! || channelTF.text == nil {
      CCAlertManager.shareInstance().performComfirmTitle("提示", message: "请输入频道名", comfirmTitle: "ok", withComfirm: nil)
      return false
    }
    
    return true
  }
  
  fileprivate func showDetailVC(role currentRole:EVRtcClientRole) {
    self.performSegue(withIdentifier: EVRTCRootViewController.kShowRTC, sender: currentRole)
  }
  
  fileprivate func resignTextFileds() {
    channelTF.resignFirstResponder()
    uidTF.resignFirstResponder()
  }
}

