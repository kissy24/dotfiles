#!/usr/bin/env python3
"""Preserve parent links and live runtime state while updating direct config links."""
import hashlib
import os
from pathlib import Path
import socket
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'scripts/lib/dotfiles.sh'


def signature(root):
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        if Path(directory) == root and ".git" in dirs:
            dirs.remove(".git")
        for name in dirs + files:
            item = Path(directory) / name
            mode = item.lstat().st_mode
            content = None
            if item.is_symlink():
                content = os.readlink(item)
            elif stat.S_ISREG(mode):
                content = hashlib.sha256(item.read_bytes()).hexdigest()
            result[str(item.relative_to(root))] = (mode, content)
    return result


class ParentLinkTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='dotfiles-parent-links-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.repo = self.root / 'repo with spaces'
        self.home = self.root / 'home with spaces'
        self.repo.mkdir()
        self.home.mkdir()
        self.paths = subprocess.check_output(['bash', '-c', 'source "$1"; managed_dotfile_paths', '_', str(LIB)], text=True).splitlines()
        for name in self.paths:
            path = self.repo / name
            if name in {'.config/nvim', '.config/wezterm', '.config/sheldon', '.config/lazygit'}:
                path = path / 'init.txt'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('committed config\n')
        for name in ('gh/hosts.yml', 'nvim/local-only.lua', 'personal/settings.json', 'herdr/runtime.log'):
            path = self.repo / '.config' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('private fixture\n')
            path.chmod(0o600)
        (self.repo / ".config/personal").chmod(0o700)
        (self.repo / 'external.txt').write_text('external target\n')
        (self.repo / '.config/personal/relative').symlink_to('../../external.txt')
        self.data = self.home / 'data'

    def shell(self, function, force=0, root=None):
        env = dict(os.environ, XDG_DATA_HOME=str(self.data), PYTHONDONTWRITEBYTECODE='1')
        return subprocess.run(['bash', '-c', 'set -euo pipefail; source "$1"; "$2" "$3" "$4" "$5"',
                               '_', str(LIB), function, str(root or self.repo), str(self.home), str(force)],
                              env=env, text=True, capture_output=True)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_absolute_trailing_and_relative_links_with_and_without_force(self):
        for spelling in ('absolute', 'trailing', 'relative'):
            for force in (0, 1):
                with self.subTest(spelling=spelling, force=force):
                    self.home = self.root / (spelling + str(force))
                    self.home.mkdir()
                    self.data = self.home / 'data'
                    source = self.repo / '.config'
                    value = str(source)
                    if spelling == 'trailing':
                        value += '/'
                    elif spelling == 'relative':
                        value = os.path.relpath(source, self.home)
                    destination = self.home / '.config'
                    destination.symlink_to(value)
                    before = signature(self.repo)
                    self.assert_success(self.shell('deploy_dotfiles', force))
                    self.assertTrue(destination.is_symlink())
                    self.assertEqual(os.readlink(destination), value)
                    self.assertEqual(signature(self.repo), before)
                    self.assertFalse(self.data.exists())
                    self.assertEqual(list(self.home.glob('.config.backup-*')), [])
                    for path in self.paths:
                        self.assertTrue((self.home / path).samefile(self.repo / path))
                    self.assert_success(self.shell('deploy_dotfiles', force))
                    self.assertEqual(signature(self.repo), before)
                    (source / 'nvim/init.txt').write_text('changed checkout\n')
                    self.assertEqual((destination / 'nvim/init.txt').read_text(), 'changed checkout\n')
                    (source / 'nvim/init.txt').write_text('committed config\n')
                    self.assert_success(self.shell('remove_symlinks'))
                    self.assertTrue(destination.is_symlink())
                    self.assertEqual(signature(self.repo), before)

    def test_unmigrated_uninstall_does_not_write_through_parent(self):
        (self.home / '.config').symlink_to(str(self.repo / '.config') + '/')
        (self.repo / '.config/starship.toml').unlink()
        (self.repo / '.config/starship.toml').symlink_to(self.repo / '.config/nvim/init.txt')
        before = signature(self.repo)
        self.assert_success(self.shell('remove_symlinks'))
        self.assertEqual(signature(self.repo), before)
        self.assertTrue((self.home / '.config').is_symlink())

    def test_unrelated_and_nested_parent_links_are_never_followed(self):
        for parent in ('.config', '.config/herdr', '.config/gh', '.local/bin'):
            with self.subTest(parent=parent):
                self.home = self.root / parent.replace('/', '_')
                self.home.mkdir()
                external = self.root / ('external' + parent.replace('/', '_'))
                external.mkdir()
                (external / 'sentinel').write_text('unmanaged\n')
                target = self.home / parent
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(external)
                before = signature(external)
                self.assert_success(self.shell('create_symlinks', force=1))
                self.assert_success(self.shell('remove_symlinks'))
                self.assertEqual(signature(external), before)
                self.assertTrue(target.is_symlink())

    def test_live_runtime_survives_deploy_and_uninstall(self):
        destination = self.home / '.config'
        destination.symlink_to(self.repo / '.config')
        herdr = self.repo / '.config/herdr'
        named = herdr / 'sessions/test'
        named.mkdir(parents=True)
        os.mkfifo(herdr / 'runtime-pipe')
        previous = Path.cwd()
        self.addCleanup(os.chdir, previous)
        # Keep socket paths short enough for macOS, but resolve through ~/.config.
        os.chdir(self.home)
        for path in ('.config/herdr/herdr.sock', '.config/herdr/sessions/test/herdr.sock'):
            with self.subTest(path=path), socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as service:
                service.bind(path)
                service.listen(2)
                service.settimeout(3)
                endpoint = Path(path).stat()
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                    client.settimeout(3)
                    client.connect(path)
                    peer, _ = service.accept()
                    with peer, (herdr / 'runtime.log').open('a') as log:
                        peer.settimeout(3)
                        for function in ('deploy_dotfiles', 'deploy_dotfiles', 'remove_symlinks'):
                            before = signature(self.repo)
                            self.assert_success(self.shell(function, force=1))
                            self.assertEqual(signature(self.repo), before)
                            after = Path(path).stat()
                            self.assertEqual((after.st_dev, after.st_ino), (endpoint.st_dev, endpoint.st_ino))
                            client.sendall(b'live')
                            self.assertEqual(peer.recv(4), b'live')
                            # Reconnection also uses the same listening endpoint.
                            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as reconnect:
                                reconnect.settimeout(3)
                                reconnect.connect(path)
                                accepted, _ = service.accept()
                                accepted.close()
                            log.write('still writing\n')
                            log.flush()
                            self.assertIn('still writing', (destination / 'herdr/runtime.log').read_text())
                            # Atomic state replacement and new session files stay visible.
                            state = herdr / 'session.tmp'
                            state.write_text(function)
                            state.replace(herdr / 'session.json')
                            self.assertEqual((destination / 'herdr/session.json').read_text(), function)
                            self.assertEqual(stat.S_IMODE((destination / 'herdr/runtime.log').stat().st_mode), 0o600)
                            self.assertTrue(destination.is_symlink())
                            self.assertEqual(list(self.home.glob('.config.backup-*')), [])


if __name__ == '__main__':
    unittest.main()
