// 手指合拢手势 — PinchSnap
// 三指合拢 -> Snapper3 标准模式；四指合拢 -> 录屏开/关切换；锁屏不触发。
// 注入 SpringBoard 与各 App：手势在本进程的 keyWindow 上识别；
// 录屏开关只在 SpringBoard 进程执行，App 进程发 Darwin 通知请 SpringBoard 代劳。
// 设置页“手指合拢手势”两个开关：三指合拢 / 四指合拢（默认都开）。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>

// ---------- 私有类前置声明（仅供编译，运行时用 respondsToSelector 兜底） ----------
@interface SBScreenRecordingController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isRecording;
- (BOOL)recording;
- (void)startRecording;
- (void)stopRecording;
- (void)toggleRecording;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isLocked;
@end

// ---------- 常量 ----------
static NSString * const kPrefsPath = @"/var/mobile/Library/Preferences/com.zzw757026112.pinchSnap.plist";
static NSString * const kKeyThreeFinger = @"ThreeFingerEnabled"; // 三指合拢
static NSString * const kKeyFourFinger  = @"FourFingerEnabled";  // 四指合拢

// Snapper3 官方文档的 Darwin 通知（标准模式）
static const char *kSnapper3StandardOpen = "com.jontelang.snapper3.force.open";
// 本插件内部：请 SpringBoard 切换录屏
static const char *kToggleRecordingNote = "com.zzw757026112.pinchSnap.toggleRecording";

// 合拢判定：手指间距平均缩小超过这么多点即触发
static const CGFloat kPinchThreshold = 35.0;

// ---------- 自定义合拢手势识别器 ----------
// 只认“指定手指数的向内合拢”。张开、平移、手指数不对都会失败，不挡 App 自己的手势。
@interface PinchInGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) NSUInteger requiredFingerCount;
@property (nonatomic, assign) CGFloat pinchThreshold;
@end

@implementation PinchInGestureRecognizer {
    NSMutableDictionary<NSValue *, NSValue *> *_points; // touch -> 当前点
    CGFloat _initialSpread;
    BOOL _initialSpreadSet;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget:target action:action];
    if (self) {
        _points = [NSMutableDictionary dictionary];
        _pinchThreshold = kPinchThreshold;
        self.cancelsTouchesInView = NO;
        self.delaysTouchesBegan = NO;
    }
    return self;
}

- (CGFloat)currentSpread {
    if (_points.count == 0) return 0;
    CGPoint c = CGPointZero;
    for (NSValue *v in _points.allValues) {
        CGPoint p = [v CGPointValue];
        c.x += p.x;
        c.y += p.y;
    }
    c.x /= _points.count;
    c.y /= _points.count;
    CGFloat total = 0;
    for (NSValue *v in _points.allValues) {
        CGPoint p = [v CGPointValue];
        total += hypot(p.x - c.x, p.y - c.y);
    }
    return total / _points.count;
}

- (void)resetTracking {
    [_points removeAllObjects];
    _initialSpread = 0;
    _initialSpreadSet = NO;
}

- (void)reset {
    [super reset];
    [self resetTracking];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateFailed) return;
    for (UITouch *t in touches) {
        _points[[NSValue valueWithNonretainedObject:t]] = [NSValue valueWithCGPoint:[t locationInView:self.view]];
    }
    // 手指数超了就失败（比如三指识别器遇到第四根手指）
    if (_points.count > self.requiredFingerCount) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    if (_points.count == self.requiredFingerCount && !_initialSpreadSet) {
        _initialSpread = [self currentSpread];
        _initialSpreadSet = YES;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateFailed || !_initialSpreadSet) return;
    for (UITouch *t in touches) {
        NSValue *key = [NSValue valueWithNonretainedObject:t];
        if (_points[key]) {
            _points[key] = [NSValue valueWithCGPoint:[t locationInView:self.view]];
        }
    }
    CGFloat spread = [self currentSpread];
    if (_initialSpread - spread >= self.pinchThreshold) {
        self.state = UIGestureRecognizerStateRecognized;
    } else if (spread - _initialSpread >= self.pinchThreshold) {
        self.state = UIGestureRecognizerStateFailed; // 张开，不是合拢
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateFailed;
    }
    [self resetTracking];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    if (self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateFailed;
    }
    [self resetTracking];
}

@end

// ---------- 管理器 ----------
@interface PinchSnapManager : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)setup;
- (void)reloadPrefs;
- (void)toggleScreenRecording;
@end

static void prefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[PinchSnapManager shared] reloadPrefs];
}

static void toggleRecordingCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[PinchSnapManager shared] toggleScreenRecording];
}

@implementation PinchSnapManager {
    NSDictionary *_prefs;
}

