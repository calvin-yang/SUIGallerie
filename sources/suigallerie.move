module suigallerie::suigallerie {
    use std::type_name;
    use sui::table::{Self, Table};
    use sui::table_vec::{Self, TableVec};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::event::emit;

    // ======== Constants =========
    const VERSION: u64 = 1;

    // ======== Types =========
    public struct DeployRecord has key {
        id: UID,
        version: u64,
        campaigns: TableVec<ID>,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct Campaign<phantom T> has key {
        id: UID,
        version: u64,
        balance: Balance<T>,
        calculate: Table<address, u64>,
        participants: TableVec<address>,
        remain: u64,
    }

    public struct CampaignOwner has key, store {
        id: UID,
        to: ID,
    }

    // ======== Events =========
    public struct DeployEvent has copy, drop {
        deployer: address,
        campaign: ID,
    }

    public struct AddFund has copy, drop {
        campaign: ID,
        value: u64,
        coinType: std::ascii::String,
        sender: address,
    }

    public struct AirDrop has copy, drop {
        campaign: ID,
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
            campaigns: table_vec::empty<ID>(ctx),  
        };
        transfer::share_object(deploy_record);
    }

    public fun deploy_campaign_non_entry<T>(deploy_record: &mut DeployRecord, ctx: &mut TxContext): CampaignOwner {
        assert!(deploy_record.version == VERSION, EVersionMismatch);
        let campaign = Campaign<T> {
            id: object::new(ctx),
            version: VERSION,
            balance: balance::zero<T>(),
            calculate: table::new<address, u64>(ctx),
            participants: table_vec::empty<address>(ctx),
            remain: 0,
        };
        let campaign_id = object::id(&campaign);
        let campaign_owner = CampaignOwner {
            id: object::new(ctx),
            to: campaign_id,
        };
        table_vec::push_back<ID>(&mut deploy_record.campaigns, campaign_id);
        transfer::share_object(campaign);
        emit(DeployEvent {
            deployer: ctx.sender(),
            campaign: campaign_id,
        });
        campaign_owner
    }

    public entry fun deploy_campaign<T>(deploy_record: &mut DeployRecord, ctx: &mut TxContext) {
        let campaign_owner = deploy_campaign_non_entry<T>(deploy_record, ctx);
        transfer::public_transfer(campaign_owner, ctx.sender());
    }

    public fun add_fund_non_entry<T>(campaign_owner: &CampaignOwner, campaign: &mut Campaign<T>, fund: Coin<T>, ctx: &mut TxContext) {
        assert!(campaign_owner.to == object::id(campaign), EOwnership);
        assert!(campaign.version == VERSION, EVersionMismatch);
        let value = coin::value<T>(&fund);
        balance::join<T>(&mut campaign.balance, coin::into_balance<T>(fund));
        campaign.remain = campaign.remain + value;
        emit(AddFund {
            campaign: object::id(campaign),
            value: value,
            coinType: type_name::into_string(type_name::get_with_original_ids<T>()),
            sender: ctx.sender(),
        });
    }

    public entry fun add_fund<T>(campaign_owner: &CampaignOwner, campaign: &mut Campaign<T>, fund: Coin<T>, ctx: &mut TxContext) {
        add_fund_non_entry<T>(campaign_owner, campaign, fund, ctx);
    }

    public fun one_add_user<T>(campaign_owner: &CampaignOwner, campaign: &mut Campaign<T>, user: address, value: u64) {
        assert!(campaign_owner.to == object::id(campaign), EOwnership);
        assert!(campaign.version == VERSION, EVersionMismatch);

        add_user(campaign, user, value);
    }

    public fun batch_add_user<T>(campaign_owner: &CampaignOwner, campaign: &mut Campaign<T>, mut users: vector<address>, value: u64) {
        assert!(campaign_owner.to == object::id(campaign), EOwnership);
        assert!(campaign.version == VERSION, EVersionMismatch);

        while(vector::length(&users) > 0 && campaign.remain > 0) {
            let user = vector::pop_back<address>(&mut users);
            add_user(campaign, user, value);
        };
    }

    public fun vector_add_user<T>(campaign_owner: &CampaignOwner, campaign: &mut Campaign<T>, mut users: vector<address>, mut values: vector<u64>) {
        assert!(campaign_owner.to == object::id(campaign), EOwnership);
        assert!(campaign.version == VERSION, EVersionMismatch);
        assert!(vector::length(&users) == vector::length(&values), ENotSameLength);

        while(vector::length(&users) > 0 && campaign.remain > 0) {
            let user = vector::pop_back<address>(&mut users);
            let value = vector::pop_back<u64>(&mut values);
            add_user(campaign, user, value);
        };
    } 

    fun add_user<T>(campaign: &mut Campaign<T>, user: address, mut value: u64) {
        if (table::contains<address, u64>(&campaign.calculate, user)) {
            let value_former = table::borrow_mut<address, u64>(&mut campaign.calculate, user);
            campaign.remain = campaign.remain + *value_former;
            if (campaign.remain < value) {
                value = campaign.remain;
            };
            campaign.remain = campaign.remain - value;
            *value_former = value;
        } else {
            if (campaign.remain < value) {
                value = campaign.remain;
            };
            campaign.remain = campaign.remain - value;
            table_vec::push_back<address>(&mut campaign.participants, user);
            table::add<address, u64>(&mut campaign.calculate, user, value);
        }
    }

    public fun burn_ownership(campaign_owner: CampaignOwner) {
        let CampaignOwner {
            id,
            to: _,
        } = campaign_owner;
        object::delete(id);
    }

    public fun withdraw_all_to<T>(_: &AdminCap, campaign: &mut Campaign<T>, recipient: address, ctx: &mut TxContext) {
        let total_value = balance::value<T>(&campaign.balance);
        let return_coin = coin::take<T>(&mut campaign.balance, total_value, ctx);
        transfer::public_transfer(return_coin, recipient);
    }

    public fun airdrop<T>(_: &AdminCap, campaign: &mut Campaign<T>, mut times: u64, ctx: &mut TxContext) {
        while (times > 0 && table_vec::length(&campaign.participants) > 0) {
            let recipient = table_vec::pop_back<address>(&mut campaign.participants);
            let value = table::remove<address, u64>(&mut campaign.calculate, recipient);
            let return_coin = coin::take<T>(&mut campaign.balance, value, ctx);
            transfer::public_transfer(return_coin, recipient);
            times = times - 1;
        };
        emit(AirDrop {
            campaign: object::id(campaign),
            sender: ctx.sender(),
        });
    }


}
