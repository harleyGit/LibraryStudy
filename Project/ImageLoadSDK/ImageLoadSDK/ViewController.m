//
//  ViewController.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 17/11/2020.
//
/**
 *iOS 自写加载框架：https://juejin.im/post/6844903807667666951
 */

#import "ViewController.h"
#import "ImageDownloader.h"
#import "UIImage+ImageFormat.h"
#import "UIView+Image.h"
#import "UIImage+ImageGIF.h"
#import "ImageManager.h"

//#import "ImageCache.h"

#import "Person.h"
#import <objc/runtime.h>



@interface ViewController ()

@property(nonatomic, strong) UIButton *downloadPicBtn;

@property(nonatomic, strong) UIImageView *downloadPic;



@end

@implementation ViewController

- (UIButton *)downloadPicBtn {
    if (!_downloadPicBtn) {
        _downloadPicBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _downloadPicBtn.backgroundColor = UIColor.redColor;
        [_downloadPicBtn setTitle:@"图片下载" forState:UIControlStateNormal];
        [_downloadPicBtn addTarget:self action:@selector(downloadPicAction) forControlEvents:UIControlEventTouchUpInside];//
    }
    
    return  _downloadPicBtn;
}

- (UIImageView *)downloadPic {
    if (!_downloadPic) {
        _downloadPic = [UIImageView new];
        _downloadPic.frame = CGRectMake(100, 100, 200, 200);
    }
    return _downloadPic;
}

- (void) personTest {
    
    Person *person = [[Person alloc] init];
    NSLog(@"person 对象：%@",person);
    Class c1 = [person class];
    Class c2 = [Person class];
    //输出1
    NSLog(@"1.  %d", c1 == c2);
    
    
    //class_isMetaClass用于判断Class对象是否为元类
    //object_getClass用于获取对象的isa指针指向的对象
    
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.downloadPic];
    self.downloadPicBtn.frame = CGRectMake(100, 300, 200, 120);
    [self.view addSubview:self.downloadPicBtn];
    
    
    UIButton *clearMemCacheBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearMemCacheBtn.frame = CGRectMake(100, 440, 200, 120);
    [clearMemCacheBtn setTitle:@"clear memory cache" forState:UIControlStateNormal];
    [clearMemCacheBtn addTarget:self action:@selector(clearMemCache) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearMemCacheBtn];
    
    UIButton *clearDiskCacheBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearDiskCacheBtn.frame = CGRectMake(100, 580, 200, 120);
    [clearDiskCacheBtn setTitle:@"clear disk cache" forState:UIControlStateNormal];
    [clearDiskCacheBtn addTarget:self action:@selector(clearDiskCache) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearDiskCacheBtn];
    
    
    
}




- (void) imageInfoTest {
    //    UIImage *imageInfo = CFBridgingRelease(MyCreateCGImageFromFile(@"/Users/harleyhuang/Documents/GitHub/学习笔记/Pictures/a0.jpg"));
    //    NSLog(@"🍊 Pic 信息： %@", imageInfo);
    //    self.downloadPic.image = imageInfo;
    //    CFBridgingRelease((__bridge CFTypeRef _Nullable)(imageInfo));
}




- (void) downloadPicAction {
  
    
    NSString *gifUrl = @"https://user-gold-cdn.xitu.io/2019/3/27/169bce612ee4dc21";
   
    
    //普通图片
    NSString *imageUrl = @"https://user-gold-cdn.xitu.io/2019/4/18/16a3024759afb5b5";
    __weak typeof(self) weakSelf = self;
    ImageCacheConfig *config = [[ImageCacheConfig alloc] init];
    config.maxCacheAge = 60;
    [[ImageManager shareManager] setCacheConfig:config];
    
    [self.downloadPic setImageWithURL:gifUrl options:(ImageOptionAvoidAutoSetImage | ImageOptionProgressive) progressBlock:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        NSLog(@"expectedSize:%ld, receivedSize:%ld, targetURL:%@", expectedSize, receivedSize, targetURL.absoluteString);
    } transformBlock:^UIImage * _Nullable(UIImage * _Nonnull image, NSString * _Nullable url) {
        if (image && image.imageFormat != ImageFormatGIF) {
            //若是GIF图片在这里绘制会出错，解决： https://www.jianshu.com/p/7e007cc6def1
            CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
            UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
            [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:100] addClip];
            [image drawInRect:rect];
            UIImage *transformImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            return transformImage;
        } else if (image.imageFormat == ImageFormatGIF) {
            return  image;
        }else {
            return nil;
        }
    } completionBlock:^(UIImage * _Nullable image, NSError * _Nullable error, BOOL finished) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if (strongSelf && image) {
            if (image.imageFormat == ImageFormatGIF) {
                strongSelf.downloadPic.animationImages = image.images;
                strongSelf.downloadPic.animationDuration = image.totalTimes;
                strongSelf.downloadPic.animationRepeatCount = image.loopCount;
                [strongSelf.downloadPic startAnimating];
            } else {
                strongSelf.downloadPic.image = image;
            }
        }
    }];
    
    
    
    
    /*
     //加载gif图片
     //NSString *gifUrl = @"https://user-gold-cdn.xitu.io/2019/3/27/169bce612ee4dc21";
     NSString *gifUrl = @"https://user-gold-cdn.xitu.io/2019/4/16/16a26049b33c9398";
     __weak typeof(self) weakSelf = self;
     [[ImageDownloader shareInstance] fetchImageWithURL3:gifUrl completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
     __strong typeof (weakSelf) strongSelf = weakSelf;
     if (strongSelf && image) {
     if (image.imageFormat == ImageFormatGIF) {
     strongSelf.downloadPic.animationImages = image.images;
     [strongSelf.downloadPic startAnimating];
     } else {
     strongSelf.downloadPic.image = image;
     }
     }
     }];
     */
    
    
    
    /*
     NSString *imageUrl = @"https://user-gold-cdn.xitu.io/2019/3/25/169b406dfc5fe46e";
     __weak typeof(self) weakSelf = self;
     [[ImageDownloader shareInstance] fetchImageWithURL:imageUrl completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
     __strong typeof (weakSelf) strongSelf = weakSelf;
     if (strongSelf && image) {
     strongSelf.downloadPic.image = image;
     }
     }];
     */
    
    
    /*
     //原生加载图片
     NSString *imageUrl = @"https://user-gold-cdn.xitu.io/2019/3/25/169b406dfc5fe46e";
     NSURL *url = [NSURL URLWithString:imageUrl];
     NSURLSession *session = [NSURLSession sharedSession];
     __weak typeof (self) weakSelf = self;
     NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
     if (!error && data) {
     UIImage *image = [UIImage imageWithData:data];
     __strong typeof(weakSelf) strongSelf = weakSelf;
     if (strongSelf) {
     dispatch_async(dispatch_get_main_queue(), ^{
     strongSelf.downloadPic.image = image;
     });
     }
     }
     }];
     [task resume];
     */
    
}


- (void)resetImage {
    if (self.downloadPic.isAnimating) {
        [self.downloadPic stopAnimating];
    }
    self.downloadPic.image = nil;
    
}

- (void)clearMemCache {
    [[ImageManager shareManager] clearMemoryCache];
}

- (void)clearDiskCache {
    [[ImageManager shareManager] clearDiskCache];
}




@end
