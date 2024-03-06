#!/bin/bash -ex

BUILDBIN=/yuzu/build/bin
BINFILE=yuzu-x86_64.AppImage
LOG_FILE=$HOME/curl.log
BRANCH=`echo ${GITHUB_REF##*/}`
export CC=${GCC_BINARY}
export CXX=${GXX_BINARY}

cd /tmp
	curl -sLO "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"
	curl -sLO "https://github.com/$GITHUB_REPOSITORY/raw/$BRANCH/.github/workflows/update.tar.gz"
	curl -sL https://github.com$(curl https://github.com/probonopd/go-appimage/releases/expanded_assets/continuous | grep "mkappimage-.*-x86_64.AppImage" | head -n 1 | cut -d '"' -f 2) -o mkappimage.AppImage
	tar -xzf update.tar.gz
	chmod a+x linuxdeployqt*.AppImage
	chmod a+x mkappimage.AppImage
./linuxdeployqt-continuous-x86_64.AppImage --appimage-extract
cd $HOME
mkdir -p squashfs-root/usr/bin
cp -P "$BUILDBIN"/yuzu $HOME/squashfs-root/usr/bin/

curl -sL https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$BRANCH/dist/yuzu.svg -o ./squashfs-root/yuzu.svg
curl -sL https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$BRANCH/dist/yuzu.desktop -o ./squashfs-root/yuzu.desktop
curl -sL https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64 -o ./squashfs-root/runtime
mkdir -p squashfs-root/usr/share/applications && cp ./squashfs-root/yuzu.desktop ./squashfs-root/usr/share/applications
mkdir -p squashfs-root/usr/share/icons && cp ./squashfs-root/yuzu.svg ./squashfs-root/usr/share/icons
mkdir -p squashfs-root/usr/share/icons/hicolor/scalable/apps && cp ./squashfs-root/yuzu.svg ./squashfs-root/usr/share/icons/hicolor/scalable/apps
mkdir -p squashfs-root/usr/share/pixmaps && cp ./squashfs-root/yuzu.svg ./squashfs-root/usr/share/pixmaps
curl -sL "https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$BRANCH/.github/workflows/update.sh" -o $HOME/squashfs-root/update.sh
chmod a+x ./squashfs-root/runtime
chmod a+x ./squashfs-root/update.sh

version=$(cat /yuzu/README.md | grep -o 'early-access [[:digit:]]*' | cut -c 14-17) 
echo EA-$version > $HOME/squashfs-root/version.txt

unset QT_PLUGIN_PATH
unset LD_LIBRARY_PATH
unset QTDIR

mkdir $HOME/artifacts/
mkdir -p /yuzu/artifacts/version
# Version AppImage
    mkdir -p squashfs-root/usr/optional/{libstdc++,libgcc_s}
    mkdir -p squashfs-root/usr/lib
    cp /usr/lib/x86_64-linux-gnu/libstdc++.so.6 ./squashfs-root/usr/optional/libstdc++/
    cp /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 ./squashfs-root/usr/optional/libgcc_s/
    cp /usr/lib/x86_64-linux-gnu/libgio-2.0.so.0 ./squashfs-root/usr/lib
    curl -sSfL https://github.com/RPCS3/AppImageKit-checkrt/releases/download/continuous2/AppRun-patched-x86_64 -o ./squashfs-root/AppRun.wrapped
# create AppRun
cat << 'EOF' > $HOME/squashfs-root/AppRun
#! /usr/bin/env bash
set -e
this_dir="$(readlink -f "$(dirname "$0")")"
#GDK_PIXBUF
export GDK_PIXBUF_MODULEDIR=$(pkg-config --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0)
export GDK_PIXBUF_MODULE_FILE=$(pkg-config --variable=gdk_pixbuf_cache_file gdk-pixbuf-2.0)
exec "$this_dir"/AppRun.wrapped "$@"
EOF
    chmod a+x ./squashfs-root/{AppRun,AppRun.wrapped}
    curl -sSfL https://github.com/RPCS3/AppImageKit-checkrt/releases/download/continuous2/exec-x86_64.so -o ./squashfs-root/usr/optional/exec.so
    printf "#include <sstream>\n#include <exception>\n#include <memory_resource>\nint main(){auto x = std::stringbuf();x.get_allocator();std::make_exception_ptr(0);std::pmr::get_default_resource();}" \
    | $CXX -x c++ -std=c++2a -o ./squashfs-root/usr/optional/checker -
# Build AppDir
/tmp/squashfs-root/AppRun $HOME/squashfs-root/usr/bin/yuzu -unsupported-allow-new-glibc -no-copy-copyright-files -no-translations -bundle-non-qt-libs
export PATH=$(readlink -f /tmp/squashfs-root/usr/bin/):$PATH
	mkdir $HOME/squashfs-root/usr/plugins/platformthemes/
	cp /opt/qt515/plugins/platformthemes/libqgtk3.so $HOME/squashfs-root/usr/plugins/platformthemes/
	rm $HOME/squashfs-root/usr/lib/libglib-2.0.so.0
VERSION=pineapple /tmp/mkappimage.AppImage --appimage-extract-and-run $HOME/squashfs-root
mv ./yuzu-pineapple-x86_64.AppImage /yuzu/artifacts/version/Yuzu-EA-$version.AppImage

# Continuous AppImage
mv $HOME/squashfs-root/AppRun.wrapped ./squashfs-root/AppRun-patched
rm $HOME/squashfs-root/AppRun
curl -sL "https://raw.githubusercontent.com/$GITHUB_REPOSITORY/$BRANCH/.github/workflows/AppRun" -o $HOME/squashfs-root/AppRun
chmod a+x ./squashfs-root/AppRun
mv /tmp/update/AppImageUpdate $HOME/squashfs-root/usr/bin/
mv /tmp/update/* $HOME/squashfs-root/usr/lib/
/tmp/squashfs-root/usr/bin/appimagetool $HOME/squashfs-root -u "gh-releases-zsync|pineappleEA|pineapple-src|continuous|yuzu-x86_64.AppImage.zsync"
#	mv yuzu-x86_64.AppImage old.AppImage
#VERSION=pineapple /tmp/mkappimage.AppImage --appimage-extract-and-run $HOME/squashfs-root -u "gh-releases-zsync|pineappleEA|pineapple-src|continuous|yuzu-x86_64.AppImage.zsync"

#mv yuzu-pineapple-x86_64.AppImage yuzu-x86_64.AppImage
mv yuzu-x86_64.AppImage* /yuzu/artifacts

cp -R $HOME/artifacts/ /yuzu/
#cp "$BUILDBIN"/yuzu /yuzu/artifacts/version/
chmod -R 777 /yuzu/artifacts
cd /yuzu/artifacts
ls -al /yuzu/artifacts/
ls -al /yuzu/artifacts/version
