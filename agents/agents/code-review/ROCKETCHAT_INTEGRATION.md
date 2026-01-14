# RocketChat Integration for Code Review Agent

This document describes the RocketChat webhook integration that has been added to the code review agent.

## Overview

The code review agent now supports sending formatted reports to a RocketChat channel automatically after completing a code review. This helps teams stay informed about code quality issues and review results.

## Configuration

### New Parameters

Two new parameters have been added to the agent configuration:

- `rocketchat_webhook`: The RocketChat webhook URL (defaults to your provided webhook)
- `notify_rocketchat`: Boolean flag to enable/disable RocketChat notifications (defaults to `true`)

### Usage Examples

```bash
# Enable notifications (default)
qodo code_review --notify_rocketchat=true

# Disable notifications
qodo code_review --notify_rocketchat=false

# Use custom webhook URL
qodo code_review --rocketchat_webhook="https://your-rocketchat.com/hooks/..."

# Combined with other options
qodo code_review \
  --target_branch=main \
  --severity_threshold=medium \
  --notify_rocketchat=true \
  --focus_areas=security,performance
```

## Message Format

The RocketChat notification includes:

### Header
- 📋 Review title with repository and branch information
- Overall status emoji (✅ Approved, ⚠️ Changes Required, ❌ Blocked)

### Summary Section
- Overall code quality score (0-10)
- Approval status
- Number of files reviewed
- Total issues count
- Issues broken down by severity:
  - 🚨 Critical issues
  - 🔴 High priority issues  
  - 🟡 Medium priority issues
  - 🟢 Low priority issues

### Issue Details
- Top 2 critical issues with file paths and line numbers
- Top 2 high priority issues with file paths and line numbers

### Attachments
- Detailed review summary as structured attachment
- Color-coded based on severity (green/yellow/red)
- Repository and branch information
- Timestamp

## Example Message

```
🔍 Code Review Report in my-repo on branch `feature-branch`
✅ Status: Approved
📊 Score: 8.5/10
📁 Files: 5
🔢 Issues: 2

🚨 Critical: 0
🔴 High: 0
🟡 Medium: 2
🟢 Low: 0
```

## Technical Implementation

### Files Added

1. **`rocketchat_webhook.py`** - Comprehensive webhook utility with formatting functions
2. **`send_notification.py`** - Simple script for sending notifications from the agent
3. Updated **`agent.toml`** and **`agent.yaml`** with new parameters and instructions

### Agent Integration

The agent has been updated to:

1. Include `http` tool for making webhook requests
2. Add webhook parameters to the arguments list
3. Include webhook sending instructions in the agent prompt
4. Handle webhook errors gracefully without failing the review

### Error Handling

- Webhook failures don't stop the code review process
- Error messages are logged for debugging
- Timeout protection (10 seconds) for webhook requests
- Graceful handling of network issues

## Setup Instructions

### 1. Verify RocketChat Webhook

Ensure your RocketChat webhook URL is working:
```bash
curl -X POST "https://rocketchat.flirtmetricsplatform.com/hooks/6967d3a3f093ef2ebfa21bb4/dpQmt68eiP5hBfgqCMiWCEkv49uor8PWLZKKSvXQYmAFS5AF" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test message from code review agent"}'
```

### 2. Test Integration

Test the webhook with sample data:
```bash
python3 send_notification.py \
  "https://rocketchat.flirtmetricsplatform.com/hooks/6967d3a3f093ef2ebfa21bb4/dpQmt68eiP5hBfgqCMiWCEkv49uor8PWLZKKSvXQYmAFS5AF" \
  '{"summary":{"total_issues":1,"critical_issues":0,"high_issues":1,"medium_issues":0,"low_issues":0,"files_reviewed":2,"overall_score":7.0},"issues":[],"suggestions":[],"approved":false,"requires_changes":true}' \
  "test-repo" \
  "main"
```

### 3. Configure CI/CD

Add to your GitHub Actions:

```yaml
- name: Run code review with notifications
  uses: qodo-ai/command@v1
  env:
    QODO_API_KEY: ${{ secrets.QODO_API_KEY }}
  with:
    prompt: code-review
    agent-file: agents/code-review/agent.toml
    key-value-pairs: |
      target_branch=${{ github.base_ref }}
      severity_threshold=medium
      notify_rocketchat=true
      rocketchat_webhook=${{ secrets.ROCKETCHAT_WEBHOOK_URL }}
```

## Customization

### Message Customization

You can customize the message format by modifying the `format_code_review_message()` function in `rocketchat_webhook.py`.

### Webhook Payload

The webhook uses RocketChat's standard Incoming WebHook format. See [RocketChat documentation](https://docs.rocket.chat/guides/administration/administration/integrations) for advanced formatting options.

### Conditional Notifications

Control when notifications are sent based on severity:

```bash
# Only notify for critical/high issues
qodo code_review --severity_threshold=high --notify_rocketchat=true

# Disable for low-priority changes
qodo code_review --exclude_files="*.md,*.txt" --notify_rocketchat=false
```

## Troubleshooting

### Common Issues

1. **Webhook not working**: Verify the URL and that the webhook is enabled in RocketChat
2. **No notifications**: Check that `notify_rocketchat=true` is set
3. **Errors in logs**: The agent continues working even if webhook fails

### Debug Mode

Enable debug logging:
```bash
qodo code_review --log=debug --notify_rocketchat=true
```

### Testing Webhook Independently

Test the webhook without the agent:
```bash
cd agents/agents/code-review
python3 rocketchat_webhook.py  # Shows formatted payload
python3 send_notification.py <args>  # Sends actual test message
```

## Security Considerations

- Webhook URLs contain sensitive tokens - store them as secrets in CI/CD
- The agent doesn't log webhook URLs in output
- Webhook requests have a 10-second timeout to prevent hanging
- Error messages don't expose sensitive webhook details

## Future Enhancements

Potential improvements to consider:

- Threaded messages for follow-up discussions
- Interactive buttons for quick actions
- Different message formats for different severity levels
- Integration with project management tools
- Custom emoji sets based on team preferences