#!/usr/bin/env python3
"""Merge reviewed translation fragments into Xcode string catalogs; report gaps."""
import json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
LANGS=['ko','ja','zh-Hans','zh-Hant','es','pt-BR','de','fr','it','th','vi']
translations={}
for folder in ['Scripts','Docs']:
    for path in sorted((ROOT/folder).glob('Localization-*.json')):
        if 'missing' in path.stem.lower(): continue
        data=json.loads(path.read_text())
        if not isinstance(data,dict): continue
        for key, values in data.items():
            if isinstance(values,dict):
                key=key.replace("\\n", "\n")
                translations.setdefault(key,{}).update({lang: value.replace("\\n", "\n") for lang,value in values.items() if isinstance(value,str)})
for line in (ROOT/'Scripts/Localization-global.tsv').read_text().splitlines():
    if not line: continue
    values=line.split('|')
    assert len(values)==12, values[0]
    translations.setdefault(values[0],{}).update(dict(zip(LANGS,values[1:])))
# Extract all literal branches within preferences.text(...), including ternary expressions.
def literal_keys(source):
    for match in re.finditer(r'\b(?:prefs|preferences)\.text\(',source):
        i=match.end(); depth=1
        while i<len(source) and depth:
            if source[i]=='"':
                start=i; i+=1
                while i<len(source):
                    if source[i]=='\\': i+=2; continue
                    if source[i]=='"': break
                    i+=1
                literal=source[start:i+1]
                try:
                    value=json.loads(literal)
                    if value and '\\(' not in value: yield value
                except (ValueError, json.JSONDecodeError): pass
            elif source[i]=='(': depth+=1
            elif source[i]==')': depth-=1
            i+=1
keys=set(translations)
for path in (ROOT/'SwingLab').rglob('*.swift'):
    source=path.read_text()
    keys.update(literal_keys(source))
    # Error keys and coaching templates are passed dynamically to text(). Catch their
    # complete English sentences too; language endonyms are intentionally unchanged.
    for match in re.finditer(r'"(?:[^"\\]|\\.)*"', source):
        try: value=json.loads(match.group())
        except ValueError: continue
        if (value[:1].isupper() and ' ' in value and re.search(r'[A-Za-z]',value)
                and '\\(' not in value and value not in ['Português (Brasil)', 'Tiếng Việt']):
            keys.add(value)

# Only real translations are written. Missing translations fall back to the English source,
# are recorded explicitly below, and must be resolved before a global release.
def unit(value): return {'stringUnit':{'state':'translated','value':value}}
strings={}
missing={}
for key in sorted(keys):
    loc={'en':unit(translations.get(key,{}).get('en',key))}
    for language in LANGS:
        value=translations.get(key,{}).get(language)
        if value: loc[language]=unit(value)
        else: missing.setdefault(key,[]).append(language)
    strings[key]={'extractionState':'manual','localizations':loc}
resource=ROOT/'SwingLab/Resources'
(resource/'Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
permissions={}
for line in (ROOT/'Scripts/Localization-permissions.tsv').read_text().splitlines():
    if not line: continue
    row=line.split('|'); assert len(row)==13,row[0]
    permissions[row[0]]={'extractionState':'manual','localizations':{lang:unit(value) for lang,value in zip(['en']+LANGS,row[1:])}}
(resource/'InfoPlist.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':permissions,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
(ROOT/'Docs/LocalizationGaps.json').write_text(json.dumps(missing,ensure_ascii=False,indent=2)+'\n')
print(f'{len(strings)} UI keys; {len(permissions)} permission descriptions; {len(missing)} keys with missing locales.')
