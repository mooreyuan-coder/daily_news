#!/bin/bash
# 每日财经资讯报告生成脚本
# 使用方法: ./fetch_news.sh

REPORT_DIR="/Users/chenjiahui/Desktop/vb/stock_rotation/daily_reports"
DATE=$(date +"%Y-%m-%d")
REPORT_FILE="$REPORT_DIR/${DATE}.md"

mkdir -p "$REPORT_DIR"

log_info() {
    echo "[INFO] $1" >&2
}

fetch_sina() {
    local name=$1
    local lid=$2
    local count=${3:-10}

    log_info "抓取: $name"
    curl -s --max-time 15 \
        "https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=${lid}&num=${count}&versionNumber=1.2.4&page=1" \
        | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get('result', {}).get('data', [])
    for item in items[:$count]:
        print(f'  * {item.get(\"title\", \"\")}')
except:
    pass
" 2>/dev/null
}

generate_report() {
    log_info "开始生成每日财经报告..."

    {
        echo "# 📈 每日财经资讯报告"
        echo ""
        echo "**日期**: ${DATE}"
        echo "**生成时间**: $(date +"%H:%M:%S")"
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 港股要闻"
        echo ""
        fetch_sina "新浪财经-港股" 2516 10
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 财经新闻"
        echo ""
        fetch_sina "新浪财经-财经" 2517 10
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 国际市场"
        echo ""
        fetch_sina "新浪财经-国际" 2514 10
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 外汇贵金属"
        echo ""
        fetch_sina "新浪财经-外汇" 2519 10
        echo ""
        echo "---"
        echo ""
        echo "*报告生成于 $(date +"%Y-%m-%d %H:%M:%S")*"

    } > "$REPORT_FILE"

    log_info "报告已生成: $REPORT_FILE"
}

main() {
    echo "=========================================="
    echo "   📊 每日财经资讯报告生成器"
    echo "=========================================="
    echo ""

    generate_report

    echo ""
    echo "[INFO] 完成！报告: $REPORT_FILE"

    if [ "$1" == "--open" ] || [ "$1" == "-o" ]; then
        open "$REPORT_FILE"
    fi
}

main "$@"
