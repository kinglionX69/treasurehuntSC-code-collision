script {

    fun main(account: &signer) {
        aptos_framework::managed_coin::register<ExGuiToken::ex_gui_token::ExGuiToken>(account);

        aptos_framework::managed_coin::mint<ExGuiToken::ex_gui_token::ExGuiToken>(account, @ExGuiToken, 100_000_000_000_000);
    }
}
