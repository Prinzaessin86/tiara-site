#!/bin/sh
# Generate the GitHub issue forms from the one canonical field definition.
#
# WHY GENERATE RATHER THAN PARSE
#   The forms and make-board-ticket.sh's validator read the same list of required headings, and
#   have done since BOOT-26. Two hand written copies drift, and the drift is silent: a label typo
#   breaks the parser and the form at the same moment and neither says so. Generating means
#   there is one copy and the others are output.
#
# WHY THE SOURCE IS VALIDATED SO HARD
#   This file defines what a ticket must contain. A source edit that silently weakens a
#   requirement produces forms, a validator and a gate that all agree with the weakened form,
#   because all three were generated from it. There is then nothing left to notice. So every
#   record shape is asserted and anything unrecognised fails the run rather than being skipped.
#
# usage: sh scripts/gen-issue-forms.sh [outdir]
#   outdir defaults to .github/ISSUE_TEMPLATE. conform.sh passes a temp dir and diffs.
set -u

SRC=".github/issue-fields.psv"
OUT="${1:-.github/ISSUE_TEMPLATE}"

[ -f "$SRC" ] || { echo "gen-issue-forms: no $SRC" >&2; exit 1; }

# Generate into a staging dir and copy only on success. awk writes files as it parses and can
# only decide to fail in END, so writing straight to $OUT means a rejected source still
# destroys the committed forms and leaves a tree mixed from two generations.
STAGE=$(mktemp -d) || { echo "gen-issue-forms: could not create a staging dir" >&2; exit 1; }
trap 'rm -rf "$STAGE"' EXIT INT TERM

