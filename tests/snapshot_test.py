"""Offline contract tests: fake AWS executable; never contacts AWS."""
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/rds-snapshot.sh'

class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.aws = self.root / 'aws'
        self.aws.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$TEST_LOG"
case "$*" in
 *get-caller-identity*) echo 123456789012;;
 *describe-db-instances*) printf 'postgres\\tavailable\\n';;
 *create-db-snapshot*) [ "${FAIL_CREATE:-0}" = 0 ] || exit 1;;
 *'wait db-snapshot-available'*) [ "${FAIL_WAIT:-0}" = 0 ] || exit 255;;
 *describe-db-snapshots*) printf 'example-db\\tavailable\\n';;
 *) exit 3;;
esac
''')
        self.aws.chmod(0o700)
        self.log = self.root / 'calls'
    def tearDown(self): self.temp.cleanup()
    def run_script(self, mode, account='123456789012', **extra):
        args = ['/bin/bash', str(SCRIPT), mode, str(self.aws), 'work', 'us-east-1', 'example-db']
        if mode == 'create': args += ['example-db-20260916-1536-manual', account]
        return subprocess.run(args, env={**os.environ, 'TEST_LOG':str(self.log), **extra},capture_output=True,text=True)
    def test_inspect_read_only(self):
        r=self.run_script('inspect');self.assertEqual(r.returncode,0)
        self.assertEqual(r.stdout.strip(),'123456789012')
        self.assertNotIn('create-db-snapshot',self.log.read_text())
    def test_create_and_verify(self):
        r=self.run_script('create');self.assertEqual(r.returncode,0)
        self.assertIn('Disponible:',r.stdout)
        calls=self.log.read_text();self.assertEqual(calls.count('create-db-snapshot'),1)
        self.assertIn('--profile work --region us-east-1',calls)
    def test_account_changed(self):
        r=self.run_script('create','999999999999');self.assertNotEqual(r.returncode,0)
        self.assertNotIn('create-db-snapshot',self.log.read_text())
    def test_uncertain_create_not_retried(self):
        r=self.run_script('create',FAIL_CREATE='1');self.assertNotEqual(r.returncode,0)
        self.assertEqual(self.log.read_text().count('create-db-snapshot'),1)
        self.assertNotIn('wait db-snapshot',self.log.read_text())
    def test_wait_failure_not_success(self):
        r=self.run_script('create',FAIL_WAIT='1');self.assertNotEqual(r.returncode,0)
        self.assertNotIn('Disponible:',r.stdout)
        self.assertIn('puede seguir',r.stderr)

if __name__ == '__main__': unittest.main()
