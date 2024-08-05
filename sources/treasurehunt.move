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
    use aptos_std::table::{Self, Table};
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_token_objects::token::Token;
    
    /// Game Status
    const EGAME_INACTIVE: u8 = 0;
    const EGAME_ACTIVE: u8 = 1;
    const EGAME_PAUSED: u8 = 2;
    /// Digging
    const DIG_APTOS_AMOUNT: u64 = 10000; // 0.0001 apt

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
    /// The user has not enough progress
    const NOT_ENOUGH_PROGRESS: u64 = 11;
    /// The user is trying it with incorrect square index
    const INCORRECT_SQUARE_INDEX: u64 = 12;
    /// The user is trying to make a fast request
    const TOO_FAST_REQUEST: u64 = 13;
    /// The user is trying a progress_bar that is not allowed
    const UNKNOWN_PROGRESS_BAR: u64 = 14;

    struct GridSize has drop, store, copy {
        width: u8,
        height: u8
    }

    struct UserState has drop, store, copy {
        score: u64,
        lifetime_scroe: u64,
        grid_state: vector<u64>,
        power: u64,
        progress_bar: u64,
        update_time: u64,
    }

    struct UserScore has drop, store, copy {
        user_address: address,
        score: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GameState has key{
        status: u8,
        start_time: u64,
        end_time: u64,
        grid_size: GridSize,
        grid_state: vector<u64>,
        users_list: vector<address>,
        users_state: vector<UserState>,
        holes: u64,
    }

    public entry fun start_event( creator: &signer, start_time: u64, end_time: u64, grid_width: u8, grid_height: u8 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let current_time = timestamp::now_seconds();

        let status: u8;
        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 71 ) {
            vector::push_back(&mut init_vector, 0);
        };

        if (start_time <= current_time) {
            status = EGAME_ACTIVE;
        }
        else {
            status = EGAME_INACTIVE;
        };

        if (!exists<GameState>(creator_addr)) {
            move_to(creator, GameState{
                status: 0,
                start_time: 18_446_744_073_709_551_615,
                end_time: 18_446_744_073_709_551_615, 
                grid_size: GridSize {
                    width: 0,
                    height: 0,
                },
                grid_state: init_vector,
                users_list: vector::empty(),
                users_state: vector::empty(),
                holes: 0
            });
        };

        let game_state = borrow_global_mut<GameState>(creator_addr);

        assert!(game_state.status == 0, error::unavailable(EGAME_IS_ACTIVE_NOW));

        game_state.status = status;
        game_state.start_time = start_time;
        game_state.end_time = end_time;
        game_state.grid_size = GridSize {
            width: grid_width,
            height: grid_height
        };
        game_state.grid_state = init_vector;
        game_state.users_list = vector::empty();
        game_state.users_state = vector::empty();
        game_state.holes = 0;
    }

    public entry fun end_event( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        let current_time = timestamp::now_seconds();

        assert!(game_state.end_time <= current_time, error::unavailable(EGAME_NOT_ENDING_TIME));
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
    public entry fun purchase_powerup ( account: &signer, plan: u8 ) acquires GameState {
        let signer_addr = signer::address_of(account);

        assert!( plan == 1 || plan == 2 || plan == 3, error::unavailable(NOT_SUPPOTED_PLAN));

        if( plan == 1 ) {
            let gui_balance = 250_001; /* add function. get balance */

            assert!(gui_balance >= 250_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 1;
        }
        else if( plan == 2 ) {
            let gui_balance = 500_001; /* get balance */

            assert!(gui_balance >= 500_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 2;
        }
        else if ( plan == 3 ) {
            let gui_balance = 650_001; /* get balance */

            assert!(gui_balance >= 650_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 3;
        }
    }

    /**
        The User connect to the game using connect_game function.
    */
    public entry fun connect_game ( account: &signer ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));
        assert!(!vector::contains(&game_state.users_list, &signer_addr), error::unavailable(ALREADY_REGISTERED_USER));

        vector::push_back(&mut game_state.users_list, signer_addr);

        let init_vector = vector::empty();
        while ( vector::length(&init_vector) < 71 ) {
            vector::push_back(&mut init_vector, 0);
        };

        vector::push_back(&mut game_state.users_state, UserState{ score: 0, lifetime_scroe: 0, grid_state: init_vector, power: 0, progress_bar: 500, update_time: timestamp::now_microseconds() });
    }
    /**
        Digging method
        plan 0: maximum digging speed 5/s 
        plan 1: maximum digging speed 7.5/s
        plan 2: maximum digging speed 15/s
        plan 3: maximum digging speed 25/s
    */
    public entry fun dig( account: &signer, square_index: u64) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));
        assert!(vector::contains(&game_state.users_list, &signer_addr), error::unavailable(UNREGISTERED_USER));
        assert!( ( square_index >=0 && square_index <= 71 ), error::invalid_argument(INCORRECT_SQUARE_INDEX) );

        let now_microseconds = timestamp::now_microseconds();
        let ( _, index ) = vector::index_of(&game_state.users_list, &signer_addr);

        let user_state = vector::borrow_mut(&mut game_state.users_state, index);

        assert!( user_state.progress_bar != 0, error::unavailable(NOT_ENOUGH_PROGRESS) );

        assert!( ( user_state.power == 0 && ( now_microseconds - user_state.update_time ) > 190_000  )
        || ( user_state.power == 1 && ( now_microseconds - user_state.update_time ) > 130_000 )
        || ( user_state.power == 2 && ( now_microseconds - user_state.update_time ) > 60_000 ) 
        || ( user_state.power == 3 && ( now_microseconds - user_state.update_time ) >  35_000 ),
        error::unavailable(TOO_HIGH_DIGGING_SPEED) );

        assert!(*vector::borrow(&game_state.grid_state, square_index) < 100, error::invalid_argument(EXCEED_DIGGING));

        coin::transfer<AptosCoin>(account, @clicker, DIG_APTOS_AMOUNT);

        *vector::borrow_mut(&mut game_state.grid_state, square_index) = *vector::borrow_mut(&mut game_state.grid_state, square_index) + 1;

        *vector::borrow_mut(&mut user_state.grid_state, square_index) = *vector::borrow_mut(&mut user_state.grid_state, square_index) + 1;
        user_state.progress_bar = user_state.progress_bar - 1;
        user_state.score = user_state.score + 1;
        user_state.lifetime_scroe = user_state.lifetime_scroe + 1;
        user_state.update_time = timestamp::now_microseconds();

        // check holes count
        if ( *vector::borrow( &game_state.grid_state, square_index ) == 100 ) {
            game_state.holes = game_state.holes + 1;

            let init_vector = vector::empty();
            while ( vector::length(&init_vector) < 71 ) {
                vector::push_back(&mut init_vector, 0);
            };
            
            if ( game_state.holes == 72 ) {
                game_state.grid_state = init_vector;
                game_state.holes = 0;

                let i = 0;
                let len = vector::length(&game_state.users_state);

                while ( i < len ) {
                    let user_state = vector::borrow_mut(&mut game_state.users_state, i);
                    
                    user_state.grid_state = init_vector;
                    user_state.progress_bar = 500;
                }
            }
        }
    }

    public entry fun charge_progress_bar( account: &signer ) acquires GameState {
        let signer_addr = signer::address_of(account);

        let game_state = borrow_global_mut<GameState>(@clicker);

        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));
        assert!(vector::contains(&game_state.users_list, &signer_addr), error::unavailable(UNREGISTERED_USER));

        let ( _, index ) = vector::index_of(&game_state.users_list, &signer_addr);

        let user_state = vector::borrow_mut(&mut game_state.users_state, index);

        let now_microseconds = timestamp::now_microseconds();

        assert!( ( user_state.progress_bar >= 0 && user_state.progress_bar <= 495 ), error::unavailable( UNKNOWN_PROGRESS_BAR ) );
        assert!( ( user_state.progress_bar == 0 && ( now_microseconds - user_state.update_time ) > 5_000_000 )
        || ( user_state.progress_bar != 0 && ( now_microseconds - user_state.update_time ) > 1_000_000 ), error::unavailable( TOO_FAST_REQUEST ) );

        user_state.progress_bar = user_state.progress_bar + 5;
    }

    // #[view]
    // public fun show_leaderboard () acquires GameState {
    //     let game_state = borrow_global_mut<GameState>(@clicker);

        // }


    
    // public entry fun reward_distribution ( creator: &signer, start_time: u64, end_time: u64, grid_width: u8, grid_height: u8 ) /* acquires GameState */ {

    // }


    // #[view]
    // public fun show_player_score ( player: address ) acquires GameState{

    // }

}