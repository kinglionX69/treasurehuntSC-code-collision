compile:
	aptos move compile --skip-fetch-latest-git-deps --included-artifacts=none
publish-clicker:
	aptos move publish --skip-fetch-latest-git-deps --included-artifacts=none --named-addresses module_name=0xfad5a4731cc1185de6f779520b8281aecf7ab5a178dbccee41b703d1a6c82c21 --profile=clicker
publish-ExGuiToken:
	aptos move publish --skip-fetch-latest-git-deps  --included-artifacts=none --named-addresses module_name=0xfad5a4731cc1185de6f779520b8281aecf7ab5a178dbccee41b703d1a6c82c21 --profile=clicker
fund-gui:
	aptos move run-script --skip-fetch-latest-git-deps --script-path ./scripts/register.move --profile=clicker
fund:
	aptos account fund-with-faucet --profile $(name)

.PHONY: compile publish
