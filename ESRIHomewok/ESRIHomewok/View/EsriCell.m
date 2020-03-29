//
//  EsriCell.m
//  UCPlan
//
//  Created by 范杨 on 2018/4/26.
//  Copyright © 2018年 RPGLiker. All rights reserved.
//

#import "EsriCell.h"
#import <CoreText/CoreText.h>
#import <OpenGLES/ES1/gl.h>


#define ScreenWidth    [[UIScreen mainScreen] bounds].size.width
#define CellHeight    80.0f
@interface EsriCell()

@property (assign, nonatomic) BOOL isDraw;
@property (strong, nonatomic) UIImageView *containerImageView;
@property (strong, nonatomic) NSMutableDictionary * attributes;
@property (weak,   nonatomic) UIImage * downloadImage;

@end

@implementation EsriCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.containerImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:self.containerImageView];
        self.containerImageView.image = nil;
    }
    return self;
}

- (void)setAttributes:(NSMutableDictionary*) attributes downloadImage:(UIImage *)downloadImage
{
    self.attributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    self.downloadImage = downloadImage;
}

#pragma mark - public
- (void)draw{
    
    //drawing or not
    if (_isDraw||!self.attributes) return;
    _isDraw = YES;
    
    //draw async
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        CGRect rect = CGRectMake(0, 0, ScreenWidth, CellHeight);
        UIGraphicsBeginImageContextWithOptions(rect.size, YES, [UIScreen mainScreen].scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        //backgound color
        [[UIColor colorWithRed:170/255.0 green:176/255.0 blue:160/255.0 alpha:1] set];
        CGContextFillRect(context, rect);
        
        if (!self.isDraw) return ;
        
        if (self.attributes[@"RestaurantName"]) {
            
            NSString * title = self.attributes[@"RestaurantName"];
            [self p_drawWithNormalStr:title
                              context:context
                         textPosition:CGPointMake(100, 8)
                            textWidth:[[UIScreen mainScreen] bounds].size.width-120
                           textHeight:20
                            textColor:[UIColor blackColor]
                             textFont:[UIFont systemFontOfSize:18 weight:UIFontWeightMedium]];
            
        }
        
        if (self.attributes[@"Description"]) {
            
            NSString * description = self.attributes[@"Description"];
            [self p_drawWithNormalStr:description
                              context:context
                         textPosition:CGPointMake(100, 30)
                            textWidth:[[UIScreen mainScreen] bounds].size.width-120
                           textHeight:45
                            textColor:[UIColor blackColor]
                             textFont:[UIFont systemFontOfSize:13]];
        }
        
        if (self.downloadImage) {

            UIImage * downloadImage = self.downloadImage;
            [self p_drawWithNormalImage:downloadImage
                                context:context
                          imagePosition:CGPointMake(50-32, 40-32)
                             imageWidth:64
                            imageHeight:64
                          imageClipRect:CGRectZero];
            
            [self p_drawRectangleWithColor:[UIColor whiteColor]
                                   context:context
                                      rect:CGRectMake(50-32, 40-32, 64, 64)];
        }
        
        if (self.attributes[@"ObjectId"]) {
            int objectId = [self.attributes[@"ObjectId"] intValue];
            [self p_drawWithNormalImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@%d",@"NumberIcong",objectId]]
                                context:context
                          imagePosition:CGPointMake(50-32, 40-32)
                             imageWidth:15
                            imageHeight:15
                          imageClipRect:CGRectMake(0, 0, 32, 32)];
        }
                
        if (!self.isDraw) return ;
        
        UIImage *temp = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        //async refreash UI in Main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            self.containerImageView.frame = rect;
            self.containerImageView.image = temp;
        });
    });
    
}

- (void)clear{
    if (!_isDraw) return;
    
    self.containerImageView.frame = CGRectZero;
    self.containerImageView.image = nil;
    _isDraw = NO;
}

