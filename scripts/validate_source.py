#!/usr/bin/env python3
"""Offline repository checks; Salesforce compilation and tests run separately."""
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {'m': 'http://soap.sforce.com/2006/04/metadata'}


def validate():
    errors = []
    project = json.loads((ROOT / 'sfdx-project.json').read_text())
    if project['name'] != 'apex-async-dispatcher' or project['sourceApiVersion'] != '64.0':
        errors.append('Project name and minimum API version must match the public contract.')
    packages = {item['path']: item['default'] for item in project['packageDirectories']}
    if packages != {'force-app': True, 'examples': False}:
        errors.append('Core and examples must be separate package directories.')
    for directory in packages:
        for path in (ROOT / directory).rglob('*.xml'):
            try:
                metadata = ET.parse(path).getroot()
                if not metadata.tag.startswith('{' + NS['m'] + '}'):
                    errors.append(f'{path.relative_to(ROOT)}: missing Salesforce namespace')
                if path.name.endswith('.cls-meta.xml'):
                    if metadata.findtext('m:apiVersion', namespaces=NS) != '64.0':
                        errors.append(f'{path.name}: API version must be 64.0')
                    if not path.with_name(path.name.removesuffix('-meta.xml')).is_file():
                        errors.append(f'{path.name}: missing Apex source')
            except ET.ParseError as error:
                errors.append(f'{path.relative_to(ROOT)}: {error}')
        for path in (ROOT / directory).rglob('*.cls'):
            if not path.with_name(path.name + '-meta.xml').is_file():
                errors.append(f'{path.name}: missing class metadata')
    required = [
        'README.md', 'LICENSE', 'CONTRIBUTING.md', 'CHANGELOG.md',
    ]
    for name in ['AADDispatcher', 'AADRequest', 'AADHandler', 'AADExecutionContext',
                 'AADOperationConfig', 'AADOperationRegistry', 'AADHandlerFactory',
                 'AADQueueable', 'AADException', 'AADDispatcherTest', 'AADRequestTest',
                 'AADOperationRegistryTest', 'AADHandlerFactoryTest', 'AADQueueableTest']:
        required.append(f'force-app/main/default/classes/{name}.cls')
    for name in ['AADExampleAccountHandler', 'AADExampleCalloutHandler']:
        required.extend(f'examples/main/default/classes/{name}{suffix}.cls' for suffix in ['', 'Test'])
    for path in required:
        if not (ROOT / path).is_file():
            errors.append(f'Missing required file: {path}')
    for key, handler in [('EXAMPLE_ACCOUNT_UPDATE', 'AADExampleAccountHandler'),
                         ('EXAMPLE_HTTP_CALLOUT', 'AADExampleCalloutHandler')]:
        path = ROOT / f'examples/main/default/customMetadata/AAD_Operation.{key}.md-meta.xml'
        if not path.is_file():
            errors.append(f'Missing example registration: {key}')
            continue
        metadata = ET.parse(path).getroot()
        values = {item.findtext('m:field', namespaces=NS): item.findtext('m:value', namespaces=NS)
                  for item in metadata.findall('m:values', NS)}
        if values != {'Handler_Class__c': handler, 'Enabled__c': 'true', 'Delay_Minutes__c': '0'}:
            errors.append(f'Incorrect example registration: {key}')
    if list((ROOT / 'force-app').rglob('*.md-meta.xml')):
        errors.append('Core installation must not include example operation registrations.')
    for path in [ROOT / 'README.md', *(ROOT / 'docs').glob('*.md'), ROOT / 'CONTRIBUTING.md']:
        if not path.exists():
            continue
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', path.read_text()):
            if '://' in target or target.startswith('#'):
                continue
            if not (path.parent / target.split('#')[0]).exists():
                errors.append(f'{path.name}: broken local link {target}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Source structure, metadata XML, API versions, example registrations, and documentation links passed.')
    return 0


if __name__ == '__main__':
    sys.exit(validate())
