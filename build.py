#!/usr/bin/env python3
"""
AppOpt 模块打包脚本
将项目文件打包为可刷入的 Magisk/KernelSU 模块 zip
"""

import zipfile
import os
import sys
import io
from datetime import datetime

# 修复 Windows 终端编码问题
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# 模块名称和版本
MODULE_NAME = "AppOpt"
VERSION = "v8"

# 需要打包的文件和目录
INCLUDE_ITEMS = [
    "META-INF",
    "bin",
    "webroot",
    "customize.sh",
    "module.prop",
    "service.sh",
    "uninstall.sh",
    "applist.conf",
]

# 排除的文件模式
EXCLUDE_PATTERNS = [
    "__pycache__",
    ".pyc",
    ".DS_Store",
    "Thumbs.db",
]


def should_exclude(filepath):
    """检查文件是否应被排除"""
    for pattern in EXCLUDE_PATTERNS:
        if pattern in filepath:
            return True
    return False


def build_module():
    """打包模块为 zip 文件"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    # 生成输出文件名
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"{MODULE_NAME}-{VERSION}.zip"

    # 检查所有必要文件是否存在
    missing = []
    for item in INCLUDE_ITEMS:
        if not os.path.exists(item):
            missing.append(item)

    if missing:
        print(f"❌ 缺少以下文件/目录:")
        for m in missing:
            print(f"   - {m}")
        sys.exit(1)

    # 打包
    file_count = 0
    with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as zf:
        for item in INCLUDE_ITEMS:
            if os.path.isfile(item):
                if not should_exclude(item):
                    zf.write(item)
                    file_count += 1
                    print(f"  📄 {item}")
            elif os.path.isdir(item):
                for root, dirs, files in os.walk(item):
                    # 排除隐藏目录
                    dirs[:] = [d for d in dirs if not d.startswith(".")]
                    for f in files:
                        filepath = os.path.join(root, f)
                        if not should_exclude(filepath):
                            zf.write(filepath)
                            file_count += 1
                            print(f"  📄 {filepath}")

    # 获取文件大小
    size_bytes = os.path.getsize(output_file)
    if size_bytes > 1024 * 1024:
        size_str = f"{size_bytes / 1024 / 1024:.1f} MB"
    else:
        size_str = f"{size_bytes / 1024:.1f} KB"

    print(f"\n✅ 打包完成: {output_file}")
    print(f"   文件数量: {file_count}")
    print(f"   文件大小: {size_str}")
    print(f"\n   可直接通过 Magisk/KernelSU 刷入此 zip 文件")


if __name__ == "__main__":
    build_module()
