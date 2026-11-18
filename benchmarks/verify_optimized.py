#!/usr/bin/env python3
"""Emit psql SQL proving rewritten reads agree as multisets (R13 is a bug fix)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def queries(path):
    parts = re.split(r'^-- @([RW]\d+|END)\s*$', path.read_text(), flags=re.M)
    return {parts[i]: re.sub(r'^--.*$', '', parts[i + 1], flags=re.M).strip().rstrip(';')
            for i in range(1, len(parts) - 1, 2) if parts[i] != 'END'}

before = queries(ROOT / 'queries/workload_30.sql')
after = queries(ROOT / 'sql/06_optimized_queries.sql')
print('\\set ON_ERROR_STOP on\nSET search_path TO bms;\nBEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;')
print('COPY (')
checks = []
for key in before:
    if before[key] == after[key]:
        continue
    assert key.startswith('R'), 'Write rewrites require a state comparison'
    checks.append(f"""(WITH old AS ({before[key]}), new AS ({after[key]})
SELECT '{key}' AS query_id, (SELECT count(*) FROM old) AS before_rows,
(SELECT count(*) FROM new) AS after_rows,
(SELECT count(*) FROM ((SELECT * FROM old EXCEPT ALL SELECT * FROM new)
UNION ALL (SELECT * FROM new EXCEPT ALL SELECT * FROM old)) delta) AS different_rows)""")
print('\nUNION ALL\n'.join(checks))
print(') TO STDOUT WITH CSV HEADER;\nROLLBACK;')
