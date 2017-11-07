//
//  VideoSession.swift
//  EasyILive_iOS
//
//  Created by Lcrnice on 2017/8/8.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

import UIKit

class VideoSession: NSObject {
  private var local = false
  
  var uid: UInt = 0
  var hostingView: UIView? = nil
  var isLocal: Bool {
    return local
  }
  var isMaster: Bool = false
  
  private var uidLabel: UILabel?
  private var muteBtn: UIButton?
  private let kBtnSize: CGFloat = 20
  
  convenience init(uid: UInt) {
    self.init()
    
    if uid == 0 {
      self.local = true
    }
    
    self.uid = uid
    self.hostingView = UIView()
    self.hostingView?.translatesAutoresizingMaskIntoConstraints = false
    self.hostingView?.backgroundColor = UIColor.lightGray
    
    self.uidLabel = UILabel()
    self.uidLabel?.font = UIFont.systemFont(ofSize: 12)
    self.uidLabel?.textColor = UIColor.black
    self.uidLabel?.layer.zPosition = CGFloat.greatestFiniteMagnitude
    
    self.hostingView?.addSubview(self.uidLabel!)
    
    self.muteBtn = UIButton(type: .custom)
    self.muteBtn?.setImage(UIImage.init(named: "btn_mute"), for: .normal)
    self.muteBtn?.setImage(UIImage.init(named: "btn_mute_cancel"), for: .selected)
    self.muteBtn?.layer.zPosition = CGFloat.greatestFiniteMagnitude
    self.muteBtn?.isUserInteractionEnabled = false
    
    self.hostingView?.addSubview(self.muteBtn!)
  }
  
  func updateHostingViewFrame(_ frame: CGRect) {
    self.hostingView?.frame = frame
    
    var smallDevice = false
    if min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) == 320 {
      smallDevice = true
    }
    
    if smallDevice {
      self.uidLabel?.font = UIFont.systemFont(ofSize: 10)
    }
    
    let role = self.isMaster ? "主播" : "连麦观众"
    
    
    self.uidLabel?.text = "uid:\(self.uid) role:\(role)"
    self.uidLabel?.sizeToFit()
    
    var labelFrame = self.uidLabel?.frame
    labelFrame?.origin.x = ((self.hostingView?.frame.width)! / 2) - ((labelFrame?.width)! / 2)
    if smallDevice {
      labelFrame?.origin.x += 10
    }
    labelFrame?.origin.y = (self.hostingView?.frame.height)! - (labelFrame?.height)! - 3.5
    self.uidLabel?.frame = labelFrame!
    
    if frame.equalTo(UIScreen.main.bounds) && self.isLocal {
      self.muteBtn?.frame = .zero
      return
    }

    self.muteBtn?.frame = CGRect(x: (self.uidLabel?.frame.origin.x)! - kBtnSize - 5,
                                 y: (self.hostingView?.frame.height)! - kBtnSize,
                                 width: kBtnSize, height: kBtnSize)
  }
  
  func mutedAudio(_ muted: Bool) {
    self.muteBtn?.isSelected = muted
  }
}
