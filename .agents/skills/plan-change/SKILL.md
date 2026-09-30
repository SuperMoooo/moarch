---
name: plan-change
description: "Plan a change to moarch before writing it, by interviewing the user until every decision is settled: what generated projects get, both stacks, opt-in or always, how it is detected, what existing projects do, the agent guide, and the size of the release. Use only when the user asks to plan, scope, design or be grilled on a change — never for one that is already specified."
---

# Plan a change

An interview that ends in a plan — nothing is written here. A change to a
template lands in other people's projects, and most of what goes wrong with
one is a decision nobody made: the other stack, the projects that already
exist, the skill that still describes the old way.

## How to ask

The decisions form a tree: some can only be put once others are settled.
Work it in rounds.

- **A round is every question that can be answered now.** Number them, and
  give each your recommended answer with its reason in one line, so the user
  can reply `1 yes, 2 no — …`. A question that hangs off one still open waits
  for the next round.
- **Facts are yours to find; decisions are the user's.** What the templates
  generate today, which catalog entries and `ScaffoldContext` getters exist,
  what the last release was: read it, do not ask. What generated projects
  should get: ask, do not assume.
- **What `AGENTS.md` settles is not a question**: generators go through
  `StackTemplates`, options are detected and never remembered, edited files
  are never overwritten, there is no entity layer. Never offer a flag for a
  matter of taste — "Make it your own" in `README.md` is the answer to those.
- **Skip what the user already said**, and what does not apply.
- **Done when no question is left.** Then write the plan and wait for the
  user to confirm it before changing anything.

## The decisions

In the order they unblock each other.

### What generated projects get

- **The outcome, in the project's terms** — the files, the code in them, the
  command a developer runs. Not "a template for X".
- **Whose convention it is** — something every project should have, or one
  team's taste. The second is a no, or a clone.
- **What is out** — what this deliberately does not do yet.

### Where it lives

- **Always, or opt-in** — written by every `init`, or behind a checklist
  option (`add-init-option`), and whether that option is on by default and
  what it excludes.
- **A file, a widget, a command or a patch** — a generated file
  (`add-template`), a kit widget (`add-widget`), a new `create` subcommand, or
  a change to a file moarch does not own (one of the `*_utils.dart` patchers,
  or a `PlatformRequirement`).
- **Both stacks** — what the Riverpod and the bloc versions are. If one stack
  has no equivalent, say why (`hasActionBase` is the pattern).
- **What it varies with** — Dio, Firestore, the router, dark theme,
  localization… and the `ScaffoldContext` / `WidgetVariants` getter that
  detects each off disk. A new variant needs a new getter, and a marker on
  disk it can read.
- **The catalog** — the slug (one namespace with widget slugs, group slugs
  and `all`), the path, the category.

### Projects that already exist

- **What `moarch update` does to them** — a changed template refreshes
  untouched files and reports edited ones. Does the refreshed file still
  compile in a project that lacks something newer (an endpoint, a token, a
  module)? `inlineMissingEndpoints` / `inlineMissingTokens` and
  `singleFileInjector` are how that was handled before.
- **A new file** — `update` never adds one. Either existing projects do
  without, or `doctor` offers it (`ProjectInspector`, with a fix), and then:
  how a project that declined it is told apart from one that predates it.
- **A moved or removed file** — `movedFrom` on the spec, or what is left
  behind.
- **Breaking** — anything a developer has to change by hand after updating.

### What describes it

- **The agent guide** — which rule in `agents_templates.dart` and which
  skills in `skills_templates.dart` name the path, command or pattern that is
  changing.
- **The docs** — the package `README.md`, the generated README
  (`readme_templates.dart`), `docs/*.md` templates, and this repo's
  `AGENTS.md` when the architecture it describes changes.

### Proof and release

- **Tests** — which `test/<thing>_test.dart` asserts on the new text, for
  both stacks and both values of each option.
- **Whether it must be built** — anything that changes generated Dart needs
  `try-scaffold`, on both stacks.
- **The size** — patch, minor or major, by how big the change is
  (`release`), and whether the last commit already shipped a version.

## The plan

Reply with it; write it to a file only if the user asks. It holds:

1. **The decisions**, one line each, in the order above.
2. **What is still unknown** — never a guess dressed as a decision.
3. **The work, as the skills that do each part**: `add-init-option`,
   `add-template`, `add-widget`, then `try-scaffold` and `release`.

Stop there. The change starts when the user says the plan is right.
