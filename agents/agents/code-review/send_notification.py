#!/usr/bin/env python3
"""
Simple webhook sender for Code Review Agent
This script can be called by the agent to send notifications to RocketChat
"""

import json
import sys
import requests
from datetime import datetime


def send_rocketchat_notification(webhook_url: str, review_data: dict, repo_name: str = "", branch_name: str = ""):
    """Send code review results to RocketChat webhook"""
    
    try:
        summary = review_data.get('summary', {})
        issues = review_data.get('issues', [])
        approved = review_data.get('approved', False)
        
        # Count issues by severity
        critical_count = summary.get('critical_issues', 0)
        high_count = summary.get('high_issues', 0)
        
        # Determine emoji and status
        if approved:
            status_emoji = "✅"
            status_text = "Approved"
        elif critical_count > 0:
            status_emoji = "❌"
            status_text = "Blocked - Critical Issues"
        elif high_count > 0:
            status_emoji = "⚠️"
            status_text = "Changes Required - High Priority Issues"
        else:
            status_emoji = "🟡"
            status_text = "Changes Required"
        
        # Build message
        repo_info = f" in {repo_name}" if repo_name else ""
        branch_info = f" on `{branch_name}`" if branch_name else ""
        
        message = f"""🔍 **Code Review Report{repo_info}{branch_info}**
{status_emoji} **Status:** {status_text}
📊 **Score:** {summary.get('overall_score', 0)}/10
📁 **Files:** {summary.get('files_reviewed', 0)}
🔢 **Issues:** {summary.get('total_issues', 0)}

🚨 **Critical:** {critical_count}
🔴 **High:** {high_count}
🟡 **Medium:** {summary.get('medium_issues', 0)}
🟢 **Low:** {summary.get('low_issues', 0)}"""
        
        # Add critical/high issues details
        critical_issues = [i for i in issues if i.get('severity') == 'critical']
        high_issues = [i for i in issues if i.get('severity') == 'high']
        
        if critical_issues:
            message += f"\n\n🚨 **Critical Issues:**"
            for issue in critical_issues[:2]:  # Show top 2
                message += f"\n• **{issue.get('title', 'Unknown')}** (`{issue.get('file', 'unknown')}:{issue.get('line', '?')}`)"
        
        if high_issues:
            message += f"\n\n🔴 **High Priority Issues:**"
            for issue in high_issues[:2]:  # Show top 2
                message += f"\n• **{issue.get('title', 'Unknown')}** (`{issue.get('file', 'unknown')}:{issue.get('line', '?')}`)"
        
        # RocketChat payload
        payload = {
            "text": message,
            "alias": "Code Review Bot",
            "emoji": ":robot_face:",
            "attachments": [{
                "title": "Full Code Review Results",
                "color": "good" if approved else "warning" if high_count > 0 else "danger",
                "fields": [
                    {"title": "Repository", "value": repo_name or "Unknown", "short": True},
                    {"title": "Branch", "value": branch_name or "Unknown", "short": True},
                    {"title": "Approved", "value": "Yes" if approved else "No", "short": True},
                    {"title": "Review Time", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC"), "short": True}
                ]
            }]
        }
        
        # Send to RocketChat
        response = requests.post(
            webhook_url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        if response.status_code == 200:
            print("RocketChat notification sent successfully")
            return True
        else:
            print(f"Failed to send RocketChat notification: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"Error sending RocketChat notification: {str(e)}")
        return False


if __name__ == "__main__":
    # Usage: python3 send_notification.py <webhook_url> <review_json> [repo_name] [branch_name]
    if len(sys.argv) < 3:
        print("Usage: python3 send_notification.py <webhook_url> <review_json> [repo_name] [branch_name]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    review_json = sys.argv[2]
    repo_name = sys.argv[3] if len(sys.argv) > 3 else ""
    branch_name = sys.argv[4] if len(sys.argv) > 4 else ""
    
    try:
        review_data = json.loads(review_json)
        success = send_rocketchat_notification(webhook_url, review_data, repo_name, branch_name)
        sys.exit(0 if success else 1)
    except json.JSONDecodeError:
        print("Invalid JSON provided for review data")
        sys.exit(1)