include $(TOPDIR)/rules.mk
PKG_NAME:=luci-app-universal-openwrt
PKG_RELEASE:=1
include $(INCLUDE_DIR)/package.mk
PKGARCH:=all
define Package/luci-app-universal-openwrt
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Universal OpenWrt manager
  DEPENDS:=+luci +luci-base +rpcd +rpcd-mod-ucode +ucode
endef
define Package/luci-app-universal-openwrt/description
  LuCI management interface for Universal OpenWrt adaptive DPI/DNS/WARP stack.
endef
define Build/Compile
endef
define Package/luci-app-universal-openwrt/install
	$(CP) ./root/* $(1)/
	$(CP) ./htdocs/* $(1)/
endef
$(eval $(call BuildPackage,luci-app-universal-openwrt))
