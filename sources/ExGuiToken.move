module ExGuiToken::ex_gui_token {
    struct ExGuiToken {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<ExGuiToken>(
            sender,
            b"ExGuiToken",
            b"ExGui",
            6,
            true,
        );
    }
}
