compile:
	aptos move compile \
	--skip-fetch-latest-git-deps \
	--included-artifacts none
publish-clicker:
	aptos move publish \
	--skip-fetch-latest-git-deps \
	--included-artifacts none \
 	--named-addresses clicker=clicker \
 	--profile=clicker
publish-ExGuiToken:
	aptos move publish \
	--skip-fetch-latest-git-deps \
	--included-artifacts none \
	--named-addresses ExGuiToken=clicker \
	--profile=clicker
fund-gui:
	aptos move run-script \
	--skip-fetch-latest-git-deps \
	--compiled-script-path build/treasurehunt/bytecode_scripts/main.mv \
	--profile=clicker
fund:
	aptos account fund-with-faucet --profile $(name)
profile:
	aptos init --profile $(name) --network $(network)

.PHONY: compile publish fund fund-gui publish-clicker publish-ExGuiToken
