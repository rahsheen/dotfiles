---
name: jira-attachments
description: >-
  Download a Jira ticket's attachments (screenshots, mockups, videos, files) so
  you can view them. Use when a ticket, comment, or `jira issue view` output
  shows an [attachment] placeholder or refers to an attached design.
---

# Jira attachments

jira-cli and the Atlassian MCP show attachments only as placeholders. This
script downloads them through the Jira REST API with the jira-cli credentials.

```bash
~/.claude/skills/jira-attachments/scripts/jira-attachments <KEY> <scratchpad-dir>
```

- It prints one line per file: the MIME type, then the local path.
- Read each image with the Read tool. Read a PDF with the `pages` parameter.
- When `ffmpeg` is installed, a video also gets a `<file>.frames/` directory
  with up to 20 frames, one every 2 seconds. Read the frames in order.
- Without `ffmpeg`, report the video's filename and ask the user to describe it.

Done when you have read every image, PDF, and video frame that bears on the
ticket, and you can state what each one shows.

Auth needs `$JIRA_API_TOKEN` and `~/.config/.jira/.config.yml` (`server`,
`login`), the same setup jira-cli uses.
