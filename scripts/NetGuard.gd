extends RefCounted
## Debug builds never call the hosted API by accident. In a debug build, any request to a
## host other than localhost is refused unless the run opts in explicitly:
##   desktop/editor: command-line user arg `-- --allow-hosted`, or env CHALK_ALLOW_HOSTED=1
##   web:            ?allow_hosted=1 in the page URL
## Release builds are unaffected (always allowed). Callers fall back to their offline path.

static func allowed(url: String) -> bool:
	return decide(url, OS.is_debug_build(), _opted_in())

## Pure decision, so it can be tested for both build kinds.
static func decide(url: String, debug_build: bool, opted_in: bool) -> bool:
	if not debug_build or opted_in:
		return true
	return _is_local(url)

static func _is_local(url: String) -> bool:
	var u := url.strip_edges().to_lower()
	if u == "" or u.begins_with("res://") or u.begins_with("user://"):
		return true
	var rest := u.split("://", true, 1)
	var host := (rest[1] if rest.size() > 1 else rest[0]).split("/", true, 1)[0].split(":", true, 1)[0]
	return host in ["127.0.0.1", "localhost", "::1", "[::1]"]

static func _opted_in() -> bool:
	if "--allow-hosted" in OS.get_cmdline_user_args() or OS.get_environment("CHALK_ALLOW_HOSTED") == "1":
		return true
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var v := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('allow_hosted') || ''", true))
		return v == "1"
	return false
