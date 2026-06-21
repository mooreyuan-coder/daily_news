#!/bin/bash
# 每日财经资讯报告生成脚本
# 使用方法: ./fetch_news.sh [--send-email]

REPORT_DIR="/Users/chenjiahui/Desktop/vb/daily_news/daily_reports"
DATE=$(date +"%Y-%m-%d")
REPORT_FILE="$REPORT_DIR/${DATE}.md"

# 邮件配置
EMAIL_FROM="249131303@qq.com"
EMAIL_TO="249131303@qq.com"
EMAIL_SMTP="smtp.qq.com"
EMAIL_PORT="587"
EMAIL_PASS="tptknjsmptdgbihe"

mkdir -p "$REPORT_DIR"

log_info() {
    echo "[INFO] $1" >&2
}

# 发送邮件
send_email() {
    log_info "发送邮件..."

    REPORT_FILE="$REPORT_FILE"
    EMAIL_FROM="$EMAIL_FROM"
    EMAIL_TO="$EMAIL_TO"
    EMAIL_SMTP="$EMAIL_SMTP"
    EMAIL_PORT="$EMAIL_PORT"
    EMAIL_PASS="$EMAIL_PASS"
    DATE="$DATE"

    python3 - "$REPORT_FILE" "$EMAIL_FROM" "$EMAIL_TO" "$EMAIL_SMTP" "$EMAIL_PORT" "$EMAIL_PASS" "$DATE" << 'ENDPYTHON'
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import sys

REPORT_FILE = sys.argv[1]
EMAIL_FROM = sys.argv[2]
EMAIL_TO = sys.argv[3]
EMAIL_SMTP = sys.argv[4]
EMAIL_PORT = int(sys.argv[5])
EMAIL_PASS = sys.argv[6]
DATE = sys.argv[7]

try:
    with open(REPORT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
except:
    print("[ERROR] 无法读取报告文件")
    sys.exit(1)

msg = MIMEMultipart('alternative')
msg['Subject'] = '📈 每日财经资讯 - ' + DATE
msg['From'] = EMAIL_FROM
msg['To'] = EMAIL_TO

plain_text = content.replace('# ', '').replace('## ', '\n=== ').replace('**', '').replace('---', '').replace('  * ', '\n• ')

html_content = '<html><head><meta charset="utf-8"></head><body style="font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 20px;"><h1>📈 每日财经资讯报告</h1><p>日期: ' + DATE + '</p><hr><pre>' + content + '</pre><hr><p style="color: #999; font-size: 12px;">报告生成于 ' + DATE + '</p></body></html>'

msg.attach(MIMEText(plain_text, 'plain', 'utf-8'))
msg.attach(MIMEText(html_content, 'html', 'utf-8'))

try:
    server = smtplib.SMTP(EMAIL_SMTP, EMAIL_PORT)
    server.starttls()
    server.login(EMAIL_FROM, EMAIL_PASS)
    server.send_message(msg)
    server.quit()
    print("[INFO] 邮件发送成功！")
except Exception as e:
    print("[ERROR] 邮件发送失败: " + str(e))
ENDPYTHON
}

# 抓取新浪财经
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

# 抓取东方财富快讯
fetch_eastmoney() {
    log_info "抓取: 东方财富-市场快讯"
    curl -s --max-time 15 \
        "https://newsapi.eastmoney.com/kuaixun/v1/getlist_102_ajaxResult_20_1_.html" \
        | python3 -c "
import sys, json, re
try:
    text = sys.stdin.read()
    match = re.search(r'ajaxResult=(\{.+\})', text)
    if match:
        data = json.loads(match.group(1))
        items = data.get('LivesList', [])
        for item in items[:15]:
            title = item.get('title', '')
            if title:
                print(f'  * {title}')
except:
    pass
" 2>/dev/null
}

# 抓取36氪
fetch_36kr() {
    log_info "抓取: 36氪-科技创业"
    curl -s --max-time 15 \
        "https://36kr.com/feed" \
        | grep -o '<title>[^<]*</title>' \
        | sed 's/<title>//g; s/<\/title>//g' \
        | tail -n +2 \
        | head -10 \
        | while read line; do echo "  * $line"; done
}

# 生成报告
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
        echo "## 📰 东方财富 - 市场快讯"
        echo ""
        fetch_eastmoney
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
        echo "## 📰 36氪 - 科技创业"
        echo ""
        fetch_36kr
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 行业研究"
        echo ""
        fetch_sina "新浪财经-行业研究" 2509 10
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

    # 检查是否发送邮件
    if [ "$1" == "--send-email" ] || [ "$1" == "-s" ]; then
        echo ""
        send_email
    fi

    echo ""
    echo "[INFO] 完成！报告: $REPORT_FILE"

    if [ "$1" == "--open" ] || [ "$1" == "-o" ]; then
        open "$REPORT_FILE"
    fi
}

main "$@"
