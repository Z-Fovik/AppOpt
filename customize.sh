#!/system/bin/sh

SKIPUNZIP=0

check_magisk_version() {
	ui_print "- Magisk version: $MAGISK_VER_CODE"
	ui_print "- Module version: $(grep_prop version "${TMPDIR}/module.prop")"
	ui_print "- Module versionCode: $(grep_prop versionCode "${TMPDIR}/module.prop")"
	ui_print "********************************************"
	ui_print "- $(grep_prop description "${TMPDIR}/module.prop")"
	if [ "$MAGISK_VER_CODE" -lt 20400 ]; then
		ui_print "********************************************"
		ui_print "! 请安装 Magisk v20.4+ (20400+)"
		abort    "********************************************"
	fi
}

check_required_files() {
	REQUIRED_FILE_LIST="/sys/devices/system/cpu/present /proc/loadavg"
	for REQUIRED_FILE in $REQUIRED_FILE_LIST; do
		if [ ! -e "$REQUIRED_FILE" ]; then
			ui_print "********************************************"
			ui_print "! $REQUIRED_FILE 文件不存在"
			ui_print "! 请联系模块作者"
			abort    "********************************************"
		fi
	done
}

extract_bin() {
	ui_print "********************************************"
	if [ "$ARCH" == "arm" ]; then
		cp "$MODPATH/bin/armeabi-v7a/AppOpt" "$MODPATH"
	elif [ "$ARCH" == "arm64" ]; then
		cp "$MODPATH/bin/arm64-v8a/AppOpt" "$MODPATH"
	elif [ "$ARCH" == "x86" ]; then
		cp "$MODPATH/bin/x86/AppOpt" "$MODPATH"
	elif [ "$ARCH" == "x64" ] || [ "$ARCH" == "x86_64" ]; then
		cp "$MODPATH/bin/x86_64/AppOpt" "$MODPATH"
	else
		abort "! Unsupported platform: $ARCH"
	fi
	ui_print "- Device platform: $ARCH"
	rm -rf "$MODPATH/bin"
	[ -f "$MODPATH/AppOpt" ] && chmod 755 "$MODPATH/AppOpt"
	if ! "$MODPATH/AppOpt" -v >/dev/null 2>&1; then
		abort "! 主程序验证失败，请检查模块zip文件是否损坏"
	fi
	ui_print "- 主程序校验通过"
}


format_cpu_ranges() {
	[ -z "${1// /}" ] && { cat /sys/devices/system/cpu/present; return; }
	awk -v input="$1" 'BEGIN {
		n = split(input, arr, /[[:space:]]+/)
		j = 0
		for (i = 1; i <= n; i++) {
			if (arr[i] != "" && !seen[arr[i]]++) 
				nums[++j] = arr[i] + 0
		}
		n = j
		if (!n) exit
		for (i = 1; i < n; i++) {
			min = i
			for (j = i + 1; j <= n; j++)
				if (nums[j] < nums[min]) min = j
			if (min != i) {
				t = nums[i]
				nums[i] = nums[min]
				nums[min] = t
			}
		}
		start = last = nums[1]
		for (i = 2; i <= n; i++) {
			if (nums[i] == last + 1) {
				last = nums[i]
				continue
			}
			printf "%s%s", sep, (start == last ? start : start "-" last)
			sep = ","
			start = last = nums[i]
		}
		printf "%s", sep
		printf (start == last ? start : start "-" last)
	}'
}

sorted_groups=$(
	for policy in /sys/devices/system/cpu/cpufreq/policy*; do
		[ -d "$policy" ] || continue
		cpus=$(cat "$policy/related_cpus" 2>/dev/null)
		freq=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
		[ -z "$cpus" ] || [ -z "$freq" ] && continue
		echo "$freq:$cpus"
	done | sort -n -t: -k1,1 | awk -F: '
	$1 == prev { cores = cores " " $2; next }
	prev != "" { print prev ":" cores; cores = "" }
	{ prev = $1; cores = $2 }
	END { if (prev != "") print prev ":" cores }'
)

eval "$(echo "$sorted_groups" | awk -F: '
BEGIN {
	e_core = ""; p_core = ""; hp_core = ""
	e_core_freq = 0; p_core_freq = 0; hp_core_freq = 0
	total_groups = 0
}
{
	freq_arr[NR] = $1
	cpus_arr[NR] = $2
	total_groups = NR
}
END {
	if (total_groups == 0) {
		print "e_core=\"\"; e_core_freq=0; p_core=\"\"; p_core_freq=0; hp_core=\"\"; hp_core_freq=0; total_groups=0;"
		exit
	}
	e_core = cpus_arr[1]
	e_core_freq = freq_arr[1]
	if (total_groups >= 2) {
		hp_core = cpus_arr[total_groups]
		hp_core_freq = freq_arr[total_groups]
	}
	if (total_groups >= 3) {
		p_core = ""
		p_core_freq = 0
		for (i = 2; i < total_groups; i++) {
			p_core = p_core (p_core == "" ? "" : " ") cpus_arr[i]
			if (freq_arr[i] > p_core_freq) p_core_freq = freq_arr[i]
		}
	}
	printf "e_core=\"%s\"; e_core_freq=%d; ", e_core, e_core_freq
	printf "p_core=\"%s\"; p_core_freq=%d; ", p_core, p_core_freq
	printf "hp_core=\"%s\"; hp_core_freq=%d; ", hp_core, hp_core_freq
	printf "total_groups=%d;", total_groups
}')"
all_core="$(cat /sys/devices/system/cpu/present)"

module_instructions() {
    ui_print "********************************************"
    ui_print "- 模块安装完成"
    ui_print "- 请重启手机生效"
    ui_print "- 模块目录：/data/adb/modules/AppOpt/"
    ui_print "- 规则配置文件：applist.conf"
    ui_print "- 自动规则生成工具：【自动规则生成工具】.sh"
    ui_print "- 模块生效校验工具：【模块生效校验工具】.sh"
    ui_print "- 自动获取包名生成规则工具：【自动获取包名生成规则工具】.sh"
    ui_print "- 线程占用检测工具：【线程占用检测工具】.sh"
    ui_print "-******************更新日志****************"
    ui_print "- 20260505更新，添加更多线程优化规则和web美化"
    ui_print "********************************************"
}

add_default_rules() {
    [ ! -d "$MODPATH" ] && mkdir -p "$MODPATH"
    if [ -f "${TMPDIR}/applist.conf" ]; then
        cp -f "${TMPDIR}/applist.conf" "$MODPATH/applist.conf"
        ui_print "- 已加载用户自定义applist.conf规则"
    else
        touch "$MODPATH/applist.conf"
        ui_print "- 已创建空配置文件"
    fi
    chmod 644 "$MODPATH/applist.conf"
}

