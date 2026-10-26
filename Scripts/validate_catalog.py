#!/usr/bin/env python3
"""Validate bundled equipment facts; absence is explicit, never filled with invented specs."""
import json
import math
import re
import sys
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
CATEGORIES = {'Driver', 'Fairway Wood', 'Hybrid', 'Utility Iron', 'Iron', 'Wedge', 'Putter'}
REQUIRED_BRANDS = {'TaylorMade', 'Callaway', 'Titleist', 'PING', 'Cobra', 'Mizuno', 'Srixon', 'Cleveland', 'PXG', 'Honma', 'XXIO', 'Wilson', 'Bridgestone', 'Tour Edge', 'Yamaha', 'Ben Hogan', 'Miura', 'Epon', 'Odyssey', 'Scotty Cameron (Titleist)', 'Bettinardi', 'Evnroll', 'L.A.B. Golf'}

def check(condition, message):
    if not condition:
        raise ValueError(message)

def evidence(row):
    source = row.get('source')
    check(type(row.get('verified')) is bool, f"{row.get('id')}: verified must be explicit")
    if source is not None:
        u = urlparse(source)
        check(u.scheme == 'https' and bool(u.netloc), f"{row['id']}: invalid source URL")
    check(bool(source) or row['verified'] is False, f"{row['id']}: missing evidence")

def ids(rows):
    values = [r['id'] for r in rows]
    check(len(values) == len(set(values)), 'Duplicate stable IDs')
    for value in values:
        check(bool(re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', value)), f'Unstable ID {value}')
    return set(values)

def number(value, lo, hi):
    return type(value) in (int, float) and math.isfinite(value) and lo <= value <= hi

def validate(path):
    data = json.loads(path.read_text())
    check(data['version'] == 1, 'Unknown catalog schema')
    for collection in ['brands', 'clubs', 'shafts', 'hoselSystems']:
        ids(data[collection])
        for row in data[collection]:
            evidence(row)
    check(REQUIRED_BRANDS <= {b['name'] for b in data['brands']}, 'Missing required brand')
    brand_ids, hosel_ids = ids(data['brands']), ids(data['hoselSystems'])
    for club in data['clubs']:
        check(club['brandID'] in brand_ids, f"{club['id']}: unknown brand")
        check(club['category'] in CATEGORIES, f"{club['id']}: category")
        check(type(club['releaseYear']) is int and 2000 <= club['releaseYear'] <= date.today().year, f"{club['id']}: year")
        check(bool(club['model'].strip()), 'Empty model')
        check(club.get('hoselSystemID') is None or club['hoselSystemID'] in hosel_ids, f"{club['id']}: hosel")
        for key in ['variants', 'availableClubs']:
            check(all(type(v) is str for v in club[key]), f"{club['id']}: invalid {key}")
            check(len(set(club[key])) == len(club[key]), f"{club['id']}: duplicate {key}")
        check(all(number(x, 0, 90) for x in club['stockLoftsDegrees']), f"{club['id']}: invalid loft")
        if club['stockLoftsDegrees'] or club['availableClubs']:
            check(club['verified'] and club.get('source'), f"{club['id']}: unsourced club specification")
    for shaft in data['shafts']:
        check(shaft['material'] in {'steel', 'graphite'}, f"{shaft['id']}: material")
        check(all(number(x, 20, 200) for x in shaft['weightClassesGrams']), f"{shaft['id']}: invalid mass")
        if shaft['flexes'] or shaft['weightClassesGrams']:
            check(shaft['verified'] and shaft.get('source'), f"{shaft['id']}: unsourced shaft specification")
    for system in data['hoselSystems']:
        check(system['brandID'] in brand_ids, f"{system['id']}: brand")
        check(system['handedness'] in {'right', 'left', 'unknown'}, f"{system['id']}: handedness")
        ids(system['positions'])
        for position in system['positions']:
            evidence(position)
            check(bool(position['label']), 'Empty sleeve label')
            for key in ['loftDeltaDegrees', 'lieDeltaDegrees', 'faceAngleDegrees']:
                value = position.get(key)
                check(value is None or number(value, -10, 10), f"{position['id']}: invalid {key}")
                if value is not None:
                    check(position['verified'] and position.get('source'), f"{position['id']}: unsourced sleeve value")
    return data

if __name__ == '__main__':
    try:
        data = validate(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'SwingLab/Resources/Catalog/equipment-catalog.json')
    except (ValueError, KeyError, TypeError) as error:
        print(f'FAIL equipment catalog: {error}', file=sys.stderr)
        sys.exit(1)
    verified = sum(c['verified'] for c in data['clubs'])
    print(f"PASS equipment catalog: {len(data['brands'])} brands, {len(data['clubs'])} clubs ({verified} sourced; {len(data['clubs'])-verified} explicitly unverified), {len(data['shafts'])} shafts, {len(data['hoselSystems'])} adapter generations")
