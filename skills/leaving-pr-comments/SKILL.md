---
name: leaving-pr-comments
description: Use whenever you post a comment, review or reply on GitHub for the user. Marks it as an agent reply with a NOTE callout, checks it for secrets, keeps it direct, and confirms GitHub returned its URL. Not for PR descriptions or commit messages; use file-pr.
---

# Leaving PR Comments

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

## 1. Mark it as an agent reply

Start every comment you post for the user with this GitHub note callout:

```md
> [!NOTE]
> 🤖 **Agent responding on behalf of <user>**

Actual comment starts here.
```

Use the user's name or GitHub login. Keep the marker inside the note and the reply outside it. The
line starts with the robot emoji. Do not add a horizontal rule, Setext underline, heading,
signature footer or a second marker.

Apply it to top-level PR comments, inline review comments, replies to bots or reviewers, and
written reasons given before resolving or dismissing feedback. Do not add it to PR descriptions,
commit messages, or text the user asked you to post word for word without it.

**Done when** the draft opens with the callout and nothing else marks it.

## 2. Write the reply

- Lead with the conclusion.
- Cite the code, behavior, check or reproduction it rests on.
- Keep it short, with no filler, canned thanks or status narration.
- Separate verified facts from judgment.

**Done when** the first sentence states the conclusion.

## 3. Check and post it

Check the whole comment, including quoted text and attachments, for secrets and private details.
Preview the final Markdown so quoting and blank lines render as shown. In T3 Code post with
`pull_request_respond` or `pull_request_review`; elsewhere use `gh`. Resolve a review thread only
after its reply posted.

**Done when** GitHub returned the comment or review URL.

## Hard rules

- Never post a comment for the user without the agent callout, unless they asked for the exact
  text without it.
- Never name a model or harness in the callout. It says an agent wrote it; it does not credit one.

## Report

- Each comment URL, and each thread resolved
