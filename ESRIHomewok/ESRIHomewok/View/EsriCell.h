//
//  EsriCell.h
//  UCPlan
//
//  Created by 范杨 on 2018/4/26.
//  Copyright © 2018年 RPGLiker. All rights reserved.
//

#import <UIKit/UIKit.h>
@interface EsriCell : UITableViewCell

- (void)setAttributes:(NSMutableDictionary*) attributes downloadImage:(UIImage *)downloadImage;

- (void)draw;
- (void)clear;

@end
