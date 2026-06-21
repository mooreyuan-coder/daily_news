#!/bin/bash
# 每日财经资讯报告生成脚本
# 使用方法: ./fetch_news.sh [--send-email]

REPORT_DIR="/Users/chenjiahui/Desktop/vb/daily_news/daily_reports"
DATE=$(date +"%Y-%m-%d")
REPORT_FILE="$REPORT_DIR/${DATE}.md"
REPORT_HTML="$REPORT_DIR/${DATE}.html"

# 邮件配置
EMAIL_FROM="249131303@qq.com"
EMAIL_TO="249131303@qq.com"
EMAIL_SMTP="smtp.qq.com"
EMAIL_PORT="587"
EMAIL_PASS="tptknjsmptdgbihe"

# autocli 路径
AUTOCLI="$HOME/bin/autocli"
export PATH="$HOME/bin:$PATH"

mkdir -p "$REPORT_DIR"

log_info() {
    echo "[INFO] $1" >&2
}

# 发送邮件
send_email() {
    log_info "发送邮件..."

    python3 - "$REPORT_HTML" "$EMAIL_FROM" "$EMAIL_TO" "$EMAIL_SMTP" "$EMAIL_PORT" "$EMAIL_PASS" "$DATE" << 'ENDPYTHON'
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import sys

REPORT_HTML = sys.argv[1]
EMAIL_FROM = sys.argv[2]
EMAIL_TO = sys.argv[3]
EMAIL_SMTP = sys.argv[4]
EMAIL_PORT = int(sys.argv[5])
EMAIL_PASS = sys.argv[6]
DATE = sys.argv[7]

try:
    with open(REPORT_HTML, 'r', encoding='utf-8') as f:
        html_content = f.read()
except:
    print("[ERROR] 无法读取HTML报告文件")
    sys.exit(1)

msg = MIMEMultipart('alternative')
msg['Subject'] = '📈 每日财经资讯 - ' + DATE
msg['From'] = EMAIL_FROM
msg['To'] = EMAIL_TO

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

# 抓取新浪财经7x24快讯（autocli）- 输出 content 字段
fetch_sina_news() {
    log_info "抓取: 新浪财经7x24快讯"
    $AUTOCLI sinafinance news -f md 2>/dev/null | grep "^|" | grep -v "^| id" | grep -v "^| -" | cut -d'|' -f4 | sed 's/^ //' | sed 's/ $//' | head -15
}

# 抓取雪球热门股票（autocli）
fetch_xueqiu() {
    log_info "抓取: 雪球热门股票"
    $AUTOCLI xueqiu hot-stock -f md 2>/dev/null | grep "^|" | grep -v "^| rank" | grep -v "^| -" | sed 's/| /|/g' | sed 's/ |/|/g' | awk -F'|' '{print $4" "$5" "$6}' | head -15
}

# 抓取知乎热榜（autocli）
fetch_zhihu() {
    log_info "抓取: 知乎热榜"
    $AUTOCLI zhihu hot -f md 2>/dev/null | grep "^|" | grep -v "^| rank" | grep -v "^| -" | cut -d'|' -f3 | sed 's/^ //' | sed 's/ $//' | head -10
}

# 抓取微博热搜（autocli）
fetch_weibo() {
    log_info "抓取: 微博热搜"
    $AUTOCLI weibo hot -f md 2>/dev/null | grep "^|" | grep -v "^| rank" | grep -v "^| -" | cut -d'|' -f3 | sed 's/^ //' | sed 's/ $//' | head -10
}

# 抓取东方财富快讯（直接API）
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
            title = item.get('title', '').replace('\"', '&quot;')
            url = item.get('url_w', '')
            if title:
                print(f'  * {title}|{url}')
except:
    pass
" 2>/dev/null
}

# 抓取36氪（RSS）
fetch_36kr() {
    log_info "抓取: 36氪-科技创业"
    curl -s --max-time 15 \
        "https://36kr.com/feed" \
        | python3 -c "
import sys, re
try:
    content = sys.stdin.read()
    titles = re.findall(r'<title><!\[CDATA\[([^\]]+)\]\]></title>', content)
    links = re.findall(r'<link><!\[CDATA\[([^\]]+)\]\]></link>', content)
    for i, title in enumerate(titles[1:11]):
        link = links[i] if i < len(links) else ''
        print(f'  * {title}|{link}')
except:
    pass
" 2>/dev/null
}

