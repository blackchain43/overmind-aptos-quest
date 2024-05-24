module overmind::birthday_bot {
    use aptos_std::table::Table;
    use std::signer;
    // use std::error;
    use aptos_framework::account;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_account;

    //
    // Errors
    //
    const ERROR_DISTRIBUTION_STORE_EXIST: u64 = 0;
    const ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_LENGTHS_NOT_EQUAL: u64 = 2;
    const ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST: u64 = 3;
    const ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED: u64 = 4;

    // Static seed
    const DISTRIBUTION_SEED: vector<u8> = b"BIRTHDAY";

    //
    // Data structures
    //
    struct BirthdayGift has drop, store {
        amount: u64,
        birthday_timestamp_seconds: u64,
    }

    struct DistributionStore has key {
        birthday_gifts: Table<address, BirthdayGift>,
        signer_capability: account::SignerCapability,
    }

    //
    // Assert functions
    //
    public fun assert_distribution_store_exists(
        account_address: address,
    ) {
        //  assert that `DistributionStore` exists
        assert!(exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST);
    }

    public fun assert_distribution_store_does_not_exist(
        account_address: address,
    ) {
        //  assert that `DistributionStore` does not exist
        assert!(!exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_EXIST);
    }

    public fun assert_lengths_are_equal(
        addresses: vector<address>,
        amounts: vector<u64>,
        timestamps: vector<u64>
    ) {
        //  assert that the lengths of `addresses`, `amounts`, and `timestamps` are all equal
        let addresses_length = vector::length(&addresses);
        assert!(vector::length(&amounts) == addresses_length && vector::length(&timestamps) == addresses_length, ERROR_LENGTHS_NOT_EQUAL);
    }

    public fun assert_birthday_gift_exists(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        //  assert that `birthday_gifts` exists
        let distribution_store = borrow_global<DistributionStore>(distribution_address);
        assert!(table::contains(&distribution_store.birthday_gifts, address), ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST);

    }

    public fun assert_birthday_timestamp_seconds_has_passed(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        //  assert that the current timestamp is greater than or equal to `birthday_timestamp_seconds`
        let distribution_store = borrow_global<DistributionStore>(distribution_address);
        let birthday_gift_info = table::borrow(&distribution_store.birthday_gifts, address);
        assert!(birthday_gift_info.birthday_timestamp_seconds <= timestamp::now_seconds(), ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED);
    }

    //
    // Entry functions
    //
    /**
    * Initializes birthday gift distribution contract
    * @param account - account signer executing the function
    * @param addresses - list of addresses that can claim their birthday gifts
    * @param amounts  - list of amounts for birthday gifts
    * @param birthday_timestamps - list of birthday timestamps in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun initialize_distribution(
        account: &signer,
        addresses: vector<address>,
        amounts: vector<u64>,
        birthday_timestamps: vector<u64>
    ) {
        //  check `DistributionStore` does not exist
        let account_addr = signer::address_of(account);
        assert_distribution_store_does_not_exist(account_addr);

        //  check all lengths of `addresses`, `amounts`, and `birthday_timestamps` are equal
        assert_lengths_are_equal(addresses, amounts, birthday_timestamps);

        //  create resource account
        let (resource_account, resource_account_cap) = account::create_resource_account(account, DISTRIBUTION_SEED);

        //  register Aptos coin to resource account
        coin::register<AptosCoin>(&resource_account);

        //  loop through the lists and push items to birthday_gifts table
        let birthday_gifts = table::new<address, BirthdayGift>();
        let addresses_len = vector::length(&addresses);
        let i = 0;
        while (i < addresses_len) {
            let addr = *vector::borrow(&addresses, i);
            let amount = *vector::borrow(&amounts, i);
            let birthday_timestamp_seconds = *vector::borrow(&birthday_timestamps, i);
            table::add(&mut birthday_gifts, addr, BirthdayGift{
                amount,
                birthday_timestamp_seconds
            });
            i = i + 1;
        };

        //  transfer the sum of all items in `amounts` from initiator to resource account
        let coins = coin::withdraw<AptosCoin>(account, vector::fold(amounts, 0, |a, b| a + b));
        coin::deposit(signer::address_of(&resource_account), coins);

        //  move_to resource `DistributionStore` to account signer
        move_to(
           account,
           DistributionStore {
            birthday_gifts,
            signer_capability: resource_account_cap
           } 
        );
    }

    /**
    * Add birthday gift to `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - address that can claim the birthday gift
    * @param amount  - amount for the birthday gift
    * @param birthday_timestamp_seconds - birthday timestamp in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun add_birthday_gift(
        account: &signer,
        address: address,
        amount: u64,
        birthday_timestamp_seconds: u64
    ) acquires DistributionStore {
        //  check that the distribution store exists
        let account_addr = signer::address_of(account);
        assert_distribution_store_exists(account_addr);

        //  set new birthday gift to new `amount` and `birthday_timestamp_seconds` (birthday_gift already exists, sum `amounts` and override the `birthday_timestamp_seconds`
        let distribution_store = borrow_global_mut<DistributionStore>(account_addr);
        if(!table::contains(&distribution_store.birthday_gifts, address)){
            table::add(&mut distribution_store.birthday_gifts, address, BirthdayGift{
                amount,
                birthday_timestamp_seconds
            });
        } else {
            let birthday_gift_info = table::borrow_mut(&mut distribution_store.birthday_gifts, address);
            birthday_gift_info.birthday_timestamp_seconds = birthday_timestamp_seconds;
            birthday_gift_info.amount = birthday_gift_info.amount + amount;
        };

        //  transfer the `amount` from initiator to resource account
        let resource_account_addr = account::get_signer_capability_address(&distribution_store.signer_capability);
        aptos_account::transfer(account, resource_account_addr, amount);
    }

    /**
    * Remove birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - `birthday_gifts` address
    **/
    public entry fun remove_birthday_gift(
        account: &signer,
        address: address,
    ) acquires DistributionStore {
        // check that the distribution store exists
        let account_addr = signer::address_of(account);
        assert_distribution_store_exists(account_addr);

        //  if `birthday_gifts` exists, remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let distribution_store = borrow_global_mut<DistributionStore>(account_addr);
        if(table::contains(&distribution_store.birthday_gifts, address)){
            let birthday_gift_info = table::remove(&mut distribution_store.birthday_gifts, address);
            let resource_account_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
            aptos_account::transfer(&resource_account_signer, account_addr, birthday_gift_info.amount);
        };
    }

    /**
    * Claim birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param distribution_address - distribution contract address
    **/
    public entry fun claim_birthday_gift(
        account: &signer,
        distribution_address: address,
    ) acquires DistributionStore {
        //  check that the distribution store exists
        let account_addr = signer::address_of(account);
        assert_distribution_store_exists(distribution_address);

        //  check that the `birthday_gift` exists
        assert_birthday_gift_exists(distribution_address, account_addr);

        //  check that the `birthday_timestamp_seconds` has passed
        assert_birthday_timestamp_seconds_has_passed(distribution_address, account_addr);

        //  remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let distribution_store = borrow_global_mut<DistributionStore>(distribution_address);
        let birthday_gift_info = table::remove(&mut distribution_store.birthday_gifts, account_addr);
        let resource_account_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
        aptos_account::transfer(&resource_account_signer, account_addr, birthday_gift_info.amount);
    }
}
