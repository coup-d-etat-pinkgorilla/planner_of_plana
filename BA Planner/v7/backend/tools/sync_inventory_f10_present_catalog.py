"""Generate the static v7 present order/name table from the reviewed v6 assets."""
import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent / 'v6'
OUTPUT = ROOT / 'backend/core/inventory_present_items.py'


def natural_key(value: str):
    return tuple(int(part) if part.isdigit() else part.casefold()
                 for part in re.split(r'(\d+)', value))


def main():
    source = V6 / 'core/inventory_profiles.py'
    tree = ast.parse(source.read_text(encoding='utf-8'))
    names = None
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        if any(isinstance(target, ast.Name) and target.id == '_PRESENT_ITEM_ID_TO_NAME'
               for target in node.targets):
            names = ast.literal_eval(node.value)
            break
    if not isinstance(names, dict):
        raise RuntimeError('v6 present name table is missing')
    identities = sorted((path.stem for path in (V6 / 'templates/icons/presents').glob('*.png')),
                        key=natural_key)
    if len(identities) != len(set(identities)) or not identities:
        raise RuntimeError('v6 present identity set is empty or duplicated')
    rows = []
    for identity in identities:
        display = names.get(identity, identity)
        # The legacy table contains replacement-character mojibake for older gifts.
        # Preserve a stable readable identity instead of migrating corrupted text.
        if not isinstance(display, str) or '\ufffd' in display:
            display = identity
        rows.append((identity, display))
    lines = [
        '"""Generated F10 present identity order; do not hand-edit."""',
        '',
        'PRESENT_ORDERED_ITEMS: tuple[tuple[str, str], ...] = (',
        *(f'    ({identity!r}, {display!r}),' for identity, display in rows),
        ')',
        '',
    ]
    OUTPUT.write_text('\n'.join(lines), encoding='utf-8')
    print({'items': len(rows), 'named': sum(identity != display for identity, display in rows),
           'first': rows[0][0], 'last': rows[-1][0]})


if __name__ == '__main__':
    main()
