extends SceneTree

## Lab tool: a self-signed certificate for wss:// tests. `-- --cert-dir=/abs/folder` writes cert.crt and key.key there,
## issued for CN=mpkit.test (clients pass --tls-common-name=mpkit.test and --tls-trusted-ca=<cert.crt>).


func _initialize() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cert-dir="):
			dir = arg.substr("--cert-dir=".length())
	if dir.is_empty():
		print("CERT FAIL: --cert-dir= missing")
		quit(1)
		return
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var cert := crypto.generate_self_signed_certificate(key, "CN=mpkit.test,O=MpKit,C=AR")
	var ok := cert.save(dir.path_join("cert.crt")) == OK and key.save(dir.path_join("key.key")) == OK
	print("CERT OK" if ok else "CERT FAIL")
	quit(0 if ok else 1)
