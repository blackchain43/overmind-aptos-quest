/*
    In the first place, this quest requires from you complete the smart contract following provided hints (TODOs)
    After that, you should answer the four questions located in "QUESTIONS AND ANSWERS" section and type your answers
        in the corresponding consts with prefix "USER_ANSWER" in capability_heist module.
*/
module overmind::capability_heist {
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::aptos_hash;
    use aptos_std::capability;
    use aptos_framework::account::{Self, SignerCapability};
    use std::vector;

    friend overmind::capability_heist_test;

    ////////////
    // ERRORS //
    ////////////

    const ERROR_ACCESS_DENIED: u64 = 0;
    const ERROR_ROBBER_NOT_INITIALIZED: u64 = 1;
    const ERROR_INCORRECT_ANSWER: u64 = 2;

    // Seed for PDA account
    const SEED: vector<u8> = b"CapabilityHeist";

    ///////////////////////////
    // QUESTIONS AND ANSWERS //
    ///////////////////////////

    const ENTER_BANK_QUESTION: vector<u8> = b"What function is used to initialize a capability? The answer should start with a lower-case letter";
    const ENTER_BANK_ANSWER: vector<u8> = x"811d26ef9f4bfd03b9f25f0a8a9fa7a5662460773407778f2d10918037194536091342f3724a9db059287c0d06c6942b66806163964efc0934d7246d1e4a570d";

    const TAKE_HOSTAGE_QUESTION: vector<u8> = b"Can you acquire a capability if the feature is not defined in the module you're calling from? The answer should start with a capital letter (Yes/No)";
    const TAKE_HOSTAGE_ANSWER: vector<u8> = x"eba903d4287aaaed303f48e14fa1e81f3307814be54503d4d51e1c208d55a1a93572f2514d1493b4e9823e059230ba7369e66deb826a751321bbf23b78772c4a";

    const GET_KEYCARD_QUESTION: vector<u8> = b"How many ways are there to obtain a capability? The answer should contain only digits";
    const GET_KEYCARD_ANSWER: vector<u8> = x"564e1971233e098c26d412f2d4e652742355e616fed8ba88fc9750f869aac1c29cb944175c374a7b6769989aa7a4216198ee12f53bf7827850dfe28540587a97";

    const OPEN_VAULT_QUESTION: vector<u8> = b"Can capability be stored in the global storage? The answer should start with a capital letter (Yes/No)";
    const OPEN_VAULT_ANSWER: vector<u8> = x"51d13ec71721d968037b05371474cbba6e0acb3d336909662489d0ff1bf58b028b67b3c43e04ff2aa112529e2b6d78133a4bb2042f9c685dc9802323ebd60e10";

    const ENTER_BANK_USER_ANSWER: vector<u8> = b"create";
    const TAKE_HOSTAGE_USER_ANSWER: vector<u8> = b"Yes";
    const GET_KEYCARD_USER_ANSWER: vector<u8> = b"2";
    const OPEN_VAULT_USER_ANSWER: vector<u8> = b"No";

    /////////////////////////
    // CAPABILITY FEATURES //
    /////////////////////////

    struct EnterBank has drop {}
    struct TakeHostage has drop {}
    struct GetKeycard has drop {}
    struct OpenVault has drop {}

    /*
        Struct representing a player of the game
    */
    struct Robber has key {
        // Capability of a PDA account
        cap: SignerCapability
    }

    /*
        Initializes smart contract by creating a PDA account and capabilities
        @param robber - player of the game
    */
    public entry fun init(robber: &signer) {
        //  Assert the signer is the valid robber
        assert_valid_robber(robber);

        //  Create a resource account
        let (resource_account, resource_account_cap) = account::create_resource_account(robber, SEED);

        //  Create all the four capabilities
        capability::create<EnterBank>(&resource_account, &EnterBank{});
        capability::create<TakeHostage>(&resource_account, &TakeHostage{});
        capability::create<GetKeycard>(&resource_account, &GetKeycard{});
        capability::create<OpenVault>(&resource_account, &OpenVault{});

        //  Move Robber to the signer
        move_to(
            robber,
            Robber {
                cap: resource_account_cap
            }
        );
    }

    /*
        Verifies answer for the first question and delegates EnterBank capability to the robber
        @param robber - player of the game
        @param answer - answer to the ENTER_BANK_QUESTION question
    */
    public entry fun enter_bank(robber: &signer) acquires Robber {
        //  Create a variable holding answer for ENTER_BANK_QUESTION
        let actual_answer = string::utf8(ENTER_BANK_USER_ANSWER);

        //  Assert Robber is initialized
        assert_robber_initialized(robber);

        //  Assert the answer is correct
        assert_answer_is_correct(&ENTER_BANK_ANSWER, &actual_answer);

        //  Delegate EnterBank capability to the robber
        delegate_capability<EnterBank>(robber, &EnterBank{});
        
    }

    /*
        Verifies answer for the second question and delegates TakeHostage capability to the robber
        @param robber - player of the game
        @param answer - answer to the TAKE_HOSTAGE_QUESTION question
    */
    public entry fun take_hostage(robber: &signer) acquires Robber {
        //  Create a variable holding answer for TAKE_HOSTAGE_QUESTION
        let actual_answer = string::utf8(TAKE_HOSTAGE_USER_ANSWER);

        //  Assert Robber is initialized
        assert_robber_initialized(robber);

        //  Acquire capability from the previous question by the robber
        capability::acquire(robber, &EnterBank{});

        //  Assert the answer is correct
        assert_answer_is_correct(&TAKE_HOSTAGE_ANSWER, &actual_answer);

        //  Delegate TakeHostage capability to the robber
        delegate_capability<TakeHostage>(robber, &TakeHostage{});
    }

