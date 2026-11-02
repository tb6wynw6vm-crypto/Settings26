TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Settings26
Settings26_FILES = Tweak.x
Settings26_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
