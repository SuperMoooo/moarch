---
name: release
description: "Version and changelog a moarch change so it can be pushed: pick the bump, update pubspec.yaml, lib/src/version.dart and CHANGELOG.md, and pass every CI gate. Use at the end of any change that ships, or when asked to bump, release or publish."
---

# Release a change

Every push that carries a new version publishes it to pub.dev. A change folded
into a version that is already committed either never ships or ships
unannounced.

## Steps

1. **Is the current version already on its way out?**

   ```bash
   git show HEAD -- pubspec.yaml | grep '^[-+]version:'
   ```

   - The last commit changed `version:` → this change needs a **new** bump.
     Never add it to that version's changelog entry.
   - It did not → the pending bump (in the working tree) is shared; raise it
     if this change is bigger than the bump already made.

2. **Pick the number** by how big the change is, not by strict semver:
   - big change → major (`X.0.0`)
   - medium (a new command, option or group of files) → minor (`x.Y.0`)
   - small adjustment or fix → patch (`x.y.Z`)

   If strict semver would say something different (a breaking change in a
   minor), say so in one line, but go with this sizing.

3. **Write it in three places:**
   - `pubspec.yaml` → `version:`
   - `lib/src/version.dart` → `packageVersion` (duplicated because the pubspec
     is unreadable once globally activated; CI fails if they differ)
   - `CHANGELOG.md` → a new `## x.y.z` entry at the top, newest first.
     Bullets say what a user of the generated project sees and what an
     existing project has to do (`moarch update <name>`, `moarch doctor
     --fix`). Put anything breaking under `**Breaking**` first.

4. **Pass CI locally**, in its order:

   ```bash
   dart format --output=none --set-exit-if-changed .
   dart analyze --fatal-infos
   dart test
   dart pub publish --dry-run
   ```

Do not commit, tag or push unless asked.
