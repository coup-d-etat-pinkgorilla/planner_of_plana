"""Read real Dart preamble edges for the release source exclusion test.

This is a directive reader, not a Dart compiler. Flutter analyze remains the
syntax gate. A library's directives precede declarations; body text is never
searched for import-looking strings. All configurable branches are included.
"""
from pathlib import Path


def _tokens(text):
    offset, length = 0, len(text)
    if text.startswith('\ufeff'):
        offset = 1
    if text[offset:offset + 2] == '#!':
        offset = text.find('\n', offset)
        if offset < 0:
            return
    escapes = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f', 'v': '\v'}
    while offset < length:
        char = text[offset]
        if char.isspace():
            offset += 1
            continue
        if text.startswith('//', offset):
            end = text.find('\n', offset + 2)
            offset = length if end < 0 else end + 1
            continue
        if text.startswith('/*', offset):
            offset, depth = offset + 2, 1
            while offset < length and depth:
                if text.startswith('/*', offset):
                    depth += 1
                    offset += 2
                elif text.startswith('*/', offset):
                    depth -= 1
                    offset += 2
                else:
                    offset += 1
            if depth:
                raise ValueError('Unterminated Dart comment in library preamble')
            continue
        raw = char in 'rR' and offset + 1 < length and text[offset + 1] in "'\""
        if raw:
            offset += 1
            char = text[offset]
        if char in "'\"":
            delimiter = char * (3 if text.startswith(char * 3, offset) else 1)
            offset += len(delimiter)
            value, dynamic = [], False
            while offset < length and not text.startswith(delimiter, offset):
                char = text[offset]
                if not raw and char == '\\':
                    offset += 1
                    if offset >= length:
                        raise ValueError('Unterminated Dart URI escape')
                    char = text[offset]
                    if char == 'u':
                        if text[offset + 1:offset + 2] == '{':
                            end = text.find('}', offset + 2)
                            if end < 0:
                                raise ValueError('Unterminated Dart Unicode URI escape')
                            value.append(chr(int(text[offset + 2:end], 16)))
                            offset = end + 1
                        else:
                            digits = text[offset + 1:offset + 5]
                            if len(digits) != 4:
                                raise ValueError('Truncated Dart Unicode URI escape')
                            value.append(chr(int(digits, 16)))
                            offset += 5
                        continue
                    value.append(escapes.get(char, char))
                    offset += 1
                    continue
                dynamic = dynamic or (not raw and char == '$')
                value.append(char)
                offset += 1
            if offset >= length:
                raise ValueError('Unterminated Dart string in library preamble')
            offset += len(delimiter)
            yield ('string', ''.join(value), dynamic)
            continue
        if char.isalpha() or char in '_$':
            end = offset + 1
            while end < length and (text[end].isalnum() or text[end] in '_$'):
                end += 1
            yield ('word', text[offset:end], False)
            offset = end
        else:
            yield ('symbol', char, False)
            offset += 1


def dart_directive_uris(text: str) -> tuple[str, ...]:
    tokens = iter(_tokens(text))
    current = next(tokens, None)
    result = []
    while current is not None:
        if current[1] == '@':
            # Annotation name (possibly prefixed), then optional argument list.
            current = next(tokens, None)
            while current and (current[0] == 'word' or current[1] == '.'):
                current = next(tokens, None)
                if current and current[1] != '.':
                    break
                if current:
                    current = next(tokens, None)
            if current and current[1] == '(':
                depth = 1
                while depth:
                    current = next(tokens, None)
                    if current is None:
                        raise ValueError('Unterminated Dart library annotation')
                    if current[0] == 'symbol':
                        depth += (current[1] == '(') - (current[1] == ')')
                current = next(tokens, None)
            continue
        if current[0] != 'word' or current[1] not in ('library', 'import', 'export', 'part'):
            break  # First declaration: body strings/comments are not directives.
        directive = current[1]
        current = next(tokens, None)
        part_of = directive == 'part' and current and current[1] == 'of'
        collect = directive != 'library' and not part_of
        depth, found = 0, 0
        while current is not None and not (current[0] == 'symbol' and current[1] == ';'):
            if current[0] == 'symbol':
                depth += (current[1] == '(') - (current[1] == ')')
            if collect and current[0] == 'string' and depth == 0:
                if current[2]:
                    raise ValueError('Interpolated Dart import URI')
                result.append(current[1])
                found += 1
            current = next(tokens, None)
        if current is None or depth != 0 or (collect and not found):
            raise ValueError('Malformed Dart library directive')
        current = next(tokens, None)
    return tuple(result)


def dart_local_source_closure(lib: Path, package: str) -> set[Path]:
    lib = lib.resolve()
    visited, pending = set(), [lib / 'main.dart']
    while pending:
        source = pending.pop().resolve()
        if source in visited:
            continue
        if not source.is_relative_to(lib) or not source.is_file():
            raise ValueError(f'Dart local source is missing or outside lib: {source}')
        visited.add(source)
        for uri in dart_directive_uris(source.read_text(encoding='utf-8')):
            if uri.startswith(f'package:{package}/'):
                pending.append(lib / uri.split('/', 1)[1])
            elif ':' not in uri:
                pending.append(source.parent / uri)
    return visited
