//
//  UIView+XibConfiguration.m
//  oupai
//
//  Created by Lcrnice on 16/11/23.
//  Copyright © 2016年 yizhibo. All rights reserved.
//

#import "UIView+XibConfiguration.h"

@implementation UIView (XibConfiguration)

@dynamic borderColor,borderWidth,cornerRadius;

-(void)setBorderColor:(UIColor *)borderColor{
    [self.layer setBorderColor:borderColor.CGColor];
}

-(void)setBorderWidth:(CGFloat)borderWidth{
    [self.layer setBorderWidth:borderWidth];
}

-(void)setCornerRadius:(CGFloat)cornerRadius{
    [self.layer setCornerRadius:cornerRadius];
}

@end
