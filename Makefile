compile:
	aptos move compile --skip-fetch-latest-git-deps
publish:
	aptos move publish --named-addresses module_name=0xfad5a4731cc1185de6f779520b8281aecf7ab5a178dbccee41b703d1a6c82c21 --profile=clicker

.PHONY: compile publish
