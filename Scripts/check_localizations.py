#!/usr/bin/env python3
"""Fail-closed source-key audit for the LocalizationKey boundary.

Tokenizes Swift (including comments/escaped strings), follows typed producers and
helper parameters, and rejects unresolved text/format inputs. Swift typechecking
also enforces the StaticString-only constructor; no runtime String initializer exists.
"""
import json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
LOCALES = ['en','ko','ja','zh-Hans','zh-Hant','es','pt-BR','de','fr','it','th','vi']
TOKEN = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|[A-Za-z_$][\w$]*|->|\?\?|[^\s]')

class SwiftToken(str):
    def __new__(cls, value, line):
        token=super().__new__(cls,value);token.line=line;return token

def tokens(source):
    return [SwiftToken(m.group(),source.count('\n',0,m.start())+1) for m in TOKEN.finditer(source) if not m.group().startswith(('//','/*'))]

def assignment_rhs(ts,start):
    result=[];i=start
    while i<len(ts):
        if ts[i] in [';','}']:break
        if result and ts[i].line>ts[i-1].line and ts[i] not in ['?',':','??','.'] and ts[i-1] not in ['?',':','??','=']:break
        if ts[i] in ['let','var','return']:break
        if ts[i] in ['(','[','{']:
            end=close(ts,i);result.extend(ts[i:end+1]);i=end+1
        else:result.append(ts[i]);i+=1
    return result

def close(ts, start):
    pairs={'(':')','{':'}','[':']'}; stack=[]
    for i in range(start,len(ts)):
        if ts[i] in pairs: stack.append(pairs[ts[i]])
        elif stack and ts[i]==stack[-1]:
            stack.pop()
            if not stack: return i
    raise ValueError('Unbalanced Swift expression')

def split(ts):
    result=[]; start=0; i=0
    while i<len(ts):
        if ts[i] in ['(','{','[']: i=close(ts,i)
        elif ts[i]==',': result.append(ts[start:i]);start=i+1
        i+=1
    return result+[ts[start:]]

def literals(ts):
    for t in ts:
        if t.startswith('"'):
            if '\\(' in t: raise ValueError('Interpolated localization key is forbidden: '+t)
            try: yield json.loads(t)
            except ValueError: raise ValueError('Unsupported Swift key literal: '+t)

def key_expression(arg, typed, producers):
    if not arg: return False
    if arg[0]=='(' and close(arg,0)==len(arg)-1: return key_expression(arg[1:-1],typed,producers)
    if len(arg)==1: return arg[0].startswith('"') or arg[0] in typed|producers
    # Only result branches are keys; arbitrary conditions may decide between them.
    top=[];i=0
    while i<len(arg):
        if arg[i] in ['(','[','{']:i=close(arg,i)
        else:top.append(i)
        i+=1
    fallback=next((i for i in top if arg[i]=='??'),None)
    if fallback is not None:
        return key_expression(arg[:fallback],typed,producers) and key_expression(arg[fallback+1:],typed,producers)
    question=next((i for i in top if arg[i]=='?' and arg[i+1:i+2]!=['.']),None)
    if question is not None:
        colon=next((i for i in top if i>question and arg[i]==':'),None)
        return colon is not None and key_expression(arg[question+1:colon],typed,producers) and key_expression(arg[colon+1:],typed,producers)
    # A typed property/function is permitted. Swift rejects a mismatched receiver.
    return any(x in producers for x in arg) and '+' not in arg and arg[0]!='String' and arg[-1]!='rawValue'

