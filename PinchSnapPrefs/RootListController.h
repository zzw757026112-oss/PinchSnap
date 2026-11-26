#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>

// 注意：编译要 import 这个头文件（子类化 PSListController 必须看到它
// 完整的 @interface，前向声明不够用）。链接不要找 Preferences 框架
// （Theos 的 SDK 里没有它的链接库，Makefile 里不要写
// PRIVATE_FRAMEWORKS = Preferences）；符号靠
// -Wl,-undefined,dynamic_lookup，运行时由设置 App（已加载
// Preferences）解析。

@interface RootListController : PSListController
@end

// 告诉编译器这个方法存在（它本来就在 PSListController 上），避免
// “instance method not found” 警告变成 -Werror 编译错误。
@interface PSListController (PinchSnap)
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end
