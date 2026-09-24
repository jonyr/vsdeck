"""Run the real adapter with disposable scripts and a fake Git; never deploy."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

adapter = Path('scripts/hex-sales.sh').resolve()
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    repo = root / 'repo with spaces'
    repo.mkdir()
    binary = root / 'bin'
    binary.mkdir()
    trace = root / 'trace'
    git = binary / 'git'
    git.write_text('#!/bin/bash\nprintf "git %s\\n" "$*" >> "$TRACE"\n[ "$*" = "status --porcelain" ] || exit 99\nprintf "%s" "${DIRTY:-}"\nexit "${GIT_EXIT:-0}"\n')
    git.chmod(0o755)
    deploy = repo / 'deploy-sales.sh'
    deploy.write_text('#!/bin/bash\nprintf "deploy %s\\n" "$PWD" >> "$TRACE"\nexit "${DEPLOY_EXIT:-0}"\n')
    deploy.chmod(0o755)
    env = {**os.environ, 'PATH': f'{binary}:/usr/bin:/bin', 'TRACE': str(trace),
           'VSDECK_SALES_BACKEND': str(repo), 'VSDECK_SALES_FRONTEND': str(repo)}
    def run(*args, **extra):
        return subprocess.run(['/bin/bash', str(adapter), *args], env={**env, **extra}, capture_output=True, text=True)
    description = run('--describe')
    assert description.returncode == 0
    assert [o['value'] for o in json.loads(description.stdout)['inputs'][0]['options']] == ['backend', 'frontend']
    assert not trace.exists(), '--describe must have no Git or deployment effects'
    for app in ['backend', 'frontend']:
        trace.unlink(missing_ok=True)
        result = run('--run', '--app', app)
        assert result.returncode == 0, result.stderr
        assert trace.read_text().splitlines() == ['git status --porcelain', f'deploy {repo}']
        events = [json.loads(line[13:]) for line in result.stdout.splitlines() if line.startswith('VSDECK_EVENT ')]
        assert events[-1] == {'type': 'result', 'message': 'Tag sales publicado'}
    for extra in [{'DEPLOY_EXIT': '7'}, {'DIRTY': ' M local.txt'}, {'GIT_EXIT': '2'}]:
        trace.unlink(missing_ok=True)
        result = run('--run', '--app', 'backend', **extra)
        assert result.returncode != 0 and 'Tag sales publicado' not in result.stdout
        if 'DEPLOY_EXIT' not in extra:
            assert 'deploy ' not in trace.read_text()
    assert run('--run', '--app', 'website').returncode != 0
    assert run('--run', '--app', 'backend', VSDECK_SALES_BACKEND='').returncode != 0
print('PASS: Sales adapter description, both apps, cwd, no extra pull, clean-tree gate and failure propagation.')
