"""Installer integration checks; all writes stay in temporary directories.

Run with: python3 -B -m unittest discover -s tests -v
"""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'install.sh'
SKILL = ROOT / 'skills/suggest-commit/SKILL.md'
COMMAND = ROOT / 'commands/suggest-commit.md'


class TerminalProcess:
    def __init__(self, argv, env, cwd, script_input=None):
        self.master, self.slave = pty.openpty()
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 100, 0, 0))
        self.before = termios.tcgetattr(self.slave)
        self.output = b''

        def attach():
            os.setsid()
            fcntl.ioctl(self.slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen(
            argv, env=env, cwd=cwd, stdin=subprocess.PIPE if script_input else self.slave,
            stdout=self.slave, stderr=self.slave, preexec_fn=attach,
        )
        if script_input:
            self.process.stdin.write(script_input)
            self.process.stdin.close()

    def read_until(self, marker, timeout=8):
        deadline = time.monotonic() + timeout
        start = len(self.output)
        while marker not in self.output[start:]:
            if time.monotonic() >= deadline:
                raise AssertionError(f'Missing {marker!r}: {self.output!r}')
            ready, _, _ = select.select([self.master], [], [], .1)
            if ready:
                try:
                    data = os.read(self.master, 65536)
                except OSError as exc:
                    if exc.errno != errno.EIO:
                        raise
                    data = b''
                if data:
                    self.output += data
                elif self.process.poll() is not None:
                    break
            elif self.process.poll() is not None:
                break
        if marker not in self.output[start:]:
            raise AssertionError(f'Missing {marker!r}: {self.output!r}')

    def send(self, data):
        os.write(self.master, data)

    def finish(self):
        code = self.process.wait(timeout=8)
        assert termios.tcgetattr(self.slave) == self.before, 'Terminal settings were not restored'
        return code

    def close(self):
        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGKILL)
            self.process.wait()
        os.close(self.master)
        os.close(self.slave)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='suggest-commit-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.user_dir = self.base / 'user'
        self.user_dir.mkdir()
        self.env = dict(os.environ, HOME=str(self.user_dir), TERM='xterm',
                        XDG_CONFIG_HOME=str(self.base / 'xdg'))
        self.codex = self.user_dir / '.agents/skills/suggest-commit/SKILL.md'
        self.opencode = self.base / 'xdg/opencode/skills/suggest-commit/SKILL.md'
        self.command = self.base / 'xdg/opencode/commands/suggest-commit.md'

    def run_install(self, *args, script=SCRIPT, env=None, input=None):
        # New session ensures there is no controlling terminal.
        return subprocess.run(['sh', str(script), *args], cwd=self.base,
                              env=env or self.env, input=input, capture_output=True,
                              start_new_session=True, timeout=10)

    def terminal(self, *args, env=None, piped=False):
        proc = TerminalProcess(['sh', '-s', '--', *args] if piped else
                               ['sh', str(SCRIPT), *args], env or self.env, self.base,
                               SCRIPT.read_bytes() if piped else None)
        self.addCleanup(proc.close)
        return proc

    def assert_targets(self, codex, opencode):
        self.assertEqual(self.codex.exists(), codex)
        self.assertEqual(self.opencode.exists(), opencode)
        self.assertEqual(self.command.exists(), opencode)
        for path in (self.codex, self.opencode):
            if path.exists():
                self.assertEqual(path.read_bytes(), SKILL.read_bytes())
        if self.command.exists():
            self.assertEqual(self.command.read_bytes(), COMMAND.read_bytes())

    def test_local_targets_and_idempotence(self):
        for target in ('codex', 'opencode', 'both'):
            with self.subTest(target=target):
                # Use a separate home/config for each target.
                self.env['HOME'] = str(self.base / target)
                self.env['XDG_CONFIG_HOME'] = str(self.base / (target + '-config'))
                result = self.run_install('--target', target)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = []
                if target in ('codex', 'both'):
                    expected.append(Path(self.env['HOME']) / '.agents/skills/suggest-commit/SKILL.md')
                if target in ('opencode', 'both'):
                    expected.append(Path(self.env['XDG_CONFIG_HOME']) / 'opencode/skills/suggest-commit/SKILL.md')
                    self.assertTrue((Path(self.env['XDG_CONFIG_HOME']) / 'opencode/commands/suggest-commit.md').exists())
                for path in expected:
                    self.assertEqual(path.read_bytes(), SKILL.read_bytes())
                before = [path.stat().st_mtime_ns for path in expected]
                result = self.run_install('--target', target)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(before, [path.stat().st_mtime_ns for path in expected])
                if target == 'codex':
                    self.assertFalse(Path(self.env['XDG_CONFIG_HOME']).exists())
                if target == 'opencode':
                    self.assertFalse(Path(self.env['HOME']).exists())

    def test_unattended_default_and_xdg_default(self):
        self.env.pop('XDG_CONFIG_HOME')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.codex.exists())
        self.assertEqual((self.user_dir / '.config/opencode/skills/suggest-commit/SKILL.md').read_bytes(), SKILL.read_bytes())

    def test_invalid_input_has_no_side_effects(self):
        for args in (('--target', 'unknown'), ('--target',), ('--oops',),
                     ('--target', 'codex', '--target', 'both')):
            result = self.run_install(*args)
            self.assertEqual(result.returncode, 2)
            self.assertIn(b'Usage:', result.stderr)
            self.assert_targets(False, False)

    def test_partial_success_and_noninteractive_overwrite_refusal(self):
        self.opencode.parent.mkdir(parents=True)
        self.opencode.write_text('keep me')
        result = self.run_install('--target', 'both')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.codex.read_bytes(), SKILL.read_bytes())
        self.assertEqual(self.opencode.read_text(), 'keep me')
        self.assertEqual(self.command.read_bytes(), COMMAND.read_bytes())
        self.assertIn(b'Installed: 2; unchanged: 0; skipped: 0; failed: 1.', result.stdout)

    def remote_script(self, target):
        # file:// exercises real curl with no network or server dependency.
        remote = self.base / 'remote'
        (remote / 'skills/suggest-commit').mkdir(parents=True, exist_ok=True)
        (remote / 'skills/suggest-commit/SKILL.md').write_bytes(SKILL.read_bytes())
        if target != 'codex':
            (remote / 'commands').mkdir(exist_ok=True)
            (remote / 'commands/suggest-commit.md').write_bytes(COMMAND.read_bytes())
        bootstrap = self.base / 'bootstrap'
        bootstrap.mkdir(exist_ok=True)
        script = bootstrap / 'install.sh'
        script.write_bytes(SCRIPT.read_bytes())
        return script, dict(self.env, BASE_URL=remote.as_uri())

    def test_remote_codex_does_not_need_command_source(self):
        script, env = self.remote_script('codex')
        result = self.run_install('--target', 'codex', script=script, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_targets(True, False)

    def test_remote_opencode_and_both(self):
        script, env = self.remote_script('both')
        for target in ('opencode', 'both'):
            result = self.run_install('--target', target, script=script, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_targets(True, True)

    def test_local_codex_does_not_need_command_source(self):
        clone = self.base / 'minimal'
        (clone / 'skills/suggest-commit').mkdir(parents=True)
        (clone / 'install.sh').write_bytes(SCRIPT.read_bytes())
        (clone / 'skills/suggest-commit/SKILL.md').write_bytes(SKILL.read_bytes())
        result = self.run_install('--target', 'codex', script=clone / 'install.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_targets(True, False)

    def test_checkbox_both_and_terminal_restoration(self):
        proc = self.terminal()
        proc.read_until(b'q Cancel')
        proc.send(b' \r')  # Codex toggled on; OpenCode already selected.
        proc.read_until(b'Installed: 3;')
        self.assertEqual(proc.finish(), 0)
        self.assertIn(b'\x1b[?25h', proc.output)  # Cursor made visible.
        self.assert_targets(True, True)

    def test_navigation_and_empty_selection(self):
        proc = self.terminal()
        proc.read_until(b'q Cancel')
        proc.send(b'\x1b[B \r')  # Down to OpenCode, deselect, reject empty Enter.
        proc.read_until(b'Select at least one target.')
        self.assert_targets(False, False)
        proc.send(b'\x1b[A \r')  # Up to Codex, select it, confirm.
        proc.read_until(b'Installed: 1;')
        self.assertEqual(proc.finish(), 0)
        self.assert_targets(True, False)

    def test_numbered_fallback(self):
        proc = self.terminal(env=dict(self.env, TERM='dumb'))
        proc.read_until(b'Choose [2]')
        proc.send(b'0\n')
        proc.read_until(b'Choose 1, 2, or 3.')
        proc.send(b'3\n')
        proc.read_until(b'Installed: 3;')
        self.assertEqual(proc.finish(), 0)
        self.assert_targets(True, True)

    def test_cancellation_restores_terminal_without_fetch(self):
        for key in (b'q', b'\x1b', b'\x03'):
            with self.subTest(key=key):
                proc = self.terminal(piped=True, env=dict(self.env, BASE_URL='file:///nonexistent'))
                proc.read_until(b'q Cancel')
                proc.send(key)
                self.assertNotEqual(proc.finish(), 0)
                self.assert_targets(False, False)
                self.assertNotIn(b'Downloading', proc.output)
                # Drain the already finished child's remaining output.
                proc.read_until(b'\x1b[?25h')

    def test_handled_term_restores_terminal(self):
        proc = self.terminal()
        proc.read_until(b'q Cancel')
        os.killpg(proc.process.pid, signal.SIGTERM)
        self.assertEqual(proc.finish(), 143)
        self.assert_targets(False, False)

    def test_piped_menu_and_overwrite_confirmation(self):
        script, env = self.remote_script('codex')
        self.codex.parent.mkdir(parents=True)
        self.codex.write_text('old')
        proc = self.terminal(piped=True, env=env)
        proc.read_until(b'q Cancel')
        proc.send(b' \x1b[B \r')  # Enable Codex, disable OpenCode.
        proc.read_until(b'Overwrite ')
        proc.send(b'y\n')
        proc.read_until(b'Installed: 1;')
        self.assertEqual(proc.finish(), 0)
        self.assert_targets(True, False)

    def test_explicit_target_bypasses_menu_and_overwrite_can_skip(self):
        self.codex.parent.mkdir(parents=True)
        self.codex.write_text('old')
        proc = self.terminal('--target', 'codex')
        proc.read_until(b'Overwrite ')
        self.assertNotIn(b'Install suggest-commit for:', proc.output)
        proc.send(b'n\n')
        proc.read_until(b'skipped: 1;')
        self.assertEqual(proc.finish(), 0)
        self.assertEqual(self.codex.read_text(), 'old')


if __name__ == '__main__':
    unittest.main()
