#!/usr/bin/env bash

set -euo pipefail

export TZ=Asia/Shanghai

LOG_DIR="$(pwd)/logs"
DAILY_PATH="$(pwd)/daily"

DATE_1=$(date +"%Y%m%d")
DATE_2=$(date +"%Y-%m-%d")
DATETIME=$(date +"%Y-%m-%d %H:%M:%S")

DAILY_DAY_PATH="${DAILY_PATH}/${DATE_1}"

SUB_README_PATH="${DAILY_PATH}/README.md"

pip_install_predeldomain() {
    pip install git+https://github.com/idevsig/predeldomain.git
}

check_cn_4_3() {
    # GitHub Actions 无法使用 whois
    predeldomain --length 4 --mode 3 --suffix cn --type text --whois zzidc
}

check_cn_3_1() {
    # GitHub Actions 无法使用 whois
    predeldomain --length 3 --mode 1 --suffix cn --type text --whois zzidc
}

check_top_4_3() {
    predeldomain --length 4 --mode 3 --suffix top --type text --whois nic
}

check_top_3_1() {
    predeldomain --length 3 --mode 1 --suffix top --type text --whois nic
}

update_today() {
    suffix="$1"

    TODAY_LOG="${suffix}_${DATE_2}.log"

    if [[ -f "$TODAY_LOG" ]]; then
        TARGET_FILE="${DAILY_DAY_PATH}.${suffix}.md"
        if [[ ! -f "$TARGET_FILE" ]]; then
            touch "$TARGET_FILE"
        fi

        {
            echo
            echo "## 今日可注册的 \`$suffix\`" 
            echo ">"

            cat "$TODAY_LOG"
            echo
        } >> "$TARGET_FILE"
    fi
}

update_next() {
    suffix="$1"

    NEXT_LOG="${suffix}_${DATE_2}_next.log"
    if [[ -f "$NEXT_LOG" ]]; then
        TARGET_FILE="${DAILY_PATH}/next.${suffix}.md"
        if [[ ! -f "$TARGET_FILE" ]]; then
            touch "$TARGET_FILE"
        fi
        
        cat "$NEXT_LOG" >>"$TARGET_FILE"
        echo "" >> "$TARGET_FILE"
    fi
}

update_log() {
    # 添加前缀和后缀
    # sed -i 's/^/- /' "$TEMP_DIR"/*.log
    sed -i 's/$/   /' ./*.log    
}

progress() {
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
    fi
    mkdir -p "$LOG_DIR"
    
    pushd "$LOG_DIR" > /dev/null 2>&1
        rm -rf "$DAILY_DAY_PATH"*
        rm -rf "${DAILY_PATH}/next"*
    
        check_cn_3_1
        update_log
        update_today "cn"
        update_next "cn"

        check_cn_4_3
        update_log
        update_today "cn"
        update_next "cn"


        check_top_3_1
        update_log
        update_today "top"
        update_next "top"

        check_top_4_3
        update_log
        update_today "top"
        update_next "top"

        [[ -f "$DAILY_DAY_PATH.cn.md" ]] || touch "$DAILY_DAY_PATH.cn.md"
        [[ -f "$DAILY_DAY_PATH.top.md" ]] || touch "$DAILY_DAY_PATH.top.md"

        cat "$DAILY_DAY_PATH.cn.md" "$DAILY_DAY_PATH.top.md" > "$DAILY_DAY_PATH.md"
        cat "$DAILY_DAY_PATH.md" >> "$SUB_README_PATH"
    popd > /dev/null 2>&1

    sed -i -e "/明天过期/c\## 明天过期\n>" \
        -e "/明天以后过期/c\## 明天以后过期\n>" "${DAILY_PATH}/next"*.md 

}

history() {
    pushd "$DAILY_PATH" > /dev/null 2>&1
        # 列出所有的历史文件，写入 history.md 文件
        echo "# 历史记录" > history.md
        # grep -E '^[0-9]+\.md$' | sort -r | awk '{print "- [" $1 "](" $1 ")"}' > history.md
        # ls | grep -E '^[0-9]+\.md$' | sort -r | awk '{sub(/\.md$/, "", $1); print "- [" $1 "](" $1 ".md)"}' > history.md
        for file in [0-9]*.md; do
            if [[ $file =~ ^[0-9]+\.md$ ]]; then
                echo "- [${file%.md}]($file)"
            fi
        done | sort -r >> history.md
    popd > /dev/null 2>&1
}

# 每月1号打 tag 并删除上月数据
monthly_tag_and_cleanup() {
    local current_day
    current_day=$(date +"%d")

    # 只在每月1号执行
    if [[ "$current_day" != "01" ]]; then
        return 0
    fi

    # 获取上个月的年月
    local last_month
    last_month=$(date -d "last month" +"%Y-%m")
    local last_month_name
    last_month_name=$(date -d "last month" +"%Y年%m月")

    # 上个月的日期范围
    local first_day last_day
    first_day=$(date -d "last month" +"%Y%m01")
    last_day=$(date -d "$(date +"%Y-%m-01") -1 day" +"%Y%m%d")

    local tag_name="daily-${last_month}"

    echo "正在处理 ${last_month_name} 的 daily 文件..."

    # Git 操作 - 先提交当前状态并打 tag
    pushd "$(pwd)" > /dev/null 2>&1
        git add -A
        git commit -m "Auto-sync by sync.sh" --allow-empty || true

        # 创建并推送 tag
        if git tag -l | grep -q "^${tag_name}$"; then
            echo "Tag ${tag_name} 已存在，跳过"
        else
            git tag -a "$tag_name" -m "${last_month_name} Daily"
            echo "已创建 tag: ${tag_name}"
        fi

        git push origin main
        git push origin "$tag_name" 2>/dev/null || true
    popd > /dev/null 2>&1

    echo "Tag ${tag_name} 已推送"

    # 删除上个月的 daily 文件
    echo "正在删除 ${last_month_name} 的 daily 文件..."
    for file in "${DAILY_PATH}"/[0-9]*.md; do
        if [[ -f "$file" ]]; then
            local filename
            filename=$(basename "$file" .md)
            if [[ "$filename" -ge "$first_day" && "$filename" -le "$last_day" ]]; then
                rm -f "$file"
                echo "已删除: $file"
            fi
        fi
    done

    # 更新历史记录
    history

    # 提交删除操作
    pushd "$(pwd)" > /dev/null 2>&1
        git add -A
        git commit -m "删除 ${last_month_name} 的 daily 数据"
        git push origin main
    popd > /dev/null 2>&1

    echo "${last_month_name} 数据已清理完成！"
}

main() {
    pip_install_predeldomain

    if [[ -e "README.md" ]]; then
        rm "README.md"
    fi

    # 复制模板
    cp template.md "$SUB_README_PATH"
    ln -s "daily/README.md" README.md

    # 更新时间
    sed -i "s#{DAY}#${DATE_2}#" "$SUB_README_PATH"
    sed -i "s#{lastmod}#${DATETIME}#" "$SUB_README_PATH"

    progress

    # 每月1号打 tag 并删除上月数据
    monthly_tag_and_cleanup
}

main "$@"