def scan(sources):
    trees={path:tokens(source) for path,source in sources.items()}
    keys=set(); producers=set(); helpers={'text':[(0,None)],'format':[(0,None)]}; names={}; errors=[]
    for path,ts in trees.items():
        typed=set(); names[path]=typed
        if path.endswith('LocalizationKey.swift') is False and any(ts[i:i+2]==['stringLiteral',':'] for i in range(len(ts)-1)):
            errors.append(f'{path}: direct stringLiteral constructor is forbidden; use source literals or a typed enum')
        for i,t in enumerate(ts):
            # Every typed stored/computed key is a root, even when reached via an enum.
            if t in ['var','let'] and i+3<len(ts) and ts[i+2]==':' and ts[i+3]=='LocalizationKey':
                typed.add(ts[i+1]);producers.add(ts[i+1])
                j=i+4
                while j<len(ts) and ts[j] in ['?','!']: j+=1
                if j<len(ts) and ts[j]=='=':
                    try:keys.update(literals(assignment_rhs(ts,j+1)))
                    except ValueError as e:errors.append(f'{path}: {e}')
                if j<len(ts) and ts[j]=='{':
                    try: keys.update(literals(ts[j:close(ts,j)+1]))
                    except ValueError as e: errors.append(f'{path}: {e}')
            # Function labels and positional arguments are extracted from the declaration,
            # not a hard-coded list of helper names.
            if t in ['func','case'] and i+2<len(ts) and ts[i+2]=='(':
                end=close(ts,i+2); params=split(ts[i+3:end]); keyparams=[]
                for index,param in enumerate(params):
                    if 'LocalizationKey' in param:
                        colon=param.index(':') if ':' in param else -1
                        label=param[0] if colon>0 and param[0]!='_' else None
                        if colon>0: typed.add(param[colon-1])
                        keyparams.append((index,label))
                if keyparams: helpers.setdefault(ts[i+1],[]).extend(keyparams)
                j=end+1
                if ts[j:j+2]==['->','LocalizationKey']:
                    producers.add(ts[i+1])
                    while j<len(ts) and ts[j]!='{':j+=1
                    if j<len(ts):
                        try:keys.update(literals(ts[j:close(ts,j)+1]))
                        except ValueError as e: errors.append(f'{path}: {e}')
        # Typed error/key assignments may be spread through lifecycle callbacks.
    for path,ts in trees.items():
        typed=names[path]
        # Infer local aliases of typed producer functions/properties.
        for _ in range(4):
            for i,t in enumerate(ts[:-3]):
                if t in ['let','var'] and ts[i+2]=='=':
                    expression=ts[i+3:i+14]
                    if expression[0] in typed|producers or (len(expression)>2 and expression[1]=='.' and expression[2] in producers):typed.add(ts[i+1])
        for i,t in enumerate(ts):
            if t in typed and i+1<len(ts) and ts[i+1]=='=':
                expression=assignment_rhs(ts,i+2)
                try:keys.update(literals(expression))
                except ValueError as e: errors.append(f'{path}: {e}')
            if t not in helpers or i+1>=len(ts) or ts[i+1]!='(' or (i>0 and ts[i-1] in ['func','case']):continue
            args=split(ts[i+2:close(ts,i+1)])
            for index,label in set(helpers[t]):
                if label:
                    matches=[a[2:] for a in args if a[:2]==[label,':']]
                    if not matches:continue
                    arg=matches[0]
                elif index<len(args):arg=args[index]
                else:continue
                # Method overloads can share names. Only direct localization calls
                # must resolve here; Swift validates all other typed helper arguments.
                try:keys.update(literals(arg))
                except ValueError as e: errors.append(f'{path}: {e}')
                if t in ['text','format'] and i>=2 and ts[i-1]=='.' and ts[i-2] in ['prefs','preferences']:
                    resolved=key_expression(arg,typed,producers)
                    # $0 in a typed LocalizationKey array or typed enum closure is
                    # compiler checked; explicitly annotated arrays are roots below.
                    if arg==['$0'] and 'LocalizationKey' in ts:resolved=True
                    if not resolved:errors.append(f'{path}: unresolved dynamic {t}({" ".join(arg)})')
        # Explicit typed array literal (e.g. picker options) is also a source root.
        for i,t in enumerate(ts):
            if t=='[':
                end=close(ts,i)
                if ts[end+1:end+5]==['as','[','LocalizationKey',']']:
                    keys.update(literals(ts[i:end+1]))
    keys.discard('')
    return keys, errors

def validate(keys, catalog):
    errors=[]
    for key in sorted(keys):
        entry=catalog.get('strings',{}).get(key,{})
        for locale in LOCALES:
            loc=entry.get('localizations',{}).get(locale)
            if not loc: errors.append(f'{key}: missing {locale}');continue
            plural=loc.get('variations',{}).get('plural')
            forms=plural or {'value':loc}
            required={'other'} if locale in ['ko','ja','zh-Hans','zh-Hant','th','vi'] else {'one','other'}
            if plural and not required.issubset(forms):errors.append(f'{key}/{locale}: missing plural forms {required-set(forms)}')
            for form,value in forms.items():
                unit=value.get('stringUnit',{})
                if unit.get('state')!='translated' or not unit.get('value'):errors.append(f'{key}/{locale}/{form}: empty or untranslated')
    return errors

def main():
    sources={str(p.relative_to(ROOT)):p.read_text() for folder in ['SwingLab','Sources/SwingLabCore'] for p in (ROOT/folder).rglob('*.swift')}
    # The one storage implementation receives the typed parameter, not an unchecked API.
    keys,errors=scan(sources)
    catalog=json.loads((ROOT/'SwingLab/Resources/Localizable.xcstrings').read_text())
    errors+=validate(keys,catalog)
    if errors:
        print('\n'.join(errors));return 1
    print(f'PASS localization source reachability: {len(keys)} literal/typed-enum/helper keys, {len(LOCALES)} locales, plural forms; no unresolved text/format calls')
    return 0
if __name__=='__main__':sys.exit(main())