#pragma mark - private
- (void)p_drawWithNormalStr:(NSString *)string
                    context:(CGContextRef)context
               textPosition:(CGPoint)textPosition
                  textWidth:(CGFloat)textWidth
                 textHeight:(CGFloat)textHeight
                  textColor:(UIColor *)textColor
                   textFont:(UIFont *)textFont{
    
    NSMutableAttributedString *attributedString=[[NSMutableAttributedString alloc]initWithString:string];
    NSRange range1 = NSMakeRange(0, string.length);
    [attributedString addAttribute:NSForegroundColorAttributeName value:textColor range:range1];
    [attributedString addAttribute:NSFontAttributeName value:textFont range:range1];
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
//    style.lineSpacing = 1.0f;
//    style.lineBreakMode = NSLineBreakByTruncatingTail;

    
    [attributedString addAttribute:NSParagraphStyleAttributeName value:style range:range1];
    
    [self p_drawWithAttributedString:attributedString
                             context:context
                        textPosition:textPosition
                           textWidth:textWidth
                          textHeight:textHeight
                            textFont:textFont];
    
}

- (void)p_drawWithAttributedString:(NSMutableAttributedString *)attributedString
                           context:(CGContextRef)context
                      textPosition:(CGPoint)textPosition
                         textWidth:(CGFloat)textWidth
                        textHeight:(CGFloat)textHeight
                          textFont:(UIFont *)textFont{
    
    CGSize size = CGSizeMake(textWidth, textHeight+10);
    CGContextSetTextMatrix(context,CGAffineTransformIdentity);
    CGContextTranslateCTM(context,0,textHeight);
    CGContextScaleCTM(context,1.0,-1.0);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path,NULL,CGRectMake(textPosition.x, textHeight- textPosition.y-size.height,(size.width),(size.height)));
    
    
    CFAttributedStringRef cfAttributedString = (__bridge CFAttributedStringRef)attributedString;
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);
    CTFrameRef ctframe = CTFramesetterCreateFrame(framesetter, CFRangeMake(0,CFAttributedStringGetLength(cfAttributedString)),path,NULL);
    CTFrameDraw(ctframe,context);
    CGPathRelease(path);
    CFRelease(framesetter);
    CFRelease(ctframe);
    CGContextSetTextMatrix(context,CGAffineTransformIdentity);
    CGContextTranslateCTM(context,0, textHeight);
    CGContextScaleCTM(context,1.0,-1.0);
}

- (void)p_drawWithNormalImage:(UIImage *)image
                      context:(CGContextRef)context
                imagePosition:(CGPoint)imagePosition
                   imageWidth:(CGFloat)imageWidth
                  imageHeight:(CGFloat)imageHeight
                imageClipRect:(CGRect)rect{
    
    if (CGRectEqualToRect(rect,CGRectZero)) {
        //缩放图片
        float scaleImage = imageWidth/image.size.width;
        CGSize size = CGSizeApplyAffineTransform(image.size, CGAffineTransformMakeScale(scaleImage, scaleImage));
        [image drawInRect:CGRectMake(imagePosition.x, imagePosition.y+(size.width-size.height)/2, size.width, size.height)];
    }
    else
    {
        //显示图片
        CGImageRef subImageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
        CGContextSaveGState(context);
        // 图形上下文形变，避免图片倒立显示
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextDrawImage(context, CGRectMake(imagePosition.x, -imagePosition.y - imageHeight, imageWidth, imageHeight), subImageRef);
        CGContextRestoreGState(context);
    }
     
    



}

- (void)p_drawRectangleWithColor:(UIColor *)rectangleColor
                         context:(CGContextRef)context
                            rect:(CGRect)rectangleRect{
    
    //矩形，并填充颜色

    CGContextSetLineWidth(context,3.0);//线的宽度
    UIColor * cleanColor = [UIColor clearColor];//透明
    CGContextSetFillColorWithColor(context, cleanColor.CGColor);//填充颜色
    CGContextSetStrokeColorWithColor(context, rectangleColor.CGColor);//线框颜色
    CGContextAddRect(context,rectangleRect);//画方框
    CGContextDrawPath(context,kCGPathFillStroke);//绘画路径

   
}




@end