# 生成报告
generate_report() {
    log_info "开始生成每日财经报告..."

    # 创建临时文件存储数据
    TEMP_SINA="/tmp/sina_$$"
    TEMP_XUEQIU="/tmp/xueqiu_$$"
    TEMP_ZHIHU="/tmp/zhihu_$$"
    TEMP_WEIBO="/tmp/weibo_$$"
    TEMP_EMF="/tmp/emf_$$"
    TEMP_36KR="/tmp/36kr_$$"

    fetch_sina_news > "$TEMP_SINA" 2>/dev/null
    fetch_xueqiu > "$TEMP_XUEQIU" 2>/dev/null
    fetch_zhihu > "$TEMP_ZHIHU" 2>/dev/null
    fetch_weibo > "$TEMP_WEIBO" 2>/dev/null
    fetch_eastmoney > "$TEMP_EMF" 2>/dev/null
    fetch_36kr > "$TEMP_36KR" 2>/dev/null

    # 生成 Markdown 报告
    {
        echo "# 📈 每日财经资讯报告"
        echo ""
        echo "**日期**: ${DATE}"
        echo ""
        echo "---"
        echo ""
        echo "## 📰 新浪财经 - 7x24快讯"
        echo ""
        while IFS= read -r line; do
            echo "  * $line"
        done < "$TEMP_SINA"
        echo ""
        echo "---"
        echo ""
        echo "## 📊 雪球 - 热门股票"
        echo ""
        while IFS= read -r line; do
            echo "  * $line"
        done < "$TEMP_XUEQIU"
        echo ""
        echo "---"
        echo ""
        echo "## 💬 知乎 - 热榜"
        echo ""
        while IFS= read -r line; do
            echo "  * $line"
        done < "$TEMP_ZHIHU"
        echo ""
        echo "---"
        echo ""
        echo "## 🔥 微博 - 热搜"
        echo ""
        while IFS= read -r line; do
            echo "  * $line"
        done < "$TEMP_WEIBO"
        echo ""
        echo "---"
        echo ""
        echo "## 📰 东方财富 - 市场快讯"
        echo ""
        while IFS='|' read -r title url; do
            echo "  * $title"
        done < "$TEMP_EMF"
        echo ""
        echo "---"
        echo ""
        echo "## 💼 36氪 - 科技创业"
        echo ""
        while IFS='|' read -r title url; do
            echo "  * $title"
        done < "$TEMP_36KR"
        echo ""
        echo "---"
        echo ""
        echo "*报告生成于 $(date +"%Y-%m-%d %H:%M:%S")*"

    } > "$REPORT_FILE"

    # 生成 HTML 报告
    cat > "$REPORT_HTML" << HTML_HEAD
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>每日财经资讯 - ${DATE}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', sans-serif;
            background: #f5f6f8;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #1a73e8, #0d47a1);
            color: white;
            padding: 30px;
            border-radius: 12px;
            margin-bottom: 20px;
            text-align: center;
        }
        .header h1 { font-size: 24px; margin-bottom: 8px; }
        .header p { opacity: 0.9; font-size: 14px; }
        .section {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        }
        .section-title {
            font-size: 16px;
            font-weight: 600;
            color: #1a73e8;
            margin-bottom: 16px;
            padding-bottom: 10px;
            border-bottom: 2px solid #e8f0fe;
        }
        .news-item {
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .news-item:last-child { border-bottom: none; }
        .news-item a {
            color: #333;
            text-decoration: none;
            font-size: 14px;
            display: block;
            transition: color 0.2s;
        }
        .news-item a:hover {
            color: #1a73e8;
        }
        .news-item a::before {
            content: "• ";
            color: #1a73e8;
        }
        .stock-table {
            width: 100%;
            font-size: 13px;
        }
        .stock-table th {
            text-align: left;
            padding: 8px 4px;
            border-bottom: 2px solid #eee;
            color: #666;
            font-weight: normal;
        }
        .stock-table td {
            padding: 8px 4px;
            border-bottom: 1px solid #eee;
        }
        .stock-up { color: #c00; }
        .stock-down { color: #0a0; }
        .footer {
            text-align: center;
            color: #999;
            font-size: 12px;
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📈 每日财经资讯</h1>
            <p>${DATE}</p>
        </div>
HTML_HEAD

    # 新浪财经 7x24快讯
    cat >> "$REPORT_HTML" << 'HTML_S1'
        <div class="section">
            <div class="section-title">📰 新浪财经 - 7x24快讯</div>
HTML_S1
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "            <div class=\"news-item\">$line</div>" >> "$REPORT_HTML"
        fi
    done < "$TEMP_SINA"

    # 雪球热门股票
    cat >> "$REPORT_HTML" << 'HTML_S2'
        </div>
        <div class="section">
            <div class="section-title">📊 雪球 - 热门股票</div>
            <table class="stock-table">
                <tr><th>排名</th><th>股票</th><th>价格</th><th>涨跌幅</th><th>热度</th></tr>
HTML_S2
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 解析雪球表格行: | rank | symbol | name | price | changePercent | heat |
            rank=$(echo "$line" | sed 's/|/|/g' | awk -F'|' '{print $2}' | tr -d ' ')
            name=$(echo "$line" | sed 's/|/|/g' | awk -F'|' '{print $4}' | tr -d ' ')
            price=$(echo "$line" | sed 's/|/|/g' | awk -F'|' '{print $5}' | tr -d ' ')
            change=$(echo "$line" | sed 's/|/|/g' | awk -F'|' '{print $6}' | tr -d ' ')
            heat=$(echo "$line" | sed 's/|/|/g' | awk -F'|' '{print $7}' | tr -d ' ')

            # 设置颜色
            if [[ "$change" == *"%"* ]]; then
                if [[ "$change" == "-"* ]]; then
                    color_class="stock-down"
                else
                    color_class="stock-up"
                fi
            else
                color_class=""
            fi

            echo "                <tr><td>$rank</td><td>$name</td><td>$price</td><td class=\"$color_class\">$change</td><td>$heat</td></tr>" >> "$REPORT_HTML"
        fi
    done < "$TEMP_XUEQIU"
    echo "            </table>" >> "$REPORT_HTML"

    # 知乎热榜
    cat >> "$REPORT_HTML" << 'HTML_S3'
        </div>
        <div class="section">
            <div class="section-title">💬 知乎 - 热榜</div>
HTML_S3
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "            <div class=\"news-item\">$line</div>" >> "$REPORT_HTML"
        fi
    done < "$TEMP_ZHIHU"

    # 微博热搜
    cat >> "$REPORT_HTML" << 'HTML_S4'
        </div>
        <div class="section">
            <div class="section-title">🔥 微博 - 热搜</div>
HTML_S4
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            encoded=$(echo "$line" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))")
            echo "            <div class=\"news-item\"><a href=\"https://s.weibo.com/weibo?q=%23${encoded}%23\" target=\"_blank\">$line</a></div>" >> "$REPORT_HTML"
        fi
    done < "$TEMP_WEIBO"

    # 东方财富
    cat >> "$REPORT_HTML" << 'HTML_S5'
        </div>
        <div class="section">
            <div class="section-title">📰 东方财富 - 市场快讯</div>
HTML_S5
    while IFS='|' read -r title url; do
        if [ -n "$title" ]; then
            if [ -n "$url" ]; then
                echo "            <div class=\"news-item\"><a href=\"$url\" target=\"_blank\">$title</a></div>" >> "$REPORT_HTML"
            else
                echo "            <div class=\"news-item\">$title</div>" >> "$REPORT_HTML"
            fi
        fi
    done < "$TEMP_EMF"

    # 36氪
    cat >> "$REPORT_HTML" << 'HTML_S6'
        </div>
        <div class="section">
            <div class="section-title">💼 36氪 - 科技创业</div>
HTML_S6
    while IFS='|' read -r title url; do
        if [ -n "$title" ]; then
            if [ -n "$url" ]; then
                echo "            <div class=\"news-item\"><a href=\"$url\" target=\"_blank\">$title</a></div>" >> "$REPORT_HTML"
            else
                echo "            <div class=\"news-item\">$title</div>" >> "$REPORT_HTML"
            fi
        fi
    done < "$TEMP_36KR"

    cat >> "$REPORT_HTML" << HTML_FOOT
        </div>

        <div class="footer">
            <p>报告生成于 ${DATE} $(date +"%H:%M:%S")</p>
        </div>
    </div>
</body>
</html>
HTML_FOOT

    # 清理临时文件
    rm -f "$TEMP_SINA" "$TEMP_XUEQIU" "$TEMP_ZHIHU" "$TEMP_WEIBO" "$TEMP_EMF" "$TEMP_36KR"

    log_info "报告已生成: $REPORT_FILE"
    log_info "HTML已生成: $REPORT_HTML"
}

main() {
    echo "=========================================="
    echo "   📊 每日财经资讯报告生成器"
    echo "=========================================="
    echo ""

    generate_report

    if [ "$1" == "--send-email" ] || [ "$1" == "-s" ]; then
        echo ""
        send_email
    fi

    echo ""
    echo "[INFO] 完成！"

    if [ "$1" == "--open" ] || [ "$1" == "-o" ]; then
        open "$REPORT_FILE"
    fi
}

main "$@"