deploy_auto_rule_tool() {
    TOOL_PATH="$MODPATH/【自动规则生成工具】.sh"
    cat > "$TOOL_PATH" << 'TOOL_EOF'
#!/system/bin/sh

CONF_PATH="/data/adb/modules/AppOpt/applist.conf"
BAK_DIR="/data/adb/modules/AppOpt/规则配置备份"
TEMP_RULE="/data/adb/modules/AppOpt/【生成的规则】.txt"
RUN_LOG="/data/adb/modules/AppOpt/【自动规则生成日志】.log"

echo "===== 自动规则生成工具 运行日志 $(date +%Y年%m月%d日_%H时%M分%S秒) =====" > "$RUN_LOG"

env_check() {
    echo "【1/4】开始环境校验" >> "$RUN_LOG"
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 错误：请用ROOT权限运行此工具！" | tee -a "$RUN_LOG"
        echo "MT管理器运行请勾选「以ROOT权限执行」" | tee -a "$RUN_LOG"
        sleep 3
        exit 1
    fi
    echo "✅ ROOT权限校验通过" >> "$RUN_LOG"

    if [ ! -f "$CONF_PATH" ]; then
        echo "❌ 错误：未找到模块配置文件！" | tee -a "$RUN_LOG"
        echo "请确认模块已正常刷入，路径：$CONF_PATH" | tee -a "$RUN_LOG"
        sleep 3
        exit 1
    fi
    echo "✅ 配置文件校验通过，路径：$CONF_PATH" >> "$RUN_LOG"

    mkdir -p "$BAK_DIR"
    echo "✅ 备份目录就绪：$BAK_DIR" >> "$RUN_LOG"
    echo "✅ 环境校验全部通过" | tee -a "$RUN_LOG"
    echo ""
}

load_templates_from_conf() {
    echo "【2/4】开始加载配置文件中的自定义模板" >> "$RUN_LOG"
    
    DEFAULT_APP_TEMPLATE="
# =================={{APP_NAME}}=====================
{{PKG_NAME}}{{PKG_NAME}}=3-4
{{PKG_NAME}}{Thread-*}=3-4
{{PKG_NAME}}{Thread*}=3-4
{{PKG_NAME}}{*[!e]Thread}=3-4
{{PKG_NAME}}{binder:*}=0-1
{{PKG_NAME}}{MediaCodec_*}=3-4
{{PKG_NAME}}{VDecod2-*}=3-4
{{PKG_NAME}}=0-1
"
    APP_TEMPLATE=$(sed -n '/# ==== 普通APP模板 开始 ====/,/# ==== 普通APP模板 结束 ====/p' "$CONF_PATH" | \
        sed '1d;$d' | sed 's/^#//' | sed 's/^[[:space:]]*//' | grep -v '^$')
    if [ -z "$APP_TEMPLATE" ]; then
        echo "⚠️  未读取到普通APP模板，使用默认模板" | tee -a "$RUN_LOG"
        APP_TEMPLATE="$DEFAULT_APP_TEMPLATE"
    else
        echo "✅ 已加载【普通APP模板】" >> "$RUN_LOG"
    fi
    export APP_TEMPLATE

    DEFAULT_UNITY_GAME_TEMPLATE="
# =================={{APP_NAME}}=====================
{{PKG_NAME}}{Thread-*}=0-5
{{PKG_NAME}}{Job.Worker*}=2-5
{{PKG_NAME}}{*[!e]Thread}=0-5
{{PKG_NAME}}{Unity[!M]*}=3-4
{{PKG_NAME}}{NativeThread}=3-4
{{PKG_NAME}}{UnityMain}=6-7
{{PKG_NAME}}=0-5
"
    UNITY_GAME_TEMPLATE=$(sed -n '/# ==== 有UnityMain游戏模板 开始 ====/,/# ==== 有UnityMain游戏模板 结束 ====/p' "$CONF_PATH" | \
        sed '1d;$d' | sed 's/^#//' | sed 's/^[[:space:]]*//' | grep -v '^$')
    if [ -z "$UNITY_GAME_TEMPLATE" ]; then
        echo "⚠️  未读取到有UnityMain游戏模板，使用默认模板" | tee -a "$RUN_LOG"
        UNITY_GAME_TEMPLATE="$DEFAULT_UNITY_GAME_TEMPLATE"
    else
        echo "✅ 已加载【有UnityMain游戏模板】" >> "$RUN_LOG"
    fi
    export UNITY_GAME_TEMPLATE

    DEFAULT_NO_UNITY_GAME_TEMPLATE="
# =================={{APP_NAME}}=====================
{{PKG_NAME}}{*[!e]Thread}=6
{{PKG_NAME}}{Render Thread*}=6
{{PKG_NAME}}{Thread*}=0-1
{{PKG_NAME}}{NativeThread}=3-4
{{PKG_NAME}}{*GameThread}=7
{{PKG_NAME}}{MainThread}=7
{{PKG_NAME}}=0-5
"
    NO_UNITY_GAME_TEMPLATE=$(sed -n '/# ==== 无UnityMain游戏模板 开始 ====/,/# ==== 无UnityMain游戏模板 结束 ====/p' "$CONF_PATH" | \
        sed '1d;$d' | sed 's/^#//' | sed 's/^[[:space:]]*//' | grep -v '^$')
    if [ -z "$NO_UNITY_GAME_TEMPLATE" ]; then
        echo "⚠️  未读取到无UnityMain游戏模板，使用默认模板" | tee -a "$RUN_LOG"
        NO_UNITY_GAME_TEMPLATE="$DEFAULT_NO_UNITY_GAME_TEMPLATE"
    else
        echo "✅ 已加载【无UnityMain游戏模板】" >> "$RUN_LOG"
    fi
    export NO_UNITY_GAME_TEMPLATE

    echo ""
}

auto_backup_conf() {
    BAK_FILE="$BAK_DIR/配置备份_$(date +%Y年%m月%d日_%H时%M分).conf"
    cp -f "$CONF_PATH" "$BAK_FILE"
    echo "✅ 配置文件已自动备份至：$BAK_FILE" | tee -a "$RUN_LOG"
}

check_rule_exist() {
    local PKG_NAME="$1"
    local SILENT_MODE="$2"
    if grep -v "^#" "$CONF_PATH" | grep -q "^${PKG_NAME}[={]" 2>/dev/null; then
        if [ "$SILENT_MODE" = "-s" ]; then
            return 1
        else
            echo "⚠️  检测到配置文件中已存在【$PKG_NAME】的规则"
            echo "是否继续添加？(y/n，默认n)"
            read ADD_AGAIN
            ADD_AGAIN=${ADD_AGAIN:-n}
            if [ "$ADD_AGAIN" != "y" ] && [ "$ADD_AGAIN" != "Y" ]; then
                echo "❌ 已取消添加" | tee -a "$RUN_LOG"
                return 1
            fi
        fi
    fi
    return 0
}

check_pkg_name() {
    local PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "❌ 包名不能为空！" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    if ! echo "$PKG_NAME" | grep -q "\." || echo "$PKG_NAME" | grep -q "[[:space:]]"; then
        echo "❌ 包名格式无效！必须包含.且无空格" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    return 0
}

generate_app_rule_single() {
    echo "【3/4】进入单个普通前台APP规则生成模式" >> "$RUN_LOG"
    echo ""
    echo "===== 单个普通前台APP模式 ====="
    echo "📌 规则匹配标准逻辑："
    echo "   主线程/渲染/解码线程 → 3-4"
    echo "   binder交互/后台线程 → 0-1"
    echo "   主进程+所有子进程 → 0-1"
    echo "📌 适用：微信、抖音、小红书、淘宝、B站等常用应用"
    echo ""

    echo "请输入应用包名（例：com.tencent.mm）："
    read PKG_NAME
    check_pkg_name "$PKG_NAME" || return 1
    echo "输入的应用包名：$PKG_NAME" >> "$RUN_LOG"

    echo "请输入应用备注名（例：微信，用于注释）："
    read APP_NAME
    APP_NAME=${APP_NAME:-$PKG_NAME}
    echo "输入的应用备注名：$APP_NAME" >> "$RUN_LOG"

    check_rule_exist "$PKG_NAME" || return 1

    RULE_CONTENT=$(echo "$APP_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG_NAME/g" | sed "s/{{APP_NAME}}/$APP_NAME/g")

    echo "生成的规则内容：" >> "$RUN_LOG"
    echo "$RULE_CONTENT" >> "$RUN_LOG"
    echo ""
    echo "✅ 规则已生成，内容如下："
    echo "----------------------------------------"
    echo "$RULE_CONTENT"
    echo "----------------------------------------"
    echo ""

    echo "请选择后续操作："
    echo "1. 自动追加到配置文件（无需重启，即时生效）"
    echo "2. 生成到临时文件，手动复制使用"
    echo "3. 取消操作"
    read OP_CHOICE
    OP_CHOICE=${OP_CHOICE:-3}

    case $OP_CHOICE in
        1)
            auto_backup_conf
            chmod 644 "$CONF_PATH"
            echo "$RULE_CONTENT" >> "$CONF_PATH"
            echo "✅ 规则已成功追加到配置文件，无需重启，即时生效" | tee -a "$RUN_LOG"
            ;;
        2)
            echo "$RULE_CONTENT" > "$TEMP_RULE"
            chmod 644 "$TEMP_RULE"
            echo "✅ 规则已生成到临时文件：$TEMP_RULE" | tee -a "$RUN_LOG"
            echo "📌 可直接打开文件复制规则到配置文件使用"
            ;;
        *)
            echo "❌ 已取消操作" | tee -a "$RUN_LOG"
            return 1
            ;;
    esac
    echo "【4/4】单个APP规则生成完成" >> "$RUN_LOG"
    sleep 2
}

