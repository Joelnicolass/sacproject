class_name AgentFetch
extends RefCounted

const Ops := preload("res://addons/agent_kit/agent_ops.gd")


static func request(
	host: Node,
	url: String,
	out_path: String,
	method_name: String,
	user_agent: String
) -> String:
	if url.strip_edges().is_empty():
		return "missing --url="
	if out_path.strip_edges().is_empty():
		return "missing --out="
	var http := HTTPRequest.new()
	host.add_child(http)
	http.timeout = 30.0
	var method := HTTPClient.METHOD_GET
	var upper := method_name.strip_edges().to_upper()
	if upper == "POST":
		method = HTTPClient.METHOD_POST
	elif upper == "HEAD":
		method = HTTPClient.METHOD_HEAD
	var headers := PackedStringArray(
		[
			"User-Agent: %s" % user_agent,
			"Accept: */*",
		]
	)
	var err := http.request(url, headers, method)
	if err != OK:
		http.queue_free()
		return "HTTPRequest.request failed (%d)" % err
	var completed: Array = await http.request_completed
	http.queue_free()
	if completed.size() < 4:
		return "empty HTTP response"
	var result := int(completed[0])
	var code := int(completed[1])
	var body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return "http result=%d code=%d (2=cant_connect 3=cant_resolve 5=tls)" % [result, code]
	if code < 200 or code >= 300:
		return "http %d (%d bytes)" % [code, body.size()]
	Ops.ensure_parent_dir(out_path)
	var file := FileAccess.open(Ops.fs_path(out_path), FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % out_path
	file.store_buffer(body)
	file.close()
	print("AGENT_HTTP code=%d bytes=%d" % [code, body.size()])
	return ""
