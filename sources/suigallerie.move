module suigallerie::suigallerie {
    use std::type_name;
    use sui::table_vec::{Self, TableVec};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event::emit;

    // ======== Constants =========
    const VERSION: u64 = 1;
    const PER_GAS: u64 = 3_000_000;

    // ======== Types =========
    public struct DeployRecord has key {
        id: UID,
        version: u64,
        spaces: TableVec<ID>,
        per_gas: u64,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct Space<phantom T> has key {
        id: UID,
        version: u64,
        balance: Balance<T>,
        gas: Balance<SUI>,
    }

    // ======== Events =========
    public struct DeployEvent has copy, drop {
        deployer: address,
        space: ID,
    }

    public struct AddFund has copy, drop {
        space: ID,
        value: u64,
        coinType: std::ascii::String,
        sender: address,
    }

    public struct AddGas has copy, drop {
        space: ID,
        value: u64,
        sender: address,
    }

    public struct AirDrop has copy, drop {
        space: ID,
        sender: address,
    }

    // ======== Errors =========
    const EVersionMismatch: u64 = 0;
    const ENotSameLength: u64 = 1;

    // ======== Functions =========
    fun init(ctx: &mut TxContext) {
        let deployer = ctx.sender();

        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(admin_cap, deployer);

        let deploy_record = DeployRecord { 
            id: object::new(ctx),
            version: VERSION,
            spaces: table_vec::empty<ID>(ctx), 
            per_gas: PER_GAS, 
        };
        transfer::share_object(deploy_record);
    }

    public fun deploy_space_non_entry<T>(
        deploy_record: &mut DeployRecord, 
        ctx: &mut TxContext
    ): Space<T> {
        assert!(deploy_record.version == VERSION, EVersionMismatch);
        let space = Space<T> {
            id: object::new(ctx),
            version: VERSION,
            balance: balance::zero<T>(),
            gas: balance::zero<SUI>(),
        };
        let space_id = object::id(&space);
        table_vec::push_back<ID>(&mut deploy_record.spaces, space_id);
        emit(DeployEvent {
            deployer: ctx.sender(),
            space: space_id,
        });
        space
    }

    #[allow(lint(share_owned))]
    public entry fun deploy_space<T>(deploy_record: &mut DeployRecord, ctx: &mut TxContext) {
        let space = deploy_space_non_entry<T>(deploy_record, ctx);
        transfer::share_object(space);
    }

    public fun add_fund_non_entry<T>(space: &mut Space<T>, fund: Coin<T>, ctx: &mut TxContext) {
        assert!(space.version == VERSION, EVersionMismatch);
        let value = coin::value<T>(&fund);
        balance::join<T>(&mut space.balance, coin::into_balance<T>(fund));
        emit(AddFund {
            space: object::id(space),
            value: value,
            coinType: type_name::into_string(type_name::get_with_original_ids<T>()),
            sender: ctx.sender(),
        });
    }

    public entry fun add_fund<T>(space: &mut Space<T>, fund: Coin<T>, ctx: &mut TxContext) {
        add_fund_non_entry<T>(space, fund, ctx);
    }

    public entry fun add_gas<T>(space: &mut Space<T>, gas: Coin<SUI>, ctx: &mut TxContext) {
        assert!(space.version == VERSION, EVersionMismatch);
        let value = coin::value<SUI>(&gas);
        balance::join<SUI>(&mut space.gas, coin::into_balance<SUI>(gas));
        emit(AddGas {
            space: object::id(space),
            value: value,
            sender: ctx.sender(),
        });
    }

    public fun withdraw_coin_to<T>(_: &AdminCap, space: &mut Space<T>, value: u64, recipient: address, ctx: &mut TxContext) {
        let return_coin = coin::take<T>(&mut space.balance, value, ctx);
        transfer::public_transfer(return_coin, recipient);
    }

    public fun withdraw_gas_to<T>(_: &AdminCap, space: &mut Space<T>, value: u64, recipient: address, ctx: &mut TxContext) {
        let return_coin = coin::take<SUI>(&mut space.gas, value, ctx);
        transfer::public_transfer(return_coin, recipient);
    }

    #[allow(lint(self_transfer))]
    public fun airdrop<T>(_: &AdminCap, deploy_record: &DeployRecord, space: &mut Space<T>, mut users: vector<address>, mut values: vector<u64>, ctx: &mut TxContext) {
        assert!(vector::length(&users) == vector::length(&values), ENotSameLength);
        let mut count: u64 = vector::length(&users);
        let gas_budget: u64 = count * deploy_record.per_gas;
        let take_gas = coin::take<SUI>(&mut space.gas, gas_budget, ctx);
        transfer::public_transfer(take_gas, ctx.sender());

        while (count > 0) {
            let recipient = vector::pop_back<address>(&mut users);
            let value = vector::pop_back<u64>(&mut values);
            let airdrop_coin = coin::take<T>(&mut space.balance, value, ctx);
            transfer::public_transfer(airdrop_coin, recipient);
            count = count - 1;
        };

        emit(AirDrop {
            space: object::id(space),
            sender: ctx.sender(),
        });
    }

    public fun set_per_gas(_: &AdminCap, deploy_record: &mut DeployRecord, per_gas: u64) {
        deploy_record.per_gas = per_gas;
    }

    // ======== Read Functions =========
    public fun balance_value<T>(space: &Space<T>): u64 {
        balance::value<T>(&space.balance)
    }

    public fun gas_value<T>(space: &Space<T>): u64 {
        balance::value<SUI>(&space.gas)
    }

    /*
    // ======== Upgrade Functions for the future =========
    public fun upgrade_deploy_record(deploy_record: &mut DeployRecord) {
        assert!(deploy_record.version < VERSION, EVersionMismatch);
        deploy_record.version = VERSION;
    }

    public fun upgrade_space<T>(space: &mut Space<T>) {
        assert!(space.version < VERSION, EVersionMismatch);
        space.version = VERSION;
    }
    */

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