generate_game_rule_single() {
    echo "【3/4】进入单个游戏APP规则生成模式" >> "$RUN_LOG"
    echo ""
    echo "===== 单个游戏APP模式 ====="
    echo "📌 支持两种游戏规则模板，适配不同引擎手游"
    echo ""

    echo "请输入游戏包名（例：com.tencent.tmgp.sgame）："
    read PKG_NAME
    check_pkg_name "$PKG_NAME" || return 1
    echo "输入的游戏包名：$PKG_NAME" >> "$RUN_LOG"

    echo "请输入游戏备注名（例：王者荣耀，用于注释）："
    read GAME_NAME
    GAME_NAME=${GAME_NAME:-$PKG_NAME}
    echo "输入的游戏备注名：$GAME_NAME" >> "$RUN_LOG"

    check_rule_exist "$PKG_NAME" || return 1

    echo ""
    echo "请选择游戏规则模板类型："
    echo "1. 有UnityMain（适用于绝大多数Unity引擎手游，如王者荣耀、原神、金铲铲等，默认）"
    echo "2. 无UnityMain（适用于UE/自研引擎手游，如和平精英、鸣潮、暗区突围等）"
    read RULE_TYPE
    RULE_TYPE=${RULE_TYPE:-1}
    echo "选择的规则模板类型：$RULE_TYPE" >> "$RUN_LOG"

    if [ "$RULE_TYPE" = "1" ]; then
        RULE_CONTENT=$(echo "$UNITY_GAME_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG_NAME/g" | sed "s/{{APP_NAME}}/$GAME_NAME/g")
        echo "已生成【有UnityMain】规则模板" >> "$RUN_LOG"
    else
        RULE_CONTENT=$(echo "$NO_UNITY_GAME_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG_NAME/g" | sed "s/{{APP_NAME}}/$GAME_NAME/g")
        echo "已生成【无UnityMain】规则模板" >> "$RUN_LOG"
    fi

    echo "生成的规则内容：" >> "$RUN_LOG"
    echo "$RULE_CONTENT" >> "$RUN_LOG"
    echo ""
    echo "✅ 规则已生成，内容如下："
    echo "----------------------------------------"
    echo "$RULE_CONTENT"
    echo "----------------------------------------"
    echo ""

    echo "请选择后续操作："
    echo "1. 自动追加到配置文件（无需重启，即时生效）"
    echo "2. 生成到临时文件，手动复制使用"
    echo "3. 取消操作"
    read OP_CHOICE
    OP_CHOICE=${OP_CHOICE:-3}

    case $OP_CHOICE in
        1)
            auto_backup_conf
            chmod 644 "$CONF_PATH"
            echo "$RULE_CONTENT" >> "$CONF_PATH"
            echo "✅ 规则已成功追加到配置文件，无需重启，即时生效" | tee -a "$RUN_LOG"
            ;;
        2)
            echo "$RULE_CONTENT" > "$TEMP_RULE"
            chmod 644 "$TEMP_RULE"
            echo "✅ 规则已生成到临时文件：$TEMP_RULE" | tee -a "$RUN_LOG"
            echo "📌 可直接打开文件复制规则到配置文件使用"
            ;;
        *)
            echo "❌ 已取消操作" | tee -a "$RUN_LOG"
            return 1
            ;;
    esac
    echo "【4/4】单个游戏规则生成完成" >> "$RUN_LOG"
    sleep 2
}

generate_app_rule_batch() {
    echo "【3/4】进入批量普通前台APP规则生成模式" >> "$RUN_LOG"
    echo ""
    echo "===== 批量普通前台APP模式 ====="
    echo "📌 规则匹配标准逻辑，每个包名独立生成完整规则块"
    echo "📌 适用：一次性添加多个常用APP，无需逐个输入"
    echo ""

    echo "请输入多个应用包名，用空格分隔（例：com.tencent.mm com.ss.android.ugc.aweme）："
    read PKG_LIST
    if [ -z "$PKG_LIST" ]; then
        echo "❌ 未输入任何包名，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "输入的包名列表：$PKG_LIST" >> "$RUN_LOG"

    VALID_PKG_LIST=""
    INVALID_PKG_LIST=""
    for PKG in $PKG_LIST; do
        if check_pkg_name "$PKG" >/dev/null 2>&1; then
            VALID_PKG_LIST="$VALID_PKG_LIST $PKG"
        else
            INVALID_PKG_LIST="$INVALID_PKG_LIST $PKG"
        fi
    done
    VALID_PKG_LIST=$(echo "$VALID_PKG_LIST" | xargs)
    INVALID_PKG_LIST=$(echo "$INVALID_PKG_LIST" | xargs)

    if [ -z "$VALID_PKG_LIST" ]; then
        echo "❌ 所有输入的包名均无效，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "有效包名列表：$VALID_PKG_LIST" >> "$RUN_LOG"
    echo "✅ 有效包名：$VALID_PKG_LIST"
    if [ -n "$INVALID_PKG_LIST" ]; then
        echo "⚠️  无效包名（已自动跳过）：$INVALID_PKG_LIST"
        echo "无效包名列表：$INVALID_PKG_LIST" >> "$RUN_LOG"
    fi
    echo ""

    EXIST_PKG_LIST=""
    NEW_PKG_LIST=""
    for PKG in $VALID_PKG_LIST; do
        if ! check_rule_exist "$PKG" -s; then
            EXIST_PKG_LIST="$EXIST_PKG_LIST $PKG"
        else
            NEW_PKG_LIST="$NEW_PKG_LIST $PKG"
        fi
    done
    EXIST_PKG_LIST=$(echo "$EXIST_PKG_LIST" | xargs)
    NEW_PKG_LIST=$(echo "$NEW_PKG_LIST" | xargs)

    FINAL_PKG_LIST=""
    if [ -n "$EXIST_PKG_LIST" ]; then
        echo "⚠️  检测到以下包名已存在规则：$EXIST_PKG_LIST"
        echo "请选择统一处理方式："
        echo "1. 全部添加（保留原有规则，追加新规则）"
        echo "2. 跳过已存在的，仅添加新包名规则"
        echo "3. 取消操作"
        read CONFLICT_CHOICE
        CONFLICT_CHOICE=${CONFLICT_CHOICE:-3}

        case $CONFLICT_CHOICE in
            1)
                FINAL_PKG_LIST="$VALID_PKG_LIST"
                echo "已选择：全部添加" >> "$RUN_LOG"
                ;;
            2)
                FINAL_PKG_LIST="$NEW_PKG_LIST"
                echo "已选择：跳过已存在，仅添加新包名" >> "$RUN_LOG"
                ;;
            *)
                echo "❌ 已取消操作" | tee -a "$RUN_LOG"
                return 1
                ;;
        esac
    else
        FINAL_PKG_LIST="$VALID_PKG_LIST"
    fi

    if [ -z "$FINAL_PKG_LIST" ]; then
        echo "❌ 无需要生成的包名，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "最终生成包名列表：$FINAL_PKG_LIST" >> "$RUN_LOG"
    echo ""

    echo "请输入对应备注名，用空格分隔，数量和包名一致（无输入默认用包名）："
    echo "包名顺序：$FINAL_PKG_LIST"
    read NAME_LIST
    echo "输入的备注名列表：$NAME_LIST" >> "$RUN_LOG"

    TOTAL_RULE_CONTENT=""
    PKG_INDEX=1
    for PKG in $FINAL_PKG_LIST; do
        APP_NAME=$(echo "$NAME_LIST" | awk -v idx="$PKG_INDEX" '{print $idx}')
        APP_NAME=${APP_NAME:-$PKG}
        PKG_INDEX=$((PKG_INDEX+1))

        SINGLE_RULE=$(echo "$APP_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG/g" | sed "s/{{APP_NAME}}/$APP_NAME/g")
        TOTAL_RULE_CONTENT="$TOTAL_RULE_CONTENT$SINGLE_RULE"
        echo "已生成【$APP_NAME】规则" >> "$RUN_LOG"
    done

    echo ""
    echo "✅ 批量规则已全部生成，内容如下："
    echo "----------------------------------------"
    echo "$TOTAL_RULE_CONTENT"
    echo "----------------------------------------"
    echo ""

    echo "请选择后续操作："
    echo "1. 自动全部追加到配置文件（无需重启，即时生效）"
    echo "2. 全部生成到临时文件，手动复制使用"
    echo "3. 取消操作"
    read OP_CHOICE
    OP_CHOICE=${OP_CHOICE:-3}

    case $OP_CHOICE in
        1)
            auto_backup_conf
            chmod 644 "$CONF_PATH"
            echo "$TOTAL_RULE_CONTENT" >> "$CONF_PATH"
            echo "✅ 所有规则已成功追加到配置文件，无需重启，即时生效" | tee -a "$RUN_LOG"
            ;;
        2)
            echo "$TOTAL_RULE_CONTENT" > "$TEMP_RULE"
            chmod 644 "$TEMP_RULE"
            echo "✅ 所有规则已生成到临时文件：$TEMP_RULE" | tee -a "$RUN_LOG"
            echo "📌 可直接打开文件复制规则到配置文件使用"
            ;;
        *)
            echo "❌ 已取消操作" | tee -a "$RUN_LOG"
            return 1
            ;;
    esac
    echo "【4/4】批量APP规则生成完成" >> "$RUN_LOG"
    sleep 2
}

