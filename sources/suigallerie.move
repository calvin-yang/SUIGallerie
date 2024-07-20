module suigallerie::suigallerie {
    use std::type_name;
    use sui::table_vec::{Self, TableVec};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event::emit;

    // ======== Constants =========
    const VERSION: u64 = 1;
    const PER_GAS: u64 = 100_000;

    // ======== Types =========
    public struct DeployRecord has key {
        id: UID,
        version: u64,
        spaces: TableVec<ID>,
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

    public struct SpaceOwner has key, store {
        id: UID,
        to: ID,
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
    const EOwnership: u64 = 0;
    const EVersionMismatch: u64 = 1;
    const ENotSameLength: u64 = 2;

    // ======== Functions =========
    fun init(ctx: &mut TxContext) {
        let deployer = ctx.sender();

        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(admin_cap, deployer);

        let deploy_record = DeployRecord { 
            id: object::new(ctx),
            version: VERSION,
            spaces: table_vec::empty<ID>(ctx),  
        };
        transfer::share_object(deploy_record);
    }

    public fun deploy_space_non_entry<T>(deploy_record: &mut DeployRecord, ctx: &mut TxContext): (Space<T>, SpaceOwner) {
        assert!(deploy_record.version == VERSION, EVersionMismatch);
        let space = Space<T> {
            id: object::new(ctx),
            version: VERSION,
            balance: balance::zero<T>(),
            gas: balance::zero<SUI>(),
        };
        let space_id = object::id(&space);
        let space_owner = SpaceOwner {
            id: object::new(ctx),
            to: space_id,
        };
        table_vec::push_back<ID>(&mut deploy_record.spaces, space_id);
        emit(DeployEvent {
            deployer: ctx.sender(),
            space: space_id,
        });
        (space, space_owner)
    }

    #[allow(lint(share_owned))]
    public entry fun deploy_space<T>(deploy_record: &mut DeployRecord, ctx: &mut TxContext) {
        let (space, space_owner) = deploy_space_non_entry<T>(deploy_record, ctx);
        transfer::share_object(space);
        transfer::public_transfer(space_owner, ctx.sender());
    }

    public fun add_fund_non_entry<T>(space_owner: &SpaceOwner, space: &mut Space<T>, fund: Coin<T>, ctx: &mut TxContext) {
        assert!(space_owner.to == object::id(space), EOwnership);
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

    public entry fun add_fund<T>(space_owner: &SpaceOwner, space: &mut Space<T>, fund: Coin<T>, ctx: &mut TxContext) {
        add_fund_non_entry<T>(space_owner, space, fund, ctx);
    }

    public entry fun add_gas<T>(space_owner: &SpaceOwner, space: &mut Space<T>, gas: Coin<SUI>, ctx: &mut TxContext) {
        assert!(space_owner.to == object::id(space), EOwnership);
        assert!(space.version == VERSION, EVersionMismatch);
        let value = coin::value<SUI>(&gas);
        balance::join<SUI>(&mut space.gas, coin::into_balance<SUI>(gas));
        emit(AddGas {
            space: object::id(space),
            value: value,
            sender: ctx.sender(),
        });
    }

    public fun burn_ownership(space_owner: SpaceOwner) {
        let SpaceOwner {
            id,
            to: _,
        } = space_owner;
        object::delete(id);
    }

    public fun withdraw_all_to<T>(_: &AdminCap, space: &mut Space<T>, recipient: address, ctx: &mut TxContext) {
        let total_value = balance::value<T>(&space.balance);
        let return_coin = coin::take<T>(&mut space.balance, total_value, ctx);
        transfer::public_transfer(return_coin, recipient);
    }

    #[allow(lint(self_transfer))]
    public fun airdrop<T>(_: &AdminCap, space: &mut Space<T>, mut users: vector<address>, mut values: vector<u64>, ctx: &mut TxContext) {
        assert!(vector::length(&users) == vector::length(&values), ENotSameLength);
        let mut count: u64 = vector::length(&users);
        let gas_budget: u64 = count * PER_GAS;
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
}
