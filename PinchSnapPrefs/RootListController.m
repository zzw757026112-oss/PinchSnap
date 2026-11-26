#import "RootListController.h"

@implementation RootListController

// 不用 _specifiers 缓存（它是 PSListController 私有头文件里的 ivar，
// 不 import 头文件就看不到）。直接每次从 plist 读，设置页的 plist 很小，
// 开销可忽略。
- (NSArray *)specifiers {
    return [self loadSpecifiersFromPlistName:@"Root" target:self];
}

@end
