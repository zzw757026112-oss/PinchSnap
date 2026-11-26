# 手指合拢手势 — PinchSnap
# Theos tweak (rootless, iOS 16) + PreferenceLoader 设置页
# 产物：.deb（Sileo/Zebra 安装），含主插件 + 设置页

THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET = iphone:clang:latest:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PinchSnap
PinchSnap_FILES = Tweak.x
PinchSnap_FRAMEWORKS = UIKit Foundation
PinchSnap_CFLAGS = -fobjc-arc
PinchSnap_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += PinchSnapPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
