include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PinchSnapPrefs
PinchSnapPrefs_FILES = RootListController.m
PinchSnapPrefs_INSTALL_PATH = /Library/PreferenceBundles
PinchSnapPrefs_FRAMEWORKS = UIKit
PinchSnapPrefs_PRIVATE_FRAMEWORKS = Preferences
PinchSnapPrefs_CFLAGS = -fobjc-arc
# PSListController 在私有 Preferences 框架里，链接时解析不到会报
# linker command failed；和主插件一样改走动态查找，运行时由设置 App
#（已加载 Preferences）解析。
PinchSnapPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
