extends GutTest


func test_decodes_base64url_without_padding() -> void:
	assert_eq(
		GameSettings.decode_base64url("aHR0cHM6Ly9pc3N1ZXItZ29kb3QuZmx5LmRldg"),
		"https://issuer-godot.fly.dev"
	)


func test_decodes_url_safe_characters_and_padding() -> void:
	# "??>" is "Pz8-" in base64url ("Pz8+" in plain base64)
	assert_eq(GameSettings.decode_base64url("Pz8-"), "??>")
	assert_eq(GameSettings.decode_base64url("YQ=="), "a")
	assert_eq(GameSettings.decode_base64url("YQ"), "a")


func test_rejects_what_is_not_base64url() -> void:
	assert_eq(GameSettings.decode_base64url(""), "")
	assert_eq(GameSettings.decode_base64url("abcde"), "")


func test_the_shipped_file_has_the_issuer_and_the_version() -> void:
	assert_true(GameSettings.issuer_url().begins_with("https://"))
	assert_eq(GameSettings.game_id(), "sacrifice")
	assert_false(GameSettings.version().is_empty())
