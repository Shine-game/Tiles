"""Produce a reviewable asset migration map without modifying source assets."""
from pathlib import Path
from collections import defaultdict, Counter
import csv
import hashlib
import io
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/asset-inventory'
THEMES = {'clockwork_workshop': 'clockwork', 'coral_reef': 'coral_reef', 'vines': 'vines'}
PATTERN = re.compile(r'^(?:clockwork|coral|vines)_(tier\d+|ui)_(.+)_color(\d+)_(basic|\d+)(?:_(\d+))?$')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def natural(value):
    return tuple((1, int(p)) if p.isdigit() else (0, p) for p in re.split(r'(\d+)', value))


def theme_for(path):
    for folder, theme in THEMES.items():
        if path.startswith(f'art/themes/{folder}/'): return theme
    return 'coral_reef' if path.startswith('assets/frames/coral_') else None


def descriptor(path):
    p = Path(path)
    theme = theme_for(path)
    match = PATTERN.match(p.stem)
    if not match: raise ValueError('Unmapped image name: ' + path)
    tier, element, color, variant, frame = match.groups()
    if tier == 'ui':
        element = {'ui_background': 'background', 'drafting_paper_1080x1650': 'background'}.get(element, element)
    if element == 'core' and variant == 'basic': tier = 'tier0'
    elif element == 'core' and '/artwork/' in path and '/junctions/' not in path:
        # Preserve the distinction from the replacement single core sprite.
        element = 'core_component'
    element = {'crossroad': 'cross', 'tjoint': 't'}.get(element, element)
    return theme, tier, element, color, variant, frame


