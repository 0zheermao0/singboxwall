include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singboxwall
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=SingBoxWall maintainers

LUCI_TITLE:=LuCI support for SingBoxWall
LUCI_DEPENDS:=+luci-base +sing-box +jsonfilter +ucode +uclient-fetch +ca-bundle +ip-full +nftables +kmod-tun
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/singboxwall
/etc/singboxwall/
endef

include $(TOPDIR)/feeds/luci/luci.mk


# call BuildPackage - OpenWrt buildroot signature
