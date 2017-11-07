//
//  EVRTCViewController.swift
//  EasyILive_iOS
//
//  Created by Lcrnice on 2017/8/7.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

import UIKit
import EVRTCFramework
import EVMediaFramework


class EVRTCViewController: UIViewController {
  // IBOutlets
  @IBOutlet weak var cameraBtn: UIButton!
  @IBOutlet weak var closeBtn: UIButton!
  @IBOutlet weak var localVideoBtn: UIButton!
  @IBOutlet weak var muteBtn: UIButton!
  @IBOutlet weak var remoteContainerView: UIView!
  @IBOutlet weak var shareBtn: UIButton!
  @IBOutlet weak var switchModeBtn: UIButton!
  @IBOutlet weak var titleLabel: UILabel!
  
  /// Public vars
  var roomName: String? = ""
  var uidString: String? = "0"
  var role: EVRtcClientRole = .clientRole_Guest
  var profile: EVRtcVideoProfile = ._640x360
  
  /// File vars
  fileprivate var rtcKit: EVRTCKit?
  fileprivate var player: EVPlayer?
  fileprivate var muteVideoView: UIView?
  fileprivate var muteVideoIV: UIImageView?
  fileprivate var currentUid: UInt = 0
  fileprivate var currentChannel: String = ""
  fileprivate var connected: Bool = false
  fileprivate var mutedAudioUsers: [UInt]?
  fileprivate var videoSessions: [VideoSession]? {
    didSet {
      if remoteContainerView != nil {
        self.updateInterface()
      }
    }
  }
  fileprivate var fullSession: VideoSession? {
    didSet {
      guard fullSession != nil else {
        return
      }
      if videoSessions?.isEmpty == false {
        let fullSessionIdx = videoSessions?.index(of: fullSession!)
        let firstSession = videoSessions?.first
        videoSessions?.insert(firstSession!, at: fullSessionIdx!)
        videoSessions?.remove(at: fullSessionIdx! + 1)
        videoSessions?.insert(fullSession!, at: 0)
        videoSessions?.remove(at: 0 + 1)
      }
      
      if fullSession?.isLocal == false {
        rtcKit?.configRemoteVideoStream((fullSession?.uid)!, type: .videoStream_High)
      }
      
      if remoteContainerView != nil {
        self.updateInterface()
      }
    }
  }
  
  static let kScreenWidth = UIScreen.main.bounds.size.width
  static let kScreenHeight = UIScreen.main.bounds.size.height
  static let kRTCKey = "2f1df58774d4445bb36942b954c40dfd"
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    
    titleLabel.text = roomName
    currentChannel = roomName!
    
    if role == .clientRole_Guest {
      switchModeBtn!.isHidden = false
    }
    
    self.setupRTC()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override var prefersStatusBarHidden: Bool {
    return false
  }
  
  // MARK: - Outlet actions
  @IBAction func cleanScreen(_ sender: Any) {
    let hidden = !muteBtn.isHidden
    closeBtn.isHidden = hidden
    titleLabel.isHidden = hidden
    cameraBtn.isHidden = hidden
    muteBtn.isHidden = hidden
    localVideoBtn.isHidden = hidden
    shareBtn.isHidden = hidden
    
    if role == .clientRole_Guest {
      switchModeBtn.isHidden = muteBtn.isHidden
    }
  }
  
  @IBAction func tapGenerateQR(_ sender: Any) {
    guard titleLabel.text?.isEmpty == false else {
      return
    }
    
    let qrVC = EVGenerateQRViewController()
    qrVC.infoString = currentChannel
    self.present(qrVC, animated: true, completion: nil)
  }
  
  @IBAction func doDoubleTaped(_ sender: Any) {
    let location = (sender as! UITapGestureRecognizer) .location(in: remoteContainerView)

    var targetSession: VideoSession?
    for session in videoSessions! {
      let rect = session.hostingView?.frame
      if rect!.contains(location) {
        targetSession = session
      }
    }
    
    if fullSession != nil && fullSession != targetSession {
      rtcKit?.configRemoteVideoStream(currentUid, type: .videoStream_Low)
    }
    
    fullSession = targetSession
  }
  