generate_game_rule_batch() {
    echo "【3/4】进入批量游戏APP规则生成模式" >> "$RUN_LOG"
    echo ""
    echo "===== 批量游戏APP模式 ====="
    echo "📌 支持两种游戏规则模板，适配不同引擎手游，每个包名独立生成完整规则块"
    echo ""

    echo "请输入多个游戏包名，用空格分隔（例：com.tencent.tmgp.sgame com.miHoYo.Yuanshen）："
    read PKG_LIST
    if [ -z "$PKG_LIST" ]; then
        echo "❌ 未输入任何包名，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "输入的包名列表：$PKG_LIST" >> "$RUN_LOG"

    VALID_PKG_LIST=""
    INVALID_PKG_LIST=""
    for PKG in $PKG_LIST; do
        if check_pkg_name "$PKG" >/dev/null 2>&1; then
            VALID_PKG_LIST="$VALID_PKG_LIST $PKG"
        else
            INVALID_PKG_LIST="$INVALID_PKG_LIST $PKG"
        fi
    done
    VALID_PKG_LIST=$(echo "$VALID_PKG_LIST" | xargs)
    INVALID_PKG_LIST=$(echo "$INVALID_PKG_LIST" | xargs)

    if [ -z "$VALID_PKG_LIST" ]; then
        echo "❌ 所有输入的包名均无效，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "有效包名列表：$VALID_PKG_LIST" >> "$RUN_LOG"
    echo "✅ 有效包名：$VALID_PKG_LIST"
    if [ -n "$INVALID_PKG_LIST" ]; then
        echo "⚠️  无效包名（已自动跳过）：$INVALID_PKG_LIST"
        echo "无效包名列表：$INVALID_PKG_LIST" >> "$RUN_LOG"
    fi
    echo ""

    EXIST_PKG_LIST=""
    NEW_PKG_LIST=""
    for PKG in $VALID_PKG_LIST; do
        if ! check_rule_exist "$PKG" -s; then
            EXIST_PKG_LIST="$EXIST_PKG_LIST $PKG"
        else
            NEW_PKG_LIST="$NEW_PKG_LIST $PKG"
        fi
    done
    EXIST_PKG_LIST=$(echo "$EXIST_PKG_LIST" | xargs)
    NEW_PKG_LIST=$(echo "$NEW_PKG_LIST" | xargs)

    FINAL_PKG_LIST=""
    if [ -n "$EXIST_PKG_LIST" ]; then
        echo "⚠️  检测到以下包名已存在规则：$EXIST_PKG_LIST"
        echo "请选择统一处理方式："
        echo "1. 全部添加（保留原有规则，追加新规则）"
        echo "2. 跳过已存在的，仅添加新包名规则"
        echo "3. 取消操作"
        read CONFLICT_CHOICE
        CONFLICT_CHOICE=${CONFLICT_CHOICE:-3}

        case $CONFLICT_CHOICE in
            1)
                FINAL_PKG_LIST="$VALID_PKG_LIST"
                echo "已选择：全部添加" >> "$RUN_LOG"
                ;;
            2)
                FINAL_PKG_LIST="$NEW_PKG_LIST"
                echo "已选择：跳过已存在，仅添加新包名" >> "$RUN_LOG"
                ;;
            *)
                echo "❌ 已取消操作" | tee -a "$RUN_LOG"
                return 1
                ;;
        esac
    else
        FINAL_PKG_LIST="$VALID_PKG_LIST"
    fi

    if [ -z "$FINAL_PKG_LIST" ]; then
        echo "❌ 无需要生成的包名，已取消" | tee -a "$RUN_LOG"
        sleep 2
        return 1
    fi
    echo "最终生成包名列表：$FINAL_PKG_LIST" >> "$RUN_LOG"
    echo ""

    echo "请选择批量生成的游戏规则模板类型："
    echo "1. 有UnityMain（适用于绝大多数Unity引擎手游，默认）"
    echo "2. 无UnityMain（适用于UE/自研引擎手游）"
    read RULE_TYPE
    RULE_TYPE=${RULE_TYPE:-1}
    echo "批量选择的规则模板类型：$RULE_TYPE" >> "$RUN_LOG"

    echo "请输入对应备注名，用空格分隔，数量和包名一致（无输入默认用包名）："
    echo "包名顺序：$FINAL_PKG_LIST"
    read NAME_LIST
    echo "输入的备注名列表：$NAME_LIST" >> "$RUN_LOG"

    TOTAL_RULE_CONTENT=""
    PKG_INDEX=1
    for PKG in $FINAL_PKG_LIST; do
        GAME_NAME=$(echo "$NAME_LIST" | awk -v idx="$PKG_INDEX" '{print $idx}')
        GAME_NAME=${GAME_NAME:-$PKG}
        PKG_INDEX=$((PKG_INDEX+1))

        if [ "$RULE_TYPE" = "1" ]; then
            SINGLE_RULE=$(echo "$UNITY_GAME_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG/g" | sed "s/{{APP_NAME}}/$GAME_NAME/g")
            echo "已生成【$GAME_NAME】有UnityMain规则" >> "$RUN_LOG"
        else
            SINGLE_RULE=$(echo "$NO_UNITY_GAME_TEMPLATE" | sed "s/{{PKG_NAME}}/$PKG/g" | sed "s/{{APP_NAME}}/$GAME_NAME/g")
            echo "已生成【$GAME_NAME】无UnityMain规则" >> "$RUN_LOG"
        fi

        TOTAL_RULE_CONTENT="$TOTAL_RULE_CONTENT$SINGLE_RULE"
    done

    echo ""
    echo "✅ 批量规则已全部生成，内容如下："
    echo "----------------------------------------"
    echo "$TOTAL_RULE_CONTENT"
    echo "----------------------------------------"
    echo ""

    echo "请选择后续操作："
    echo "1. 自动全部追加到配置文件（无需重启，即时生效）"
    echo "2. 全部生成到临时文件，手动复制使用"
    echo "3. 取消操作"
    read OP_CHOICE
    OP_CHOICE=${OP_CHOICE:-3}

    case $OP_CHOICE in
        1)
            auto_backup_conf
            chmod 644 "$CONF_PATH"
            echo "$TOTAL_RULE_CONTENT" >> "$CONF_PATH"
            echo "✅ 所有规则已成功追加到配置文件，无需重启，即时生效" | tee -a "$RUN_LOG"
            ;;
        2)
            echo "$TOTAL_RULE_CONTENT" > "$TEMP_RULE"
            chmod 644 "$TEMP_RULE"
            echo "✅ 所有规则已生成到临时文件：$TEMP_RULE" | tee -a "$RUN_LOG"
            echo "📌 可直接打开文件复制规则到配置文件使用"
            ;;
        *)
            echo "❌ 已取消操作" | tee -a "$RUN_LOG"
            return 1
            ;;
    esac
    echo "【4/4】批量游戏规则生成完成" >> "$RUN_LOG"
    sleep 2
}

