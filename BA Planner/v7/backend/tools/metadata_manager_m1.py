"""M1 developer-tool handlers. Read-only; M3 provenance and M4 physical checks separate."""
from copy import deepcopy
import json
from pathlib import Path
from core.client_data_store import ClientDataStore, _relative

METHOD_NAMES=frozenset({'store.status','store.versions','store.diff','metadata.source.view','asset_map.list','asset_map.check'})


def _params(value, keys):
    if not isinstance(value,dict) or set(value)!=set(keys):
        raise ValueError('invalid_params: unexpected or missing keys')


def validate_envelope(request):
    if set(request)!={'version','method','params'} or type(request['version']) is not int or request['version']!=1:
        raise ValueError('invalid_params: expected developer tools v1 envelope')
    if not isinstance(request['params'],dict):
        raise ValueError('invalid_params: params must be an object')


def store_status(params,lock_path):
    _params(params,())
    return ClientDataStore(lock_path).status()


def store_versions(params,lock_path):
    _params(params,())
    return ClientDataStore(lock_path).versions()


def store_diff(params,lock_path):
    _params(params,('from','to'))
    return ClientDataStore(lock_path).diff(params['from'],params['to'])


def metadata_source_view(params,current_getter,forms_getter):
    _params(params,('student_id',))
    student_id=params['student_id']
    if not isinstance(student_id,str) or not student_id or not all(c.isascii() and (c.islower() or c.isdigit() or c=='_') for c in student_id):
        raise ValueError('invalid_params: invalid local student_id')
    current=current_getter({'student_id':student_id})
    rows=[]
    values={'metadata.'+key:value for key,value in current['metadata'].items()}
    values['server_availability.jp_only']=current['jp_only']
    values['forms']=forms_getter({'student_id':student_id})['forms']
    for name,value in sorted(values.items()):
        rows.append({'field':name,'value':deepcopy(value),'value_state':'unknown' if value is None else 'present',
                     'source_state':'unknown','provenance':None,'comparisons':[]})
    return {'student_id':student_id,'fields':rows,'comparison_state':'not_verified',
            'unavailable_groups':['statistics_association','store_field_comparison'],
            'note':'Existing effective values; no invented field provenance or M3 stable-ID association'}


def _map(path):
    try: value=json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError,UnicodeError,json.JSONDecodeError):
        raise ValueError('asset_map_malformed: local M0 inventory is unavailable or malformed') from None
    if not isinstance(value,dict) or set(value)!={'version','generatedAt','status','inventory','catalogs','assets'} or type(value['version']) is not int or value['version']!=1 or value['status']!='M0-draft' or not isinstance(value['assets'],list):
        raise ValueError('asset_map_malformed: invalid M0 inventory shape')
    seen=set()
    for item in value['assets']:
        if not isinstance(item,dict) or set(item)!={'plannerPath','role','addressKey','bundle','textureName','source','clientKind','note'}:
            raise ValueError('asset_map_malformed: invalid mapping row shape')
        from core.client_data_store import _parts
        _parts(item['plannerPath'])
        identity=(item['role'],item['plannerPath'].casefold())
        if identity in seen or item['role'] not in ('ui','recognition') or item['clientKind'] not in ('jp','steam') or not isinstance(item['note'],str) or not item['note']:
            raise ValueError('asset_map_malformed: duplicate or invalid mapping identity')
        seen.add(identity)
        if item['source']=='manual':
            if any(item[k] is not None for k in ('addressKey','bundle','textureName')):
                raise ValueError('asset_map_malformed: manual mapping must remain null')
        elif item['source']=='catalog':
            if any(not isinstance(item[k],str) or not item[k] for k in ('addressKey','bundle')) or '/' in item['bundle'] or '\\' in item['bundle'] or not item['bundle'].endswith('.bundle'):
                raise ValueError('asset_map_malformed: catalog mapping fields missing/invalid')
            if item['textureName'] is not None and (not isinstance(item['textureName'],str) or not item['textureName']):
                raise ValueError('asset_map_malformed: invalid texture mapping field')
        else: raise ValueError('asset_map_malformed: unknown source')
    return value


def asset_map_list(params,map_path):
    _params(params,())
    value=_map(map_path)
    return {'map_version':1,'inventory_status':value['status'],'assets':deepcopy(value['assets']),
            'verification':'M0_mapping_draft; physical_not_verified'}


def asset_map_check(params,map_path,planner_root):
    _params(params,('scope',))
    if params['scope'] not in ('all','ui','recognition'):
        raise ValueError('invalid_params: scope must be all/ui/recognition')
    value=_map(map_path); rows=[]; seen=set()
    for item in value['assets']:
        if not isinstance(item,dict) or set(item)!={'plannerPath','role','addressKey','bundle','textureName','source','clientKind','note'}:
            raise ValueError('asset_map_malformed: invalid mapping row shape')
        path=_relative(Path(planner_root),item['plannerPath'])
        identity=(item['role'],item['plannerPath'].casefold())
        if identity in seen or item['role'] not in ('ui','recognition'):
            raise ValueError('asset_map_malformed: duplicate or invalid role')
        seen.add(identity)
        if item['source']=='manual':
            if any(item[k] is not None for k in ('addressKey','bundle','textureName')):
                raise ValueError('asset_map_malformed: manual mapping must remain null')
        elif item['source']=='catalog':
            if any(not isinstance(item[k],str) or not item[k] for k in ('addressKey','bundle')):
                raise ValueError('asset_map_malformed: catalog mapping keys missing')
        else: raise ValueError('asset_map_malformed: unknown source')
        if params['scope']!='all' and item['role']!=params['scope']: continue
        rows.append({'plannerPath':item['plannerPath'],'role':item['role'],
                     'structure_state':'valid','local_file_state':'present' if path.is_file() else 'missing',
                     'mapping_state':item['source'],'physical_state':'not_verified'})
    return {'scope':params['scope'],'rows':rows,'physical_validation':'M4_required',
            'source_verification':'local_structure_only'}
