#!/usr/bin/env python3
"""Detach a legacy ~/.config -> this checkout link without changing its source."""
import datetime
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile


def migrate(repo_root, target_home, link_root, managed):
    destination = target_home / '.config'
    source = repo_root / '.config'
    if not destination.is_symlink() or not source.is_dir():
        return
    if destination.resolve() != source.resolve():
        return
    source = source.resolve()
    original_link = os.readlink(destination)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')

    # Detect sockets/FIFOs before copying; they represent live state, not files.
    for directory, dirs, files in os.walk(source, followlinks=False):
        for name in dirs + files:
            item = Path(directory) / name
            mode = item.lstat().st_mode
            if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode) or stat.S_ISLNK(mode)):
                raise ValueError('Cannot migrate special file: ' + str(item)
                                 + '. Stop the owning service and remove stale endpoints before retrying.')

    with tempfile.TemporaryDirectory(prefix='.config-migration.', dir=target_home) as temporary:
        staged = Path(temporary) / 'config'
        shutil.copytree(source, staged, symlinks=True, copy_function=shutil.copy2)
        # Relative links were resolved relative to the checkout's physical path.
        # Preserve their original referents after moving the copied directory.
        for directory, dirs, files in os.walk(staged, followlinks=False):
            for name in dirs + files:
                item = Path(directory) / name
                if item.is_symlink():
                    value = os.readlink(item)
                    if not os.path.isabs(value):
                        old_parent = source / item.relative_to(staged).parent
                        item.unlink()
                        item.symlink_to(os.path.normpath(old_parent / value))

        backups = []
        for path in managed:
            if not path.startswith('.config/'):
                continue
            relative = Path(path).relative_to('.config')
            target = staged / relative
            # Never follow a nested user-managed directory link while replacing.
            if any((staged / parent).is_symlink() for parent in relative.parents):
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() or target.is_symlink():
                backup = Path(tempfile.mkdtemp(prefix=target.name + '.backup-' + stamp + '.',
                                               dir=target.parent)) / 'original'
                target.rename(backup)
                backups.append(destination / backup.relative_to(staged))
            target.symlink_to(link_root / path)

        # Refuse to replace a path changed by another process during the copy.
        if not destination.is_symlink() or os.readlink(destination) != original_link:
            raise ValueError('The .config link changed during migration; retry after stopping other writers.')
        backup_dir = Path(tempfile.mkdtemp(prefix='.config.backup-' + stamp + '.', dir=target_home))
        original = backup_dir / 'original'
        destination.rename(original)  # Move only the link, never the source directory.
        try:
            staged.rename(destination)
        except OSError:
            if not os.path.lexists(destination):
                original.rename(destination)
                backup_dir.rmdir()
            raise
        print('- Backed up legacy .config link: ' + str(original))
        for backup in backups:
            print('- Preserved copied config: ' + str(backup))
        print('- Migrated legacy .config directory link: ' + str(destination))


if __name__ == '__main__':
    try:
        migrate(*(Path(arg).absolute() for arg in sys.argv[1:4]), sys.argv[4:])
    except (OSError, ValueError) as error:
        print('Error: .config migration aborted: ' + str(error), file=sys.stderr)
        sys.exit(1)