main_menu() {
    echo ""
    echo "============================================="
    echo "  AppOpt 自动规则生成工具"
    echo "  双游戏规则模板 | 批量生成 | 全中文输出"
    echo "  已支持读取applist.conf自定义模板"
    echo "============================================="
    echo "📌 请选择要优化的应用类型"
    echo "1. 单个APP规则生成"
    echo "2. 批量APP规则生成"
    echo "3. 单个游戏规则生成"
    echo "4. 批量游戏规则生成"
    echo "5. 备份当前配置文件"
    echo "6. 退出工具"
    echo "============================================="
    read MENU_CHOICE
    MENU_CHOICE=${MENU_CHOICE:-6}

    case $MENU_CHOICE in
        1)
            echo ""
            generate_app_rule_single
            ;;
        2)
            echo ""
            generate_app_rule_batch
            ;;
        3)
            echo ""
            generate_game_rule_single
            ;;
        4)
            echo ""
            generate_game_rule_batch
            ;;
        5)
            echo ""
            auto_backup_conf
            ;;
        6)
            echo "✅ 工具已正常退出" | tee -a "$RUN_LOG"
            exit 0
            ;;
        *)
            echo "❌ 无效选择，请输入1-6的数字" | tee -a "$RUN_LOG"
            sleep 2
            ;;
    esac

    echo ""
    echo "按回车键返回主菜单，输入q退出工具"
    read AGAIN_CHOICE
    AGAIN_CHOICE=${AGAIN_CHOICE:-q}
    if [ "$AGAIN_CHOICE" = "q" ] || [ "$AGAIN_CHOICE" = "Q" ]; then
        echo "✅ 工具已正常退出" | tee -a "$RUN_LOG"
        exit 0
    else
        main_menu
    fi
}

env_check
load_templates_from_conf
main_menu
TOOL_EOF

    chmod 755 "$TOOL_PATH"
    chcon u:object_r:magisk_file:s0 "$TOOL_PATH" 2>/dev/null
    ui_print "- 已部署 自动规则生成工具"
}

deploy_verify_tool() {
    VERIFY_TOOL_PATH="$MODPATH/【模块生效校验工具】.sh"
    cat > "$VERIFY_TOOL_PATH" << 'VERIFY_EOF'
#!/system/bin/sh

CONF_PATH="/data/adb/modules/AppOpt/applist.conf"
VERIFY_LOG="/data/adb/modules/AppOpt/【模块校验结果日志】.log"

echo "===== AppOpt 模块校验日志 $(date +%Y年%m月%d日_%H时%M分%S秒) =====" > "$VERIFY_LOG"

echo "开始校验..."
echo ""

PID_FILE="/data/adb/modules/AppOpt/AppOpt.pid"
if [ -f "$PID_FILE" ]; then
    MAIN_PID=$(cat "$PID_FILE")
    if kill -0 "$MAIN_PID" 2>/dev/null; then
        echo "✅ 主程序运行中 (PID: $MAIN_PID)" | tee -a "$VERIFY_LOG"
    else
        echo "❌ 主程序未运行（PID文件存在但进程已退出）" | tee -a "$VERIFY_LOG"
        echo "============================================="
        echo "❌ 模块未生效，请重启手机或重新刷入模块"
        exit 1
    fi
else
    echo "❌ 主程序未运行（PID文件不存在）" | tee -a "$VERIFY_LOG"
    echo "============================================="
    echo "❌ 模块未生效，请重启手机或重新刷入模块"
    exit 1
fi

MAIN_UID=$(ps -o uid= -p "$MAIN_PID" 2>/dev/null | xargs)
if [ "$MAIN_UID" = "0" ]; then
    echo "✅ 主程序拥有ROOT权限" | tee -a "$VERIFY_LOG"
else
    echo "❌ 主程序未获得ROOT权限" | tee -a "$VERIFY_LOG"
    echo "============================================="
    echo "❌ ROOT权限异常，模块无法工作"
    exit 1
fi

if [ -f "$CONF_PATH" ]; then
    RULE_COUNT=$(grep -v "^#" "$CONF_PATH" | grep -v "^$" | grep "=" | wc -l)
    echo "✅ 配置文件正常，规则总数：$RULE_COUNT 条" | tee -a "$VERIFY_LOG"
else
    echo "❌ 配置文件不存在" | tee -a "$VERIFY_LOG"
    echo "============================================="
    echo "❌ 配置文件缺失，模块无法工作"
    exit 1
fi

echo ""
echo "============================================="
echo "🎉 模块完全正常，所有规则均可生效"
echo "📌 详细日志：$VERIFY_LOG"
echo "============================================="
echo ""
echo "校验完成，按任意键退出"
read -n 1
exit 0
VERIFY_EOF

    chmod 755 "$VERIFY_TOOL_PATH"
    chcon u:object_r:magisk_file:s0 "$VERIFY_TOOL_PATH" 2>/dev/null
    ui_print "- 已部署 模块生效校验工具"
}

