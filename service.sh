#!/system/bin/sh

wait_sys_boot_completed() {
    local i=9
    until [ "$(getprop sys.boot_completed)" == "1" ] || [ $i -le 0 ]; do
        i=$((i-1))
        sleep 9
    done
}
wait_sys_boot_completed
MODDIR="${0%/*}"
cd "$MODDIR"

nohup "${MODDIR}/AppOpt" >/dev/null 2>&1 &
echo $! > "${MODDIR}/AppOpt.pid"

pid=$(cat "${MODDIR}/AppOpt.pid")
if kill -0 "$pid" 2>/dev/null; then
    STATUS="【当前状态：线程生效】"
else
    STATUS="【当前状态：未线程优化】"
fi
BASE_DESC="目录地址：${MODDIR}/"
NEW_DESC="${STATUS} ${BASE_DESC}"
TEMP_PROP="$MODDIR/module.prop.tmp"
grep -v '^description=' "$MODDIR/module.prop" 2>/dev/null > "$TEMP_PROP"
echo "description=$NEW_DESC" >> "$TEMP_PROP"
mv "$TEMP_PROP" "$MODDIR/module.prop"