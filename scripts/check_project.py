"""Reproducible source/documentation/history gates; no network or credentials."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise SystemExit(message)


def metrics():
    files = sorted(p for p in ROOT.glob('*.mbt')
                   if not p.name.endswith(('_test.mbt', '_wbtest.mbt', '_bbtest.mbt')))
    result = []
    for path in files:
        lines = path.read_text(encoding='utf-8-sig').splitlines()
        substantive = sum(bool(s.strip()) and not s.lstrip().startswith('//') for s in lines)
        result.append({'file': path.name, 'physical': len(lines), 'substantive': substantive})
    return result


def main():
    rows = metrics()
    total = sum(row['substantive'] for row in rows)
    require(total >= 1500, 'Production MoonBit lines below 1500')
    for path in ('README.md', 'LICENSE', 'PROVENANCE.md', 'pkg.generated.mbti',
                 'docs/design.md', 'docs/competition/duplicate-check.md',
                 'scripts/requirements-oracle.txt', 'scripts/verify_interop.py'):
        require((ROOT / path).is_file(), 'Missing required artifact: ' + path)
    manifest = (ROOT / 'moon.mod').read_text(encoding='utf-8-sig')
    for field, expected in [('name', 'y666-sos/moonelan'), ('version', '0.1.0'),
                            ('license', 'MIT'), ('readme', 'README.md'),
                            ('repository', 'https://github.com/y666-sos/moonelan')]:
        require(re.search(r'^' + field + r'\s*=\s*"' + re.escape(expected) + '"',
                          manifest, re.M), 'Manifest mismatch: ' + field)
    readme = (ROOT / 'README.md').read_text(encoding='utf-8-sig')
    require(len(re.findall(r'[\u4e00-\u9fff]', readme)) > 600, 'Chinese README incomplete')
    require('y666-sos/moonelan@0.1.0' in readme, 'README version missing')
    for page in [ROOT / 'README.md', *sorted((ROOT / 'docs').rglob('*.md'))]:
        text = page.read_text(encoding='utf-8-sig')
        for link in re.findall(r'\]\(([^)]+)\)', text):
            if re.match(r'[A-Za-z][A-Za-z0-9+.-]*:', link) or link.startswith('#'):
                continue
            require((page.parent / link.split('#')[0]).is_file(),
                    'Broken local link in ' + page.name + ': ' + link)
    for name in ('curate', 'edit', 'dataset', 'oracle'):
        require((ROOT / 'examples' / name / 'main.mbt').is_file(), 'Missing workflow: ' + name)
    tests = sum(len(re.findall(r'^test\s', p.read_text(encoding='utf-8-sig'), re.M))
                for p in ROOT.glob('*_wbtest.mbt'))
    require(tests >= 26, 'Expected semantic regression tests missing')
    # This only rejects empty history entries; the purpose/scope of each commit is
    # reviewed separately in docs/competition/release-audit.md.
    commits = subprocess.check_output(['git', 'rev-list', '--reverse', 'HEAD'], cwd=ROOT,
                                      text=True).splitlines()
    nonempty = [sha for sha in commits if subprocess.check_output(
        ['git', 'diff-tree', '--root', '--no-commit-id', '--name-only', '-r', sha], cwd=ROOT)]
    require(len(nonempty) >= 20, 'Fewer than 20 nonempty engineering commits')
    print(json.dumps({'production_files': len(rows), 'physical_lines': sum(r['physical'] for r in rows),
                      'substantive_lines': total, 'moonbit_tests': tests,
                      'nonempty_commits': len(nonempty), 'files': rows}, indent=2))


if __name__ == '__main__':
    main()
