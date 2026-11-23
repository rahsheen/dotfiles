#!/usr/bin/env python3
"""Restore declared skills and verify the delivered files for each agent."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


class Failure(Exception):
    pass


def run(args, capture=False, env_overrides=None):
    try:
        result = subprocess.run(args, stdin=subprocess.DEVNULL, text=True, timeout=120,
                                stdout=subprocess.PIPE if capture else None,
                                env=dict(dict(os.environ, DISABLE_TELEMETRY='1', GIT_OPTIONAL_LOCKS='0'),
                                         **(env_overrides or {})))
    except subprocess.TimeoutExpired:
        raise Failure('command timed out: ' + shlex.join(map(str, args)))
    if result.returncode:
        raise Failure('command failed: ' + shlex.join(map(str, args)))
    return result.stdout if capture else None


def load(path, default=None):
    return json.loads(path.read_text()) if path.exists() else default


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    os.replace(f.name, path)


def payload(path):
    """Match the skills CLI exclusions; preserve scripts and agents/openai.yaml."""
    if not path.is_dir():
        return None
    result = {}
    for base, dirs, files in os.walk(path, followlinks=True):
        dirs[:] = sorted(d for d in dirs if d not in ('.git', '__pycache__', '__pypackages__'))
        for name in sorted(files):
            if name != 'metadata.json':
                f = Path(base) / name
                result[str(f.relative_to(path))] = hashlib.sha256(f.read_bytes()).hexdigest()
    return result


def skill_payload(path):
    return payload(path) if (path / 'SKILL.md').is_file() else None


class Manager:
    def __init__(self, args):
        self.args = args
        self.home = Path.home()
        self.sources = Path(os.environ.get('SKILLS_SOURCES', self.home / '.config/skills/sources.json'))
        self.data = load(self.sources)
        if not self.data or self.data.get('schema') != 2:
            raise Failure('expected sources.json schema 2: ' + str(self.sources))
        self.root = Path(os.path.expanduser(self.data['root']))
        self.agents = [a for a in ('codex', 'claude') if shutil.which(a)]
        self.state_path = self.home / '.local/state/agent-skills/install.json'
        self.state = load(self.state_path, {})
        self.errors = []
        self.restricted = bool(os.environ.get('CODER'))
        for path in (self.home / '.claude/remote-settings.json',
                     Path('/Library/Application Support/ClaudeCode/managed-settings.json'),
                     Path('/etc/claude-code/managed-settings.json')):
            if 'strictKnownMarketplaces' in load(path, {}):
                self.restricted = True
        self.validate()

    def validate(self):
        names = set()
        for repo in self.data['repos']:
            if not re.fullmatch(r'[\w-]+', repo['dir']):
                raise Failure('invalid repo directory')
            if not re.fullmatch(r'[0-9a-f]{40}', repo['pin']):
                raise Failure('exact 40-character pin required: ' + repo['dir'])
            for name, rel in repo['skills'].items():
                if not re.fullmatch(r'[\w-]+', name) or name in names:
                    raise Failure('invalid or duplicate skill name: ' + name)
                names.add(name)
                if Path(rel).is_absolute() or '..' in Path(rel).parts:
                    raise Failure('skill path must stay inside its source')
            for agent, method in repo['targets'].items():
                if agent not in ('codex', 'claude') or method not in ('skills', 'plugin'):
                    raise Failure('unsupported target method')
                if method == 'plugin' and agent != 'claude':
                    raise Failure('native plugin adapter currently supports Claude only')

    def destination(self, agent, name):
        return self.home / ('.agents' if agent == 'codex' else '.claude') / 'skills' / name

    def source(self, repo):
        # A new pin gets a separate checkout. Restore never moves an existing pin.
        path = self.root / repo['dir'] / repo['pin']
        if not path.exists():
            if self.args.check:
                raise Failure('missing pinned source: ' + str(path))
            path.parent.mkdir(parents=True, exist_ok=True)
            tmp = Path(tempfile.mkdtemp(prefix='.clone-', dir=path.parent))
            try:
                run(['git', 'init', '-q', str(tmp)])
                run(['git', '-C', str(tmp), 'remote', 'add', 'origin', repo['url']])
                run(['git', '-C', str(tmp), 'fetch', '-q', '--depth=1', 'origin', repo['pin']])
                run(['git', '-C', str(tmp), 'checkout', '-q', '--detach', 'FETCH_HEAD'])
                tmp.rename(path)
            finally:
                if tmp.exists():
                    shutil.rmtree(tmp)
        sha = run(['git', '-C', str(path), 'rev-parse', 'HEAD'], capture=True).strip()
        dirty = run(['git', '-C', str(path), 'status', '--porcelain'], capture=True)
        if sha != repo['pin'] or dirty:
            raise Failure('pinned source differs or has edits: ' + str(path))
        for name, rel in repo['skills'].items():
            skill = path / rel
            if not skill.resolve().is_relative_to(path.resolve()) or skill_payload(skill) is None:
                raise Failure('missing skill at declared path: ' + str(skill))
        if 'plugin' in repo['targets'].values():
            spec = repo['plugin']
            plugin_root = path / spec['path']
            manifest = load(plugin_root / '.claude-plugin/plugin.json', {})
            if (not plugin_root.resolve().is_relative_to(path.resolve())
                    or manifest.get('name') != spec['id'].split('@')[0]
                    or manifest.get('version') != spec['version']):
                raise Failure('native plugin metadata differs from the declared version')
        return path

    def backup(self, path, move=True):
        if not path.exists() and not path.is_symlink():
            return
        folder = self.home / '.local/state/agent-skills/backups'
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / (path.name + '-' + str(time.time_ns()))
        if move:
            shutil.move(str(path), str(target))
        elif path.is_dir():
            shutil.copytree(path, target, symlinks=True)
        else:
            shutil.copy2(path, target)
        print('    backed up {} -> {}'.format(path, target))

    def plugins(self, agent):
        result = json.loads(run([agent, 'plugin', 'list', '--json'], capture=True))
        return result.get('installed', []) if isinstance(result, dict) else result

    def legacy(self, repo, agent, disable=False):
        ids = repo.get('replaces', {}).get(agent, [])
        if not ids:
            return
        if agent == 'claude':
            path = self.home / '.claude/settings.json'
            settings = load(path, {})
            enabled = settings.setdefault('enabledPlugins', {})
            if disable and any(enabled.get(name) is not False for name in ids):
                for name in ids:
                    enabled[name] = False
                self.backup(path, move=False)
                save(path, settings)
            duplicate = [name for name in ids if enabled.get(name, False)]
        else:
            installed = self.plugins(agent)
            duplicate = [p['pluginId'] for p in installed
                         if p.get('pluginId') in ids and p.get('enabled', True)]
            if disable:
                for name in duplicate:
                    run(['codex', 'plugin', 'remove', name])
                duplicate = [p['pluginId'] for p in self.plugins(agent)
                             if p.get('pluginId') in ids and p.get('enabled', True)]
        if duplicate:
            raise Failure('duplicate legacy plugins enabled: ' + ', '.join(duplicate))

    def generic(self, repo, source, agent):
        expected = {name: skill_payload(source / rel) for name, rel in repo['skills'].items()}
        missing = [name for name in expected
                   if self.destination(agent, name).is_symlink()
                   or skill_payload(self.destination(agent, name)) != expected[name]]
        if missing and self.args.check:
            raise Failure('missing, broken, or modified skills: ' + ', '.join(missing))
        if missing:
            for name in repo['skills']:
                # npx rewrites every selected directory; preserve existing local copies.
                self.backup(self.destination(agent, name))
            run(['npx', '-y', 'skills@' + self.data['skills_cli_version'], 'add', str(source),
                 '--skill', *repo['skills'], '-a', 'codex' if agent == 'codex' else 'claude-code',
                 '-g', '-y', '--copy'])
        for name in expected:
            if skill_payload(self.destination(agent, name)) != expected[name]:
                raise Failure('installed content differs: ' + str(self.destination(agent, name)))
        self.legacy(repo, agent, disable=not self.args.check)

    def native_ok(self, repo, source, require_enabled=True):
        plugin = repo['plugin']
        settings = load(self.home / '.claude/settings.json', {})
        if require_enabled and not settings.get('enabledPlugins', {}).get(plugin['id'], False):
            return False
        registry = load(self.home / '.claude/plugins/installed_plugins.json', {})
        for entry in registry.get('plugins', {}).get(plugin['id'], []):
            path = Path(entry.get('installPath', '/nonexistent'))
            if entry.get('scope') == 'user' and payload(path) == payload(source / plugin['path']):
                return True
        return False

    def native(self, repo, source):
        if self.restricted:
            # Keep the existing policy-compatible commands-and-agents fallback.
            if not self.args.check:
                fallback = dict(self.data, root=str(self.root / 'restricted'), repos=[repo])
                with tempfile.TemporaryDirectory() as tmp:
                    path = Path(tmp) / 'sources.json'
                    save(path, fallback)
                    run(['skillsync', '--sources', str(path)], env_overrides={'LC_ALL': 'C'})
            for name, rel in repo['skills'].items():
                if skill_payload(self.destination('claude', name)) != skill_payload(source / rel):
                    raise Failure('restricted Claude skill missing or differs: ' + name)
            for kind in ('commands', 'agents'):
                for item in (source / repo['plugin']['path'] / kind).glob('*.md'):
                    dest = self.home / '.claude' / kind
                    if kind == 'commands':
                        dest /= repo['plugin']['id'].split('@')[0]
                    target = dest / item.name
                    if not target.is_file():
                        raise Failure('restricted Claude component missing: ' + str(dest / item.name))
                    # skillsync rewrites plugin-relative references to its clone path.
                    proot = self.root / 'restricted' / repo['dir'] / repo['plugin']['path']
                    expected = re.sub(r'\]\((\.{1,2}/[^)\s]+)\)',
                                      lambda m: '](' + str((proot / kind / m[1]).resolve()) + ')',
                                      item.read_text())
                    expected = expected.replace('${CLAUDE_PLUGIN_ROOT}', str(proot))
                    expected = re.sub(r'\$CLAUDE_PLUGIN_ROOT\b', str(proot), expected)
                    if target.read_text() != expected:
                        raise Failure('restricted Claude component differs: ' + str(target))
            replaced = dict(repo, replaces={'claude': [repo['plugin']['id']]
                                           + repo.get('replaces', {}).get('claude', [])})
            self.legacy(replaced, 'claude', disable=not self.args.check)
            return
        if not self.native_ok(repo, source):
            if self.args.check:
                raise Failure('Claude plugin missing, disabled, or differs: ' + repo['plugin']['id'])
            if not self.native_ok(repo, source, require_enabled=False):
                registry = load(self.home / '.claude/plugins/installed_plugins.json', {})
                installed = [p for p in registry.get('plugins', {}).get(repo['plugin']['id'], [])
                             if p.get('scope') == 'user']
                for entry in installed:
                    self.backup(Path(entry['installPath']), move=False)
                if installed:
                    run(['claude', 'plugin', 'uninstall', repo['plugin']['id'], '--scope', 'user'])
                # Local marketplace paths are immutable; restore cannot advance pins.
                name = repo['plugin']['id'].split('@')[1]
                known = load(self.home / '.claude/plugins/known_marketplaces.json', {}).get(name)
                if known and known.get('source', {}).get('path') != str(source):
                    run(['claude', 'plugin', 'marketplace', 'remove', name])
                    known = None
                if not known:
                    run(['claude', 'plugin', 'marketplace', 'add', str(source)])
                run(['claude', 'plugin', 'install', repo['plugin']['id'], '--scope', 'user'])
            # Claude install enables a new plugin. Enabling it again is an error.
            enabled = load(self.home / '.claude/settings.json', {}).get('enabledPlugins', {})
            if not enabled.get(repo['plugin']['id'], False):
                run(['claude', 'plugin', 'enable', repo['plugin']['id'], '--scope', 'user'])
            if not self.native_ok(repo, source):
                raise Failure('Claude plugin verification failed: ' + repo['plugin']['id'])
        if not self.args.check:
            self.legacy(repo, 'claude', disable=True)
            for name in repo['skills']:
                self.backup(self.destination('claude', name))
        self.legacy(repo, 'claude')
        for name in repo['skills']:
            path = self.destination('claude', name)
            if path.exists() or path.is_symlink():
                raise Failure('duplicate standalone Claude skill: ' + str(path))

    def binary(self, spec):
        name = spec['name']
        if not shutil.which(spec['command'][0]):
            print('==> {}: binary not on PATH; skipped'.format(name))
            return
        for agent in self.agents:
            if agent not in spec['agents']:
                continue
            dest = self.destination(agent, name) / 'SKILL.md'
            key = agent + '/' + name
            version = run([spec['command'][0], '--version'], capture=True).strip()
            record = self.state.get(key, {})
            same = (dest.is_file() and hashlib.sha256(dest.read_bytes()).hexdigest() == record.get('sha256')
                    and version == record.get('binary_version')
                    and record.get('fallback_ref') == spec['fallback_ref'])
            if self.args.check:
                if not same:
                    raise Failure('binary skill missing, changed, or unrecorded: ' + str(dest))
                print('    OK {} {}'.format(agent, name))
                continue
            if same:
                print('    OK {} {} (unchanged)'.format(agent, name))
                continue
            result = subprocess.run(spec['command'], stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if result.returncode == 0 and result.stdout.strip():
                content, origin = result.stdout, 'binary'
            else:
                content = run(['curl', '-fsSL', spec['fallback_url']], capture=True).encode()
                origin = spec['fallback_ref']
            if not content.startswith(b'---\n') or b'\nname:' not in content:
                raise Failure('invalid skill output for ' + name)
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists() and dest.read_bytes() != content:
                self.backup(dest, move=False)
            with tempfile.NamedTemporaryFile(dir=dest.parent, delete=False) as f:
                f.write(content)
            os.replace(f.name, dest)
            self.state[key] = {'sha256': hashlib.sha256(content).hexdigest(),
                               'source': origin, 'binary_version': version,
                               'fallback_ref': spec['fallback_ref']}
            save(self.state_path, self.state)
            print('    OK {} {} ({})'.format(agent, name, origin))

    def propose(self):
        matches = [r for r in self.data['repos'] if r['dir'] == self.args.propose_update]
        if len(matches) != 1 or not self.args.ref:
            raise Failure('usage: skills-update SOURCE --ref TAG_OR_BRANCH')
        repo = matches[0]
        refs = [self.args.ref]
        if not self.args.ref.startswith('refs/') and self.args.ref != 'HEAD':
            refs += ['refs/heads/' + self.args.ref, 'refs/tags/' + self.args.ref]
        output = run(['git', 'ls-remote', repo['url'], *refs,
                      *(ref + '^{}' for ref in refs)], capture=True)
        resolved = {ref: sha for sha, ref in (line.split() for line in output.splitlines())}
        candidates = {resolved.get(ref + '^{}', sha) for ref, sha in resolved.items()
                      if not ref.endswith('^{}')}
        if len(candidates) != 1:
            raise Failure('ref missing or ambiguous; use an exact refs/heads/... or refs/tags/... name')
        new = candidates.pop()
        print('Current pin: ' + repo['pin'])
        print('Proposed pin: ' + new)
        print('Review: {}/compare/{}...{}'.format(repo['url'].removesuffix('.git'), repo['pin'], new))
        print('After review, edit pin and plugin version in ' + str(self.sources))
        print('No manifest or installed skills changed.')

    def execute(self):
        if self.args.propose_update:
            self.propose()
            return 0
        if not self.agents:
            print('No supported agent on PATH; skipped')
            return 0
        for repo in self.data['repos']:
            if repo.get('enabled') is False:
                continue
            targets = [a for a in self.agents if a in repo['targets']]
            if self.args.dry_run:
                for agent in targets:
                    print('{}: {} {} at {}'.format(agent, repo['targets'][agent], repo['dir'], repo['pin']))
                continue
            if not targets:
                continue
            try:
                source = self.source(repo)
            except (Failure, OSError) as exc:
                self.errors.append(str(exc))
                continue
            for agent in targets:
                try:
                    print('==> {}: {} ({})'.format(agent, repo['dir'], repo['targets'][agent]))
                    if repo['targets'][agent] == 'skills':
                        self.generic(repo, source, agent)
                    else:
                        self.native(repo, source)
                    print('    OK: verified ' + repo['pin'])
                except (Failure, OSError) as exc:
                    self.errors.append('{} {}: {}'.format(agent, repo['dir'], exc))
        for spec in self.data.get('binary_skills', []):
            if self.args.dry_run:
                print('binary skill: ' + spec['name'])
                continue
            try:
                self.binary(spec)
            except (Failure, OSError) as exc:
                self.errors.append(str(exc))
        for error in self.errors:
            print('ERROR: ' + error, file=sys.stderr)
        return 1 if self.errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true', help='verify only; do not install or fetch')
    mode.add_argument('-n', '--dry-run', action='store_true', help='print the declared plan')
    mode.add_argument('--propose-update', metavar='SOURCE')
    parser.add_argument('--ref', help='tag or branch for an update proposal')
    try:
        return Manager(parser.parse_args()).execute()
    except (Failure, OSError, ValueError, KeyError) as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