+ (instancetype)shared {
    static PinchSnapManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (BOOL)isSpringBoard {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

// 锁屏判断：只在 SpringBoard 进程里查；App 在前台时设备一定已解锁
- (BOOL)isLocked {
    if (![self isSpringBoard]) return NO;
    Class lsm = objc_getClass("SBLockScreenManager");
    if (lsm) {
        id mgr = [lsm sharedInstance];
        if (mgr && [mgr respondsToSelector:@selector(isUILocked)]) {
            return [mgr isUILocked];
        }
    }
    Class ui = objc_getClass("SBUIController");
    if (ui) {
        id ctl = [ui sharedInstance];
        if (ctl && [ctl respondsToSelector:@selector(isLocked)]) {
            return [ctl isLocked];
        }
    }
    return NO;
}

// ---------- 设置 ----------
- (void)reloadPrefs {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    _prefs = d ?: @{};
}

- (BOOL)prefBool:(NSString *)key default:(BOOL)def {
    NSNumber *v = _prefs[key];
    return v ? [v boolValue] : def;
}

- (BOOL)threeFingerEnabled { return [self prefBool:kKeyThreeFinger default:YES]; }
- (BOOL)fourFingerEnabled  { return [self prefBool:kKeyFourFinger default:YES]; }

// ---------- 手势挂载 ----------
// iOS 13+ 的取 keyWindow 写法（UIApplication.keyWindow 自 iOS 13 废弃，
// Theos 默认 -Werror 会把它变成编译错误，所以改走 UIWindowScene）。
- (UIWindow *)ps_keyWindow {
    UIApplication *app = [UIApplication sharedApplication];
    for (UIScene *scene in app.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive
            && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindow *w = ((UIWindowScene *)scene).keyWindow;
            if (w) return w;
        }
    }
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindow *w = ((UIWindowScene *)scene).keyWindow;
            if (w) return w;
        }
    }
    return nil;
}

- (void)attachToKeyWindow {
    UIWindow *w = [self ps_keyWindow];
    if (!w) return;
    for (UIGestureRecognizer *gr in [w.gestureRecognizers copy]) {
        if ([gr isKindOfClass:[PinchInGestureRecognizer class]]) {
            [w removeGestureRecognizer:gr];
        }
    }
    PinchInGestureRecognizer *three = [[PinchInGestureRecognizer alloc] initWithTarget:self action:@selector(handleThreeFinger:)];
    three.requiredFingerCount = 3;
    three.pinchThreshold = kPinchThreshold;
    three.delegate = self;
    [w addGestureRecognizer:three];

    PinchInGestureRecognizer *four = [[PinchInGestureRecognizer alloc] initWithTarget:self action:@selector(handleFourFinger:)];
    four.requiredFingerCount = 4;
    four.pinchThreshold = kPinchThreshold;
    four.delegate = self;
    [w addGestureRecognizer:four];
}

// 不挡 App 自己的手势（滚动、双指捏合等）
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handleThreeFinger:(PinchInGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateRecognized) return;
    if (![self threeFingerEnabled]) return;
    if ([self isLocked]) return;
    // Snapper3 标准模式
    notify_post(kSnapper3StandardOpen);
}

- (void)handleFourFinger:(PinchInGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateRecognized) return;
    if (![self fourFingerEnabled]) return;
    if ([self isLocked]) return;
    if ([self isSpringBoard]) {
        [self toggleScreenRecording];
    } else {
        notify_post(kToggleRecordingNote);
    }
}

// ---------- 录屏开关（只在 SpringBoard 进程跑） ----------
- (void)toggleScreenRecording {
    if (![self isSpringBoard]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = objc_getClass("SBScreenRecordingController");
        if (!cls) return;
        SBScreenRecordingController *ctl = [cls sharedInstance];
        if (!ctl) return;
        // 先看当前是不是在录
        BOOL recording = NO;
        if ([ctl respondsToSelector:@selector(isRecording)]) {
            recording = [ctl isRecording];
        } else if ([ctl respondsToSelector:@selector(recording)]) {
            recording = [ctl recording];
        }
        if ([ctl respondsToSelector:@selector(toggleRecording)]) {
            [ctl toggleRecording];
            return;
        }
        if (recording) {
            if ([ctl respondsToSelector:@selector(stopRecording)]) [ctl stopRecording];
        } else {
            if ([ctl respondsToSelector:@selector(startRecording)]) [ctl startRecording];
        }
    });
}

- (void)setup {
    [self reloadPrefs];
    // 设置改动刷新缓存
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        prefsChangedCallback, CFSTR("com.zzw757026112.pinchSnap.prefsChanged"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    // SpringBoard 接 App 进程发来的录屏切换请求
    if ([self isSpringBoard]) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            toggleRecordingCallback, CFSTR("com.zzw757026112.pinchSnap.toggleRecording"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    [self attachToKeyWindow];
    // keyWindow 会变（弹窗、切 App），跟过去重新挂
    [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [[PinchSnapManager shared] attachToKeyWindow];
    }];
}

@end

%ctor {
    // 只在有界面的进程里激活（SpringBoard / App），守护进程直接退出
    if (NSClassFromString(@"UIApplication") == nil) return;
    // 晚一点再挂，等 keyWindow 建好
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[PinchSnapManager shared] setup];
    });
}
