# TIA-50 draft: `xcc get-trigger` in the TestFlight recipe

Draft for [TIA-50](https://github.com/Prinzaessin86/tiara-site/issues/50). The runbook is not a file:
it is the `SEED.runbook` array on `index.html:699`, and `:980` replaces `data.runbook` with the
code copy on every load. So this is a code edit, and it lands with a `TIARA_VERSION` bump.

This document exists because that whole line is one 40,000-character JSON blob, so a git diff of it
is unreadable. Below is the prose before and after, then the exact JSON to paste.

Verified before drafting: `get-trigger` is committed and clean in `_bootstrap/scripts/xcc.js`,
`--strict` exists, and I ran both against the live App Store Connect account.

---

## Change 1 of 2: a new verification step

**Currently:** the recipe has six steps and no way to read the trigger. Between *"Onboard each app
as its OWN Xcode Cloud product"* and *"Set the build number in XCODE CLOUD"* there is nothing that
confirms the thing step one just told you to configure.

**Add, as the new step 2:**

> **do:** Check the trigger without changing it
>
> **why:** the files filter lives only in App Store Connect. Nothing on disk records it and
> `xcc workflows` does not print it, so until now the only ways to answer "is the trigger right"
> were to click through App Store Connect or to run `set-trigger`, which is a write. Reading a
> setting should not require changing it.
>
> **how:** `cd ~/Developer/_bootstrap && . scripts/xcc.env && ./scripts/xcc get-trigger [app]`
>
> **check:** the workflow prints `version trigger: YES` and a `filesAndFoldersRule` naming
> `Config/Version.xcconfig`. Run with no app name to audit every product at once. `--strict` exits 1
> when a workflow has no version trigger at all, so it works in a script. Note what it does **not**
> catch: a rule that is broader than FD-0010, such as matching any `.xcconfig` in `Config/`, is
> reported in words but still exits 0.

Real output, run today:

```
$ ./scripts/xcc get-trigger rainybow
rainybow
  - CI CD rainybow  id=50C40D17-E1ED-4EFD-AD4A-C0C64D24C45A  enabled=true
      version trigger: YES
      filesAndFoldersRule: {"mode":"START_IF_ANY_FILE_MATCHES","matchers":[{"directory":"Config","fileExtension":null,"fileName":"Version.xcconfig"}]}
      branches: {"isAllMatch":false,"patterns":[{"pattern":"main","isPrefix":false}]}  autoCancel: true

VERSION-TRIGGER: 1/1 workflow(s) fire on Config/Version.xcconfig.
```

### The `--strict` caveat is not hypothetical

Running it across every product found one live deviation:

```
PagingDrDaddy
  - Push PDD to Testflight  enabled=true
      version trigger: YES, by a BROADER rule than FD-0010
      filesAndFoldersRule: {... "directory":"Config","fileExtension":"xcconfig","fileName":null}

VERSION-TRIGGER: 5/5 workflow(s) fire on Config/Version.xcconfig, 1 of them by a rule broader than FD-0010.
exit=0
```

PDD's release workflow fires on **any** `.xcconfig` in `Config/`. The tool says so plainly and
`--strict` still passes it. That is why the drafted step describes the limit rather than calling
`--strict` a gate. Making it fail on a broader rule is a change to `xcc.js` and belongs in its own
ticket.

---

## Change 2 of 2: repoint the failure line

**Currently**, in the "When a build fails" step:

> NO runs ever fired ▸ the workflow's files filter is wrong or missing (classic: 'xconfig' typo,
> should be 'xcconfig').

It names the cause and leaves you to go and look in App Store Connect.

**Replace with:**

> NO runs ever fired ▸ the workflow's files filter is wrong or missing (classic: 'xconfig' typo,
> should be 'xcconfig'). Read it rather than guessing: `./scripts/xcc get-trigger <app>` prints the
> live rule.

Nothing else in that step changes.

---

## The exact JSON

`index.html:699`, inside the `{"id": "testflight", …}` recipe. Insert as the second element of its
`steps` array, immediately after the onboarding step:

```json
{"do": "Check the trigger without changing it",
 "why": "the files filter lives only in App Store Connect. Nothing on disk records it and 'xcc workflows' does not print it, so the only ways to answer 'is the trigger right' were to click through App Store Connect or to run set-trigger, which is a write. Reading a setting should not require changing it.",
 "how": "cd ~/Developer/_bootstrap && . scripts/xcc.env && ./scripts/xcc get-trigger [app]   (no app name audits every product; --strict exits 1 when a workflow has no version trigger)",
 "check": "the workflow prints 'version trigger: YES' and a filesAndFoldersRule naming Config/Version.xcconfig. Caveat: a rule BROADER than FD-0010, such as any .xcconfig in Config/, is reported in words but still exits 0, so --strict is not a full gate."}
```

And in the final step's `how`, replace:

```
NO runs ever fired ▸ the workflow's files filter is wrong or missing (classic: 'xconfig' typo, should be 'xcconfig').
```

with:

```
NO runs ever fired ▸ the workflow's files filter is wrong or missing (classic: 'xconfig' typo, should be 'xcconfig'). Read it rather than guessing: ./scripts/xcc get-trigger <app> prints the live rule.
```

---

## Applying it

1. Edit `SEED.runbook` on `index.html:699` as above.
2. Bump `TIARA_VERSION` on `index.html:2263`. Required by `tiara-site/CLAUDE.md` and by
   `scripts/hooks/pre-commit`.
3. Update `**Describes:**` in `tiara/docs/HOW-TIARA-WORKS.md` to the same version.
4. Commit citing both a full `TICKET:` URL **and** a bare `TIA-50`. The URL alone fails the
   deliverable gate, which is [_ticketflow#7](https://github.com/Prinzaessin86/_ticketflow/issues/7).

Not applied here: the `TIARA_VERSION` bump was refused by a permission guard during the session
this was drafted in, and a runbook edit without the bump would break the convention rather than
follow it.
