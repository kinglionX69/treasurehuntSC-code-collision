module clicker::treasurehunt { 

    use std::error;
    use std::option::{Self, Option, some, is_some};
    use std::string::{Self, String};
    use std::vector;
    use std::signer;
    use aptos_framework::object::{Self, ConstructorRef, Object};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::managed_coin;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account::SignerCapability;
    use aptos_token::token::{Self, Token, TokenId};
    
    /// Game Status
    const EGAME_INACTIVE: u8 = 0;
    const EGAME_ACTIVE: u8 = 1;
    const EGAME_PAUSED: u8 = 2;
    /// Digging
    const DIG_APTOS_AMOUNT: u64 = 10000; // 0.0001 apt
    const APTOS_TOKEN_DECIMAL: u64 = 100_000_000;
    const EX_GUI_TOKEN_DECIMAL: u64 = 1_000_000;

    /// The user is not allowed to do this operation
    const EGAME_PERMISSION_DENIED: u64 = 0;
    /// The game is active now
    const EGAME_IS_ACTIVE_NOW: u64 = 1;
    /// The game is inactive now
    const EGAME_IS_INACTIVE_NOW: u64 = 2;
    /// The game is not ending time
    const EGAME_NOT_ENDING_TIME: u64 = 3;
    /// The game can not pause or resume
    const EGAME_CAN_NOT_PAUSE_OR_RESUME: u64 = 4;
    /// Gui balance is not enough
    const BALANCE_IS_NOT_ENOUGH: u64 = 5;
    /// unregistered user
    const UNREGISTERED_USER: u64 = 6;
    /// already registered user
    const ALREADY_REGISTERED_USER: u64 = 7;
    /// It is not supported plan
    const NOT_SUPPOTED_PLAN: u64 = 8;
    /// The square already all digged
    const EXCEED_DIGGING: u64 = 9;
    /// The user is trying it at high speed
    const TOO_HIGH_DIGGING_SPEED: u64 = 10;
    /// The user has not enough energy
    const NOT_ENOUGH_ENERGY: u64 = 11;
    /// The user is trying it with incorrect square index
    const INCORRECT_SQUARE_INDEX: u64 = 12;
    /// The user is trying to make a fast request
    const TOO_FAST_REQUEST: u64 = 13;
    /// The user is trying a energy that is not allowed
    const UNKNOWN_ENERGY: u64 = 14;
    /// Now is not distribution time
    const NOT_DISTRIBUTION_TIME: u64 = 15;
    /// Time set error
    const TIME_SET_ERROR: u64 = 16;
    /// Incorrect token type
    const INCORRECT_TOKEN_TYPE: u64 = 17;
    /// Incorrect square length
    const INCORRECT_SQUARE_VECTOR: u64 = 18;

    struct UserState has drop, store, copy {
        dig: u64,
        earned_pool: u64,
        grid_state: vector<u64>,
        powerup: u64,
        powerup_purchase_time: u64, // with second
        energy: u64,
        update_time: u64, // with microsecond
    }

    struct UserDig has drop, store, copy {
        user_address: address,
        dig: u64,
    }

    struct LeaderBoard has drop, store, copy {
        top_user: UserDig,
        second_user: UserDig,
        third_user: UserDig,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GameState has copy, key{
        status: u8,
        start_time: u64, // with second
        end_time: u64, // with second
        grid_state: vector<u64>,
        users_list: vector<address>,
        users_state: vector<UserState>,
        leaderboard: LeaderBoard,
        holes: u64,
        total_pool: u256,
        daily_pool: u256
    }

    struct ModuleData has key {
        signer_cap: SignerCapability
    }

    fun init_module( deployer: &signer ) {
        let creator_addr = signer::address_of( deployer );

        if ( !exists<ModuleData>( creator_addr ) ) {
            let ( resource_signer, resource_signer_cap ) = account::create_resource_account( deployer, x"4503317842200101300202");

            move_to( deployer, ModuleData {
                signer_cap: resource_signer_cap
            } )
        };
    }

    public entry fun start_event( creator: &signer, start_time: u64 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let current_time = timestamp::now_seconds();

        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 72 ) {
            vector::push_back(&mut init_vector, 0);
        };

        assert!( start_time >= current_time, error::unavailable(TIME_SET_ERROR) );

        if (!exists<GameState>(creator_addr)) {
            move_to(creator, GameState{
                status: EGAME_INACTIVE,
                start_time: 18_446_744_073_709_551_615,
                end_time: 18_446_744_073_709_551_615, 
                grid_state: init_vector,
                users_list: vector::empty(),
                users_state: vector::empty(),
                leaderboard: LeaderBoard {
                    top_user: UserDig {
                        user_address: @0x1,
                        dig: 0,
                    },
                    second_user: UserDig {
                        user_address: @0x1,
                        dig: 0,
                    },
                    third_user: UserDig {
                        user_address: @0x1,
                        dig: 0
                    }
                },
                holes: 0,
                total_pool: 0,
                daily_pool: 0
            });
        };

        let game_state = borrow_global_mut<GameState>(creator_addr);

        assert!(game_state.status == EGAME_INACTIVE, error::unavailable(EGAME_IS_ACTIVE_NOW));

        game_state.status = EGAME_ACTIVE;
        game_state.start_time = start_time;
        game_state.end_time = 18_446_744_073_709_551_615;
        game_state.grid_state = init_vector;
        game_state.users_list = vector::empty();
        game_state.users_state = vector::empty();
        game_state.leaderboard = LeaderBoard {
            top_user: UserDig {
                user_address: @0x1,
                dig: 0,
            },
            second_user: UserDig {
                user_address: @0x1,
                dig: 0,
            },
            third_user: UserDig {
                user_address: @0x1,
                dig: 0
            }
        };
        game_state.holes = 0;
    }

    public entry fun end_event( creator: &signer, end_time: u64 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        let current_time = timestamp::now_seconds();

        assert!(end_time > game_state.start_time, error::unavailable(TIME_SET_ERROR));
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));

        game_state.status = EGAME_INACTIVE;
    }

    public entry fun pause_and_resume ( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        assert!(game_state.status == EGAME_ACTIVE || game_state.status == EGAME_PAUSED, error::unavailable(EGAME_CAN_NOT_PAUSE_OR_RESUME));

        if (game_state.status == EGAME_ACTIVE) {
            game_state.status = EGAME_PAUSED;
        }
        else if (game_state.status == EGAME_PAUSED) {
            game_state.status = EGAME_ACTIVE;
        }
    }

    /**
        purchase powerup
        plan: 1(1.5 times), 2(3 times), 3(5 times)
     */
    // purchase powerup
    public entry fun purchase_powerup ( account: &signer, plan: u64 ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW)); // game active check

        let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

        assert!(found, error::unavailable(UNREGISTERED_USER)); // check user exist

        let user_state = vector::borrow_mut(&mut game_state.users_state, index);
        let now_seconds = timestamp::now_seconds();

        if ( user_state.powerup == 1 && ( now_seconds - user_state.powerup_purchase_time ) > 900 ) {
            user_state.powerup = 0;
        }
        else if ( user_state.powerup == 2 && ( now_seconds - user_state.powerup_purchase_time ) > 1800 ) {
            user_state.powerup = 0;
        }
        else if ( user_state.powerup == 3 && ( now_seconds - user_state.powerup_purchase_time ) > 3600 ) {
            user_state.powerup = 0;
        };

        assert!( plan == 1 || plan == 2 || plan == 3, error::unavailable(NOT_SUPPOTED_PLAN));

        if( plan == 1 && ( user_state.powerup < plan ) ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( account, @clicker, 250_000 * EX_GUI_TOKEN_DECIMAL );

            now_seconds = timestamp::now_seconds();

            user_state.powerup = 1;
            user_state.powerup_purchase_time = now_seconds;

            game_state.daily_pool = game_state.daily_pool + 250_000;
            game_state.total_pool = game_state.total_pool + 250_000;
        }
        else if( plan == 2 && ( user_state.powerup < plan ) ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( account, @clicker, 500_000 * EX_GUI_TOKEN_DECIMAL );

            now_seconds = timestamp::now_seconds();

            user_state.powerup = 2;
            user_state.powerup_purchase_time = now_seconds;

            game_state.daily_pool = game_state.daily_pool + 500_000;
            game_state.total_pool = game_state.total_pool + 500_000;
        }
        else if ( plan == 3 && ( user_state.powerup < plan ) ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( account, @clicker, 650_000 * EX_GUI_TOKEN_DECIMAL );

            now_seconds = timestamp::now_seconds();

            user_state.powerup = 3;
            user_state.powerup_purchase_time = now_seconds;

            game_state.daily_pool = game_state.daily_pool + 650_000;
            game_state.total_pool = game_state.total_pool + 650_000;
        }
    }

    /**
        The User connect to the game using connect_game function.
    */
    public entry fun connect_game ( account: &signer ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));
        let ( found, index ) = vector::index_of(&game_state.users_list, &signer_addr);
        if ( !found ) {

            vector::push_back(&mut game_state.users_list, signer_addr);

            let init_vector = vector::empty();
            while ( vector::length(&init_vector) < 72 ) {
                vector::push_back(&mut init_vector, 0);
            };

            vector::push_back(&mut game_state.users_state, UserState{ dig: 0, earned_pool: 0, grid_state: init_vector, powerup: 0, powerup_purchase_time: 0,  energy: 500, update_time: timestamp::now_microseconds() });
        }
    }

    public entry fun dig_multi( account: &signer, square_vec: vector<u64>) acquires GameState {
        let signer_addr = signer::address_of(account); // get address of signer

        let game_state = borrow_global_mut<GameState>(@clicker); // get gamestate.

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW)); // check game is active
        assert!(vector::contains(&game_state.users_list, &signer_addr), error::unavailable(UNREGISTERED_USER)); // check user exist
        let len = vector::length(&square_vec);

        let i = 0;
        while ( i < len ) {
            let square_index = *vector::borrow(&square_vec, i);
            assert!( ( square_index >=0 && square_index <= 71 ), error::invalid_argument(INCORRECT_SQUARE_INDEX) ); // check square index
            i = i + 1;
        };

        let now_microseconds = timestamp::now_microseconds(); // get now time with microsecond
        let ( _, index ) = vector::index_of(&game_state.users_list, &signer_addr); // get user index from user address

        let user_state = vector::borrow_mut(&mut game_state.users_state, index); // get userstate

        assert!( user_state.energy >= len, error::unavailable(NOT_ENOUGH_ENERGY) ); // check energy

        let now_seconds = timestamp::now_seconds();

        if ( user_state.powerup == 1 && ( now_seconds - user_state.powerup_purchase_time ) > 900 ) {
            user_state.powerup = 0;
        }
        else if ( user_state.powerup == 2 && ( now_seconds - user_state.powerup_purchase_time ) > 1800 ) {
            user_state.powerup = 0;
        }
        else if ( user_state.powerup == 3 && ( now_seconds - user_state.powerup_purchase_time ) > 3600 ) {
            user_state.powerup = 0;
        };

        coin::transfer<AptosCoin>(account, @admin, DIG_APTOS_AMOUNT * len);

        i = 0;
        while ( i < len ) {
            let square_index = *vector::borrow(&square_vec, i);
            
            if ( *vector::borrow(&game_state.grid_state, square_index) == 100 ) continue;

            *vector::borrow_mut(&mut game_state.grid_state, square_index) = *vector::borrow_mut(&mut game_state.grid_state, square_index) + 1;
            *vector::borrow_mut(&mut user_state.grid_state, square_index) = *vector::borrow_mut(&mut user_state.grid_state, square_index) + 1;
            i = i + 1;
        };

        user_state.energy = user_state.energy - len;
        user_state.dig = user_state.dig + len;
        user_state.update_time = timestamp::now_microseconds();

        if( game_state.leaderboard.top_user.dig < user_state.dig ) {
            if( *( &game_state.leaderboard.top_user.user_address ) == signer_addr ) {
                game_state.leaderboard.top_user.dig = *(&user_state.dig);
            }
            else {
                game_state.leaderboard.third_user.dig = *(&game_state.leaderboard.second_user.dig);
                game_state.leaderboard.third_user.user_address = *(&game_state.leaderboard.second_user.user_address);

                game_state.leaderboard.second_user.dig = *(&game_state.leaderboard.top_user.dig);
                game_state.leaderboard.second_user.user_address = *(&game_state.leaderboard.top_user.user_address);

                game_state.leaderboard.top_user.dig = *(&user_state.dig);
                game_state.leaderboard.top_user.user_address = signer_addr;
            };
        }
        else if ( game_state.leaderboard.second_user.dig < user_state.dig ) {
            if ( *(&game_state.leaderboard.second_user.user_address) == signer_addr ) {
                game_state.leaderboard.second_user.dig = *(&user_state.dig);
            }
            else {
                game_state.leaderboard.third_user.dig = *(&game_state.leaderboard.second_user.dig);
                game_state.leaderboard.third_user.user_address = *(&game_state.leaderboard.second_user.user_address);

                game_state.leaderboard.second_user.dig = *(&user_state.dig);
                game_state.leaderboard.second_user.user_address = signer_addr;
            };
        }
        else if ( game_state.leaderboard.third_user.dig < user_state.dig ) {
            game_state.leaderboard.third_user.dig = *(&user_state.dig);
            game_state.leaderboard.third_user.user_address = signer_addr;
        };

        // check holes count
        i = 0;
        while ( i < len ) {
            let square_index = vector::borrow( &square_vec, i );
            if ( *vector::borrow( &game_state.grid_state, *square_index ) == 100 ) {
                game_state.holes = game_state.holes + 1;
            };
            i = i + 1;
        };

        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 72 ) {
            vector::push_back(&mut init_vector, 0);
        };
        
        if ( game_state.holes == 72 ) {
            game_state.grid_state = init_vector;
            game_state.holes = 0;

            i = 0;
            len = vector::length(&game_state.users_state);

            while ( i < len ) {
                let user_state = vector::borrow_mut(&mut game_state.users_state, i);
                
                user_state.grid_state = init_vector;
                user_state.energy = 500;

                i = i + 1;
            }
        }
    }

    public entry fun charge_energy( account: &signer ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));
        assert!(vector::contains(&game_state.users_list, &signer_addr), error::unavailable(UNREGISTERED_USER));

        let ( _, index ) = vector::index_of(&game_state.users_list, &signer_addr);

        let user_state = vector::borrow_mut(&mut game_state.users_state, index);

        let now_microseconds = timestamp::now_microseconds();

        assert!( ( user_state.energy >= 0 && user_state.energy < 500 ), error::unavailable( UNKNOWN_ENERGY ) );
        assert!( ( user_state.energy == 0 && ( now_microseconds - user_state.update_time ) > 5_000_000 )
        || ( user_state.energy != 0 && ( now_microseconds - user_state.update_time ) > 1_000_000 ), error::unavailable( TOO_FAST_REQUEST ) );

        if ( user_state.energy > 495 ) {
            user_state.energy = 500;
            user_state.update_time = now_microseconds;
        }
        else {
            user_state.energy = user_state.energy + 5;
            user_state.update_time = now_microseconds;
        };
    }

    public entry fun reward_distribution ( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);

        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let now_seconds: u64 = timestamp::now_seconds();

        let game_state = borrow_global_mut<GameState>(@clicker);

        // assert!( ( now_seconds - game_state.start_time ) > 86_400, error::permission_denied( NOT_DISTRIBUTION_TIME ) );

        let daily_pool = coin::balance<ExGuiToken::ex_gui_token::ExGuiToken>(@clicker);

        // send gui token to admin address
        coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( creator, @admin, daily_pool / 10 );
        daily_pool = daily_pool - daily_pool / 10;

        // send gui token to each user addres
        let i: u64 = 0;
        let len: u64 = vector::length(&game_state.users_state);
        let total: u64 = 0;

        // 2x
        let collection_name_2x = string::utf8(b"Martian Testnet73459");
        let token_name_2x = string::utf8(b"Martian NFT #73459");
        // 3x
        let collection_name_3x = string::utf8(b"Martian Testnet3x");
        let token_name_3x = string::utf8(b"Martian NFT #3x");

        let updated_users_dig = vector::empty();

        while ( i < len ) {
            let user_state = vector::borrow(&game_state.users_state, i);
            let dig = user_state.dig;

            if ( token::check_tokendata_exists ( *vector::borrow(&game_state.users_list, i), collection_name_3x, token_name_3x ) ) {
                dig = user_state.dig * 3;
            }
            else if ( token::check_tokendata_exists ( *vector::borrow(&game_state.users_list, i), collection_name_2x, token_name_2x ) ) {
                dig = user_state.dig * 2;
            };

            total = total + dig;
            vector::push_back( &mut updated_users_dig, dig );

            i = i + 1;
        };

        i = 0;
        while ( i < len ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( creator, *vector::borrow(&game_state.users_list, i), *vector::borrow(&updated_users_dig, i) * daily_pool / total );

            let user_state = vector::borrow_mut(&mut game_state.users_state, i);
            user_state.earned_pool = user_state.earned_pool + ( *vector::borrow(&updated_users_dig, i) * daily_pool / total / EX_GUI_TOKEN_DECIMAL );
            user_state.dig = 0;

            i = i + 1;
        };

        game_state.daily_pool = 0;
    }

    public entry fun withdraw ( account: &signer, token_type: u64, dest_addr: address, amount: u64 ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        let ( found, index ) = vector::index_of(&game_state.users_list, &signer_addr);

        assert!( found, error::unavailable(UNREGISTERED_USER) );
        assert!( token_type == 1 || token_type == 2, error::unavailable(INCORRECT_TOKEN_TYPE) );

        if ( token_type == 1 ) {
            coin::transfer<AptosCoin>(account, dest_addr, amount * APTOS_TOKEN_DECIMAL );
        }
        else if ( token_type == 2 ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>(account, dest_addr, amount * EX_GUI_TOKEN_DECIMAL);
        };
    }

    #[view]
    public fun show_leaderboard (): LeaderBoard acquires GameState {
        let game_state = borrow_global<GameState>(@clicker);

        game_state.leaderboard
    }

    #[view]
    public fun game_state (): GameState acquires GameState {
        let game_state = borrow_global<GameState>(@clicker);

        *game_state
    }

    // #[test(creator = @0x123)]
    // fun test_start_event(creator: &signer) acquires GameState {
    //     start_event(creator, 271821291);


    // }

    // #[test(creator = @0x123)]
    // fun test_pause_and_resume(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_end_event(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_connect_game(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_dig(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_purchase_powerup(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_charge_energy(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_reward_distribution(creator: &signer) acquires GameState {
        
    // }

    // #[test(creator = @0x123)]
    // fun test_withdraw(creator: &signer) acquires GameState {
        
    // }

}