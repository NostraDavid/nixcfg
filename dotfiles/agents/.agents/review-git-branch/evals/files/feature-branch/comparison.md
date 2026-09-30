# Branch comparison

- Repository: /tmp/review-git-branch-fixture
- Current branch: feature/cache-timeout
- Base branch: origin/main
- Merge base: 1111111
- Branch commits since merge base: 2
- Worktree: clean

## Commits

- aaaaaaa Add configurable cache timeout
- bbbbbbb Cover cache timeout behavior

## Diff stat

```text
 src/cache.py             | 12 ++++++++----
 tests/test_cache.py      | 18 ++++++++++++++++++
 2 files changed, 26 insertions(+), 4 deletions(-)
```

## Changed paths

```text
M	src/cache.py
A	tests/test_cache.py
```

## Diff checks

No whitespace errors reported by git diff --check.

## Patch

```diff
diff --git a/src/cache.py b/src/cache.py
index 1111111..2222222 100644
--- a/src/cache.py
+++ b/src/cache.py
@@ -1,12 +1,20 @@
-def get_timeout(config):
-    return int(config.get(\"timeout\", 30))
+def get_timeout(config):
+    value = int(config.get(\"timeout\", 30))
+    if value < 0:
+        return value
+    return value
diff --git a/tests/test_cache.py b/tests/test_cache.py
new file mode 100644
--- /dev/null
+++ b/tests/test_cache.py
@@ -0,0 +1,18 @@
+def test_default_timeout():
+    assert get_timeout({}) == 30
+
+def test_configured_timeout():
+    assert get_timeout({\"timeout\": 5}) == 5
```
