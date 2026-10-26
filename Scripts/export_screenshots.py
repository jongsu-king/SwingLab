#!/usr/bin/env python3
"""Export actual Round 4 XCTest screenshots with explicit simulator evidence."""
import argparse, hashlib, json, re, shutil, subprocess, tempfile
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--result',required=True,type=Path)
p.add_argument('--output',required=True,type=Path)
p.add_argument('--device',required=True)
p.add_argument('--runtime',required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='swinglab-screenshots-') as tmp:
    source=Path(tmp)
    subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(a.result),'--output-path',tmp],check=True)
    captured={}
    for test in json.loads((source/'manifest.json').read_text()):
        for attachment in test.get('attachments',[]):
            match=re.search(r'(round4-(?:en|ko|de)-(?:light|dark)-[a-z-]+)(?=$|[._ ])',attachment.get('suggestedHumanReadableName',''))
            if not match:continue
            original=source/attachment['exportedFileName']
            if original.read_bytes()[:8]!=b'\x89PNG\r\n\x1a\n':raise SystemExit('Non-PNG screenshot')
            destination=a.output/(match.group(1)+'.png');shutil.copyfile(original,destination)
            captured[destination.name]={'file':destination.name,'test':test['testIdentifier'],
                'device':a.device,'runtime':a.runtime,'deviceID':attachment.get('deviceId'),
                'timestamp':attachment.get('timestamp'),'resultBundle':str(a.result),
                'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
    expected={f'round4-{lang}-{style}-{screen}.png' for lang in ['en','ko','de'] for style in ['light','dark']
              for screen in ['home','swing','swing-detail-empty','flight','course','performance','settings','bag']}
    missing=expected-captured.keys()
    (a.output/'manifest.json').write_text(json.dumps({'device':a.device,'runtime':a.runtime,'resultBundle':str(a.result),
        'screenshots':[captured[k] for k in sorted(captured)]},indent=2)+'\n')
    print(f'Exported {len(captured)} screenshots: {a.device}, {a.runtime}, {a.output}')
    if missing:raise SystemExit('Missing screenshots: '+', '.join(sorted(missing)))
