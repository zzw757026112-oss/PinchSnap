#import <UIKit/UIKit.h>

// PSListController 在私有 Preferences 框架里。编译不 import 该头文件、
// 链接不找 Preferences 框架（Theos 的 SDK 里没有它的链接库，链接会报
// framework not found），只前向声明；运行时由设置 App（已加载
// Preferences）解析符号。
@class PSListController;

@interface RootListController : PSListController
@end

// 告诉编译器这个方法存在（它本来就在 PSListController 上），避免
// “instance method not found” 警告变成 -Werror 编译错误。
@interface PSListController (PinchSnap)
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end
