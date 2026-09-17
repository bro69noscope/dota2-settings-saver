#!/usr/bin/env python3
"""
Merge dota2 personal keybind files: new__ as baseline (key layout, Keys/Items
sections), old__ as source of truth for which ability slots are quickcast vs
regular-cast per hero.

Usage:
    python merge_hero_binds.py old__dotakeys_personal.lst new__dotakeys_personal.lst merge__dotakeys_personal.lst
"""

import re
import sys

# ---------------------------------------------------------------------------
# Minimal VDF (Valve KeyValues) parser/serializer.
# Preserves insertion order. Assumes no genuine duplicate keys within a
# block (verified true for this file format on manual inspection).
# ---------------------------------------------------------------------------

# Note: this format does NOT use backslash-escaping inside quoted strings
# (the file contains literal single-backslash values, e.g. the Console key
# "\", so a backslash-escape regex misreads the closing quote). Quoted
# strings simply run until the next literal double-quote.
TOKEN_RE = re.compile(r'"([^"]*)"|([{}])')


def tokenize(text):
    return TOKEN_RE.findall(text)


def parse_block(tokens, idx):
    result = {}
    n = len(tokens)
    while idx < n:
        tok_str, tok_brace = tokens[idx]
        if tok_brace == "}":
            return result, idx + 1
        key = tok_str
        idx += 1
        if idx >= n:
            break
        next_str, next_brace = tokens[idx]
        if next_brace == "{":
            idx += 1
            value, idx = parse_block(tokens, idx)
            result[key] = value
        else:
            result[key] = next_str
            idx += 1
    return result, idx


def parse_vdf(text):
    tokens = tokenize(text)
    root, _ = parse_block(tokens, 0)
    return root


def dump_vdf(obj, indent=0):
    lines = []
    pad = "\t" * indent
    for key, value in obj.items():
        if isinstance(value, dict):
            lines.append(f'{pad}"{key}"')
            lines.append(f"{pad}{{")
            lines.append(dump_vdf(value, indent + 1))
            lines.append(f"{pad}}}")
        else:
            lines.append(f'{pad}"{key}"\t\t"{value}"')
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Merge logic
# ---------------------------------------------------------------------------

SLOTS = ["Primary1", "Primary2", "Primary3", "Secondary1", "Secondary2", "Ultimate"]

# new__'s fixed key layout per slot: uppercase/digit form (used on the
# active cast-type field) and lowercase form (used on AutoCast /
# AutoCastAlternate2, which are always Alt-modified).
SLOT_KEY = {
    "Primary1": "1",
    "Primary2": "2",
    "Primary3": "3",
    "Secondary1": "E",
    "Secondary2": "R",
    "Ultimate": "4",
}
SLOT_KEY_LOWER = {k: v.lower() for k, v in SLOT_KEY.items()}

TALENT_NEUTRAL_TEMPLATE = {
    "TalentUpgradeStatLeft": {"Key": "6", "Mode": "0"},
    "TalentUpgradeStatRight": {"Key": "8", "Mode": "0"},
    "TalentUpgradeAttribute": {"Key": "7", "Mode": "0"},
    "NeutralItemSelect1": {"Key": "1", "Mode": "-1"},
    "NeutralItemSelect2": {"Key": "2", "Mode": "-1"},
    "NeutralItemSelect3": {"Key": "3", "Mode": "-1"},
    "NeutralItemSelect4": {"Key": "4", "Mode": "-1"},
}


def merge_hero(old_hero):
    """old_hero: dict for one hero's block from old__['Units'][hero_name]."""
    new_hero = {}
    for k, v in TALENT_NEUTRAL_TEMPLATE.items():
        new_hero[k] = dict(v)

    skipped_slots = []

    for slot in SLOTS:
        base_field = old_hero.get(f"Ability{slot}", {})
        qc_field = old_hero.get(f"Ability{slot}QuickCast", {})
        alt_field = old_hero.get(f"Ability{slot}AutoCastAlternate2", {})
        ac_field = old_hero.get(f"Ability{slot}AutoCast", {})

        k_upper = SLOT_KEY[slot]
        k_lower = SLOT_KEY_LOWER[slot]

        is_quickcast = "Key" in qc_field
        is_regular = (not is_quickcast) and "Key" in base_field

        if not is_quickcast and not is_regular:
            # Neither field carries a Key in old__ -> no explicit override
            # for this slot on this hero. Leave it out of the merged block
            # (falls back to whatever global/base default new__ has).
            skipped_slots.append(slot)
            continue

        if is_quickcast:
            new_hero[f"Ability{slot}QuickCast"] = {"Key": k_upper, "Mode": "1"}
            # base Ability{slot} field intentionally omitted
        else:  # is_regular
            new_hero[f"Ability{slot}"] = {"Key": k_upper, "Mode": "0"}
            new_hero[f"Ability{slot}QuickCast"] = {"Mode": "1"}

        if "Key" in alt_field:
            new_hero[f"Ability{slot}AutoCastAlternate2"] = {
                "Key": k_lower,
                "Modifier": "ALT",
                "ChannelCancel": "ALT",
                "Mode": "-1",
            }
        else:
            new_hero[f"Ability{slot}AutoCastAlternate2"] = {"Mode": "-1"}

        if "Key" in ac_field:
            new_hero[f"Ability{slot}AutoCast"] = {
                "Key": k_lower,
                "Modifier": "ALT",
                "Mode": "0",
                "ChannelCancel": "ALT",
            }
        else:
            new_hero[f"Ability{slot}AutoCast"] = {"Mode": "0"}

    return new_hero, skipped_slots


def main():
    if len(sys.argv) != 4:
        print("Usage: merge_dota_keys.py <old.lst> <new.lst> <merge_out.lst>")
        sys.exit(1)

    old_path, new_path, out_path = sys.argv[1:4]

    old_root = parse_vdf(open(old_path, encoding="utf-8").read())
    new_root = parse_vdf(open(new_path, encoding="utf-8").read())

    old_units = old_root["KeyBindings"]["Units"]
    new_units = new_root["KeyBindings"]["Units"]

    merged_units = {}

    for hero_name, old_hero in old_units.items():
        merged_hero, skipped = merge_hero(old_hero)
        merged_units[hero_name] = merged_hero
        if skipped:
            print(
                f"[note] {hero_name}: no explicit old__ override for "
                f"slot(s) {', '.join(skipped)} -> omitted, falls back to default"
            )

    # Heroes present in new__ but absent from old__ (e.g. courier, if it
    # has no old__ override) are carried over from new__ untouched.
    for hero_name, new_hero in new_units.items():
        if hero_name not in merged_units:
            merged_units[hero_name] = new_hero
            print(
                f"[note] {hero_name}: no old__ data at all -> carried over from new__ as-is"
            )

    # Build output: clone new__'s KeyBindings root, swap in merged Units,
    # leave Keys / Items / everything else untouched.
    out_root = {"KeyBindings": dict(new_root["KeyBindings"])}
    out_root["KeyBindings"]["Units"] = merged_units

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(dump_vdf(out_root))
        f.write("\n")

    print(f"\nWrote {out_path} ({len(merged_units)} heroes)")


if __name__ == "__main__":
    main()
