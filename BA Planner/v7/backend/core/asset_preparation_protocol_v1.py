from __future__ import annotations

from core.scanner_session import ScannerError

METHODS = frozenset('assets.prepare.' + suffix for suffix in
                    ('status', 'game_dir.set', 'start', 'cancel', 'snapshot'))


class AssetPreparationProtocolV1:
    def __init__(self, service):
        self.service = service

    def handle(self, request):
        method = request['method']
        try:
            payload = request.get('payload')
            if not isinstance(payload, dict):
                raise ScannerError('invalid_payload', 'payload must be an object')
            suffix = method.removeprefix('assets.prepare.')
            expected = {'path'} if suffix == 'game_dir.set' else ({'job_id','generation'} if suffix in {'cancel','snapshot'} else set())
            if set(payload) != expected:
                raise ScannerError('invalid_payload', 'asset preparation payload has invalid fields')
            if suffix == 'game_dir.set':
                path = payload['path']
                if path is not None and (not isinstance(path, str) or not path.strip() or len(path) > 32767 or '\x00' in path):
                    raise ScannerError('invalid_payload', 'path must be null or a nonempty path')
                result = self.service.set_game_dir(path)
            elif suffix in {'cancel','snapshot'}:
                job, generation = payload['job_id'], payload['generation']
                if (not isinstance(job, str) or not job or type(generation) is not int or generation < 1):
                    raise ScannerError('invalid_payload', 'job cursor must be a nonempty ID and positive generation')
                result = getattr(self.service, suffix)(job, generation)
            else:
                result = getattr(self.service, suffix)()
            return self._response(request, result)
        except ScannerError as exc:
            return self._response(request, {'error': {'code': exc.code, 'message': exc.message, 'details': exc.details}})
        except (OSError, ValueError):
            return self._response(request, {'error': {'code': 'asset_prepare_io_error',
                                                    'message': 'asset preparation state could not be accessed', 'details': {}}})

    @staticmethod
    def _response(request, payload):
        return {'protocol': 1, 'type': 'response', 'id': request['id'], 'method': request['method'], 'payload': payload}
