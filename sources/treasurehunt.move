module clicker::treasurehunt { 

    use std::error;
    use std::option::{Self, Option, some, is_some};
    use std::string::{Self, String};
    use std::vector;
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    
    /// Game Status
    const EGAME_INACTIVE: u8 = 0;
    const EGAME_ACTIVE: u8 = 1;
    const EGAME_PAUSED: u8 = 2;

    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;

    
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

    struct GameData has drop, store, copy {
        status: u8,
        start_time: u64,
        end_time: u64,
        grid_size: GridSize,
        users: u64,
        leaderboard: Vector<UserScore>,
        users_state: Table<address, UserState>
    }

    public entry fun start_event( creator: &signer, start_time: u64 ) acquires GameData {

    }
}