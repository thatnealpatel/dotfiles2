#!/usr/bin/env python3
"""Hermetic entrypoint tests; no downloads, installs, sudo or service changes.
Run: python3 .bootstrap/test/platform_test.py
Requires Python 3.11+ (tomllib).
Uses real bash and basic text/file utilities, with command mocks on an isolated
PATH. This tests composition, not native macOS/Linux installation success.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which("bash")
GIT = shutil.which("git")
JJ = shutil.which("jj")
ZSH = shutil.which("zsh")

# One dispatcher keeps mocks strict: an unexpected invocation fails the test.
MOCK = r'''import json, os, pathlib, shutil, subprocess, sys
p = pathlib.Path
cmd, args = p(sys.argv[0]).name, sys.argv[1:]
home = p(os.environ['HOME'])
with open(os.environ['MOCK_LOG'], 'a') as f:
    f.write(json.dumps([cmd, *args]) + '\n')
def executable(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/bin/bash\n' + text + '\n')
    path.chmod(0o755)
def binary(path, version):
    executable(path, 'printf "%s\\n" ' + repr(version))
if cmd == 'uname':
    print(os.environ['MOCK_OS'] if args == ['-s'] else os.environ['MOCK_ARCH'])
elif cmd == 'id':
    print('tester' if args == ['-un'] else ('501' if os.environ['MOCK_OS'] == 'Darwin' else '0'))
elif cmd == 'xcode-select':
    sys.exit(int(os.environ.get('MOCK_NO_CLT', '0')))
elif cmd == 'brew':
    assert os.environ['PATH'].startswith('/opt/homebrew/bin:/opt/homebrew/sbin:'), os.environ['PATH']
    if args[0] == 'install':
        assert 'watchman' not in args
        if 'tailscale' in args:
            (p(os.environ['MOCK_BIN']) / 'tailscale').symlink_to(p(os.environ['MOCK_BIN']) / 'dispatch')
    elif args == ['services', 'start', 'tailscale']:
        if os.environ.get('MOCK_SERVICE_FAIL') == '1': sys.exit(1)
        (home / 'service-ready').touch()
    else: raise AssertionError(args)
elif cmd == 'sudo':
    assert args[0] in ('-v', '-n') or p(args[0]).name in ('brew', 'tailscale', 'tee', 'chsh'), args
    if args[0] not in ('-v', '-n'): sys.exit(subprocess.call(args))
elif cmd == 'git':
    if args[:1] == ['config']:
        sys.exit(subprocess.call([os.environ['REAL_GIT'], *args]))
    if args[0].startswith('--git-dir='):
        a = args[2:]
        if a[0] == 'checkout':
            shutil.copytree(p(os.environ['SOURCE']) / '.bootstrap', home / '.bootstrap', dirs_exist_ok=True)
            shutil.copytree(p(os.environ['SOURCE']) / '.config', home / '.config', dirs_exist_ok=True)
        elif a[0] == 'ls-tree' and 'HEAD' in a: print('.bootstrap')
        else: assert a[0] in ('config', 'fetch', 'branch', 'ls-tree'), a
    elif args[0] == 'clone':
        dest = p(args[-1]); dest.mkdir(parents=True, exist_ok=True)
        if '--bare' not in args: (dest / '.git').mkdir(exist_ok=True)
        if 'https://go.googlesource.com/go' in args:
            executable(dest / 'src/make.bash', 'exec "$MOCK_BIN/build-go"')
    elif args[:1] == ['-C']:
        if args[2:] == ['rev-parse', 'HEAD']: print('abcdef123456')
        elif args[2:] == ['remote', 'get-url', 'fork']: sys.exit(1)
        else: assert args[2] in ('remote', 'fetch', 'reset'), args
    else: raise AssertionError(args)
elif cmd == 'dpkg-query':
    sys.exit(1)  # model a fresh install, not an already-provisioned host
elif cmd == 'apt-get':
    if 'tailscale' in args:
        (p(os.environ['MOCK_BIN']) / 'tailscale').symlink_to(p(os.environ['MOCK_BIN']) / 'dispatch')
elif cmd == 'curl':
    url = args[-1]
    if '-o' in args: p(args[args.index('-o') + 1]).write_text(url)
    else: print(url)
elif cmd == 'tar':
    url = sys.stdin.read().strip()
    dest = p(args[args.index('-C') + 1])
    if 'zoxide-' in url:
        assert args[-1] == 'zoxide'
        binary(dest / 'zoxide', 'zoxide 0.10.0')
    elif '/jj-' in url:
        assert args[-1] == './jj'
        binary(dest / 'jj', 'jj 0.45.1-test')
    elif 'go.dev/dl/' in url:
        assert '--strip-components=1' in args
        binary(dest / 'bin/go', 'go bootstrap')
        (dest / 'VERSION').write_text('go1.27.1\n')
    elif 'neovim/archive/' in url:
        src = dest / 'neovim-0.12.5'; src.mkdir(parents=True)
        (src / 'CMakeLists.txt').touch()
    else: raise AssertionError(url)
elif cmd == 'build-go':
    assert os.environ['GOROOT_BOOTSTRAP'] == str(home / 'd/go')
    binary(home / 'w/go/bin/go', 'go version devel test')
    binary(home / 'w/go/bin/gofmt', 'gofmt')
elif cmd == 'make':
    if args == ['install']:
        binary(home / '.local/nvim/v0.12.5/bin/nvim', 'NVIM v0.12.5')
    else:
        expected = '8' if os.environ['MOCK_OS'] == 'Darwin' else '4'
        assert '-j' + expected in args and 'CMAKE_BUILD_TYPE=Release' in args, args
elif cmd == 'sysctl':
    assert args == ['-n', 'hw.ncpu'] and os.environ['MOCK_OS'] == 'Darwin', args
    print('8')
elif cmd == 'nproc':
    assert os.environ['MOCK_OS'] == 'Linux'
    print('4')
elif cmd == 'dscl':
    assert args == ['.', '-read', '/Users/tester', 'UserShell']
    print('UserShell: /bin/bash')
elif cmd == 'getent':
    assert args == ['passwd', 'tester'] and os.environ['MOCK_OS'] == 'Linux'
    print('tester:x:1000:1000::/home/tester:/bin/bash')
elif cmd == 'chsh':
    assert args == ['-s', str(p(os.environ['MOCK_BIN']) / 'zsh'), 'tester'], args
elif cmd == 'tee':
    assert args[-1] in ('/etc/shells', '/usr/share/keyrings/tailscale-archive-keyring.gpg', '/etc/apt/sources.list.d/tailscale.list'), args
    sys.stdin.read()  # never write host files
elif cmd == 'install':
    assert args == ['-d', '-m', '0755', '/usr/share/keyrings'], args
elif cmd == 'readlink':
    assert len(args) == 1 and not args[0].startswith('-'), args
    print(os.readlink(args[0]))
elif cmd == 'tailscale':
    if args == ['status']:
        sys.exit(0 if (home / 'joined').exists() else 1)
    elif args == ['status', '--json']:
        sys.exit(0 if (home / 'service-ready').exists() else 1)
    elif args[0] == 'up':
        assert args == ['up', '--auth-key=test-only-key'], args
        (home / 'joined').touch()
    elif args == ['ip', '-4']: print('100.64.0.1')
    else: raise AssertionError(args)
else:
    raise AssertionError('forbidden command: ' + cmd + ' ' + repr(args))
'''


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="bootstrap-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'commands.jsonl'
        self.log.touch()
        dispatcher = self.bin / 'dispatch'
        dispatcher.write_text(f'#!{sys.executable}\n' + MOCK)
        dispatcher.chmod(0o755)
        tools = 'bash env mkdir mv rm dirname basename sed awk cut grep tr chmod cp ln cat date head tail'
        for tool in tools.split():
            (self.bin / tool).symlink_to(shutil.which(tool))
        mocks = ('uname id xcode-select brew sudo git dpkg-query apt-get curl tar build-go make '
                 'sysctl nproc dscl getent chsh tee install readlink zsh '
                 'systemctl tailscaled watchman unzip nohup sleep')
        for tool in mocks.split():
            (self.bin / tool).symlink_to(dispatcher)
        self.env = dict(HOME=str(self.home), PATH=str(self.bin), MOCK_BIN=str(self.bin),
                        MOCK_LOG=str(self.log), MOCK_OS='Linux', MOCK_ARCH='x86_64',
                        SOURCE=str(ROOT), REAL_GIT=GIT, GIT_CONFIG_NOSYSTEM='1', LC_ALL='C')

    def mac(self):
        self.env.update(MOCK_OS='Darwin', MOCK_ARCH='arm64')

    def run_script(self, args=(), stage=None, ok=True):
        if stage:
            cmd = [BASH, str(ROOT / '.bootstrap/stages' / stage), *args]
            source = None
        else:
            # Model curl | bash: no local lib.sh or checkout exists at startup.
            cmd = [BASH, '-s', '--', *args]
            source = (ROOT / '.bootstrap/bootstrap.sh').read_text()
        result = subprocess.run(cmd, input=source, env=self.env, text=True,
                                capture_output=True, cwd=self.home, timeout=20)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self, command=None):
        rows = [json.loads(line) for line in self.log.read_text().splitlines()]
        return [r for r in rows if command is None or r[0] == command]

    def identity(self, name, email):
        for key, value in [('name', name), ('email', email)]:
            out = subprocess.check_output([GIT, 'config', '--global', 'user.' + key],
                                          env=self.env, text=True).strip()
            self.assertEqual(out, value)
        config = self.home / '.config/jj/conf.d/99-bootstrap-user.toml'
        self.assertEqual(tomllib.loads(config.read_text())['user'], dict(name=name, email=email))
        if JJ:
            # Read real jj's effective user config without touching any repo.
            for key, value in [('name', name), ('email', email)]:
                out = subprocess.check_output([JJ, '--ignore-working-copy', 'config', 'get', 'user.' + key],
                                              env=self.env, cwd=self.home, text=True).strip()
                self.assertEqual(out, value)

    def test_missing_and_malformed_identity_before_mutations(self):
        for args in [[], ['--git-user'], ['--git-user='], ['--git-user=Nobody'],
                     ['--git-user= <a@b>'], ['--git-user=Name <>'],
                     ['--git-user=Name <a@b>\n'], ['--git-user=Name <a@b> extra']]:
            with self.subTest(args=args):
                self.run_script(args, ok=False)
                self.assertEqual(list(self.home.iterdir()), [])
                self.assertFalse(self.calls('git'))
                self.assertFalse(self.calls('brew'))
        self.run_script(['--help'])

    def test_unsupported_platforms_fail_before_side_effects(self):
        for os_name, arch in [('Linux', 'aarch64'), ('Darwin', 'x86_64'), ('FreeBSD', 'x86_64')]:
            self.env.update(MOCK_OS=os_name, MOCK_ARCH=arch)
            self.run_script(['--git-user=Test User <test@example.com>'], ok=False)
            self.run_script(stage='20-tmux.sh', ok=False)
            self.assertEqual(list(self.home.iterdir()), [])
            self.assertFalse(self.calls('git'))
            self.assertFalse(self.calls('apt-get'))
            self.assertFalse(self.calls('brew'))

    def test_mac_prerequisites_fail_before_checkout(self):
        self.mac()
        (self.bin / 'brew').unlink()
        # This hermetic test expects no native Homebrew installed on the test host.
        if Path('/opt/homebrew/bin/brew').exists():
            self.skipTest('native brew would be found by absolute PATH initialization')
        out = self.run_script(['--git-user=Test User <a@b>'], ok=False)
        self.assertIn('https://brew.sh', out.stderr)
        self.assertFalse(self.calls('git'))
        (self.bin / 'brew').symlink_to(self.bin / 'dispatch')
        self.env['MOCK_NO_CLT'] = '1'
        out = self.run_script(['--git-user=Test User <a@b>'], ok=False)
        self.assertIn('xcode-select --install', out.stderr)
        self.assertFalse(self.calls('git'))

    def test_streamed_linux_and_selected_tailscale_opt_out(self):
        self.run_script(['--git-user', 'A Person <person@example.com>', '--no-tailscale', '05-tailscale'])
        self.identity('A Person', 'person@example.com')
        self.assertTrue(self.calls('apt-get'))
        self.assertFalse(self.calls('brew'))
        self.assertFalse(self.calls('tailscale'))
        self.assertFalse(any('tailscale' in str(r) for r in self.calls('apt-get')))
        self.assertTrue((self.home / '.bootstrap/lib.sh').exists())

    def test_streamed_mac_composition_no_tailscale_or_watchman(self):
        self.mac()
        name = 'A "Quoted" \\ Person'
        self.run_script(['--git-user=' + name + ' <person@example.com>', '--no-tailscale'])
        self.identity(name, 'person@example.com')
        urls = '\n'.join(' '.join(r) for r in self.calls('curl'))
        self.assertIn('go1.27.1.darwin-arm64.tar.gz', urls)
        self.assertIn('jj-v0.45.1-aarch64-apple-darwin.tar.gz', urls)
        self.assertIn('zoxide-0.10.0-aarch64-apple-darwin.tar.gz', urls)
        self.assertIn('neovim/archive/refs/tags/v0.12.5.tar.gz', urls)
        for cmd in ['apt-get', 'dpkg-query', 'getent', 'systemctl', 'tailscaled', 'tailscale', 'nproc', 'watchman', 'unzip', 'nohup']:
            self.assertFalse(self.calls(cmd), cmd)
        self.assertEqual(self.calls('sysctl'), [['sysctl', '-n', 'hw.ncpu']])
        packages = str(self.calls('brew'))
        for package in ['cmake', 'ninja', 'gettext', 'pkgconf', 'opam']:
            self.assertIn(package, packages)
        self.assertNotIn('tailscale', packages)
        self.assertNotIn('watchman', packages)
        self.assertTrue(self.calls('build-go'))
        self.assertTrue(self.calls('dscl'))
        self.assertTrue(self.calls('chsh'))
        self.assertTrue((self.home / '.local/bin/nvim').is_symlink())

    def test_standalone_linux_downloads_and_source_builds(self):
        conf = self.home / '.config/zsh'
        conf.mkdir(parents=True)
        shutil.copy(ROOT / '.config/zsh/local.zsh.example', conf)
        for stage in ['10-zsh.sh', '15-jj.sh', '30-go.sh', '50-neovim.sh']:
            self.run_script(stage=stage)
        urls = str(self.calls('curl'))
        for asset in ['go1.27.1.linux-amd64.tar.gz', 'jj-v0.45.1-x86_64-unknown-linux-musl.tar.gz',
                      'zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz']:
            self.assertIn(asset, urls)
        self.assertTrue(self.calls('nproc'))
        self.assertTrue(self.calls('getent'))
        self.assertFalse(self.calls('brew'))
        self.assertFalse(self.calls('sysctl'))
        self.assertFalse(self.calls('watchman'))

    def test_standalone_skip_has_no_dependency_or_status_work(self):
        for os_name, arch in [('Linux', 'x86_64'), ('Darwin', 'arm64')]:
            self.env.update(MOCK_OS=os_name, MOCK_ARCH=arch, BOOTSTRAP_NO_TAILSCALE='1')
            self.run_script(stage='05-tailscale.sh')
        self.assertEqual(self.calls(), [])

    def test_mac_tailscale_fresh_service_auth_and_failure(self):
        self.mac()
        self.env['TS_AUTHKEY'] = 'test-only-key'
        result = self.run_script(stage='05-tailscale.sh')
        self.assertIn(['brew', 'install', 'tailscale'], self.calls('brew'))
        self.assertIn(['brew', 'services', 'start', 'tailscale'], self.calls('brew'))
        self.assertIn(['tailscale', 'up', '--auth-key=test-only-key'], self.calls('tailscale'))
        self.assertNotIn('test-only-key', result.stderr)
        for cmd in ['apt-get', 'systemctl', 'tailscaled', 'nohup']:
            self.assertFalse(self.calls(cmd))
        (self.home / 'joined').unlink()
        (self.bin / 'tailscale').unlink()
        self.env['MOCK_SERVICE_FAIL'] = '1'
        result = self.run_script(stage='05-tailscale.sh', ok=False)
        self.assertIn('could not start Tailscale', result.stderr)
        self.assertFalse(self.calls('tailscaled'))

    def test_linux_tailscale_fresh_apt_no_key(self):
        self.run_script(stage='05-tailscale.sh')
        self.assertIn(['apt-get', 'install', '-y', '-qq', '--no-install-recommends', 'tailscale'], self.calls('apt-get'))
        self.assertIn('pkgs.tailscale.com/stable/', str(self.calls('curl')))
        self.assertFalse(self.calls('brew'))
        self.assertFalse(self.calls('tailscaled'))

    def test_selected_mac_tailscale_opt_out(self):
        self.mac()
        self.run_script(['--git-user=Test User <test@example.com>', '--no-tailscale', '05-tailscale'])
        self.assertTrue(self.calls('brew'))
        self.assertFalse(any('tailscale' in str(r) for r in self.calls('brew')))
        self.assertFalse(self.calls('tailscale'))
        self.assertFalse(self.calls('apt-get'))

    def test_identity_preserves_unrelated_and_legacy_config(self):
        (self.home / '.gitconfig').write_text('[alias]\n  st = status\n[user]\n  name = Old Name\n  email = old@example.com\n')
        legacy = self.home / '.jjconfig.toml'
        original = '[user]\nname = "Old Name"\nemail = "old@example.com"\n[ui]\ncolor = "never"\n'
        legacy.write_text(original)
        self.run_script(['--git-user=New Person <new@example.com>', '--no-tailscale', '20-tmux'])
        self.identity('New Person', 'new@example.com')
        self.assertEqual(legacy.read_text(), original)
        alias = subprocess.check_output([GIT, 'config', '--global', 'alias.st'], env=self.env, text=True)
        self.assertEqual(alias.strip(), 'status')
        # A rerun does not require the jj stage or replace unrelated settings.
        self.run_script(['--git-user', 'Another Person <another@example.com>', '--no-tailscale', '20-tmux'])
        self.identity('Another Person', 'another@example.com')

    def test_interactive_mac_path_and_ls(self):
        if not ZSH:
            self.skipTest('zsh not installed')
        for ostype, expected in [('darwin23.0', 'ls -G'), ('linux-gnu', 'ls --color=auto')]:
            code = ('OSTYPE=' + ostype + '; source "$SOURCE/.config/zsh/path.zsh"; '
                    'source "$SOURCE/.config/zsh/aliases.zsh"; print -r -- "$PATH"; alias ls')
            result = subprocess.run([ZSH, '-fc', code], env=self.env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = result.stdout.splitlines()
            self.assertIn(expected, lines[1])
            path = lines[0].split(':')
            self.assertEqual(path[:2], [str(self.home / 'bin'), str(self.home / '.local/bin')])
            if ostype.startswith('darwin'):
                self.assertEqual(path[2:4], ['/opt/homebrew/bin', '/opt/homebrew/sbin'])
            else:
                self.assertNotIn('/opt/homebrew/bin', path)

    def test_portable_symlink_migration(self):
        self.mac()
        target = self.home / '.local/nvim/v0.12.5/bin/nvim'
        target.parent.mkdir(parents=True)
        target.write_text('managed')
        (self.home / 'bin').mkdir()
        (self.home / 'bin/indirect').symlink_to('../.local/nvim/v0.12.5/bin/nvim')
        (self.home / 'bin/nvim').symlink_to('indirect')
        self.run_script(['--git-user=Test User <test@example.com>', '--no-tailscale', '-migrate', '05-tailscale'])
        self.assertTrue((self.home / 'bin/nvim').is_symlink())
        self.assertTrue(self.calls('readlink'))
        self.assertFalse((self.home / '.dotfiles-backup').exists())

    def test_tracked_jj_has_no_identity_or_fsmonitor(self):
        config = tomllib.loads((ROOT / '.config/jj/config.toml').read_text())
        self.assertNotIn('user', config)
        self.assertNotIn('fsmonitor', config)


if __name__ == '__main__':
    unittest.main(verbosity=2)
