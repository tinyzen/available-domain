#!/usr/bin/env bash

set -euo pipefail

export TZ=Asia/Shanghai

TEMP_DIR="/tmp/predomain"
DATE_1=$(date +"%Y%m%d")
DATE_2=$(date +"%Y-%m-%d")
DATETIME=$(date +"%Y-%m-%d %H:%M:%S")

DAILY_PATH="daily"
DAILY_DAY_PATH="${DAILY_PATH}/${DATE_1}"

pip_install_predeldomain() {
    pip install git+https://github.com/idevsig/predeldomain.git
}

check_cn() {
    predeldomain --length 4 --mode 3 --suffix cn --type text --whois whois
}

check_top() {
    predeldomain --length 4 --mode 3 --suffix top --type text --whois nic
}

progress() {
    suffix="$1"
    echo "suffix: $suffix"

    TODAY_LOG="${TEMP_DIR}/${suffix}_${DATE_2}.log"
    target_file="${DAILY_DAY_PATH}.${suffix}.md"
    if [[ -f "$TODAY_LOG" ]]; then
        {
            echo ""
            echo "## 今日可注册的 \`$suffix\`" 
            echo "" 

            cat "$TODAY_LOG"
        } > "$target_file"

        cat "$target_file" >> "$DAILY_DAY_PATH.md"
    fi
}

progress_next() {
    suffix="$1"
    echo "suffix: $suffix"

    NEXT_LOG="${TEMP_DIR}/${suffix}_${DATE_2}_next.log"
    if [[ -f "$NEXT_LOG" ]]; then
        target_file="${DAILY_PATH}/next.${suffix}.md"
        
        cp "$NEXT_LOG" "$target_file"
        sed -i -e "/明天过期/c\## 明天过期" \
            -e "/明天以后过期/c\## 明天以后过期" "$target_file"
    fi
}

main() {
    pip_install_predeldomain

    mkdir -p "$TEMP_DIR"
    pushd "$TEMP_DIR" > /dev/null 2>&1
        check_top

        check_cn

        # 添加前缀和后缀
        # sed -i 's/^/- /' ./*.log
        sed -i 's/$/   /' ./*.log
    popd > /dev/null 2>&1

    if [[ -f "README.md" ]]; then
        rm "README.md"
    fi

    cp template.md "$DAILY_DAY_PATH.md"
    ln -s "$DAILY_DAY_PATH.md" README.md

    sed -i "s#{DAY}#${DATE_2}#" "$DAILY_DAY_PATH.md"
    sed -i "s#{lastmod}#${DATETIME}#" "$DAILY_DAY_PATH.md"

    progress cn
    progress_next cn
    
    progress top
    progress_next top

    if [[ -f "$DAILY_DAY_PATH.md" ]]; then
        cp "$DAILY_DAY_PATH.md" "$DAILY_PATH/README.md"
    fi
}

main "$@"