  @IBAction func close(_ sender: Any) {
    if connected {
      CCAlertManager.shareInstance().performComfirmTitle("提示", message: "是否确认退出连麦？", cancelButtonTitle: "不了", comfirmTitle: "是的", withComfirm: { 
        self.leaveChannel()
        self.popVC()
      }, cancel: nil)
    } else {
      if role == .clientRole_Guest {
        player?.shutDown()
        player = nil
      } else {
        self.leaveChannel()
      }
      
      self.popVC()
    }
  }
  
  fileprivate func leaveChannel() {
    rtcKit?.leaveChannel()
    rtcKit = nil
  }
  
  fileprivate func popVC() {
    self.rorateScreen(orientation: .portrait)
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func switchCamera(_ sender: Any) {
    let result = rtcKit?.switchCamera()
    if result == 0 {
      cameraBtn.isSelected = !cameraBtn.isSelected
    }
  }
  
  @IBAction func mute(_ sender: Any) {
    let result = rtcKit?.muteLocalAudioStream(!(sender as! UIButton).isSelected)
    if result == 0 {
      muteBtn.isSelected = !muteBtn.isSelected
      
      let session = self.fetchSessionOfUid(uid: self.currentUid)
      session?.mutedAudio(muteBtn.isSelected)
    }
  }
  
  @IBAction func localVideo(_ sender: Any) {
    let result = rtcKit?.muteLocalVideoStream(!(sender as! UIButton).isSelected)
    if result == 0 {
      localVideoBtn.isSelected = !localVideoBtn.isSelected
      cameraBtn.isEnabled = !(sender as! UIButton).isSelected
      
      self.updateInterface()
    }
  }
  
  @IBAction func switchMode(_ sender: Any) {
    let btn = sender as! UIButton
    btn.isSelected = !btn.isSelected
    
    self.enableMedia(enable: btn.isSelected)
    
    let views = remoteContainerView.subviews
    for v in views {
      v.removeFromSuperview()
    }
    
    if btn.isSelected {
      muteBtn.isSelected = false
      localVideoBtn.isSelected = false
      player?.shutDown()
      player = nil
      role = .clientRole_LiveGuest
    } else {
      self.leaveChannel()
      role = .clientRole_Guest
      connected = false
    }
    
    self.setupRTC()
  }
  
  @IBAction func share(_ sender: Any) {
    let hud = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    hud.center = remoteContainerView.center
    hud.startAnimating()
    remoteContainerView.addSubview(hud)
    
    rtcKit?.fetchShareURL(withChannel: currentChannel, callback: { [weak self] (code: EVRtcResponseCode, info: [AnyHashable : Any]?, error: Error?) in
      hud.stopAnimating()
      hud .removeFromSuperview()
      
      if code == .none {
        let url = info?[NSLocalizedDescriptionKey]
        let shareVC = EVShareViewController.instanceVC()
        shareVC.urlString = (url as! String)
        shareVC.showInViewController(parentViewController: self!)
      } else {
        self?.alertString(string: "获取分享地址失败，请稍后再试:\n \(error.debugDescription)")
      }
      
    })
  }
}


extension EVRTCViewController {
  fileprivate func setupRTC() {
    self.rorateScreen(orientation: .landscapeLeft)
    
    videoSessions = Array()
    mutedAudioUsers = Array()
    
    muteVideoIV = UIImageView(image: UIImage(named: "btn_join_cancel"))
    muteVideoIV?.contentMode = .scaleAspectFit
    
    muteVideoView = UIView()
    muteVideoView?.backgroundColor = UIColor.white
    muteVideoView?.addSubview(muteVideoIV!)
    
    rtcKit = EVRTCKit(rtcid: EVRTCViewController.kRTCKey)
    rtcKit?.delegate = self
    rtcKit?.profile = profile
    
    _ = self.videoSessionOfUid(uid: 0)
    
    switch role {
    case .clientRole_Master:
      rtcKit?.createAndJoinChannel(roomName, uid: UInt(uidString!)!, hasPublisher: true, record: true, callback: { [weak self] (code: EVRtcResponseCode, info: [AnyHashable : Any]?, error: Error?) in
        if code == .none {
          UIApplication.shared.isIdleTimerDisabled = true
        } else {
          self?.videoSessions?.removeAll()
          DispatchQueue.main.async {
            self?.alertString(string: "Create channel failed: \(error.debugDescription)")
          }
        }
      })
    case .clientRole_LiveGuest:
      guard roomName?.isEmpty == false else {
        print("加入互动时，channel为必传参数")
        return
      }
      rtcKit?.joinChannel(roomName!, uid: UInt(uidString!)!, callback: { [weak self] (code: EVRtcResponseCode, info: [AnyHashable : Any]?, error: Error?) in
        if code == .none {
          UIApplication.shared.isIdleTimerDisabled = true
        } else {
          self?.videoSessions?.removeAll()
          DispatchQueue.main.async {
            self?.alertString(string: "Join channel failed: \(error.debugDescription)")
          }
        }
      })
    case .clientRole_Guest:
      self.enableMedia(enable: false)
      guard roomName?.isEmpty == false else {
        print("观看互动时，channel为必传参数")
        return
      }
      rtcKit?.watchLive(withChannel: roomName!, callback: { [weak self] (code: EVRtcResponseCode, info: [AnyHashable : Any]?, error: Error?) in
        if code == .none {
          let url: String = info?[NSLocalizedDescriptionKey] as! String
          print("播放地址为:\(url)")
          self?.setupPlayer(url: url)
        } else {
          self?.videoSessions?.removeAll()
          DispatchQueue.main.async {
            self?.alertString(string: "watch channel failed: \(error.debugDescription)")
          }
        }
      })
    }
  }
  
