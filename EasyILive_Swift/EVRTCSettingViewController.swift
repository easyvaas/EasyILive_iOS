//
//  EVRTCSettingViewController.swift
//  EasyILive_iOS
//
//  Created by Lcrnice on 2017/8/7.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

import UIKit
import EVRTCFramework

class EVRTCSettingViewController: UIViewController {
  
  @IBOutlet weak var ev180pView: UIView!
  @IBOutlet weak var ev360pView: UIView!
  @IBOutlet weak var ev720pView: UIView!
  
  
  var currentProfile: Int = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    self.configProfile(profile: EVRtcVideoProfile(rawValue: currentProfile)!)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func switchTo180p(_ sender: Any) {
    self.configProfile(profile: ._320x180)
  }

  @IBAction func switchTo360p(_ sender: Any) {
    self.configProfile(profile: ._640x360)
  }
  
  @IBAction func switchTo720p(_ sender: Any) {
    self.configProfile(profile: ._1280x720)
  }
  
  private func configProfile(profile: EVRtcVideoProfile) {
    ev180pView.backgroundColor = UIColor.clear
    ev360pView.backgroundColor = UIColor.clear
    ev720pView.backgroundColor = UIColor.clear
    
    switch profile {
    case ._320x180:
      ev180pView.backgroundColor = UIColor.init(white: 0.5, alpha: 0.2)
    case ._640x360:
      ev360pView.backgroundColor = UIColor.init(white: 0.5, alpha: 0.2)
    case ._1280x720:
      ev720pView.backgroundColor = UIColor.init(white: 0.5, alpha: 0.2)
    }
    
    currentProfile = profile.rawValue
  }
  
}
