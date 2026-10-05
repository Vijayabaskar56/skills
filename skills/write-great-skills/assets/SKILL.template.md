---
name: skill-name
description: Use when <trigger>, <second distinct trigger>. <What it does in one sentence>. Not for <nearest wrong match>; use <other skill>.
argument-hint: "<what the user passes, if anything>"
---

# Skill title

<One or two lines the agent needs before step 1: what overrides this file, where scripts live,
and the per-repo config and notes file that hold project facts.>

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line with `references/setup.md`, asking once before
installing anything, and confirm each `session` line yourself. <Delete this step if the skill needs
nothing outside itself.>

**Done when** doctor exits 0.

## 1. <Verb phrase>

<Condition first, then the instruction. Point to scripts/<name>.sh for any check that must not be skipped.>

**Done when** <observable fact: a file exists, a command exits 0, a value is printed>.

## 2. <Verb phrase>

<...>

**Done when** <...>.

## Hard rules

- <Action to take, phrased positively. Name the consent source for anything irreversible.>

## Report

- <Value the scripts or tools printed, quoted>
- Skipped steps, each with its reason
