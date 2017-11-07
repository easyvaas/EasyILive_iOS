//
//  EVShareViewController.swift
//  EasyILive_iOS
//
//  Created by Lcrnice on 2017/8/7.
//  Copyright © 2017年 Easyvaas. All rights reserved.
//

import UIKit

class EVShareViewController: UIViewController {
  
  var urlString: String? = ""
  
  @IBOutlet weak var QRImageView: UIImageView!
  @IBOutlet weak var urlTF: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = UIColor.clear
    urlTF.text = urlString
    let qrImage = self.qrImageWithString(urlString!, size: 100)
    QRImageView.image = qrImage
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  class func instanceVC() -> EVShareViewController {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    return storyboard.instantiateViewController(withIdentifier: "EVShareViewController") as! EVShareViewController
  }
  
  func showInViewController(parentViewController vc: UIViewController) {
    if self.parent == vc {
      return
    }
    
    vc.addChildViewController(self)
    self.view.alpha = 0
    self.view.frame = vc.view.frame
    vc.view.addSubview(self.view)
    
    self.didMove(toParentViewController: vc)
    
    UIView.animate(withDuration: 0.25, animations: {
      self.view.alpha = 1
    })
  }
  
  private func dismissVC() {
    UIView.animate(withDuration: 0.25, animations: {
      self.view.alpha = 0
    }, completion: { finished in
      self.willMove(toParentViewController: nil)
      self.view .removeFromSuperview()
      self .removeFromParentViewController()
    })
  }
  
  @IBAction func onBackgroundTouchDown(_ sender: UIControl) {
    urlTF.resignFirstResponder()
    self.dismissVC()
  }
  
  @IBAction func copyURL(_ sender: UIButton) {
    guard urlString != nil else {
      print("没有可拷贝的链接地址")
      return
    }
    
    let pasteboard = UIPasteboard.general
    pasteboard.string = urlString
    
    CCAlertManager.shareInstance().performComfirmTitle("已复制", message: nil, comfirmTitle: "OK", withComfirm: nil)
  }
  
  @IBAction func systemShare(_ sender: UIButton) {
    guard urlString != nil else {
      print("没有可分享的链接地址")
      return
    }
    let title = "易视云教育互动直播"
    let url = URL(string: urlString!)!
    let activityVC = UIActivityViewController(activityItems: [title, url], applicationActivities: nil)
    self.present(activityVC, animated: true, completion: nil)
  }
  
  private func qrImageWithString(_ string: String, size: CGFloat) -> UIImage? {
    let filter = CIFilter(name: "CIQRCodeGenerator")
    filter?.setDefaults()
    let data = string.data(using: .utf8)!
    filter?.setValue(data, forKey: "inputMessage")
    filter?.setValue("H", forKey: "inputCorrectionLevel")
    let outputImage = filter?.outputImage
    
    var img: UIImage? = nil
    
    guard #available(iOS 9.0, *) else {
      print("Swift3 在 iOS 8 及以下的系统中转化 CIContext.init 有错误，无法生成图片")
      return nil
    }
    
    img = self.createNonInterpolatedUIImageByCIImage(outputImage!, size: size)
    
    return img
  }
  
  private func createNonInterpolatedUIImageByCIImage(_ image: CIImage, size: CGFloat) -> UIImage? {
    let extent = image.extent.integral
    let scale = min(size/extent.width, size/extent.height)
    
    let width: size_t = size_t(extent.width * scale)
    let height: size_t = size_t(extent.height * scale)
    
    let cs = CGColorSpaceCreateDeviceGray()
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    let bitmapRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: bitmapInfo.rawValue)
    let context = CIContext.init(options: nil)
    let bitmapImage = context.createCGImage(image, from: extent)
    bitmapRef!.interpolationQuality = .none
    bitmapRef!.scaleBy(x: scale, y: scale)
    bitmapRef!.draw(bitmapImage!, in: extent)
    
    let scaledImage = bitmapRef!.makeImage()
    
    let outputImage = UIImage(cgImage: scaledImage!)
    
    UIGraphicsBeginImageContextWithOptions(outputImage.size, false, UIScreen.main.scale)
    outputImage.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    
    let newPic = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newPic
  }
}
