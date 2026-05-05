include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singboxwall
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=SingBoxWall maintainers

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for SingBoxWall
  DEPENDS:=+luci-base +sing-box +jsonfilter +ucode +uclient-fetch +ca-bundle +ip-full +nftables +kmod-tun
  PKGARCH:=all
  URL:=https://github.com/0zheermao0/singboxwall
  MAINTAINER:=$(PKG_MAINTAINER)
endef

define Package/$(PKG_NAME)/description
  SingBoxWall is a sing-box-only LuCI application for transparent proxying,
  rule-set based routing, DNS handling, subscriptions, server mode, and backups.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/singboxwall
/etc/singboxwall/
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www/
	$(INSTALL_DIR) $(1)/
	$(CP) ./root/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))