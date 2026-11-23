---
name: leaving-pr-comments
description: Use whenever you post a comment, review or reply on GitHub for the user. Keeps it direct and grounded, checks it for secrets, and confirms GitHub returned its URL. Not for PR descriptions or commit messages; use file-pr.
---

# Leaving PR Comments

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

## 1. Write the reply

- Lead with the conclusion.
- Cite the code, behavior, check or reproduction it rests on.
- Keep it short, with no filler, canned thanks or status narration.
- Separate verified facts from judgment.

**Done when** the first sentence states the conclusion.

## 2. Check and post it

Check the whole comment, including quoted text and attachments, for secrets and private details.
Preview the final Markdown so quoting and blank lines render as shown. In T3 Code post with
`pull_request_respond` or `pull_request_review`; elsewhere use `gh`. Resolve a review thread only
after its reply posted.

**Done when** GitHub returned the comment or review URL.

## Hard rules

- Post in the user's voice. Add no agent marker, callout, signature or footer, and never name an
  AI tool, model or harness.

## Report

- Each comment URL, and each thread resolved
