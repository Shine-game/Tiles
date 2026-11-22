"""Read-only dependency audit. Writes a report, never assets or the export allowlist.

Active configuration references are retained conservatively, including validation-
only parts. This is dependency evidence, not a claim that every image is drawn.
"""
from pathlib import Path
from collections import defaultdict, Counter
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
IMAGE = {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.bmp', '.tga', '.res'}
FILE = IMAGE | {'.gd', '.tscn', '.tres', '.gdshader', '.json', '.ttf', '.otf', '.ogg'}
LITERAL = re.compile(r'''["']([^"'\n]+)["']''')
ARCHIVED = ('art/themes/zen_garden/', 'scripts/zen', 'assets/themes/archived/')
# Reviewed code expansions. Do not infer arbitrary globs as live assets.
DYNAMIC = {
    'scripts/clockwork_visuals.gd': {
        'assets/themes/clockwork/sprites/tier3/clockwork_tier3_steam_color0_%02d.png': [1, 2, 3],
    },
    'scripts/pattern/animated_fingers.gd': {
        'assets/themes/coral_reef/assembly/coral_reef_tier3_fingers.json': None,
    },
}


def audit():
    edges = defaultdict(list)
    pending = ['project.godot']
    seen = set()
    missing = []
    deferred = []
    dynamic = []
    skipped_authoring = []
    unresolved = []
    registry = json.loads((ROOT / 'assets/themes/themes.json').read_text())

    def add(path, owner, field, reason):
        path = Path(path).resolve()
        if not path.is_relative_to(ROOT):
            missing.append({'owner': owner, 'field': field, 'path': str(path), 'reason': 'outside project'})
            return
        rel = path.relative_to(ROOT).as_posix()
        entry = {'owner': owner, 'field': field, 'reason': reason}
        if entry not in edges[rel]: edges[rel].append(entry)
        if not path.is_file():
            missing.append({'owner': owner, 'field': field, 'path': rel})
        elif rel not in seen: pending.append(rel)

    def resolve(value, owner, field, reason):
        if Path(value).suffix.lower() not in FILE: return
        if value.startswith(('user://', 'http://', 'https://', '/tmp/')): return
        if '%' in value:
            unresolved.append({'owner': owner, 'field': field, 'expression': value})
            return
        if value.startswith('res://'):
            path = ROOT / value[6:]
        else:
            path = ROOT / owner
            path = path.parent / value
            if value.startswith('artwork/') and owner.startswith('scripts/'):
                theme = 'clockwork_workshop' if 'clockwork_' in value else 'coral_reef'
                path = ROOT / 'art/themes' / theme / value
            # Literal filenames appended to ROOT in the animated finger loader.
            elif owner == 'scripts/pattern/animated_fingers.gd' and value == 'salmon.json':
                path = ROOT / 'art/themes/coral_reef/artwork/fingers' / value
            elif not path.is_file() and (ROOT / value).is_file(): path = ROOT / value
            elif not path.is_file() and owner.endswith('.gd'):
                # Short suffix/type literals ('.png', 'png', etc.) are not paths.
                if '/' not in value: return
        rel = path.resolve().relative_to(ROOT).as_posix() if path.resolve().is_relative_to(ROOT) else str(path)
        if rel.startswith(ARCHIVED):
            deferred.append({'owner': owner, 'field': field, 'path': rel, 'reason': 'inactive Zen branch; not followed'})
            return
        add(path, owner, field, reason)

    def walk(value, owner, field=''):
        if isinstance(value, dict):
            for key, item in value.items():
                if key in ['authoring', 'provenance', 'source_asset', 'manifest', 'shared_manifest']:
                    skipped_authoring.append({'owner': owner, 'field': field + '/' + key})
                    continue
                walk(item, owner, field + '/' + key)
        elif isinstance(value, list):
            for i, item in enumerate(value): walk(item, owner, field + '/' + str(i))
        elif isinstance(value, str): resolve(value, owner, field, 'active configuration dependency')

    while pending:
        owner = pending.pop()
        if owner in seen: continue
        seen.add(owner)
        p = ROOT / owner
        if p.suffix == '.json':
            data = json.loads(p.read_text())
            if owner == 'assets/themes/themes.json':
                # Include only selectable theme profiles, never archived labels.
                for theme in registry['order']: walk(data['themes'][theme], owner, '/themes/' + theme)
                for key, value in data.items():
                    if key not in ['themes', 'archived_labels']: walk(value, owner, '/' + key)
            else: walk(data, owner)
        elif p.suffix in {'.gd', '.tscn', '.tres', '.gdshader'} or owner == 'project.godot':
            for line, text in enumerate(p.read_text().splitlines(), 1):
                if text.lstrip().startswith(('#', ';', '//')): continue
                for match in LITERAL.finditer(text):
                    resolve(match[1], owner, 'line:' + str(line), 'reachable scene/script/shader reference')
            for pattern, values in DYNAMIC.get(owner, {}).items():
                paths = [pattern] if values is None else [pattern % n for n in values]
                dynamic.append({'owner': owner, 'expression': pattern, 'expanded_paths': paths,
                                'evidence': 'ROOT + salmon.json; all 6 x 3 frames from its variants array' if values is None else 'mini(2, int(life * 3)) + 1 gives 1..3'})
                for path in paths: add(ROOT / path, owner, 'reviewed dynamic expansion', 'generated runtime path')

    old = set()
    for manifest in [registry['shared_manifest']] + [p['manifest'] for p in registry['themes'].values()]:
        data = json.loads((ROOT / manifest.removeprefix('res://')).read_text())
        old.update(path.removeprefix('res://') for path in data['files'] if path.endswith('.png'))
    # The three steam frames are the only formatted source-image path in active code.
    unresolved = [row for row in unresolved if not any(row['owner'] == d['owner'] and row['expression'].endswith(Path(d['expression']).name) for d in dynamic)]
    inventory = []
    for p in sorted(ROOT.rglob('*')):
        rel = p.relative_to(ROOT).as_posix()
        if not p.is_file() or any(part in {'.git', '.godot', 'build', '__pycache__'} for part in p.relative_to(ROOT).parts): continue
        if p.suffix.lower() not in IMAGE | {'.ogg', '.wav', '.mp3', '.flac', '.ttf', '.otf'}: continue
        if rel in edges: status = 'required_by_active_dependencies'
        elif rel == 'tests/fixtures/decoration_test.png': status = 'test_only_fixture'
        elif rel.startswith('art/themes/zen_garden/'): status = 'preserve_inactive_zen'
        else: status = 'unreferenced_candidate'
        inventory.append({'path': rel, 'kind': 'image' if p.suffix.lower() in IMAGE else 'font' if p.suffix.lower() in {'.ttf', '.otf'} else 'audio',
                          'status': status, 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
                          'evidence': edges.get(rel, [])})
    retained = {r['path'] for r in inventory if r['status'] == 'required_by_active_dependencies' and r['path'].endswith('.png')}
    # Flag known render filters without pretending those source dependencies
    # can be deleted while the old sets still validate them.
    review = [
        {'theme': 'clockwork', 'source': 'scripts/clockwork_visuals.gd',
         'finding': 'Generative Tier 1 filters T01/T03; the junction layer filters ordinary center parts, including C01/C02/C03. Old parts are still validated from tier0/tier1 JSON.',
         'action_later': 'Remove superseded set parts and their validation references before dropping any associated images.'},
        {'theme': 'coral_reef', 'source': 'scripts/coral_visuals.gd',
         'finding': 'Generative Tier 1 filters arm_* and the junction layer filters ordinary junction-center parts. Their set definitions still validate images and masks.',
         'action_later': 'Review old arm/junction compositions and masks against the replacement metadata before deleting their source files.'},
        {'theme': 'vines', 'source': 'scripts/pattern/junction_layer.gd',
         'finding': 'Core roles can be composed from leaves, while explicit core artwork metadata remains in the theme configuration and validation graph.',
         'action_later': 'Keep these references until the planned manifest/metadata cleanup resolves the distinction.'},
    ]
    generated_images = []
    for p in sorted((ROOT / 'build').rglob('*')):
        if p.is_file() and p.suffix.lower() in IMAGE:
            generated_images.append({'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                                     'has_import_sidecar': Path(str(p) + '.import').is_file(),
                                     'status': 'generated_test_output_not_runtime_source'})
    by_status = {}
    for row in inventory:
        key = row['status']
        bucket = by_status.setdefault(key, {'count': 0, 'bytes': 0, 'groups': {}})
        bucket['count'] += 1
        bucket['bytes'] += row['bytes']
        group = '/'.join(row['path'].split('/')[:3])
        bucket['groups'][group] = bucket['groups'].get(group, 0) + 1
    hashes = defaultdict(list)
    for row in inventory:
        if row['kind'] == 'image': hashes[row['sha256']].append(row['path'])
    return {'schema': 'tiles.asset-inventory-verification.v1' , 'active_themes': registry['order'],
            'scope': 'Read-only audit of the current game source dependency graph. Imported caches and generated Android build files excluded.',
            'limitations': ['Configuration closure is conservative: references validated by active loaders remain required even when a renderer currently bypasses them.',
                            'No exhaustive gameplay observation claim. This report traces dependencies and explicitly reviewed generated paths.',
                            'Unreferenced candidates need the planned migration review before deletion; Zen must be preserved separately.'],
            'summary': {kind: dict(Counter(r['status'] for r in inventory if r['kind'] == kind)) for kind in ['image', 'audio', 'font']},
            'comparison_with_export_inventory': {'previous_runtime_png_count': len(old), 'verified_required_png_count': len(retained),
                                                'required_but_not_allowlisted': sorted(retained - old), 'allowlisted_without_dependency_evidence': sorted(old - retained)},
             'totals_by_status': by_status,
            'renderer_bypass_review': review,
            'identical_image_groups': [paths for paths in hashes.values() if len(paths) > 1],
            'duplicate_policy': 'Identical bytes do not prove redundant roles; retain separate bend/T/X and color identifiers until their contracts are reviewed.',
            'import_exposure': {'source_images_outside_active_closure': sum(r['kind'] == 'image' and r['status'] != 'required_by_active_dependencies' for r in inventory),
                                'generated_test_images_inside_project': len(generated_images),
                                'explanation': 'Source files inside the project can be imported regardless of whether the game draws them. Cache deletion cannot remove these sources.'},
            'generated_editor_visible_images': generated_images,
            'apk_validation': 'Not performed in this step; source dependency verification does not certify the contents of an APK.',
            'runtime_generated_assets': ['Procedural brush/linear reveal textures', 'Generated atlas regions and alpha masks', 'User gallery images under user:// (not shipped source artwork)'],
            'missing_dependencies': missing, 'unreviewed_dynamic_resource_literals': unresolved,
            'reviewed_dynamic_paths': dynamic, 'inactive_conditional_references': deferred,
            'ignored_authoring_fields': skipped_authoring,
            'dependency_documents': sorted(seen), 'assets': inventory}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='docs/asset-inventory/current.json')
    args = parser.parse_args()
    report = audit()
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['summary', 'comparison_with_export_inventory', 'missing_dependencies', 'unreviewed_dynamic_resource_literals']}, indent=2))
    return bool(report['missing_dependencies'] or report['unreviewed_dynamic_resource_literals'])


if __name__ == '__main__': raise SystemExit(main())
