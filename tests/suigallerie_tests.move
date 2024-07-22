#[test_only]
module suigallerie::suigallerie_tests {
    use sui::coin;
    use sui::sui::SUI;
    use sui::test_scenario;
    use suigallerie::suigallerie;


    public struct TEST has drop {}

    #[test]
    fun test_suigallerie() {
        let sender = @0xABBA;
        let alice = @0xCAEE;
        let bob = @0xB0B;

        let mut scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, sender);
        {
            suigallerie::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            suigallerie::deploy_space<TEST>(&mut deploy_record, test_scenario::ctx(scenario));
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let test_coin = coin::mint_for_testing<TEST>(200_000_000_000, test_scenario::ctx(scenario));
            suigallerie::add_fund<TEST>(&mut space, test_coin, test_scenario::ctx(scenario));
            let gas_coin = coin::mint_for_testing<SUI>(100_000_000_000, test_scenario::ctx(scenario));
            suigallerie::add_gas<TEST>(&mut space, gas_coin, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 200_000_000_000, 1);
            assert!(suigallerie::gas_value<TEST>(&space) == 100_000_000_000, 2);
            test_scenario::return_shared(space);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            let mut times = 5;
            let mut users: vector<address> = vector::empty();
            let mut values: vector<u64> = vector::empty();
            while (times > 0) {
                vector::push_back(&mut users, bob);
                vector::push_back(&mut values, 1_000_000_000);
                times = times - 1;
            };
            suigallerie::airdrop<TEST>(&admin_cap, &deploy_record, &mut space, users, values, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 195_000_000_000, 3);
            assert!(suigallerie::gas_value<TEST>(&space) == 99_985_000_000, 4);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            suigallerie::withdraw_coin_to<TEST>(&admin_cap, &mut space, alice, 195_000_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 0, 5);
            suigallerie::withdraw_gas_to<TEST>(&admin_cap, &mut space, alice, 99_985_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::gas_value<TEST>(&space) == 0, 6);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure]
    fun test_suigallerie_not_enough_gas() {
        let sender = @0xABBA;
        let alice = @0xCAEE;
        let bob = @0xB0B;

        let mut scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, sender);
        {
            suigallerie::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            suigallerie::deploy_space<TEST>(&mut deploy_record, test_scenario::ctx(scenario));
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let test_coin = coin::mint_for_testing<TEST>(200_000_000_000, test_scenario::ctx(scenario));
            suigallerie::add_fund<TEST>(&mut space, test_coin, test_scenario::ctx(scenario));
            let gas_coin = coin::mint_for_testing<SUI>(50_000, test_scenario::ctx(scenario));
            suigallerie::add_gas<TEST>(&mut space, gas_coin, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 200_000_000_000, 1);
            assert!(suigallerie::gas_value<TEST>(&space) == 50_000, 2);
            test_scenario::return_shared(space);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            let mut times = 5;
            let mut users: vector<address> = vector::empty();
            let mut values: vector<u64> = vector::empty();
            while (times > 0) {
                vector::push_back(&mut users, bob);
                vector::push_back(&mut values, 1_000_000_000);
                times = times - 1;
            };
            suigallerie::airdrop<TEST>(&admin_cap, &deploy_record, &mut space, users, values, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 195_000_000_000, 3);
            assert!(suigallerie::gas_value<TEST>(&space) == 99_985_000_000, 4);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            suigallerie::withdraw_coin_to<TEST>(&admin_cap, &mut space, alice, 195_000_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 0, 5);
            suigallerie::withdraw_gas_to<TEST>(&admin_cap, &mut space, alice, 99_985_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::gas_value<TEST>(&space) == 0, 6);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
        };

        test_scenario::end(scenario_val);
    }

    #[test, expected_failure]
    fun test_suigallerie_not_enough_budget() {
        let sender = @0xABBA;
        let alice = @0xCAEE;
        let bob = @0xB0B;

        let mut scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, sender);
        {
            suigallerie::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            suigallerie::deploy_space<TEST>(&mut deploy_record, test_scenario::ctx(scenario));
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let test_coin = coin::mint_for_testing<TEST>(200, test_scenario::ctx(scenario));
            suigallerie::add_fund<TEST>(&mut space, test_coin, test_scenario::ctx(scenario));
            let gas_coin = coin::mint_for_testing<SUI>(100_000_000_000, test_scenario::ctx(scenario));
            suigallerie::add_gas<TEST>(&mut space, gas_coin, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 200, 1);
            assert!(suigallerie::gas_value<TEST>(&space) == 100_000_000_000, 2);
            test_scenario::return_shared(space);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let deploy_record = test_scenario::take_shared<suigallerie::DeployRecord>(scenario);
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            let mut times = 5;
            let mut users: vector<address> = vector::empty();
            let mut values: vector<u64> = vector::empty();
            while (times > 0) {
                vector::push_back(&mut users, bob);
                vector::push_back(&mut values, 1_000_000_000);
                times = times - 1;
            };
            suigallerie::airdrop<TEST>(&admin_cap, &deploy_record, &mut space, users, values, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 195_000_000_000, 3);
            assert!(suigallerie::gas_value<TEST>(&space) == 99_985_000_000, 4);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
            test_scenario::return_shared(deploy_record);
        };

        test_scenario::next_tx(scenario, sender);
        {
            let mut space = test_scenario::take_shared<suigallerie::Space<TEST>>(scenario);
            let admin_cap = test_scenario::take_from_sender<suigallerie::AdminCap>(scenario);
            suigallerie::withdraw_coin_to<TEST>(&admin_cap, &mut space, alice, 195_000_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::balance_value<TEST>(&space) == 0, 5);
            suigallerie::withdraw_gas_to<TEST>(&admin_cap, &mut space, alice, 99_985_000_000, test_scenario::ctx(scenario));
            assert!(suigallerie::gas_value<TEST>(&space) == 0, 6);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(space);
        };

        test_scenario::end(scenario_val);
    }

}
