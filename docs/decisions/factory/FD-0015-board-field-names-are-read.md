# FD-0015. A board's field names are read, never assumed

**Status:** Accepted
**Date:** 2026-08-14
**Enforced by:** advisory: no automated check. The honest options were all worse than saying so.
A conform check would read every registered board and needs a token and the network, which
`docs/testing.md` excludes on purpose. A grep that no script compares a field name to a literal
constrains the shape of the code rather than the state of the boards, and would pass a script that
resolved two names and still got them wrong. This line says advisory rather than naming a check
that does not exist, which is the defect BOOT-86 was opened for.

## Context

Every app's board carries three fields the factory depends on: `Lane`, `Priority`, and the work
type. Scripts read them by name.

GitHub reserves the name `Type` on Projects v2. `gh project field-create --name "Type"` is refused.
Boards created before the reservation keep the field and are grandfathered; boards created after it
cannot have one under that name. So the fleet permanently contains two spellings of the same field:

- older boards, including `_bootstrap`'s own, carry `Type`
- boards created since carry `Work type`

Measured on 2026-08-14 by creating a throwaway app end to end. Its board came out with `Lane`
[New, Up next, Doing, Verify, Blocked, Done], `Priority` [High, Med, Low] and `Work type`
[Bug, Feature, Chore]: the same option sets a working board has, differing only in that one name.
A ticket was then filed onto a board of the new shape and its type set, which proves the reading
side works against both spellings.

Neither obvious repair exists. Renaming new boards back to `Type` is the operation GitHub refuses.
Adopting GitHub's native issue types is unavailable: they are an organisation feature, this is a
User account, and `repository.issueTypes` is null.

This is not a migration state. There is no migration. It is the permanent shape of the fleet.

## Decision

**A script that reads a board field resolves it by trying the names the fleet actually uses, in
order, and fails naming every name it tried if none is present. No script assumes one spelling, and
no script renames or migrates an existing board.**

For the work type field the order is `Type`, then `Work type`.

Three consequences, each stated because someone will otherwise try it:

- **Existing boards are never migrated.** They keep the field they have. A rename is a destructive
  operation on live data, to buy a consistency the readers do not need.
- **New boards are created under the name GitHub accepts.** Creating under a reserved name does not
  produce a differently named field, it produces no field at all and a board the ticket scripts
  cannot use.
- **A failed resolution names the candidates it tried.** "Field not found" without the list sends
  the reader to the wrong repo, because the real cause is a board made under a name now refused.

## Consequences

The fleet keeps two names for one field, permanently, and that is accepted rather than tolerated.
The cost is one lookup in each reader. The benefit is that the next reservation is handled by adding
a candidate rather than by discovering it through a board that came up empty.

This generalises past the work type field. Anything GitHub can reserve, it can reserve later, and
`Status` is already a built-in name on every Projects v2 board.

**The gap this leaves, stated rather than implied:** nothing checks compliance. A script added
tomorrow that compares a field name to a single literal will not be caught by any gate, and the
first symptom will be a board the ticket scripts cannot use. If that happens twice, the answer is
the conform check and the token it needs, not a tighter grep.