    /*
        Verifies answer for the third question and delegates GetKeycard capability to the robber
        @param robber - player of the game
        @param answer - answer to the GET_KEYCARD_QUESTION question
    */
    public entry fun get_keycard(robber: &signer) acquires Robber {
        //  Create a variable holding answer for GET_KEYCARD_QUESTION
        let actual_answer = string::utf8(GET_KEYCARD_USER_ANSWER);

        //  Assert Robber is initialized
        assert_robber_initialized(robber);

        //  Acquire capabilities from the previous questions by the robber
        capability::acquire(robber, &EnterBank{});
        capability::acquire(robber, &TakeHostage{});

        //  Assert the answer is correct
        assert_answer_is_correct(&GET_KEYCARD_ANSWER, &actual_answer);

        //  Delegate GetKeycard capability to the robber
        delegate_capability<GetKeycard>(robber, &GetKeycard{});
    }

    /*
        Verifies answer for the fourth question and delegates OpenVault capability to the robber
        @param robber - player of the game
        @param answer - answer to the OPEN_VAULT_QUESTION question
    */
    public entry fun open_vault(robber: &signer) acquires Robber {
        //  Create a variable holding answer for OPEN_VAULT_QUESTION
        let actual_answer = string::utf8(OPEN_VAULT_USER_ANSWER);

        //  Assert Robber is initialized
        assert_robber_initialized(robber);

        //  Acquire capabilities from the previous questions by the robber
        capability::acquire(robber, &EnterBank{});
        capability::acquire(robber, &TakeHostage{});
        capability::acquire(robber, &GetKeycard{});

        //  Assert the answer is correct
        assert_answer_is_correct(&OPEN_VAULT_ANSWER, &actual_answer);

        //  Delegate OpenVault capability to the robber
        delegate_capability<OpenVault>(robber, &OpenVault{});
    }

    /*
        Gives the player provided capability
        @param robber - player of the game
        @param feature - capability feature to be given to the player
    */
    public fun delegate_capability<Feature>(
        robber: &signer,
        feature: &Feature
    ) acquires Robber {
        //  Delegate a capability with provided feature to the robber
        let robber_resource = borrow_global<Robber>(signer::address_of(robber));
        let resource_account_signer = &account::create_signer_with_capability(&robber_resource.cap);
        let cap = capability::acquire<Feature>(resource_account_signer, feature);
        capability::delegate<Feature>(cap, feature, robber);
    }

    /*
        Gets user's answers and creates a hash out of it
        @returns - SHA3_512 hash of user's answers
    */
    public fun get_flag(): vector<u8> {
        //  Create empty vector
        let answers = vector::empty<u8>();

        //  Push user's answers to the vector
        vector::for_each_ref(&vector[
            ENTER_BANK_USER_ANSWER, 
            TAKE_HOSTAGE_USER_ANSWER,
            GET_KEYCARD_USER_ANSWER,
            OPEN_VAULT_USER_ANSWER,
        ], |answer| {
            let answer: &vector<u8> = answer;
            vector::append(&mut answers, *answer);
        });

        //  Return SHA3_512 hash of the vector
        aptos_hash::sha3_512(answers)

    }

    /*
        Checks if Robber resource exists under the provided address
        @param robber_address - address of the player
        @returns - true if it exists, otherwise false
    */
    public(friend) fun check_robber_exists(robber_address: address): bool {
        // Check if Robber resource exists in robber_address
        exists<Robber>(robber_address)
    }

    /*
        EnterBank constructor
    */
    public(friend) fun new_enter_bank(): EnterBank {
        //  Return EnterBank instance
        EnterBank{}
    }

    /*
        TakeHostage constructor
    */
    public(friend) fun new_take_hostage(): TakeHostage {
        //  Return TakeHostage instance
        TakeHostage{}
    }

    /*
        GetKeycard constructor
    */
    public(friend) fun new_get_keycard(): GetKeycard {
        //  Return GetKeycard instance
        GetKeycard{}
    }

    /*
        OpenVault constructor
    */
    public(friend) fun new_open_vault(): OpenVault {
        //  Return OpenVault instance
        OpenVault{}
    }

    /////////////
    // ASSERTS //
    /////////////

    inline fun assert_valid_robber(robber: &signer) {
        //  Assert that address of the robber is the same as in Move.toml
        assert!(signer::address_of(robber) == @robber, ERROR_ACCESS_DENIED);
    }

    inline fun assert_robber_initialized(robber: &signer) {
        //  Assert that Robber resource exists at robber's address
        assert!(exists<Robber>(signer::address_of(robber)), ERROR_ROBBER_NOT_INITIALIZED);
    }

    inline fun assert_answer_is_correct(expected_answer: &vector<u8>, actual_answer: &String) {
        //  Assert that SHA3_512 hash of actual_answer is the same as expected_answer
        assert!(*expected_answer == aptos_hash::sha3_512(*string::bytes(actual_answer)) , ERROR_INCORRECT_ANSWER);
    }
}
