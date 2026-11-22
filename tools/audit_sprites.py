"""Audit current dependencies, canonical numbering and retained image bytes."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import re
import sys
from verify_asset_inventory import audit as dependency_audit

ROOT = Path(__file__).resolve().parents[1]


def audit():
    source = dependency_audit()
    used = [a['path'] for a in source['assets'] if a['kind'] == 'image' and a['status'] == 'required_by_active_dependencies' and a['path'].endswith('.png')]
    errors = []
    groups = defaultdict(set)
    animation = defaultdict(set)
    for path in used:
        match = re.fullmatch(r'(.+_color\d+)_(\d{2})(?:_frame(\d{2}))?\.png', Path(path).name)
        if not match:
            errors.append('Noncanonical sprite name: ' + path)
            continue
        groups[match[1]].add(int(match[2]))
        if match[3]: animation[(match[1], match[2])].add(int(match[3]))
    for family, values in list(groups.items()) + list(animation.items()):
        if sorted(values) != list(range(1, max(values) + 1)): errors.append('Nonconsecutive family: ' + str(family))
    plan = json.loads((ROOT / 'docs/asset-inventory/migration-plan.json').read_text())
    for row in plan['rows']:
        if row['kind'] == 'image' and row['action'] == 'retain_move':
            path = ROOT / row['destination']
            if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                errors.append('Retained image bytes changed: ' + row['destination'])
    compare = source['comparison_with_export_inventory']
    for key in ['required_but_not_allowlisted', 'allowlisted_without_dependency_evidence']:
        errors.extend(key + ': ' + p for p in compare[key])
    return {'runtime_pngs': sorted(used), 'runtime_metadata': [p for p in source['dependency_documents'] if p.endswith('.json')],
            'unreferenced_pngs': [a['path'] for a in source['assets'] if a['kind'] == 'image' and a['status'] != 'required_by_active_dependencies'],
            'missing_references': source['missing_dependencies'], 'errors': errors}


if __name__ == '__main__':
    report = audit()
    (ROOT / 'docs/asset-inventory/current-sprite-audit.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Sprite audit:', len(report['runtime_pngs']), 'runtime PNGs;', len(report['missing_references']), 'missing references;', len(report['errors']), 'errors')
    for item in report['missing_references'] + report['errors']: print(item)
    sys.exit(bool(report['missing_references'] or report['errors']))