  fileprivate func enableMedia(enable: Bool) {
    muteBtn.isEnabled = enable
    cameraBtn.isEnabled = enable
    localVideoBtn.isEnabled = enable
  }
  
  
  fileprivate func rorateScreen(orientation: UIDeviceOrientation) {
    EVScreenManager.share().setDeviceOrientationTo(orientation)
  }
  
  fileprivate func videoSessionOfUid(uid: UInt) -> VideoSession {
    let videoSession = self.fetchSessionOfUid(uid: uid)
    
    if videoSession != nil {
      return videoSession!
    } else {
      let newSession = VideoSession(uid: uid)
      if (uid == self.rtcKit?.masterUid) ||
        (self.role == .clientRole_Master && uid == 0) {
        newSession.isMaster = true
      }
      rtcKit?.configCanvas(with: newSession.hostingView!, uid: uid, mode: .render_Fit)
      videoSessions?.append(newSession)
      self.updateInterface()
      
      return newSession
    }
  }
  
  fileprivate func fetchSessionOfUid(uid: UInt) -> VideoSession? {
    for session in videoSessions! {
      if session.uid == uid {
        return session
      }
    }
    
    return nil
  }
  
  fileprivate func updateInterface() {
    let maxVerticalCount: Int = 3
    let kMargin: CGFloat = 10
    let w = (CGFloat(EVRTCViewController.kScreenWidth) - (CGFloat)(maxVerticalCount - 1) * kMargin) / CGFloat(maxVerticalCount)
    let vW = w
    let vH = w / (16 / 9.0)
    
    let tempSessions = videoSessions! as NSArray
    tempSessions.enumerateObjects({ (session, idx, stop) in
      let obj = session as! VideoSession
      
      if idx == 0 {
        obj.updateHostingViewFrame(UIScreen.main.bounds)
      } else {
        let column = ((idx - 1) / maxVerticalCount)
        let x = CGFloat(EVRTCViewController.kScreenWidth) - (vW * (CGFloat)(column + 1)) - (kMargin * CGFloat(column))
        let row: CGFloat = CGFloat((idx - 1) % maxVerticalCount)
        let y = row * (vH + kMargin);
        
        obj.updateHostingViewFrame(CGRect(x: x, y: y, width: vW, height: vH))
      }
      
      if obj.isLocal {
        self.showLocalMuteImage(show: localVideoBtn.isSelected, view: obj.hostingView!)
      }
      
      if obj.hostingView?.superview == nil {
        remoteContainerView.addSubview(obj.hostingView!)
      }
      
      if fullSession?.uid == obj.uid && remoteContainerView.subviews.contains(obj.hostingView!) {
        remoteContainerView.sendSubview(toBack: obj.hostingView!)
      }
    })
    
//    self.updatePublisherFrame()
  }
  
