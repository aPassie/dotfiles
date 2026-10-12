#!/bin/sh
# Builds glass-shim.so next to this script (to a temporary name first, so a running Dolphin keeps its copy).
cd "$(dirname "$0")" && g++ -O2 -shared -fPIC -std=c++17 -fvisibility=hidden \
    $(pkg-config --cflags Qt6Widgets) -I/usr/include/KF6/KIOFileWidgets -I/usr/include/KF6/KIOCore -I/usr/include/KF6/KIOWidgets -I/usr/include/KF6/KIOGui -I/usr/include/KF6/KIO -I/usr/include/KF6 \
    glass-shim.cpp -o glass-shim.so.new -lKF6KIOFileWidgets -lQt6Widgets -lQt6Gui -lQt6Core && mv glass-shim.so.new glass-shim.so