def plan():
    report = json.loads((OUT / 'verified.json').read_text())
    rows = []
    destinations = {}
    source_rows = {}

    def add(source, target, action, reason, kind=None):
        p = ROOT / source
        if source in source_rows: raise ValueError('Repeated source: ' + source)
        if not p.is_file(): raise ValueError('Missing source: ' + source)
        if target:
            if target in destinations: raise ValueError('Destination collision: ' + target)
            destinations[target] = source
        row = {'source': source, 'destination': target, 'action': action,
               'kind': kind or p.suffix.removeprefix('.'), 'bytes': p.stat().st_size,
               'sha256': digest(p), 'reason': reason}
        rows.append(row)
        source_rows[source] = row
        return row

    retained = [a for a in report['assets'] if a['status'] == 'required_by_active_dependencies']
    groups = defaultdict(set)
    descriptors = {}
    for a in retained:
        path = a['path']
        if a['kind'] != 'image' or path == 'assets/icon.svg': continue
        d = descriptor(path)
        descriptors[path] = d
        groups[d[:4]].add(d[4])
    variant_index = {key: {v: n for n, v in enumerate(sorted(variants, key=lambda v: (v != 'basic', natural(v))), 1)}
                     for key, variants in groups.items()}
    for a in retained:
        path = a['path']
        if digest(ROOT / path) != a['sha256']: raise ValueError('Inventory hash changed: ' + path)
        if path == 'assets/icon.svg': target = 'assets/shared/ui/app_icon.svg'
        elif a['kind'] == 'font': target = 'assets/shared/fonts/lora_regular.ttf'
        elif a['kind'] == 'audio':
            theme = Path(path).parent.name
            target = f'assets/themes/{theme}/audio/{Path(path).name}'
        else:
            theme, tier, element, color, variant, frame = descriptors[path]
            index = variant_index[(theme, tier, element, color)][variant]
            folder = f'assets/themes/{theme}/' + ('ui' if tier == 'ui' else f'sprites/{tier}')
            if element.startswith('mask_'): folder += '/masks'
            name = f'{theme}_{tier}_{element}_color{color}_{index:02d}'
            if frame: name += f'_frame{int(frame):02d}'
            target = f'{folder}/{name}{Path(path).suffix.lower()}'
        add(path, target, 'retain_move', 'Required by active dependency graph; preserve bytes, roles and color/animation ordering.', a['kind'])

    # Move every reachable theme document, maintaining shared metadata contracts.
    for path in report['dependency_documents']:
        if not path.endswith('.json'): continue
        p = Path(path)
        theme = theme_for(path)
        if theme:
            data = json.loads((ROOT / path).read_text())
            images = data.get('images', {})
            image = data.get('image') or (images[sorted(images)[0]] if images else None)
            if image:
                original = (ROOT / p.parent / image.removeprefix('res://')).resolve() if not image.startswith('res://') else ROOT / image[6:]
                rel = original.relative_to(ROOT).as_posix()
                if rel not in source_rows: raise ValueError('Metadata image not retained: ' + rel)
                target = str(Path(source_rows[rel]['destination']).with_suffix('.json'))
                reason = 'Sprite metadata stays beside its primary image; shared JSON continues to describe both color variants.'
            else:
                if p.name == 'radial.json': name = f'{theme}_tier2_radial_petals.json'
                elif p.name == 'salmon.json': name = f'{theme}_tier3_fingers.json'
                elif p.name == 'environment.json': name = f'{theme}_environment.json'
                elif p.name == 'tier1-artwork.json': name = f'{theme}_tier1_sprite_catalog.json'
                else: name = f'{theme}_{p.name}'
                target = f'assets/themes/{theme}/assembly/{name}'
                reason = 'Theme assembly/catalog; update its relative paths using this map.'
        elif path.startswith('assets/schemas/'):
            target = 'assets/shared/schemas/' + p.name
            reason = 'Shared schema, not theme artwork.'
        elif path == 'assets/themes/tier1-generation.json':
            target = 'assets/shared/assembly/tier1-generation.json'
            reason = 'Shared generation defaults.'
        elif path == 'assets/themes/themes.json':
            target = path
            reason = 'Keep the registry entry point; later point it to the three per-theme manifests.'
        else: raise ValueError('Unclassified runtime document: ' + path)
        add(path, target, 'retain_rewrite' if path == target else 'retain_move_rewrite', reason, 'metadata')

    for path in report['dependency_documents']:
        if path.startswith('art/themes/') and path.endswith('.gdshader'):
            theme = theme_for(path)
            add(path, f'assets/themes/{theme}/shaders/{theme}_{Path(path).name}', 'retain_move', 'Required theme-owned shader.', 'shader')
    add('assets/schemas/junction-sprite-v1.schema.json', 'assets/shared/schemas/junction-sprite-v1.schema.json', 'retain_move', 'Preserve the authoring contract even though the runtime validator is inline.', 'schema')
    add('assets/fonts/lora/OFL.txt', 'assets/shared/fonts/lora_ofl.txt', 'retain_move', 'Preserve the font license.', 'license')
    for source, target in {
        'assets/audio/catalog.json': 'docs/asset-inventory/audio-provenance.json',
        'assets/sprites/audit.json': 'docs/asset-inventory/prior-export-inventory.json',
        'assets/sprites/renames.json': 'docs/asset-inventory/prior-renames.json',
        'assets/sprites/cleanup.json': 'docs/asset-inventory/prior-cleanup.json',
    }.items():
        add(source, target, 'retain_move_rewrite_consumers', 'Preserve provenance/history outside runtime assets; switch the exporter and audit tools to the new manifests first.', 'audit_record')

    for a in report['assets']:
        if a['status'] == 'unreferenced_candidate':
            add(a['path'], None, 'delete_candidate', 'No dependency from selectable themes, reachable runtime scripts or reviewed generated asset paths.', a['kind'])

    # Cover remaining authoring metadata and shaders, not just image files.
    active_sources = set(report['dependency_documents'])
    for p in sorted((ROOT / 'art/themes').rglob('*')):
        source = p.relative_to(ROOT).as_posix()
        if not p.is_file() or source in source_rows or p.suffix in ['.import', '.uid']: continue
        if source.startswith('art/themes/zen_garden/'):
            add(source, '../Tiles-archive/zen_garden/' + source, 'preserve_outside_project', 'Preserve the full inactive Zen tree with original relative paths.', 'archived_source')
        elif source not in active_sources:
            add(source, None, 'delete_candidate', 'Unreferenced theme metadata/shader; no active dependency. Review test/tool references during implementation.', 'metadata' if p.suffix == '.json' else 'shader')
        else: raise ValueError('Uncovered active theme source: ' + source)
    # Include the dormant Zen implementation and restoration notes in the archive.
    archive_paths = set()
    for pattern in ['scripts/zen*.gd', 'tests/*zen*.gd', 'assets/themes/*zen*.json', 'assets/themes/archived/*']:
        archive_paths.update(p for p in ROOT.glob(pattern) if p.is_file())
    for p in sorted(archive_paths):
        source = p.relative_to(ROOT).as_posix()
        if source in source_rows: continue
        if source in active_sources: continue
        add(source, '../Tiles-archive/zen_garden/' + source, 'preserve_outside_project', 'Inactive Zen support; preserve for restoration. Remove guarded loads only during implementation.', 'archived_support')

    for p in sorted(list((ROOT / 'art').rglob('*')) + list((ROOT / 'assets').rglob('*'))):
        source = p.relative_to(ROOT).as_posix()
        if not p.is_file() or source in source_rows or p.suffix not in ['.import', '.uid']: continue
        parent = str(p)[:-len(p.suffix)]
        owner = source_rows.get(Path(parent).relative_to(ROOT).as_posix())
        if owner is None: raise ValueError('Sidecar has no disposition: ' + source)
        action = owner['action']
        if action == 'preserve_outside_project':
            add(source, owner['destination'] + p.suffix, action, 'Preserve Zen source sidecar with its owner.', 'sidecar')
        elif action == 'delete_candidate':
            add(source, None, action, 'Remove the sidecar together with its unused owner.', 'sidecar')
        elif p.suffix == '.import':
            row = add(source, owner['destination'] + p.suffix, 'regenerate_import', 'Preserve import settings/UIDs, then let Godot regenerate source/cache paths; do not copy stale remap hashes.', 'sidecar')
            row['preserve_import_parameters'] = True
        else:
            add(source, owner['destination'] + p.suffix, 'retain_move', 'Preserve resource UID beside its renamed shader.', 'sidecar')
    for p in sorted((ROOT / 'scripts').glob('zen*.gd.uid')):
        source = p.relative_to(ROOT).as_posix()
        if source not in source_rows: add(source, '../Tiles-archive/zen_garden/' + source, 'preserve_outside_project', 'Preserve dormant Zen script UID.', 'sidecar')
    for p in sorted((ROOT / 'tests').glob('*zen*.gd.uid')):
        source = p.relative_to(ROOT).as_posix()
        if source not in source_rows: add(source, '../Tiles-archive/zen_garden/' + source, 'preserve_outside_project', 'Preserve dormant Zen test UID.', 'sidecar')

    for artifact in report['generated_editor_visible_images']:
        source = artifact['path']
        add(source, None, 'delete_generated_output', 'Generated test rendering; keep future output outside the Godot project.', 'generated_image')
        if (ROOT / (source + '.import')).is_file(): add(source + '.import', None, 'delete_generated_output', 'Sidecar for generated test rendering.', 'sidecar')

    # Check the map covers every source under both asset roots.
    uncovered = [p.relative_to(ROOT).as_posix() for base in ['art', 'assets'] for p in (ROOT / base).rglob('*')
                 if p.is_file() and p.relative_to(ROOT).as_posix() not in source_rows]
    if uncovered: raise ValueError('Source files without a disposition: ' + str(uncovered))
    for target, source in destinations.items():
        if target.startswith('../'): continue
        if (ROOT / target).exists() and target != source and target not in source_rows: raise ValueError('Occupied destination: ' + target)
    # Every family is numbered 01..N. Color pairs preserve their old shared index.
    for family, variants in variant_index.items():
        assert sorted(variants.values()) == list(range(1, len(variants) + 1)), family

    payload = {
        'schema': 'tiles.asset-migration-plan.v1', 'status': 'proposed_only_no_asset_changes',
        'inventory_sha256': digest(OUT / 'verified.json'),
        'naming': {'themes': ['vines', 'coral_reef', 'clockwork'],
                   'sprites': '<theme>_tier<n>_<element>_color<c>_<variant:02>[_frame<frame:02>].png',
                   'ui': '<theme>_ui_<element>_color<c>_<variant:02>.png',
                   'audio': '<theme>_ambient.ogg and <theme>_place_click.ogg',
                   'metadata': 'Same basename as the primary image; keep one descriptor for shared color variants.',
                   'rules': ['No recoloring, resizing, pixel changes or changed animation order.', 'No automatic deduplication; bend/T/X remain distinct roles/files.',
                             'Renumber only within a family; change paths, never logical component IDs.', 'Keep masks under sprites/tierN/masks.']},
        'future_manifests': [f'assets/themes/{theme}/manifest.json' for theme in ['vines', 'coral_reef', 'clockwork']],
        'archive_policy': {'destination': '../Tiles-archive/zen_garden/',
                           'required_before_removal': 'Create and verify a portable ZIP and SHA-256 inventory of the full Zen bundle outside the project. Keep an independently retrievable copy; Git history alone is not the archive.',
                           'restore_note': 'Keep the archived profile and original relative paths. Shared dependencies remain in the game; save the complete rename map in the Zen bundle for restoration.'},
        'counts_by_action': dict(Counter(r['action'] for r in rows)),
        'renderer_bypass_review': report['renderer_bypass_review'],
        'implementation_gates': [
            'Freeze/check this map against current hashes and make a Git checkpoint before migration.',
            'Move/rewrite retained dependencies atomically; retain all validation-only artwork in this pass.',
            'Create manifests from the mapped dependency closure; update registry, loaders, exporter, audit utilities and active tests.',
            'Rewrite relative JSON paths semantically using their old and new owners; raw substring replacement is insufficient.',
            'Rewrite dynamic finger/steam loaders using their mapped frame lists, retaining exact sequence and bounds.',
            'Preserve import options and UIDs; regenerate remap/cache paths after relocation.',
            'Update deprecated test-only references before removing unreferenced theme metadata; do not restore obsolete runtime artwork for old tests.',
            'Verify and deliver the external Zen archive before removing its project copies or guarded loaders.',
            'Then remove deletion candidates and generated renders, rebuild caches/staging, and verify a fresh APK against the manifests.'
        ],
        'deferred': 'Do not delete validation-only legacy assets in this plan; removing their old set parts/code requires a separate dependency audit.',
        'rows': sorted(rows, key=lambda r: r['source']),
    }
    return payload


def main():
    applied = OUT / 'applied-step3.json'
    if applied.exists():
        print('Migration has been applied. Keep the frozen map; run tools/audit_sprites.py to validate current assets.')
        return
    result = plan()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'migration-plan.json').write_text(json.dumps(result, indent=2) + '\n')
    out = io.StringIO(newline='')
    writer = csv.DictWriter(out, fieldnames=['action', 'source', 'destination', 'kind', 'bytes', 'sha256', 'reason'])
    writer.writeheader()
    for row in result['rows']: writer.writerow({key: row.get(key) for key in writer.fieldnames})
    (OUT / 'migration-map.csv').write_text(out.getvalue())
    print(json.dumps({'status': result['status'], 'rows': len(result['rows']), 'counts': result['counts_by_action']}, indent=2))


if __name__ == '__main__': main()
