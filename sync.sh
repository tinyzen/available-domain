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
}

main "$@"