  fileprivate func updatePublisherFrame() {
    if (rtcKit?.isMaster)! {
      var array = Array<EVRTCVideoRegion>()
      let tempSessions = videoSessions! as NSArray

      tempSessions.enumerateObjects({ (session, idx, stop) in
        let obj = session as! VideoSession
        
        let region = EVRTCVideoRegion()
        region.renderMode = .render_Fit
        region.zOrder = idx
        region.uid = obj.uid != 0 ? obj.uid : currentUid
        
        region.x = Double(CGFloat((obj.hostingView?.frame.origin.x)! / CGFloat(EVRTCViewController.kScreenWidth)))
        region.y = Double((obj.hostingView?.frame.origin.y)! / CGFloat(EVRTCViewController.kScreenHeight))
        region.width = Double((obj.hostingView?.frame.width)! / CGFloat(EVRTCViewController.kScreenWidth))
        region.height = Double((obj.hostingView?.frame.height)! / CGFloat(EVRTCViewController.kScreenHeight))
        
        array.append(region)
      })
      
      rtcKit?.configVideoRegion(array)
    }
  }
  
  fileprivate func alertString(string: String?) {
    guard let text = string else {
      return
    }
    
    let alertVC = UIAlertController(title: nil, message: text, preferredStyle: .alert)
    alertVC.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    self.present(alertVC, animated: true, completion: nil)
  }
  
  fileprivate func hudString(string: String?) {
    guard let text = string else {
      return
    }
    
    let hudVC = UIAlertController(title: nil, message: text, preferredStyle: .alert)
    self.present(hudVC, animated: true, completion: nil)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      hudVC.dismiss(animated: true, completion: nil)
    }
  }
  
  fileprivate func showLocalMuteImage(show: Bool, view: UIView) {
    if show {
      muteVideoView?.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
      muteVideoIV?.center = (muteVideoView?.center)!
      view.addSubview(muteVideoView!)
    } else {
      if view.subviews.contains(muteVideoView!) {
        muteVideoView?.removeFromSuperview()
      }
    }
  }
  
  fileprivate func handleMutedAudioUsersWithMuted(_ muted: Bool, uid: UInt) {
    if muted {
      if self.mutedAudioUsers?.contains(uid) == false {
        self.mutedAudioUsers?.append(uid)
      }
    } else {
      if self.mutedAudioUsers?.contains(uid) != nil {
        self.mutedAudioUsers?.remove(object: uid)
      }
    }
  }
  
  fileprivate func checkMutedWithUid(_ uid: UInt) {
    if self.mutedAudioUsers?.contains(uid) != nil {
      let session = self.fetchSessionOfUid(uid: uid)
      session?.mutedAudio(true)
    }
  }
}

// MARK: - EVRTCDelegate
extension EVRTCViewController: EVRTCDelegate {
  func evRTCKit(_ kit: EVRTCKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
    currentUid = uid
    currentChannel = channel
    titleLabel.text = "点击[ \(channel) ]显示二维码"
    connected = true
    let localSession = self.fetchSessionOfUid(uid: 0)
    if (localSession != nil) {
      localSession?.uid = uid
      localSession?.updateHostingViewFrame((localSession?.hostingView?.frame)!)
    }
    
    
    var roleString: String! = ""
    switch role {
    case .clientRole_Master:
      roleString = "主播"
    case .clientRole_LiveGuest:
      roleString = "连麦观众"
    case .clientRole_Guest:
      roleString = "观众"
    }
    
    CCAlertManager.shareInstance().performComfirmTitle("已加入频道", message: "\n身份：\(roleString!)\nuid:\(uid)", comfirmTitle: "OK", withComfirm: nil)
  }
  
