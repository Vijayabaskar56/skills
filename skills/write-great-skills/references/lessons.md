# Lessons behind the rules

Distilled from pstack (poteto) and Matt Pocock's skills, and from building `mobile/ship-builds` and `general/figma-to-code`.
Each lesson has the rule, why it holds, and a before-and-after from a real skill.

## 1. Rules the agent must follow become scripts

A skill is a prompt, and the agent can skim past any sentence in it. A script cannot be skimmed.

- Before: "`asc xcode archive` exits 0 on failure. Check the log for ARCHIVE SUCCEEDED."
- After: `ship-builds/scripts/build-ios.sh` greps the log itself and exits 1 on failure.

A script can still check the wrong thing. `upload-ios.sh` first compared the IPA to the requested
build number; Xcode's export renumbered the build, the check passed, and a real build shipped.
The fix compared against the archive too. Test what the check compares, not only that it runs.

## 2. Keep SKILL.md to what every run needs

Everything in SKILL.md fills the agent's context on every run. Workflow skills in both collections
run 30 to 110 lines.

- Before: 189 lines, including a first-run detection table, a config schema and a failure table.
- After: 120 lines. First run, signing and troubleshooting moved to `references/`, the config
  example to `assets/`.

## 3. Every step has a finish line

Without one, the agent decides when a step is done, often too early.

- Before: "Start both builds in the background."
- After: "**Done when** build-ios prints the same N and build-android prints a path."

## 4. Reruns end in the same state

Runs crash, time out and get interrupted. Ask what the previous run left behind.

- Before: the upload step always exported and uploaded.
- After: `upload-ios.sh` asks App Store Connect first; if build N is there, it only sets notes.
  `bump-ios-build.sh` returns the same number until a build is uploaded.

## 5. Find facts, ask for choices, remember answers

"Finding facts is your job, never the user's" (Matt Pocock).

- The bundle id and scheme come from the repo; nobody is asked for them.
- Beta groups are a choice, so they are asked once with a recommended answer first.
- Answers go to `.ship-builds.json`; the second run asks nothing.

## 6. State the rule; explain only when it looks wrong

"Tell it to do the thing and skip the reason" (pstack). Phrase rules as the action to take,
because a prohibition puts the forbidden action in the agent's mind.

- Before: "Never upload without the version check."
- After: the upload script refuses on a mismatch, and the prose says what the script guarantees.
- Headings are verbs ("Bump the iOS build number"), conditions come first ("If validate fails,
  stop the run").

## 7. Do not restate the environment

A table of what the machine has goes stale; the agent can look instead. Matt Pocock calls such a
table a cache.

- Before: a tools table listing each tool, its check command and install hint.
- After: `ship-builds/scripts/doctor.sh` checks the real machine and prints what is missing.

## 8. Descriptions name triggers and near misses

The description decides when the skill loads. Lead with the triggers, merge synonyms, and route
near misses away.

- `ship-builds` ends with "Not for EAS builds or App Store releases; use eas-app-stores", because
  both answer "make a TestFlight build".

## 9. The report is evidence

"Report the evidence, not just the outcome" (pstack). A fixed list of printed values lets a
reviewer check the run without redoing it: commit and tag, build number and processing state, groups,
artifact path, size and signer, and every skipped step with its reason.

## 10. A shared skill carries no project facts

A skill written inside one repo fills up with that repo: its paths, component names, tokens, fonts,
deep link scheme and the author's own folders. Nobody else can use it, and it breaks when the repo
moves on.

- Before: `figma-to-react-native` named the author's own design folder, the app's text component, its token file,
  the app's font weight tokens and its `myapp://` deep link inline, and ran a repo-local text-diff script
  and the repo's own figma-critic agent definition.
- After: `figma-to-code` reads `.figma-to-code.json` and a notes file for every project fact, and
  bundles its own `figma-to-code/scripts/text-diff.mjs` and `figma-to-code/assets/figma-critic.md`. Project facts moved into
  the repo's `docs/figma-to-code.md`, where they are tracked with the code they describe.

Two look-alike facts still need two fields. One `assetDir` first stood for both the folder Figma
may write to and the repo's asset folder; they are different directories.

## 11. Platform differences get a shared core and one file per platform

When the same job runs on two stacks, most steps are identical and a few differ.

- Before: one React Native skill whose verification step assumed a simulator.
- After: steps 1 to 5 are shared; step 6 points to `verify-react-native.md` (argent) or
  `verify-web.md` (agent-browser), and each deep reference has a neutral part plus a React Native
  and a Web section.

## 12. Every dependency gets a setup check

A skill that needs a CLI, an MCP server or a running app fails halfway through a run when one is
missing, after the agent has already done work.

- Before: `figma-to-react-native` assumed ffmpeg, argent and both Figma MCP servers, and first
  found out otherwise mid-task.
- After: step 0 runs `figma-to-code/scripts/doctor.sh <platform>`, which prints `ok`, `missing` with the fix,
  `optional`, or `session` for checks only the agent can make (an MCP tool answering). Install and
  connection steps live in `figma-to-code/references/setup.md`.

## 13. Check claims before they ship

Skills state facts about the world, and agents writing skills state them confidently.

- A restructuring agent wrote "nothing in lint enforces this" for `no-use-effect`; `.oxlintrc.json`
  already set a no-direct-useEffect rule to error, so the new check script duplicated a better
  lint rule. Search for existing enforcement before writing a check.
- The figma references pointed at a colour file and a component, both deleted months earlier.
- Two platform sections gave different blur conversions (`R/3` and `R/2`) for the same quantity,
  both stated as facts and neither measured. One rule now says "start in that range, calibrate,
  record the ratio".

## Sources to read next

- pstack `poteto-mode/playbooks/authoring-a-skill.md`: deletion-first authoring.
- Matt Pocock `writing-for-agents`: inline versus pointer, triggers, prompting the positive.
- pstack `principle-encode-lessons-in-structure` and `principle-make-operations-idempotent`.