deploy_auto_pkg_tool() {
    TOOL_PATH="$MODPATH/【自动获取包名生成规则工具】.sh"
    cat > "$TOOL_PATH" << 'PKG_EOF'
#!/system/bin/sh

CONF_PATH="/data/adb/modules/AppOpt/applist.conf"
BAK_DIR="/data/adb/modules/AppOpt/规则配置备份"
TEMP_PKG_LIST="/data/adb/modules/AppOpt/temp_pkg_list.txt"
RUN_LOG="/data/adb/modules/AppOpt/【自动获取包名日志】.log"

GAME_KEYWORDS="game|games|play|王者|荣耀|和平|精英|原神|崩坏|阴阳师|决战|平安京|火影|忍者|CF|穿越火线|LOL|英雄联盟|DNF|地下城|冒险岛|梦幻西游|大话西游|魔兽|炉石|传说|刀塔|自走棋|金铲铲|三国杀|第五人格|明日之后|明日方舟|少女前线|碧蓝航线|战舰|少女|崩坏3|崩坏星穹铁道|绝区零|鸣潮|战双|帕弥什|幻塔|天涯明月刀|完美世界|诛仙|问道|问道手游|问道外传|问道奇经|问道经典|问道怀旧|问道新服|问道新区|问道老区|问道专区|问道专服|问道专版"

echo "===== 自动获取包名工具（免下载版）运行日志 $(date +%Y年%m月%d日_%H时%M分%S秒) =====" > "$RUN_LOG"

env_check() {
    echo "【步骤1/6】开始环境校验" >> "$RUN_LOG"
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 错误：请用ROOT权限运行此工具！" | tee -a "$RUN_LOG"
        sleep 3
        exit 1
    fi
    echo "✅ ROOT权限校验通过" >> "$RUN_LOG"

    if [ ! -f "$CONF_PATH" ]; then
        echo "❌ 错误：未找到模块配置文件！" | tee -a "$RUN_LOG"
        sleep 3
        exit 1
    fi
    echo "✅ 配置文件校验通过" >> "$RUN_LOG"

    mkdir -p "$BAK_DIR"
    echo "✅ 备份目录就绪" >> "$RUN_LOG"
    echo ""
}

load_templates_from_conf() {
    echo "【步骤2/6】加载配置文件中的自定义模板" >> "$RUN_LOG"
    
    DEFAULT_APP_TEMPLATE="
# =================={{APP_NAME}}=====================
{{PKG_NAME}}{{PKG_NAME}}=3-4
{{PKG_NAME}}{Thread-*}=3-4
{{PKG_NAME}}{Thread*}=3-4
{{PKG_NAME}}{*[!e]Thread}=3-4
{{PKG_NAME}}{binder:*}=0-1
{{PKG_NAME}}{MediaCodec_*}=3-4
{{PKG_NAME}}{VDecod2-*}=3-4
{{PKG_NAME}}=0-1
"
    APP_TEMPLATE=$(sed -n '/# ==== 普通APP模板 开始 ====/,/# ==== 普通APP模板 结束 ====/p' "$CONF_PATH" | \
        sed '1d;$d' | sed 's/^#//' | sed 's/^[[:space:]]*//' | grep -v '^$')
    if [ -z "$APP_TEMPLATE" ]; then
        echo "⚠️  未读取到普通APP模板，使用默认模板" | tee -a "$RUN_LOG"
        APP_TEMPLATE="$DEFAULT_APP_TEMPLATE"
    else
        echo "✅ 已加载【普通APP模板】" >> "$RUN_LOG"
    fi
    export APP_TEMPLATE

    echo ""
}

get_user_packages() {
    echo "【步骤3/6】扫描用户安装的应用包名..." | tee -a "$RUN_LOG"
    pm list packages -3 | cut -d: -f2 > "$TEMP_PKG_LIST"
    TOTAL=$(wc -l < "$TEMP_PKG_LIST")
    echo "✅ 共扫描到 $TOTAL 个用户应用" | tee -a "$RUN_LOG"
    echo ""
}

get_app_name() {
    local pkg=$1
    local dump=$(dumpsys package "$pkg" 2>/dev/null)
    local name=""
    name=$(echo "$dump" | grep -m1 "application-label-zh:" | cut -d':' -f2- | xargs | tr -d '"' | tr -d "'")
    if [ -n "$name" ]; then
        echo "$name"
        return
    fi
    name=$(echo "$dump" | grep -m1 "application-label:" | cut -d':' -f2- | xargs | tr -d '"' | tr -d "'")
    if [ -n "$name" ]; then
        echo "$name"
        return
    fi
    echo "$pkg"
}

is_game() {
    local pkg=$1
    local name=$2
    local pkg_lower=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    echo "$pkg_lower $name_lower" | grep -qE "$GAME_KEYWORDS"
    return $?
}

pkg_exists() {
    grep -v "^#" "$CONF_PATH" | grep -q "^${1}[={]" 2>/dev/null
}

insert_app_rules() {
    local content="$1"
    local marker="# ==================APP====================="
    local tmp_file="$CONF_PATH.tmp"
    
    if grep -q "$marker" "$CONF_PATH"; then
        local marker_line=$(grep -n "$marker" "$CONF_PATH" | cut -d: -f1 | head -1)
        local next_marker_line=$(grep -n "^# ==================" "$CONF_PATH" | grep -v "^${marker_line}:" | cut -d: -f1 | while read line; do if [ $line -gt $marker_line ]; then echo $line; break; fi; done)
        if [ -z "$next_marker_line" ]; then
            next_marker_line=$(wc -l < "$CONF_PATH")
        else
            next_marker_line=$((next_marker_line - 1))
        fi
        
        head -n $marker_line "$CONF_PATH" > "$tmp_file.head"
        tail -n +$((marker_line + 1)) "$CONF_PATH" | head -n $((next_marker_line - marker_line)) > "$tmp_file.mid"
        tail -n +$((next_marker_line + 1)) "$CONF_PATH" > "$tmp_file.tail"
        
        cat "$tmp_file.mid" > "$tmp_file.newmid"
        echo "$content" >> "$tmp_file.newmid"
        
        cat "$tmp_file.head" > "$tmp_file"
        echo "" >> "$tmp_file"
        cat "$tmp_file.newmid" >> "$tmp_file"
        cat "$tmp_file.tail" >> "$tmp_file"
        
        mv "$tmp_file" "$CONF_PATH"
        rm -f "$tmp_file.head" "$tmp_file.mid" "$tmp_file.tail" "$tmp_file.newmid"
        echo "✅ 规则已追加到APP区域末尾" >> "$RUN_LOG"
    else
        echo "" >> "$CONF_PATH"
        echo "$marker" >> "$CONF_PATH"
        echo "$content" >> "$CONF_PATH"
        echo "✅ 已创建APP区域并插入规则" >> "$RUN_LOG"
    fi
}

insert_game_comments() {
    local comment="$1"
    local marker="# ==================游戏===================="
    local tmp_file="$CONF_PATH.tmp"
    
    if grep -q "$marker" "$CONF_PATH"; then
        local marker_line=$(grep -n "$marker" "$CONF_PATH" | cut -d: -f1 | head -1)
        local next_marker_line=$(grep -n "^# ==================" "$CONF_PATH" | grep -v "^${marker_line}:" | cut -d: -f1 | while read line; do if [ $line -gt $marker_line ]; then echo $line; break; fi; done)
        if [ -z "$next_marker_line" ]; then
            next_marker_line=$(wc -l < "$CONF_PATH")
        else
            next_marker_line=$((next_marker_line - 1))
        fi
        
        head -n $marker_line "$CONF_PATH" > "$tmp_file.head"
        tail -n +$((marker_line + 1)) "$CONF_PATH" | head -n $((next_marker_line - marker_line)) > "$tmp_file.mid"
        tail -n +$((next_marker_line + 1)) "$CONF_PATH" > "$tmp_file.tail"
        
        cat "$tmp_file.mid" > "$tmp_file.newmid"
        echo "$comment" >> "$tmp_file.newmid"
        
        cat "$tmp_file.head" > "$tmp_file"
        echo "" >> "$tmp_file"
        cat "$tmp_file.newmid" >> "$tmp_file"
        cat "$tmp_file.tail" >> "$tmp_file"
        
        mv "$tmp_file" "$CONF_PATH"
        rm -f "$tmp_file.head" "$tmp_file.mid" "$tmp_file.tail" "$tmp_file.newmid"
        echo "✅ 注释已追加到游戏区域末尾" >> "$RUN_LOG"
    else
        echo "" >> "$CONF_PATH"
        echo "$marker" >> "$CONF_PATH"
        echo "$comment" >> "$CONF_PATH"
        echo "✅ 已创建游戏区域并插入注释" >> "$RUN_LOG"
    fi
}

auto_backup_conf() {
    BAK_FILE="$BAK_DIR/配置备份_$(date +%Y年%m月%d日_%H时%M分).conf"
    cp -f "$CONF_PATH" "$BAK_FILE"
    echo "✅ 配置文件已备份至：$BAK_FILE" | tee -a "$RUN_LOG"
}

main() {
    env_check
    load_templates_from_conf
    get_user_packages

    echo "【步骤4/6】开始分析应用类型并去重..." | tee -a "$RUN_LOG"

    auto_backup_conf

    APP_RULES=""
    GAME_COMMENTS=""
    SKIPPED=0
    APP_COUNT=0
    GAME_COUNT=0

    while IFS= read -r pkg; do
        app_name=$(get_app_name "$pkg")
        
        if pkg_exists "$pkg"; then
            echo "⚠️  应用 $app_name ($pkg) 已存在配置，跳过" | tee -a "$RUN_LOG"
            SKIPPED=$((SKIPPED+1))
            continue
        fi

        if is_game "$pkg" "$app_name"; then
            comment="# $app_name"
            if [ -z "$GAME_COMMENTS" ]; then
                GAME_COMMENTS="$comment"
            else
                GAME_COMMENTS="${GAME_COMMENTS}\n\n$comment"
            fi
            GAME_COUNT=$((GAME_COUNT+1))
            echo "🎮 游戏: $app_name ($pkg)" >> "$RUN_LOG"
        else
            rule=$(echo "$APP_TEMPLATE" | sed "s/{{PKG_NAME}}/$pkg/g" | sed "s/{{APP_NAME}}/$app_name/g")
            if [ -z "$APP_RULES" ]; then
                APP_RULES="$rule"
            else
                APP_RULES="${APP_RULES}\n\n$rule"
            fi
            APP_COUNT=$((APP_COUNT+1))
            echo "📱 APP: $app_name ($pkg)" >> "$RUN_LOG"
        fi
    done < "$TEMP_PKG_LIST"

    echo ""
    echo "【步骤5/6】写入配置文件..." | tee -a "$RUN_LOG"

    if [ -n "$APP_RULES" ]; then
        insert_app_rules "$APP_RULES"
        echo "✅ 已添加 $APP_COUNT 条普通APP规则" | tee -a "$RUN_LOG"
    fi

    if [ -n "$GAME_COMMENTS" ]; then
        insert_game_comments "$GAME_COMMENTS"
        echo "✅ 已添加 $GAME_COUNT 条游戏注释" | tee -a "$RUN_LOG"
    fi

    if [ $SKIPPED -gt 0 ]; then
        echo "⚠️  跳过了 $SKIPPED 个已存在的包名" | tee -a "$RUN_LOG"
    fi

    echo ""
    echo "【步骤6/6】操作完成！" | tee -a "$RUN_LOG"
    echo "============================================="
    echo "  统计结果"
    echo "============================================="
    echo "新增普通APP规则: $APP_COUNT"
    echo "新增游戏注释: $GAME_COUNT"
    echo "跳过已有包名: $SKIPPED"
    echo "============================================="
    echo ""
    echo "📌 详细日志: $RUN_LOG"
    echo ""
    echo "按任意键退出"
    read -n 1
}

main
PKG_EOF

    chmod 755 "$TOOL_PATH"
    chcon u:object_r:magisk_file:s0 "$TOOL_PATH" 2>/dev/null
    ui_print "- 已部署 自动获取包名生成规则工具"
}

