"""Run with python3 -m unittest discover -s .config/skills/tests -v.

Real Git sources and isolated homes; only external agent/package CLIs are fixtures.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]
INSTALL = REPO / '.local/bin/skills-install'

# A package/agent boundary fixture. It can fail or report success without delivering.
CLI = r'''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
h = pathlib.Path.home()
args = sys.argv[1:]
tool = pathlib.Path(sys.argv[0]).name
with (h / 'calls').open('a') as f:
    f.write(json.dumps([tool] + args) + '\n')
def load(p, default):
    return json.loads(p.read_text()) if p.exists() else default
def save(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data))
if tool == 'npx':
    if os.environ.get('FAIL_INSTALL'):
        sys.exit(9)
    if os.environ.get('EMPTY_INSTALL'):
        sys.exit(0)
    source = pathlib.Path(args[args.index('add') + 1])
    names = args[args.index('--skill') + 1:args.index('-a')]
    agent = args[args.index('-a') + 1]
    dest = h / ('.agents' if agent == 'codex' else '.claude') / 'skills'
    for name in names:
        src = next(p.parent for p in source.rglob('SKILL.md') if p.parent.name == name)
        shutil.copytree(src, dest / name, dirs_exist_ok=True)
elif tool == 'codex':
    path = h / 'codex-plugins.json'
    data = load(path, {'installed': []})
    if args[:2] == ['plugin', 'list']:
        print(json.dumps(data))
    elif args[:2] == ['plugin', 'remove']:
        data['installed'] = [p for p in data['installed'] if p['pluginId'] != args[2]]
        save(path, data)
elif tool == 'claude':
    settings = h / '.claude/settings.json'
    s = load(settings, {})
    if args[:3] == ['plugin', 'marketplace', 'add']:
        known = h / '.claude/plugins/known_marketplaces.json'
        if load(known, {}).get('market'):
            sys.exit(1)
        save(known, {'market': {'source': {'path': args[3]}}})
        save(h / 'marketplace.json', {'path': args[3]})
    elif args[:3] == ['plugin', 'marketplace', 'remove']:
        save(h / '.claude/plugins/known_marketplaces.json', {})
    elif args[:2] == ['plugin', 'install']:
        source = pathlib.Path(load(h / 'marketplace.json', {})['path']) / 'plugin'
        dest = h / '.claude/plugins/cache/native'
        shutil.copytree(source, dest, dirs_exist_ok=True)
        save(h / '.claude/plugins/installed_plugins.json', {'plugins': {
            args[2]: [{'scope': 'user', 'installPath': str(dest)}]}})
        s.setdefault('enabledPlugins', {})[args[2]] = True
        save(settings, s)
    elif args[:2] == ['plugin', 'uninstall']:
        shutil.rmtree(h / '.claude/plugins/cache/native', ignore_errors=True)
        save(h / '.claude/plugins/installed_plugins.json', {'plugins': {}})
    elif args[:2] == ['plugin', 'enable']:
        if s.get('enabledPlugins', {}).get(args[2]):
            sys.exit(1)
        s.setdefault('enabledPlugins', {})[args[2]] = True
        save(settings, s)
elif tool == 'herdr':
    if args == ['--version']:
        print('herdr fixture 1')
    elif os.environ.get('OLD_HERDR'):
        sys.exit(2)
    else:
        print('---\nname: herdr\ndescription: test\n---\nA binary skill.')
elif tool == 'curl':
    if os.environ.get('FAIL_DOWNLOAD'):
        sys.exit(22)
    print('---\nname: herdr\ndescription: fallback\n---\nFallback skill.')
'''


class RestoreTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.bin = self.home / '.local/bin'
        self.bin.mkdir(parents=True)
        self.source = self.base / 'source'
        self.source.mkdir()
        for name in ('review', 'extra'):
            p = self.source / 'skills' / name
            p.mkdir(parents=True)
            (p / 'SKILL.md').write_text('---\nname: ' + name + '\ndescription: fixture\n---\nInstructions\n')
            (p / 'agents').mkdir()
            (p / 'agents/openai.yaml').write_text('policy:\n  allow_implicit_invocation: false\n')
            (p / 'references').mkdir()
            (p / 'references/guide.md').write_text('Reference instructions\n')
        plugin = self.source / 'plugin'
        (plugin / '.claude-plugin').mkdir(parents=True)
        (plugin / '.claude-plugin/plugin.json').write_text(
            '{"name":"native","version":"1.0","skills":["../skills/review"]}')
        (self.source / '.claude-plugin').mkdir()
        (self.source / '.claude-plugin/marketplace.json').write_text(
            '{"name":"market","plugins":[{"name":"native","source":"./plugin"}]}')
        for kind in ('commands', 'agents'):
            (plugin / kind).mkdir()
            (plugin / kind / 'review.md').write_text('Plugin component\n')
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        self.pin = self.git('rev-parse', 'HEAD').strip()
        self.data = {'schema': 2, 'root': str(self.home / 'sources'), 'skills_cli_version': '1.5.18',
                     'repos': [{'dir': 'example', 'url': str(self.source), 'pin': self.pin,
                                'skills': {'review': 'skills/review'},
                                'targets': {'codex': 'skills', 'claude': 'skills'},
                                'replaces': {'codex': ['old@market'], 'claude': ['old@market']}}],
                     'binary_skills': []}
        self.manifest = self.home / 'sources.json'
        self.write_manifest()
        for name in ('npx', 'codex', 'claude', 'herdr', 'curl'):
            p = self.bin / name
            p.write_text(CLI.replace('#!/usr/bin/env python3', '#!' + shutil.which('python3')))
            p.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':' + os.environ['PATH'],
                        SKILLS_SOURCES=str(self.manifest))
        self.env.pop('CODER', None)
        self.env.pop('CLAUDE_CONFIG_DIR', None)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args], text=True)

    def write_manifest(self):
        self.manifest.write_text(json.dumps(self.data))

    def invoke(self, *args, success=True, **env):
        result = subprocess.run(['bash', str(INSTALL), *args], env=dict(self.env, **env),
                                text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self):
        p = self.home / 'calls'
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def test_restore_is_pinned_selected_and_idempotent(self):
        self.invoke()
        for root in ('.agents', '.claude'):
            self.assertEqual((self.home / root / 'skills/review/agents/openai.yaml').read_bytes(),
                             (self.source / 'skills/review/agents/openai.yaml').read_bytes())
            self.assertFalse((self.home / root / 'skills/extra').exists())
        first = len([c for c in self.calls() if c[0] == 'npx'])
        self.invoke()
        self.assertEqual(first, len([c for c in self.calls() if c[0] == 'npx']))
        self.invoke('--check')
        # Advancing upstream does not advance restore.
        (self.source / 'skills/review/SKILL.md').write_text('new upstream content')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'advance')
        self.invoke()
        self.assertNotEqual((self.home / '.agents/skills/review/SKILL.md').read_text(), 'new upstream content')

    def test_check_reports_missing_and_modified_without_writes(self):
        self.invoke('--check', success=False)
        self.assertFalse((self.home / 'sources').exists())
        self.invoke()
        path = self.home / '.agents/skills/review/references/guide.md'
        path.write_text('local change')
        before = {str(p): p.read_bytes() for p in self.home.rglob('*') if p.is_file() and p.name != 'calls'}
        result = self.invoke('--check', success=False)
        self.assertIn('modified', result.stderr)
        after = {str(p): p.read_bytes() for p in self.home.rglob('*') if p.is_file() and p.name != 'calls'}
        self.assertEqual(before, after)
        self.invoke()
        self.assertTrue(any(p.read_text() == 'local change' for p in
                             (self.home / '.local/state/agent-skills/backups').rglob('guide.md')))

    def test_failure_and_false_success_propagate(self):
        self.invoke(success=False, FAIL_INSTALL='1')
        self.invoke(success=False, EMPTY_INSTALL='1')

    def test_migration_disables_only_declared_plugins(self):
        settings = self.home / '.claude/settings.json'
        settings.parent.mkdir()
        settings.write_text(json.dumps({'enabledPlugins': {'old@market': True, 'keep@work': True},
                                        'permissions': {'allow': ['Bash(git *)']}}))
        (self.home / 'codex-plugins.json').write_text(json.dumps({'installed': [
            {'pluginId': 'old@market', 'enabled': True}, {'pluginId': 'keep@work', 'enabled': True}]}))
        old = self.home / '.claude/skills/review'
        old.mkdir(parents=True)
        (old / 'SKILL.md').write_text('my custom copy')
        self.invoke()
        data = json.loads(settings.read_text())
        self.assertFalse(data['enabledPlugins']['old@market'])
        self.assertTrue(data['enabledPlugins']['keep@work'])
        self.assertEqual(data['permissions']['allow'], ['Bash(git *)'])
        self.assertEqual(json.loads((self.home / 'codex-plugins.json').read_text())['installed'],
                         [{'pluginId': 'keep@work', 'enabled': True}])
        self.invoke('--check')

    def test_native_plugin_checks_commands_and_disabled_state(self):
        repo = self.data['repos'][0]
        repo['targets']['claude'] = 'plugin'
        repo['plugin'] = {'id': 'native@market', 'path': 'plugin', 'version': '1.0'}
        self.write_manifest()
        self.invoke()
        self.invoke('--check')
        calls = len([c for c in self.calls() if c[:2] == ['claude', 'plugin']])
        self.invoke()
        self.assertEqual(calls, len([c for c in self.calls() if c[:2] == ['claude', 'plugin']]))
        (self.home / '.claude/plugins/cache/native/commands/review.md').unlink()
        self.invoke('--check', success=False)
        self.invoke()
        p = self.home / '.claude/settings.json'
        d = json.loads(p.read_text())
        d['enabledPlugins']['native@market'] = False
        p.write_text(json.dumps(d))
        self.invoke('--check', success=False)

    def test_binary_fallback_and_failed_download_preserve_previous(self):
        self.data['repos'] = []
        self.data['binary_skills'] = [{'name': 'herdr', 'command': ['herdr', '--skill'],
            'fallback_url': 'https://example.invalid/pinned', 'fallback_ref': 'v1',
            'agents': ['codex', 'claude']}]
        self.write_manifest()
        self.invoke(OLD_HERDR='1')
        self.invoke('--check')
        path = self.home / '.agents/skills/herdr/SKILL.md'
        before = path.read_bytes()
        # A changed fallback pin requires restoration, even at the same binary version.
        self.data['binary_skills'][0]['fallback_ref'] = 'v2'
        self.write_manifest()
        self.invoke(success=False, OLD_HERDR='1', FAIL_DOWNLOAD='1')
        self.assertEqual(before, path.read_bytes())

    def test_dry_run_has_no_side_effects(self):
        self.invoke('--dry-run')
        self.assertFalse((self.home / 'sources').exists())
        self.assertEqual(self.calls(), [])

    def test_restricted_fallback_preserves_commands_and_agents(self):
        repo = self.data['repos'][0]
        repo['targets']['claude'] = 'plugin'
        repo['plugin'] = {'id': 'native@market', 'path': 'plugin', 'version': '1.0'}
        self.write_manifest()
        shutil.copy2(REPO / '.local/bin/skillsync', self.bin / 'skillsync')
        self.invoke(CODER='1')
        self.invoke('--check', CODER='1')
        command = self.home / '.claude/commands/native/review.md'
        self.assertEqual(command.read_text(), 'Plugin component\n')
        command.write_text('modified command')
        self.invoke('--check', CODER='1', success=False)

    def test_matching_legacy_symlinks_are_migrated_to_pinned_copies(self):
        dest = self.home / '.claude/skills/review'
        dest.parent.mkdir(parents=True)
        dest.symlink_to(self.source / 'skills/review')
        self.invoke()
        self.assertFalse(dest.is_symlink())
        self.invoke('--check')

    def test_annotated_tag_proposes_the_commit_not_tag_object(self):
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'tag', '-a', 'v1', '-m', 'release')
        result = self.invoke('--propose-update', 'example', '--ref', 'refs/tags/v1')
        self.assertIn('Proposed pin: ' + self.pin, result.stdout)

    def test_update_proposal_does_not_change_manifest_or_install(self):
        before = self.manifest.read_bytes()
        result = self.invoke('--propose-update', 'example', '--ref', 'HEAD')
        self.assertIn(self.pin, result.stdout)
        self.assertEqual(before, self.manifest.read_bytes())
        self.assertFalse((self.home / 'sources').exists())


if __name__ == '__main__':
    unittest.main()
