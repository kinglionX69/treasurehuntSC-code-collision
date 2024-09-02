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
    /// Incorrect update energy
    const INCORRECT_UPDATE_ENERGY: u64 = 19;
    /// Incorrect year argument
    const INCORRECT_YEAR_ARGUMENT: u64 = 20;
    /// Incorrect month argument
    const INCORRECT_MONTH_ARGUMENT: u64 = 21;
    /// Incorrect day argument
    const INCORRECT_DAY_ARGUMENT: u64 = 22;
    /// Incorrect hour argument
    const INCORRECT_HOUR_ARGUMENT: u64 = 23;
    /// Incorrect minute argument
    const INCORRECT_MINUTE_ARGUMENT: u64 = 24;
    /// Incorrect second argument
    const INCORRECT_SECOND_ARGUMENT: u64 = 25;

    struct UserState has drop, store, copy {
        dig: u64,
        earned_pool: u64,
        grid_state: vector<u64>,
        powerup: u64,
        powerup_purchase_time: u64, // with second
        energy: u64,
        update_time: u64, // with microsecond
        old_digs: vector<u64>,
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
    struct GameState has copy, store, key{
        status: u8,
        start_time: u64, // with second
        end_time: u64, // with second
        grid_state: vector<u64>,
        users_list: vector<address>,
        users_state: vector<UserState>,
        leaderboard: LeaderBoard,
        holes: u64,
        total_pool: u256,
        daily_pool: u256,
        total_transation: u256
    }

    struct GameStateWithTime has copy, key {
        game_state: GameState,
        now_time_second: u64,
        now_time_microsecond: u64
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

    public fun is_leap_year(year: u64): bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }

    public fun date_time_to_timestamp(year: u64, month: u64, day: u64, hour: u64, minute: u64, second: u64): u64 {
        assert!(month >= 1 && month <= 12, INCORRECT_MONTH_ARGUMENT);
        assert!(day >= 1 && day <= 31, INCORRECT_DAY_ARGUMENT); // Initial validation
        assert!(hour < 24, INCORRECT_HOUR_ARGUMENT);
        assert!(minute < 60, INCORRECT_MINUTE_ARGUMENT);
        assert!(second < 60, INCORRECT_SECOND_ARGUMENT);

        let days_in_month: vector<u64> = vector[0, 31, 
            28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        
        if ( is_leap_year( year ) == true ) {
            *vector::borrow_mut(&mut days_in_month, 2) = *vector::borrow_mut(&mut days_in_month, 2) + 1;
        };

        assert!(day <= *vector::borrow(&days_in_month, month), INCORRECT_DAY_ARGUMENT);

        let total_days: u64 = 0;

        let i = 1970;
        while ( i < year ) {
            if ( is_leap_year(i) == true ) {
                total_days = total_days + 366;
            }
            else {
                total_days = total_days + 365;
            };
            i = i + 1;
        };

        i = 0;
        while ( i < month ) {
            total_days = total_days + *vector::borrow(&days_in_month, i);
            i = i + 1;
        };

        total_days = total_days + day - 1;

        let timestamp = total_days * 86400 + hour * 3600 + minute * 60 + second- 10800 ; // seconds in a day
        timestamp
    }

    public entry fun start_event( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let current_timestamp = timestamp::now_seconds();

        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 72 ) {
            vector::push_back(&mut init_vector, 0);
        };

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
                daily_pool: 0,
                total_transation: 0
            });
        };

        let game_state = borrow_global_mut<GameState>(creator_addr);

        assert!(game_state.status == EGAME_INACTIVE, error::unavailable(EGAME_IS_ACTIVE_NOW));

        game_state.status = EGAME_ACTIVE;
        game_state.start_time = current_timestamp;
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
        game_state.total_transation  = 0;
    }

    public entry fun start_event_with_time( creator: &signer, year: u64, month: u64, day: u64, hours: u64, minutes: u64, seconds: u64 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let start_timestamp = date_time_to_timestamp(year, month, day, hours, minutes, seconds);

        let current_time = timestamp::now_seconds();
        // assert!( start_timestamp >= current_time, error::unavailable(TIME_SET_ERROR) );

        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 72 ) {
            vector::push_back(&mut init_vector, 0);
        };

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
                daily_pool: 0,
                total_transation: 0
            });
        };

        let game_state = borrow_global_mut<GameState>(creator_addr);

        assert!(game_state.status == EGAME_INACTIVE, error::unavailable(EGAME_IS_ACTIVE_NOW));

        game_state.start_time = start_timestamp;
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
        game_state.total_transation  = 0;
    }

    public entry fun end_event( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        let current_timestamp = timestamp::now_seconds();

        assert!(current_timestamp > game_state.start_time, error::unavailable(TIME_SET_ERROR));
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));

        game_state.status = EGAME_INACTIVE;
        game_state.end_time = current_timestamp;
    }

    public entry fun end_event_with_time( creator: &signer, year: u64, month: u64, day: u64, hours: u64, minutes: u64, seconds: u64 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let end_timestamp = date_time_to_timestamp(year, month, day, hours, minutes, seconds);

        let game_state = borrow_global_mut<GameState>(creator_addr);

        // assert!(end_timestamp > game_state.start_time, error::unavailable(TIME_SET_ERROR));
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));

        game_state.end_time = end_timestamp;
    }

    public entry fun pause_and_resume ( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        assert!(game_state.status == EGAME_ACTIVE || game_state.status == EGAME_PAUSED, error::unavailable(EGAME_CAN_NOT_PAUSE_OR_RESUME));

        if (game_state.status == EGAME_ACTIVE) {
            game_state.status = EGAME_PAUSED;
            game_state.total_transation = game_state.total_transation + 1;
        }
        else if (game_state.status == EGAME_PAUSED) {
            game_state.status = EGAME_ACTIVE;
            game_state.total_transation = game_state.total_transation + 1;
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
            game_state.total_transation = game_state.total_transation + 1;
        }
        else if( plan == 2 && ( user_state.powerup < plan ) ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( account, @clicker, 500_000 * EX_GUI_TOKEN_DECIMAL );

            now_seconds = timestamp::now_seconds();

            user_state.powerup = 2;
            user_state.powerup_purchase_time = now_seconds;

            game_state.daily_pool = game_state.daily_pool + 500_000;
            game_state.total_pool = game_state.total_pool + 500_000;
            game_state.total_transation = game_state.total_transation + 1;
        }
        else if ( plan == 3 && ( user_state.powerup < plan ) ) {
            coin::transfer<ExGuiToken::ex_gui_token::ExGuiToken>( account, @clicker, 650_000 * EX_GUI_TOKEN_DECIMAL );

            now_seconds = timestamp::now_seconds();

            user_state.powerup = 3;
            user_state.powerup_purchase_time = now_seconds;

            game_state.daily_pool = game_state.daily_pool + 650_000;
            game_state.total_pool = game_state.total_pool + 650_000;
            game_state.total_transation = game_state.total_transation + 1;
        }
    }

    /**
        The User connect to the game using connect_game function.
    */
    public entry fun connect_game ( account: &signer ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        let current_time = timestamp::now_seconds();
        // check start_time of game
        if ( game_state.start_time <= current_time && game_state.status != EGAME_PAUSED ) {
            game_state.status = EGAME_ACTIVE;
        };
        if ( game_state.end_time <= current_time) {
            game_state.status = EGAME_INACTIVE;
        };

        let ( found, index ) = vector::index_of(&game_state.users_list, &signer_addr);
        if ( !found ) {

            vector::push_back(&mut game_state.users_list, signer_addr);
            if ( coin::is_account_registered<ExGuiToken::ex_gui_token::ExGuiToken>(signer_addr) == false ) {
                managed_coin::register<ExGuiToken::ex_gui_token::ExGuiToken>(account);
            };


            let init_vector = vector::empty();
            while ( vector::length(&init_vector) < 72 ) {
                vector::push_back(&mut init_vector, 0);
            };

            vector::push_back(&mut game_state.users_state, UserState{ dig: 0, earned_pool: 0, grid_state: init_vector, powerup: 0, powerup_purchase_time: 0,  energy: 500, update_time: timestamp::now_microseconds(), old_digs: vector::empty() });
            game_state.total_transation = game_state.total_transation + 1;
        }
    }

    public entry fun dig_multi( account: &signer, square_vec: vector<u64>, update_energy: u64) acquires GameState {
        let signer_addr = signer::address_of(account); // get address of signer

        let game_state = borrow_global_mut<GameState>(@clicker); // get gamestate.

        assert!((update_energy >= 0 && update_energy < 500), error::invalid_argument(INCORRECT_UPDATE_ENERGY));
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW)); // check game is active
        assert!(vector::contains(&game_state.users_list, &signer_addr), error::unavailable(UNREGISTERED_USER)); // check user exist

        let current_time = timestamp::now_seconds();
        // check start_time of game
        if ( game_state.start_time >= current_time && game_state.status != EGAME_PAUSED ) {
            game_state.status = EGAME_ACTIVE;
        };
        if ( game_state.end_time <= current_time) {
            game_state.status = EGAME_INACTIVE;
        };

        if( game_state.status == EGAME_ACTIVE ) {
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

            user_state.energy = update_energy;

            user_state.old_digs = vector::empty();

            let flag = false;
            i = 0;
            while ( i < len ) {
                let square_index = *vector::borrow(&square_vec, i);
                
                if ( *vector::borrow(&game_state.grid_state, square_index) != 100 ) {
                    *vector::borrow_mut(&mut game_state.grid_state, square_index) = *vector::borrow_mut(&mut game_state.grid_state, square_index) + 1;
                    *vector::borrow_mut(&mut user_state.grid_state, square_index) = *vector::borrow_mut(&mut user_state.grid_state, square_index) + 1;

                    user_state.dig = user_state.dig + 1;
                    flag = true;
                    vector::push_back(&mut user_state.old_digs, square_index);

                    i = i + 1;
                };
            };

            if( flag == true ) {
                game_state.total_transation = game_state.total_transation + 1;
            };

            user_state.update_time = timestamp::now_microseconds();

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
        let creator_address_2x = @0x5470e0f328736e9bd75321888a5478eb46801517e8e1644dcf05273752fbd33c;
        let collection_name_2x = string::utf8(b"Martian Testnet82079");
        let token_name_2x = string::utf8(b"Martian NFT #82079");
        // 3x
        let creator_address_3x = @0x5470e0f328736e9bd75321888a5478eb46801517e8e1644dcf05273752fbd33c;
        let collection_name_3x = string::utf8(b"Martian Testnet86114");
        let token_name_3x = string::utf8(b"Martian NFT #86114");

        let token_data_id_2x: TokenId = token::create_token_id_raw(creator_address_2x, collection_name_2x, token_name_2x, 0);
        let token_data_id_3x: TokenId = token::create_token_id_raw(creator_address_3x, collection_name_3x, token_name_3x, 0);

        let updated_users_dig = vector::empty();

        while ( i < len ) {
            let user_state = vector::borrow(&game_state.users_state, i);
            let dig = user_state.dig;

            if ( token::balance_of ( *vector::borrow(&game_state.users_list, i), token_data_id_3x ) > 0 ) {
                dig = user_state.dig * 3;
            }
            else if ( token::balance_of ( *vector::borrow(&game_state.users_list, i), token_data_id_2x ) > 0 ) {
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

        game_state.total_transation = game_state.total_transation + 1;
        game_state.daily_pool = 0;
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

    #[view]
    public fun game_state_with_time (): GameStateWithTime acquires GameState {
        let game_state = borrow_global<GameState>(@clicker);

        GameStateWithTime {
            game_state: *game_state,
            now_time_second: timestamp::now_seconds(),
            now_time_microsecond: timestamp::now_microseconds()
        }
    }

    
    #[test_only]
    use aptos_framework::account;

    #[test(creator = @0x123)]
    fun test_pause_and_resume(creator: &signer) acquires GameState {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        unfreeze_transfer(creator, token);
        object::transfer(creator, token, @0x345);
    }

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