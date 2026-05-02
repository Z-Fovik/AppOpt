#!/system/bin/sh

# 卸载时清理模块运行时产生的临时文件和日志
MODDIR="/data/adb/modules/AppOpt"

# 清理日志文件
rm -f "$MODDIR/【自动规则生成日志】.log"
rm -f "$MODDIR/【模块校验结果日志】.log"
rm -f "$MODDIR/【自动获取包名日志】.log"
rm -f "$MODDIR/【线程占用日志】.log"

# 清理临时文件
rm -f "$MODDIR/【生成的规则】.txt"
rm -f "$MODDIR/temp_pkg_list.txt"
rm -f "$MODDIR/module.prop.tmp"

# 清理临时监控目录
rm -rf "/data/local/tmp/thread_monitor"

# 清理主程序二进制
rm -f "$MODDIR/AppOpt"

# 清理工具脚本
rm -f "$MODDIR/【自动规则生成工具】.sh"
rm -f "$MODDIR/【模块生效校验工具】.sh"
rm -f "$MODDIR/【自动获取包名生成规则工具】.sh"
rm -f "$MODDIR/【线程占用检测工具】.sh"

# 清理规则配置备份目录
rm -rf "$MODDIR/规则配置备份/"

# 清理配置文件
rm -f "$MODDIR/applist.conf"

# 清理 PID 文件
rm -f "$MODDIR/AppOpt.pid"
