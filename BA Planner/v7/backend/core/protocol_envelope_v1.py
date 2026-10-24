"""Pure JSONL trust boundary; importing it never loads user data or metadata."""

ENVELOPE_KEYS = frozenset({'protocol','id','type','method','payload'})


def trusted_request(message):
    # Preserve PlanningProtocolV1's established envelope acceptance exactly.
    if not isinstance(message,dict) or set(message)!=ENVELOPE_KEYS:
        return None
    if message.get('protocol')!=1 or message.get('type')!='request':
        return None
    if not isinstance(message.get('id'),str) or not message['id']:
        return None
    if not isinstance(message.get('method'),str) or not message['method']:
        return None
    if not isinstance(message.get('payload'),dict):
        return None
    return message
