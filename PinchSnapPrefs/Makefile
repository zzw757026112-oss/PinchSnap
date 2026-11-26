include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PinchSnapPrefs
PinchSnapPrefs_FILES = RootListController.m
PinchSnapPrefs_INSTALL_PATH = /Library/PreferenceBundles
PinchSnapPrefs_FRAMEWORKS = UIKit
PinchSnapPrefs_CFLAGS = -fobjc-arc
# 注意：不要加 PRIVATE_FRAMEWORKS = Preferences。Theos 的 SDK 里没有
# Preferences 框架的链接库，链接器会报 framework not found（上一轮
# dynamic_lookup 没修好就是这个原因：dynamic_lookup 只放行未定义符号，
# 找不到框架本身还是会失败）。PSListController 只靠前向声明 +
# -Wl,-undefined,dynamic_lookup，运行时由设置 App（已加载 Preferences）解析。
PinchSnapPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
