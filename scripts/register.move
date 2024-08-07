//:!:>moon
script {

    fun main(account: &signer) {
        aptos_framework::managed_coin::register<ExGuiToken::ex_gui_token::ExGuiToken>(account);

        aptos_framework::managed_coin::mint<ExGuiToken::ex_gui_token::ExGuiToken>(account, @ExGuiToken, 1_000_000_000_000);

        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr1, 10_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr2, 10_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr3, 10_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr4, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr5, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr6, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr7, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr8, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr9, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr10, 1_000_000);
        // aptos_framework::coin::transfer<MoonCoin::moon_coin::MoonCoin>(account, @dest_addr11, 1_000_000);

    }
}
//<:!:moon