awk -F'|' -v out="$STAGE" -v src="$SRC" '
  function trim(s){ sub(/^[ \t\r]+/,"",s); sub(/[ \t\r]+$/,"",s); return s }
  # YAML double quoted scalar. Backslash first, then quote: the reverse order would re-escape
  # the backslashes it just inserted.
  function q(s){ gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); return "\"" s "\"" }
  function err(msg){ print "gen-issue-forms: " src " line " NR ": " msg > "/dev/stderr"; bad = 1 }
  # The header states provenance and nothing else. It used to claim "conform.sh fails if this file
  # and the source disagree", which was true only in template/: no clone carries the source, and no
  # installed conform.sh carries the check. A file asserting a guarantee nothing provides is worse
  # than one asserting nothing, because a reader stops looking. Restore the claim when the check
  # actually reaches the repos, not before (_bootstrap#18).
  function header(f){
    print "# GENERATED FILE. Do not edit."              > f
    print "# Source:     " src                          > f
    print "# Regenerate: sh scripts/gen-issue-forms.sh" > f
  }
  # A placeholder becomes a block scalar so newlines survive without quoting games.
  # Four backslashes: awk string "\\\\n" is the two chars \n, which as a split regex matches a
  # literal backslash followed by n. Two backslashes would be the regex \n, a real newline,
  # which silently leaves the escape unexpanded in the output.
  function block(f, key, val,   n, parts, i) {
    print "      " key ": |" > f
    n = split(val, parts, "\\\\n")
    for (i = 1; i <= n; i++) print "        " parts[i] > f
  }

  { sub(/\r$/, "") }            # a CR survives into the last column and is illegal inside a
                                # YAML double quoted scalar. One Windows-touched editor would
                                # otherwise produce four unloadable forms at exit 0.
  /^[ \t]*#/ { next }
  /^[ \t]*$/ { next }

  trim($1) == "meta" {
    if (NF != 6) { err("meta needs exactly 6 fields, got " NF ". No field may contain a pipe."); next }
    t = trim($2)
    if (t !~ /^[a-z][a-z0-9_-]*$/) { err("type [" t "] must be lowercase, starting with a letter"); next }
    if (t in seen)                 { err("duplicate meta for type " t); next }
    if (trim($3) == "")            { err("type " t " has an empty name"); next }
    if (trim($4) == "")            { err("type " t " has an empty description; GitHub requires one"); next }
    if (trim($6) == "")            { err("type " t " has an empty label; GitHub rejects an empty labels entry"); next }
    seen[t] = 1; order[++ntypes] = t
    file = out "/" t ".yml"
    header(file)
    print "name: " q(trim($3))        > file
    print "description: " q(trim($4)) > file
    print "title: " q($5)             > file   # NOT trimmed: the trailing space is deliberate
    print "labels:"                   > file
    print "  - " q(trim($6))          > file
    print "body:"                     > file
    next
  }

  # field, dropdown and checkboxes share every validation and differ only in what column 7 means:
  # a placeholder, or a \n separated option list. Keeping one block means a rule added here cannot
  # be forgotten on two of the three, which is how the duplicate-id check came to cover only
  # contiguous types.
  trim($1) == "field" || trim($1) == "dropdown" || trim($1) == "checkboxes" {
    kind = trim($1)
    if (NF != 7) { err(kind " needs exactly 7 fields, got " NF ". No field may contain a pipe."); next }
    t = trim($2); id = trim($3); label = trim($4); req = trim($5)
    if (!(t in seen))  { err(kind " for type " t " appears before its meta"); next }
    if (id !~ /^[a-z][a-z0-9_-]*$/) { err("id [" id "] must be lowercase, starting with a letter"); next }
    # Key on the PAIR. Keying on id alone and overwriting with the last type seen meant that any
    # type whose records were not contiguous lost the check entirely, because ids like `summary`
    # legitimately recur across types. That shipped a form with two `id: summary` entries, which
    # GitHub rejects outright, at exit 0.
    if ((t SUBSEP id) in idseen) { err("duplicate id [" id "] within type " t); next }
    idseen[t SUBSEP id] = 1
    if (label == "") { err(kind " " t "." id " has an empty label; GitHub rejects that"); next }
    if (req != "yes" && req != "no") { err("required must be yes or no, got [" req "] on " t "." id); next }
    nfields[t]++
    file = out "/" t ".yml"

    if (kind == "field") {
      print "  - type: textarea"          > file
      print "    id: " id                 > file
      print "    attributes:"             > file
      print "      label: " q(label)      > file
      if (trim($6) != "") print "      description: " q(trim($6)) > file
      if (trim($7) != "") block(file, "placeholder", trim($7))
      print "    validations:"            > file
      print "      required: " (req == "yes" ? "true" : "false") > file
      next
    }

    # Options are \n separated, the same escape the placeholder column already uses, because the
    # column separator is a pipe and an option may not contain one.
    if (trim($7) == "") { err(kind " " t "." id " has no options; a chooser with nothing to choose is not a field"); next }
    nopt = split(trim($7), opts, "\\\\n")
    # One option is not a choice: it renders as a control the filer cannot answer wrongly and
    # cannot answer meaningfully, which is worse than a textarea.
    if (nopt < 2) { err(kind " " t "." id " has " nopt " option; at least 2 are needed"); next }
    delete optseen
    optbad = 0
    for (i = 1; i <= nopt; i++) {
      o = trim(opts[i])
      if (o == "")        { err(kind " " t "." id " option " i " is empty"); optbad = 1 }
      else if (o in optseen) { err(kind " " t "." id " repeats the option [" o "]; GitHub rejects duplicates"); optbad = 1 }
      optseen[o] = 1
    }
    if (optbad) next

    print "  - type: " kind             > file
    print "    id: " id                 > file
    print "    attributes:"             > file
    print "      label: " q(label)      > file
    if (trim($6) != "") print "      description: " q(trim($6)) > file
    print "      options:"              > file
    for (i = 1; i <= nopt; i++) {
      o = trim(opts[i])
      if (kind == "dropdown") print "        - " q(o) > file
      else {
        # checkboxes options are mappings, and requiredness is per option rather than on the
        # field. A checkboxes record with required=yes means every box must be ticked.
        print "        - label: " q(o) > file
        if (req == "yes") print "          required: true" > file
      }
    }
    # Only dropdown carries validations. GitHub rejects a validations block on checkboxes.
    if (kind == "dropdown") {
      print "    validations:"          > file
      print "      required: " (req == "yes" ? "true" : "false") > file
    }
    next
  }

  { print "gen-issue-forms: " src " line " NR ": unrecognised record: " $0 > "/dev/stderr"; bad = 1 }

  END {
    if (ntypes < 1) { print "gen-issue-forms: " src " defines no types. Refusing to generate." > "/dev/stderr"; bad = 1 }
    for (i = 1; i <= ntypes; i++)
      if (nfields[order[i]] + 0 == 0) {
        print "gen-issue-forms: type " order[i] " has no fields; GitHub rejects an empty body." > "/dev/stderr"
        bad = 1
      }
    exit bad ? 1 : 0
  }
' "$SRC" || { echo "gen-issue-forms: source rejected, $OUT left untouched" >&2; exit 1; }

# config.yml is not derived from the field list, so it is a literal here rather than a record
# type with exactly one instance. blank_issues_enabled is the load bearing line: it is what
# makes the three forms the only way to open an issue through the web UI.
# No contact_links. It used to offer "Something else entirely" pointing at _bootstrap's chooser,
# which in twelve of thirteen repos silently relocated the filer to the wrong repository, and in
# _bootstrap was a self-link to the page already on screen. With blank_issues_enabled false this is
# the only remaining path when none of the three forms fits, so a wrong one is worse than none.
# The three type cards ARE the door; anything that fits none of them is a chore (_bootstrap#18).
cat > "$STAGE/config.yml" <<'YAML'
# GENERATED FILE. Do not edit.
# Source:     scripts/gen-issue-forms.sh (a literal, not derived from the field table)
# Regenerate: sh scripts/gen-issue-forms.sh
blank_issues_enabled: false
YAML

mkdir -p "$OUT" || exit 1
rm -f "$OUT"/*.yml
cp "$STAGE"/*.yml "$OUT"/ || exit 1

echo "gen-issue-forms: wrote $(ls "$OUT"/*.yml | wc -l | tr -d ' ') files to $OUT"
