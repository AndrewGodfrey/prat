# Given a root directory and a path under it (to an existing item), returns the relative path from the root.
param ($expectedRoot, $path)
if (-not (Split-Path $path -IsAbsolute)) { throw "Expected absolute path. Actual: $path" }
if (-not (Test-Path -LiteralPath $path)) { throw "Expected literal path to existing item. Actual: $path" }

$canonicalRoot = (Resolve-Path $expectedRoot).Path
$canonicalPath = (Resolve-Path $path).Path
if (-not ($canonicalPath.StartsWith($canonicalRoot))) { throw "Expected subpath. '$root' does not seem to be a root of '$path'" }
if ($canonicalPath -eq $canonicalRoot) { return "" }

# "+1" to strip off leading path separator.
return $canonicalPath.SubString($canonicalRoot.Length + 1)

