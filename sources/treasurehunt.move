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
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    
    /// Game Status
    const EGAME_INACTIVE: u8 = 0;
    const EGAME_ACTIVE: u8 = 1;
    const EGAME_PAUSED: u8 = 2;

    /// The user is not allowed to do this operation
    const EGAME_PERMISSION_DENIED: u64 = 0;
    /// The game is active now
    const EGAME_IS_ACTIVE_NOW: u64 = 1;

    
    struct GridSize has drop, store, copy {
        width: u8,
        height: u8
    }

    struct UserState has drop, store, copy {
        score: u64,
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
        users: u64,
        leaderboard: vector<UserScore>,
        users_list: vector<address>,
        users_state: vector<UserState>
    }

    public entry fun start_event( creator: &signer, start_time: u64, end_time: u64, grid_width: u8, grid_height: u8 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let current_time = timestamp::now_seconds();

        let status: u8;
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
                users: 0,
                leaderboard: vector::empty(),
                users_list: vector::empty(),
                users_state: vector::empty(),
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
        game_state.users = 0;
        game_state.leaderboard = vector::empty();
        game_state.users_list = vector::empty();
        game_state.users_state = vector::empty();
    }


}