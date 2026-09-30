# Branch comparison

- Repository: /tmp/review-git-branch-fixture
- Current branch: feature/parser
- Base branch: dev
- Merge base: 3333333
- Branch commits since merge base: 1
- Worktree: clean

## Commits

- ccccccc Parse user-supplied configuration

## Diff stat

```text
 src/parser.py | 17 ++++++++++++++++-
 1 file changed, 16 insertions(+), 1 deletion(-)
```

## Changed paths

```text
M	src/parser.py
```

## Diff checks

No whitespace errors reported by git diff --check.

## Patch

```diff
diff --git a/src/parser.py b/src/parser.py
index 3333333..4444444 100644
--- a/src/parser.py
+++ b/src/parser.py
@@ -1,8 +1,23 @@
-def parse_port(value):
-    return int(value)
+def parse_port(value):
+    port = int(value)
+    if port < 1 or port > 65535:
+        raise ValueError(\"port out of range\")
+    return port
+
+def parse_mode(value):
+    return value.strip().lower()
+
+def load_config(path):
+    with open(path) as handle:
+        return handle.read()
```
