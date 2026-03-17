from __future__ import annotations

import os
from pathlib import Path
import sqlite3
import subprocess
import shutil
import unittest


class MigrationTests(unittest.TestCase):
    def test_alembic_upgrade_head_creates_constraints(self) -> None:
        db_path = Path("migration_check.db")
        if db_path.exists():
            db_path.unlink()

        env = os.environ.copy()
        env["DATABASE_URL"] = f"sqlite+pysqlite:///{db_path}"

        alembic_bin = Path(".venv/bin/alembic")
        command = [str(alembic_bin), "upgrade", "head"] if alembic_bin.exists() else [shutil.which("alembic") or "alembic", "upgrade", "head"]

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        conn = sqlite3.connect(db_path)
        try:
            tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
            self.assertIn("completion_logs", tables)
            self.assertIn("user_preferences", tables)

            idx_rows = conn.execute(
                "SELECT sql FROM sqlite_master WHERE type='index' AND name='ix_user_preferences_user_id'"
            ).fetchall()
            self.assertTrue(idx_rows)
        finally:
            conn.close()
            db_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