  func evRTCKit(_ kit: EVRTCKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
    _ = self.videoSessionOfUid(uid: uid)
    self.checkMutedWithUid(uid)
  }
  
  func evRTCKit(_ kit: EVRTCKit, firstLocalVideoFrameWith size: CGSize, elapsed: Int) {
    if self.videoSessions?.isEmpty == false {
      self.updateInterface()
    }
  }
  
  func evRTCKit(_ kit: EVRTCKit, didAudioMuted muted: Bool, byUid uid: UInt) {
    let session = self.fetchSessionOfUid(uid: uid)
    session?.mutedAudio(muted)
    
    self.handleMutedAudioUsersWithMuted(muted, uid: uid)
    
    var msg = ""
    
    if muted {
      msg = "用户:\(uid)\n设置静音"
    } else {
      msg = "用户:\(uid)\n取消静音"
    }
    
    self.hudString(string: msg)
  }
  
  func evRTCKit(_ kit: EVRTCKit, didVideoMuted muted: Bool, byUid uid: UInt) {
    var msg = ""
    
    if muted {
      msg = "用户:\(uid)\n暂停传输视频数据"
    } else {
      msg = "用户:\(uid)\n回来了"
    }
    
    self.hudString(string: msg)
  }
  
  func evRTCKitConnectionDidInterrupted(_ kit: EVRTCKit) {
    self.hudString(string: "连接中断...")
  }
  
  func evRTCKitConnectionDidLost(_ kit: EVRTCKit) {
    self.hudString(string: "连接已丢失！")
  }
  
  func evRTCKit(_ kit: EVRTCKit, didOfflineOfUid uid: UInt, reason: EVRtcOfflineReason) {
    var deleteSession: VideoSession? = nil
    for session in videoSessions! {
      if session.uid == uid {
        deleteSession = session
      }
    }
    
    if deleteSession != nil {
      videoSessions?.remove(object: deleteSession!)
      deleteSession?.hostingView?.removeFromSuperview()
      self.updateInterface()
      
      if deleteSession == fullSession {
        fullSession = self.fetchSessionOfUid(uid: 0)
      }
    }
  }
  
  func evRTCKit(_ kit: EVRTCKit, didOccurErrorWithCode errorCode: Int) {
    connected = false
    
    if errorCode == EVRtcResponseCode.masterExit.rawValue {
      CCAlertManager.shareInstance().performComfirmTitle("当前频道主播关闭了连麦", message: nil, comfirmTitle: "OK", withComfirm: { 
        self.leaveChannel()
        self.popVC()
      })
    } else if errorCode == 18 {
      self.alertString(string: "离开频道操作被拒绝")
    } else {
      self.alertString(string: "did occur error with code:\(errorCode)")
    }
  }
}

// MARK: - 配置播放器
extension EVRTCViewController {
  fileprivate func setupPlayer(url: String) {
    player = EVPlayer()
    player?.playerContainerView = remoteContainerView
    player?.live = true
    player?.playURLString = url
    player?.delegate = self
    
    player?.playPrepareComplete({ [weak self] (code: EVPlayerResponseCode, info: [AnyHashable : Any]?, error: Error?) in
      guard let sSelf = self else {
        return
      }
      
      if code == EVPlayerResponseCode.okay {
        sSelf.player?.play()
      }
    })
  }
}

extension EVRTCViewController: EVPlayerDelegate {
    func evPlayerDidFinishPlay(_ player: EVPlayer!, reason: MPMovieFinishReason) {
        CCAlertManager.shareInstance().performComfirmTitle(nil, message: "视频结束", comfirmTitle: "OK") { 
            self.popVC()
        }
    }
}

extension Array where Element: Equatable {
  
  // Remove first collection element that is equal to the given `object`:
  mutating func remove(object: Element) {
    if let index = index(of: object) {
      remove(at: index)
    }
  }
}
