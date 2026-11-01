#!/usr/bin/env python3
"""Exercise legacy parent-link migration in disposable homes and repositories."""
import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import socket
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'scripts/lib/dotfiles.sh'
spec = importlib.util.spec_from_file_location('migration', ROOT / 'scripts/lib/migrate-config.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


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


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='dotfiles-config-migration-')
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
        self.git('init', '-q')
        self.git('config', 'user.name', 'Migration Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'core.hooksPath', '/dev/null')
        self.git('config', 'commit.gpgsign', 'false')
        self.git('add', '--', *self.paths)
        self.git('commit', '-qm', 'Initial fixture')
        for name in ('gh/hosts.yml', 'nvim/local-only.lua', 'personal/settings.json', 'herdr/runtime.log'):
            path = self.repo / '.config' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('private fixture\n')
            path.chmod(0o600)
        (self.repo / ".config/personal").chmod(0o700)
        (self.repo / 'external.txt').write_text('external target\n')
        (self.repo / '.config/personal/relative').symlink_to('../../external.txt')
        self.data = self.home / 'data'

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

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
                    self.assertFalse(destination.is_symlink())
                    self.assertEqual(signature(self.repo), before)
                    self.assertEqual(self.git('status', '--porcelain', '--untracked-files=no'), '')
                    for path in self.paths:
                        self.assertEqual(os.readlink(self.home / path), str(self.data / 'dotfiles/current' / path))
                    for name in ('gh/hosts.yml', 'personal/settings.json', 'herdr/runtime.log'):
                        self.assertEqual((destination / name).read_text(), 'private fixture\n')
                        self.assertEqual(stat.S_IMODE((destination / name).stat().st_mode), 0o600)
                    self.assertEqual((destination / 'personal/relative').read_text(), 'external target\n')
                    self.assertEqual(stat.S_IMODE((destination / 'personal').stat().st_mode), 0o700)
                    backups = list(destination.glob('nvim.backup-*/original/local-only.lua'))
                    self.assertEqual(len(backups), 1)
                    self.assertEqual(backups[0].read_text(), 'private fixture\n')
                    self.assertFalse((destination / 'nvim/local-only.lua').exists())
                    original = [p / 'original' for p in self.home.glob('.config.backup-*')]
                    self.assertEqual(len(original), 1)
                    self.assertEqual(os.readlink(original[0]), value)
                    backup_names = sorted(str(p) for p in self.home.rglob('*.backup-*'))
                    self.assert_success(self.shell('deploy_dotfiles', force))
                    self.assertEqual(sorted(str(p) for p in self.home.rglob('*.backup-*')), backup_names)
                    # Editing the checkout cannot change the deployed config.
                    (source / 'nvim/init.txt').write_text('changed checkout\n')
                    self.assertEqual((destination / 'nvim/init.txt').read_text(), 'committed config\n')
                    (source / 'nvim/init.txt').write_text('committed config\n')
                    self.assert_success(self.shell('remove_symlinks', root=self.data / 'dotfiles/current'))
                    self.assertFalse((destination / 'nvim').exists())
                    self.assertEqual((destination / 'gh/hosts.yml').read_text(), 'private fixture\n')
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

    def test_special_files_abort_before_switching_any_live_link(self):
        (self.home / '.config').symlink_to(self.repo / '.config')
        os.mkfifo(self.repo / '.config/live-pipe')
        old = self.root / 'old-release'
        old.mkdir()
        current = self.data / 'dotfiles/current'
        current.parent.mkdir(parents=True)
        current.symlink_to(old)
        before = signature(self.repo)
        result = self.shell('deploy_dotfiles', force=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Stop the owning service', result.stderr)
        self.assertTrue((self.home / '.config').is_symlink())
        self.assertEqual(current.resolve(), old)
        self.assertEqual(list((self.data / 'dotfiles/releases').iterdir()), [])
        self.assertFalse((self.home / '.zshrc').exists())
        self.assertEqual(signature(self.repo), before)

    def test_live_unix_socket_aborts_without_stopping_its_owner(self):
        (self.home / '.config').symlink_to(self.repo / '.config')
        previous = Path.cwd()
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as service:
            try:
                os.chdir(self.repo / '.config')
                # Use a relative path to avoid sockaddr path-length limits on macOS.
                try:
                    service.bind('live.sock')
                except PermissionError:
                    self.skipTest('This sandbox does not permit binding a Unix socket')
                service.listen(1)
            finally:
                os.chdir(previous)
            before = signature(self.repo)
            result = self.shell('deploy_dotfiles', force=1)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('live.sock', result.stderr)
            self.assertTrue((self.home / '.config').is_symlink())
            self.assertEqual(signature(self.repo), before)
            self.assertGreaterEqual(service.fileno(), 0)
            self.assertEqual(list(self.home.glob('.config.backup-*')), [])

    def test_copy_failure_leaves_original_link_and_no_backup(self):
        destination = self.home / '.config'
        destination.symlink_to(self.repo / '.config')
        before = signature(self.repo)
        with patch.object(shutil, 'copytree', side_effect=OSError('simulated disk full')):
            with self.assertRaises(OSError):
                migration.migrate(self.repo, self.home, self.root / 'snapshot', self.paths)
        self.assertTrue(destination.is_symlink())
        self.assertEqual(list(self.home.glob('.config.backup-*')), [])
        self.assertEqual(list(self.home.glob('.config-migration.*')), [])
        self.assertEqual(signature(self.repo), before)

    def test_failed_final_rename_restores_original_link(self):
        destination = self.home / '.config'
        destination.symlink_to(self.repo / '.config')
        before = signature(self.repo)
        rename = Path.rename

        def fail_publish(path, target):
            if path.name == 'config' and path.parent.name.startswith('.config-migration.'):
                raise OSError('simulated publish failure')
            return rename(path, target)

        with patch.object(Path, 'rename', fail_publish):
            with self.assertRaises(OSError):
                migration.migrate(self.repo, self.home, self.root / 'snapshot', self.paths)
        self.assertTrue(destination.is_symlink())
        self.assertEqual(destination.resolve(), self.repo / '.config')
        self.assertEqual(list(self.home.glob('.config.backup-*')), [])
        self.assertEqual(signature(self.repo), before)


if __name__ == '__main__':
    unittest.main()
