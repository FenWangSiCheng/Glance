#!/usr/bin/env python3
"""
Daily report generator and email sender for Redmine time entries.

Reads SMTP config from environment variables:
- SMTP_HOST: SMTP server host (default: smtp.exmail.qq.com)
- SMTP_PORT: SMTP port (default: 465)
- EMAIL_USER: Sender email address (企业微信邮箱)
- EMAIL_PASS: Client-specific password (客户端专用密码)
- EMAIL_TO: Recipients, comma-separated
- EMAIL_SENDER_NAME: Sender display name (用于日报签名和邮件 From 字段)

Usage:
    python3 send_report.py test
    python3 send_report.py send --data '[{"project_name":"...", "hours":"2.0", "comments":"..."}]'
"""

import os
import sys
import json
import smtplib
import argparse
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formatdate
from typing import Dict, List, Any


class EmailError(Exception):
    """Custom exception for email errors."""
    pass


def load_config() -> Dict[str, str]:
    """Load and validate email configuration from environment variables."""
    config = {
        'smtp_host': os.getenv('SMTP_HOST', 'smtp.exmail.qq.com'),
        'smtp_port': os.getenv('SMTP_PORT', '465'),
        'email_user': os.getenv('EMAIL_USER', ''),
        'email_pass': os.getenv('EMAIL_PASS', ''),
        'email_to': os.getenv('EMAIL_TO', ''),
        'sender_name': os.getenv('EMAIL_SENDER_NAME', ''),
    }

    missing = []
    if not config['email_user']:
        missing.append('EMAIL_USER')
    if not config['email_pass']:
        missing.append('EMAIL_PASS')
    if not config['email_to']:
        missing.append('EMAIL_TO')
    if not config['sender_name']:
        missing.append('EMAIL_SENDER_NAME')

    if missing:
        raise EmailError(f"Missing required environment variables: {', '.join(missing)}")

    return config


def group_entries_by_project(entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Group time entries by project name.
    Sorted by total_hours descending — matches Swift entriesByProject behavior.
    """
    grouped: Dict[str, Dict[str, Any]] = {}

    for entry in entries:
        project = entry.get('project_name', '未知项目')
        if project not in grouped:
            grouped[project] = {
                'project_name': project,
                'total_hours': 0.0,
                'comments': []
            }

        hours = float(entry.get('hours', 0))
        grouped[project]['total_hours'] += hours

        comment = entry.get('comments', '')
        if comment:
            grouped[project]['comments'].append(comment)

    return sorted(grouped.values(), key=lambda g: g['total_hours'], reverse=True)


def generate_html_report(entries: List[Dict[str, Any]], sender_name: str) -> str:
    """
    Generate HTML daily report.
    Format:
      - grouped by project (sorted by hours desc)
      - per group: <h3>project</h3> + 内容 (comments joined by ；) + 时间
    """
    groups = group_entries_by_project(entries)

    body = f'各位好，我是{sender_name}<br/>\n'
    body += '下面是今日的工作汇报，请查收。<br/><br/>\n'
    body += '■ 今日成果 <br/>\n'

    for group in groups:
        body += f'<h3>{group["project_name"]}</h3>\n'
        combined = '；'.join(group['comments'])
        hours_str = f'{group["total_hours"]:.1f}'
        body += f'内容：{combined}<br/>时间：{hours_str}h<br/>\n'

    html = (
        '<!DOCTYPE html>\n'
        '<html>\n'
        '<head>\n'
        '    <meta charset="UTF-8">\n'
        '    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
        '</head>\n'
        '<body>\n'
        f'{body}'
        '</body>\n'
        '</html>'
    )
    return html


def connect_smtp(config: Dict[str, str]) -> smtplib.SMTP_SSL:
    """Create authenticated SMTP_SSL connection (port 465)."""
    smtp_host = config['smtp_host']
    smtp_port = int(config['smtp_port'])
    sender = config['email_user']

    try:
        server = smtplib.SMTP_SSL(smtp_host, smtp_port)
        server.login(sender, config['email_pass'])
        return server
    except smtplib.SMTPAuthenticationError:
        raise EmailError("SMTP认证失败，请检查 EMAIL_USER 和 EMAIL_PASS（客户端专用密码）")
    except smtplib.SMTPConnectError as e:
        raise EmailError(f"连接 SMTP 服务器失败: {e}")
    except smtplib.SMTPException as e:
        raise EmailError(f"SMTP 错误: {e}")
    except Exception as e:
        raise EmailError(f"连接失败: {e}")


def send_email(config: Dict[str, str], subject: str, html_body: str) -> None:
    """Send HTML email via SMTP SSL."""
    sender = config['email_user']
    sender_name = config['sender_name']
    recipients = [r.strip() for r in config['email_to'].split(',') if r.strip()]

    msg = MIMEMultipart('alternative')
    msg['From'] = f'{sender_name} <{sender}>'
    msg['To'] = ', '.join(recipients)
    msg['Subject'] = subject
    msg['Date'] = formatdate(localtime=True)
    msg['MIME-Version'] = '1.0'
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))

    try:
        with connect_smtp(config) as server:
            server.sendmail(sender, recipients, msg.as_string())
    except EmailError:
        raise
    except smtplib.SMTPException as e:
        raise EmailError(f"发送失败: {e}")


def cmd_test(args: argparse.Namespace) -> int:
    """Test SMTP connection and authentication."""
    try:
        config = load_config()
        with connect_smtp(config) as server:
            server.quit()
        print(json.dumps({"success": True, "message": "SMTP连接测试成功"}, ensure_ascii=False))
        return 0
    except EmailError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        return 1


def cmd_send(args: argparse.Namespace) -> int:
    """Generate report from entries JSON and send via email."""
    try:
        config = load_config()
        entries = json.loads(args.data)

        if not entries:
            raise EmailError("工时记录数据为空")

        sender_name = config['sender_name']
        html_body = generate_html_report(entries, sender_name)
        subject = f'[日报] {sender_name}'

        send_email(config, subject, html_body)
        print(json.dumps({
            "success": True,
            "message": f"日报发送成功，收件人: {config['email_to']}"
        }, ensure_ascii=False))
        return 0

    except EmailError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"JSON解析错误: {e}"}, ensure_ascii=False), file=sys.stderr)
        return 1
    except Exception as e:
        print(json.dumps({"error": f"未知错误: {e}"}, ensure_ascii=False), file=sys.stderr)
        return 1


def main() -> int:
    parser = argparse.ArgumentParser(description='Redmine 工时日报生成与发送')
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # test command
    subparsers.add_parser('test', help='Test SMTP connection')

    # send command
    send_parser = subparsers.add_parser('send', help='Generate and send daily report')
    send_parser.add_argument('--data', type=str, required=True,
                             help='Time entries JSON array')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    if args.command == 'test':
        return cmd_test(args)
    elif args.command == 'send':
        return cmd_send(args)

    return 1


if __name__ == '__main__':
    sys.exit(main())
