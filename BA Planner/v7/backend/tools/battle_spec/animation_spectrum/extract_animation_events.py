"""A1-b: local JP AnimationClip metadata only; no texture/mesh/Spine reads."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import importlib.metadata
from pathlib import Path
import re
import sys
import time
from _research_common import ROOT, VERSION, load, sha, file_record, source_context, write_new
sys.path.insert(0, str(ROOT / 'backend/tools/asset_spec'))
from ba_catalog import Catalog
import UnityPy


def alias(name):
    # Exactly one declared prefix rule, shared for folder/controller selection.
    return re.sub(r'^(.+?)(?:_default(?:_.*)?)?$', r'\1_original', name.casefold(), count=1)


def choose(name, available):
    exact = name.casefold()
    if exact in available:
        return exact, 'exact-casefold'
    prefixed = alias(name)
    if prefixed != exact and prefixed in available:
        return prefixed, 'base-prefix-to-original'
    return None, None


def read_bundle(path, client):
    env = UnityPy.load(str(path))
    clips = []
    for obj in env.objects:
        if obj.type.name != 'AnimationClip':
            continue
        raw = obj.read_typetree()
        muscle = raw.get('m_MuscleClip', {})
        start, stop = muscle.get('m_StartTime'), muscle.get('m_StopTime')
        if start is None or stop is None:
            raise ValueError('AnimationClip lacks explicit start/stop: ' + raw['m_Name'])
        events = []
        for e in raw.get('m_Events', []):
            ref = e.get('objectReferenceParameter') or {}
            events.append({'time': e['time'], 'functionName': e['functionName'],
                           'stringParameter': e.get('data', ''), 'intParameter': e.get('intParameter', 0),
                           'floatParameter': e.get('floatParameter', 0.0),
                           'objectReferencePathId': ref.get('m_PathID', ref.get('path_id', 0))})
        clips.append({'name': raw['m_Name'], 'pathId': obj.path_id,
                      'bundlePath': path.relative_to(client).as_posix(), 'sourceFps': raw['m_SampleRate'],
                      'startTime': start, 'stopTime': stop, 'lengthSeconds': stop - start, 'events': events})
    return sorted(clips, key=lambda c: (c['name'], c['pathId']))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--skill-index', type=Path, required=True)
    ap.add_argument('--out-dir', type=Path, required=True)
    ap.add_argument('--evidence-index', type=Path, required=True)
    ap.add_argument('--receipt', type=Path, required=True)
    args = ap.parse_args()
    for p in (args.out_dir, args.evidence_index, args.receipt):
        if p.exists() or not p.resolve().is_relative_to(ROOT):
            raise ValueError('preserve existing output / workspace boundary: ' + str(p))
    started = time.perf_counter()
    lock, manifest, sources = source_context(('GameAssembly.dll', 'global-metadata.dat', 'ExcelDB.db', 'Excel.zip'))
    client = Path(manifest['installed_root']) if 'installed_root' in manifest else Path(manifest['files']['GameAssembly.dll']['installed_path']).parent
    catalog_path = client / 'BlueArchive_Data/StreamingAssets/catalog_Remote.json'
    catalog = Catalog(catalog_path)
    bundle_root = client / 'BlueArchive_Data/StreamingAssets/AssetBundles'
    characters = load(args.skill_index)
    if characters['clientVersionId'] != VERSION:
        raise ValueError('skill index version mismatch')
    motions, motion_receipts = {}, []
    for kind, filename in (('motion', 'motion-jp.json'), ('motion-npc', 'motion-jp-npc.json')):
        spec = next(e for e in lock['extracts'] if e['server'] == 'jp' and e['kind'] == kind)
        p = ROOT / 'data/extracted' / filename
        if sha(p) != spec['files'][filename]:
            raise ValueError('motion input hash mismatch')
        motion_receipts.append(file_record(p))
        for name, data in load(p)['controllers'].items():
            states = data['states'] if 'states' in data else data
            motions.setdefault(name.casefold(), []).append({'controller': name, 'file': filename, 'states': states})
    folders = defaultdict(set)
    for address in sorted(catalog.index):
        if not address.startswith(('assets/_mx/characters/', 'assets/_mx/npcs/')) or not address.endswith('.anim'):
            continue
        folder = address.split('/')[3].casefold()
        for resolved in catalog.resolve(address):
            if resolved['bundles']:
                containing = resolved['bundles'][0]
                # A0 Yuuka is in a prolog bundle: the .anim address and first
                # dependency establish containment, not a filename substring.
                folders[folder].add(containing)
    cache, bundle_records, per_character, files = {}, {}, [], []
    mapping_counts, missing_counts = Counter(), Counter()
    for n, ch in enumerate(characters['characters'], 1):
        cid, dev = ch['characterId'], ch['devName']
        folder, folder_rule = choose(dev, folders)
        controller, controller_rule = choose(dev, motions)
        controllers = motions.get(controller, [])
        clip_rows, bundle_paths, errors = [], [], []
        for filename in sorted(folders.get(folder, [])):
            path = bundle_root / filename
            rel = path.relative_to(client).as_posix()
            if filename not in cache:
                if not path.is_file():
                    cache[filename] = {'clips': [], 'error': 'catalog containing bundle absent'}
                else:
                    digest = sha(path)
                    try:
                        clips = read_bundle(path, client)
                        cache[filename] = {'clips': clips, 'error': None}
                    except Exception as exc:
                        cache[filename] = {'clips': [], 'error': type(exc).__name__ + ': ' + str(exc)}
                    bundle_records[rel] = {'path': rel, 'sha256': digest, 'bytes': path.stat().st_size,
                        'clipCount': len(cache[filename]['clips']),
                        'eventCount': sum(len(c['events']) for c in cache[filename]['clips']), 'error': cache[filename]['error']}
                    print({'bundleRead': len(bundle_records), 'clips': len(cache[filename]['clips'])}, flush=True)
            info = cache[filename]
            if info['error']:
                errors.append({'bundlePath': rel, 'reason': info['error']})
            else:
                bundle_paths.append(rel)
                for c in info['clips']:
                    linked = [{'controller': m['controller'], 'motionFile': m['file'], 'state': state,
                               'rule': 'exact clip name', 'controllerRule': controller_rule}
                              for m in controllers for state, value in m['states'].items()
                              if value.get('clip') == c['name']]
                    clip_rows.append(dict(c, motionStates=linked, unmapped=not linked))
        reason = ('missing CharacterExcel DevName' if not dev else 'no exact/default-prefix animationclips catalog folder') if folder is None else None
        if not clip_rows and reason is None:
            reason = 'resolved bundles have no readable AnimationClip' if not errors else 'bundle missing/read error (see errors)'
        if reason:
            missing_counts[reason] += 1
        mapping_counts['mapped'] += sum(not c['unmapped'] for c in clip_rows)
        mapping_counts['unmapped'] += sum(c['unmapped'] for c in clip_rows)
        bundle_hashes = [bundle_records[p] for p in bundle_paths]
        payload = {'schema': 'ba-planner.animation-events.v1', 'clientVersionId': VERSION,
            'characterId': cid, 'devName': dev, 'kind': ch['kind'], 'variantKinds': ch['variantKinds'],
            'catalogFolder': folder, 'folderRule': folder_rule, 'controller': controller,
            'controllerRule': controller_rule, 'clipsBundle': bundle_paths or None, 'missingReason': reason,
            'sourceHashes': {'excelDbSha256': sources['ExcelDB.db']['sha256'], 'excelZipSha256': sources['Excel.zip']['sha256'],
                             'bundles': [{'path': p['path'], 'sha256': p['sha256']} for p in bundle_hashes]},
            'clips': clip_rows, 'errors': errors, 'spine': {'decoded': False, 'evidence': '[?]', 'reason': '.skel excluded by A1 task'}}
        p = args.out_dir / f'{cid}.json'
        write_new(p, payload)
        rec = file_record(p)
        files.append(rec)
        per_character.append({**{k: payload[k] for k in ('characterId', 'devName', 'kind', 'clipsBundle', 'missingReason', 'folderRule', 'controllerRule')},
            'file': p.name, 'sha256': rec['sha256'], 'bytes': rec['bytes'], 'clipCount': len(clip_rows),
            'eventCount': sum(len(c['events']) for c in clip_rows), 'unmappedClipCount': sum(c['unmapped'] for c in clip_rows)})
    index = {'schema': 'ba-planner.animation-events-index.v1', 'clientVersionId': VERSION,
        'gameAssemblySha256': sources['GameAssembly.dll']['sha256'], 'metadataSha256': sources['global-metadata.dat']['sha256'],
        'sourceHashes': sources, 'catalog': {'path': catalog_path.relative_to(client).as_posix(), 'sha256': sha(catalog_path)},
        'skillIndex': file_record(args.skill_index), 'motionInputs': motion_receipts, 'tool': file_record(Path(__file__)),
        'unityPyVersion': importlib.metadata.version('UnityPy'), 'python': sys.executable,
        'rules': ['Catalog folders/controller names: exact casefold first; one regex ^(.+?)(?:_default(?:_.*)?)?$ -> base_original (A0 Yuuka and Binah)',
                  'AnimationClip m_Name equals motion states[*].clip exactly; no fuzzy matching or inferred states',
                  'Catalog .anim address first dependency is containing bundle, including A0 Yuuka prolog; bundle filename is not a type gate',
                  'Only AnimationClip read_typetree; objectReference is path_id only; Spine not read [?]'],
        'bundles': sorted(bundle_records.values(), key=lambda r: r['path']), 'bundleCount': len(bundle_records),
        'uniqueClipCount': sum(r['clipCount'] for r in bundle_records.values()),
        'uniqueEventCount': sum(r['eventCount'] for r in bundle_records.values()),
        'characterCount': len(per_character), 'charactersWithClips': sum(bool(c['clipCount']) for c in per_character),
        'missingReasons': dict(missing_counts), 'mappingCountsWithCharacterReuse': dict(mapping_counts),
        'characters': per_character, 'files': files, 'totalPayloadBytes': sum(r['bytes'] for r in files),
        'elapsedSeconds': time.perf_counter() - started,
        'limits': ['Bundle/catalog hashes are local observations, not historical manifest pins',
                   'Callback names do not establish damage/effect/hit application', 'Missing assets/unmapped states are visible; no name-similarity guesses']}
    write_new(args.out_dir / 'index.json', index)
    write_new(args.evidence_index, index)
    write_new(args.receipt, {k: index[k] for k in ('characterCount', 'charactersWithClips', 'bundleCount',
            'uniqueClipCount', 'uniqueEventCount', 'missingReasons', 'totalPayloadBytes', 'elapsedSeconds')})
    print(load(args.receipt), flush=True)


if __name__ == '__main__':
    main()
