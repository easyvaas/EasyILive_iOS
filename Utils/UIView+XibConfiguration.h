//
//  UIView+XibConfiguration.h
//  oupai
//
//  Created by Lcrnice on 16/11/23.
//  Copyright © 2016年 yizhibo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (XibConfiguration)

@property (nonatomic) IBInspectable UIColor *borderColor;
@property (nonatomic) IBInspectable CGFloat borderWidth;
@property (nonatomic) IBInspectable CGFloat cornerRadius;

@end