deploy_thread_monitor_tool() {
    TOOL_PATH="$MODPATH/【线程占用检测工具】.sh"
    cat > "$TOOL_PATH" << 'MONITOR_EOF'
#!/system/bin/sh

CONF_PATH="/data/adb/modules/AppOpt/applist.conf"
LOG_PATH="/data/adb/modules/AppOpt/【线程占用日志】.log"
TOTAL_TIME=120
TMP_DIR="/data/local/tmp/thread_monitor"
THREAD_STATS="$TMP_DIR/thread.stats"
PREV_STATE="$TMP_DIR/prev.state"
CUR_STATE="$TMP_DIR/cur.state"
PATTERN_FILE="$TMP_DIR/patterns.txt"

mkdir -p "$TMP_DIR"
> "$THREAD_STATS"
> "$PREV_STATE"

echo "===== 线程占用检测工具 推荐规则版 运行日志 $(date +%Y年%m月%d日_%H时%M分%S秒) =====" > "$LOG_PATH"
echo "监控模式：自动追踪前台应用，只统计最后一个前台应用的数据，监控时长120秒" >> "$LOG_PATH"
echo "" >> "$LOG_PATH"

load_rule_patterns() {
    echo "【步骤0】加载模板规则..." >> "$LOG_PATH"
    > "$PATTERN_FILE"

    if [ ! -f "$CONF_PATH" ]; then
        echo "⚠️  未找到配置文件 $CONF_PATH，跳过规则推荐" | tee -a "$LOG_PATH"
        return
    fi

    grep -v "^#" "$CONF_PATH" | grep "{" | grep "=" | while read -r line; do
        line=$(echo "$line" | xargs)
        pattern=$(echo "$line" | sed -n 's/.*{\([^}]*\)}.*/\1/p')
        cores=$(echo "$line" | awk -F '=' '{print $2}' | xargs)
        if [ -n "$pattern" ] && [ -n "$cores" ]; then
            echo "$pattern|$cores" >> "$PATTERN_FILE"
            echo "  加载规则: $pattern -> $cores" >> "$LOG_PATH"
        fi
    done

    if [ ! -s "$PATTERN_FILE" ]; then
        echo "  未找到线程级规则" >> "$LOG_PATH"
    fi
}

get_foreground_pkg() {
    local pkg=""

    pkg=$(dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | grep -v "null" | tail -n 1 | sed -E 's/.* ([a-zA-Z0-9._]+)\/.*/\1/')
    [ -n "$pkg" ] && { echo "$pkg"; return 0; }

    pkg=$(dumpsys activity activities 2>/dev/null | grep -E 'mResumedActivity|mFocusedActivity' | head -n 1 | sed -E 's/.* ([a-zA-Z0-9._]+)\/.*/\1/')
    [ -n "$pkg" ] && { echo "$pkg"; return 0; }

    if command -v cmd >/dev/null 2>&1; then
        pkg=$(cmd activity get-front-focus 2>/dev/null | grep -oE 'packageName=[a-zA-Z0-9._]+' | cut -d'=' -f2 | head -n 1)
        [ -n "$pkg" ] && { echo "$pkg"; return 0; }
    fi

    pkg=$(dumpsys activity recents 2>/dev/null | grep "Recent #0:" -A 5 | grep "basePackage" | head -n 1 | awk '{print $2}')
    [ -n "$pkg" ] && { echo "$pkg"; return 0; }

    echo ""
    return 1
}

get_pid() {
    local pkg="$1"
    if command -v pidof >/dev/null 2>&1; then
        pidof "$pkg" | awk '{print $1}'
    else
        pgrep -f "$pkg" | head -n 1
    fi
}

get_threads_cpu() {
    local pid=$1
    local tid_dir="/proc/$pid/task"
    [ ! -d "$tid_dir" ] && return
    for tid in $(ls "$tid_dir" 2>/dev/null); do
        local stat_file="$tid_dir/$tid/stat"
        [ ! -f "$stat_file" ] && continue
        local stat=$(cat "$stat_file" 2>/dev/null)
        [ -z "$stat" ] && continue
        local utime=$(echo "$stat" | awk '{print $14}')
        local stime=$(echo "$stat" | awk '{print $15}')
        local comm=$(echo "$stat" | awk '{print $2}' | tr -d '()')
        if echo "$utime$stime" | grep -qE '^[0-9]+$'; then
            total=$((utime + stime))
            echo "$tid $total $comm"
        fi
    done
}

reset_stats() {
    > "$THREAD_STATS"
    > "$PREV_STATE"
    echo "   统计已重置，开始追踪新应用" | tee -a "$LOG_PATH"
}

update_stats() {
    local cur_file="$1"
    local prev_file="$2"
    local stats_file="$3"
    local tmp_stats="$TMP_DIR/tmp.stats"

    awk '
    FILENAME == "'"$cur_file"'" {
        tid = $1;
        cur = $2;
        comm = $3;
        cur_data[tid] = cur;
        cur_comm[tid] = comm;
    }
    FILENAME == "'"$prev_file"'" {
        tid = $1;
        prev = $2;
        prev_data[tid] = prev;
    }
    END {
        while ((getline line < "'"$stats_file"'") > 0) {
            split(line, arr, " ");
            tid = arr[1];
            sum = arr[2];
            cnt = arr[3];
            old_comm = arr[4];
            stats_sum[tid] = sum;
            stats_cnt[tid] = cnt;
            stats_comm[tid] = old_comm;
        }
        close("'"$stats_file"'");

        for (tid in cur_data) {
            if (tid in prev_data) {
                delta = cur_data[tid] - prev_data[tid];
                if (delta < 0) delta = 0;
                new_sum = stats_sum[tid] + delta;
                new_cnt = stats_cnt[tid] + 1;
                stats_comm[tid] = cur_comm[tid];
                printf "%s %d %d %s\n", tid, new_sum, new_cnt, stats_comm[tid] > "'"$tmp_stats"'";
            } else {
                printf "%s %d %d %s\n", tid, 0, 0, cur_comm[tid] > "'"$tmp_stats"'";
            }
        }
        for (tid in prev_data) {
            if (!(tid in cur_data) && (tid in stats_sum)) {
                printf "%s %d %d %s\n", tid, stats_sum[tid], stats_cnt[tid], stats_comm[tid] > "'"$tmp_stats"'";
            }
        }
    }' "$cur_file" "$prev_file"

    mv "$tmp_stats" "$stats_file"
}

recommend_cores() {
    local thread_name="$1"
    if [ ! -s "$PATTERN_FILE" ]; then
        echo "无规则"
        return
    fi
    while IFS='|' read -r pattern cores; do
        case "$thread_name" in
            $pattern)
                echo "$cores"
                return
                ;;
        esac
    done < "$PATTERN_FILE"
    echo "未匹配"
}

print_stats() {
    local total_samples=$(cat "$THREAD_STATS" | awk '{sum += $3} END {print sum}')
    if [ -z "$total_samples" ] || [ "$total_samples" -eq 0 ]; then
        echo "⚠️  未采集到有效数据" | tee -a "$LOG_PATH"
        return
    fi

    local tmp_avg="$TMP_DIR/avg.txt"
    awk '{if($3>0) avg = $2 / $3; else avg=0; printf "%s %.2f %d %s\n", $1, avg, $3, $4}' "$THREAD_STATS" | sort -rn -k2 > "$tmp_avg"

    echo ""
    echo "========== 线程平均CPU占用率 TOP10（含推荐核心） ==========" | tee -a "$LOG_PATH"
    echo "排名  平均占用率(%)  采样次数  线程ID  线程名         推荐核心" >> "$LOG_PATH"
    local rank=1
    head -10 "$tmp_avg" | while read tid avg cnt comm; do
        rec=$(recommend_cores "$comm")
        line=$(printf "%2d    | %8.2f      | %5d    | %-7s | %-15s | %s" "$rank" "$avg" "$cnt" "$tid" "$comm" "$rec")
        echo "$line" | tee -a "$LOG_PATH"
        rank=$((rank+1))
    done
    echo "=====================================================================" | tee -a "$LOG_PATH"

    echo ""
    echo "TOP10线程（按平均占用率排序，推荐核心）："
    i=1
    head -10 "$tmp_avg" | while read tid avg cnt comm; do
        rec=$(recommend_cores "$comm")
        printf "%2d. %-20s (tid %-7s) : 平均 %.2f%% (采样%d次) 推荐核心: %s\n" "$i" "$comm" "$tid" "$avg" "$cnt" "$rec"
        i=$((i+1))
    done
}

monitor() {
    local start_time=$(date +%s)
    local end_time=$((start_time + TOTAL_TIME))
    local current_pkg=""
    local current_pid=""
    local prev_file="$PREV_STATE"
    local cur_file="$CUR_STATE"

    current_pkg=$(get_foreground_pkg)
    if [ -z "$current_pkg" ]; then
        echo "❌ 无法获取前台应用包名，请确保屏幕亮起且有应用在前台" | tee -a "$LOG_PATH"
        exit 1
    fi
    current_pid=$(get_pid "$current_pkg")
    if [ -z "$current_pid" ]; then
        echo "❌ 应用 $current_pkg 进程不存在" | tee -a "$LOG_PATH"
        exit 1
    fi
    echo "✅ 初始监控: $current_pkg (PID: $current_pid)" | tee -a "$LOG_PATH"
    get_threads_cpu "$current_pid" > "$prev_file"

    while [ $(date +%s) -lt $end_time ]; do
        sleep 1
        local now=$(date +%s)
        local remaining=$((end_time - now))
        [ $remaining -lt 0 ] && remaining=0
        printf "\r⏱️  剩余时间: %02d秒  当前应用: %s" "$remaining" "$current_pkg"

        local new_pkg=$(get_foreground_pkg)
        if [ -n "$new_pkg" ] && [ "$new_pkg" != "$current_pkg" ]; then
            local new_pid=$(get_pid "$new_pkg")
            if [ -n "$new_pid" ]; then
                echo ""
                echo "🔄 应用切换: $current_pkg -> $new_pkg (PID: $new_pid)" | tee -a "$LOG_PATH"
                current_pkg="$new_pkg"
                current_pid="$new_pid"
                reset_stats
                get_threads_cpu "$current_pid" > "$prev_file"
                > "$cur_file"
                continue
            fi
        fi

        get_threads_cpu "$current_pid" > "$cur_file"
        update_stats "$cur_file" "$prev_file" "$THREAD_STATS"
        cp "$cur_file" "$prev_file"
    done
    echo ""
}

cleanup() {
    rm -rf "$TMP_DIR"
}

main() {
    echo "============================================="
    echo "   线程占用检测工具（推荐规则版·120秒）"
    echo "============================================="
    echo ""
    echo "⚠️  请将当前MT管理器缩小到小窗或后台，"
    echo "   然后在前台全屏打开您要监控的应用。"
    echo ""
    echo "准备好后，按回车键开始120秒监控..."
    read -r dummy

    echo "正在检测当前前台应用..."
    PKG=$(get_foreground_pkg)
    if [ -z "$PKG" ]; then
        echo "❌ 无法获取前台应用包名，请确保屏幕亮起且有应用在前台"
        exit 1
    fi
    echo "✅ 检测到前台应用: $PKG"
    echo ""

    echo "监控期间可自由切换应用，工具会自动追踪前台应用，"
    echo "但**只统计最后一个应用**的数据，并根据模板推荐核心。"
    echo "开始120秒倒计时..."
    monitor

    load_rule_patterns
    echo "✅ 监控完成，正在统计..."
    print_stats

    cleanup
    echo ""
    echo "📌 详细日志已保存至: $LOG_PATH"
    echo ""
    echo "按任意键退出"
    read -n 1
}

main
MONITOR_EOF

    chmod 755 "$TOOL_PATH"
    chcon u:object_r:magisk_file:s0 "$TOOL_PATH" 2>/dev/null
    ui_print "- 已部署 线程占用检测工具"
}

check_magisk_version
check_required_files
extract_bin
module_instructions
add_default_rules
deploy_auto_rule_tool
deploy_verify_tool
deploy_auto_pkg_tool
deploy_thread_monitor_tool

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/AppOpt" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/【自动规则生成工具】.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/【模块生效校验工具】.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/【自动获取包名生成规则工具】.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/【线程占用检测工具】.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/uninstall.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/service.sh" 0 2000 0755 u:object_r:magisk_file:s0
set_perm "$MODPATH/applist.conf" 0 0 0644 u:object_r:magisk_file:s0