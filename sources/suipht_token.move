module 0x1::suipht_token {
    // Import required modules and functions.
    use sui::object::{UID, new as new_uid};
    use sui::tx_context::TxContext;
    use sui::object::{ID, UID, new as new_uid};
    use sui::balance::{Balance, create, join, split, value, zero};
    use sui::coin::Coin;
    use sui::transfer;
    use sui::error;

    /// Admin struct to manage minting and liquidity pools.
    public struct TokenAdmin has key {
        id: UID,
        admin: address,
    }

    /// Struct representing our custom token.
    /// The `balance` holds the token balance as a resource of type Balance<SuiphtToken>.
    public struct SuiphtToken has key, store {
        id: UID,
        name: vector<u8>,
        symbol: vector<u8>,
        total_supply: u64,
        balance: Balance<SuiphtToken>,
    }

    /// Struct representing a liquidity pool for the token.
    /// It holds the pool’s token and SUI balances.
    public struct LiquidityPool has key, store {
        id: UID,
        token_balance: Balance<SuiphtToken>,
        sui_balance: Coin<SUI>,
        owner: address,
    }

    /// Initializes token admin.
    public fun create_admin(admin: address, ctx: &mut TxContext): TokenAdmin {
        TokenAdmin { id: new_uid(ctx), admin }
    }

    /// Initializes the token (only admin can call this).
    public fun create_token(
        admin: &TokenAdmin,
        name: vector<u8>,
        symbol: vector<u8>,
        ctx: &mut TxContext
    ): SuiphtToken {
        SuiphtToken {
            id: new_uid(ctx),
            name,
            symbol,
            total_supply: 0,
            balance: zero(),
        }
    }

    /// Mints new tokens (only admin can call this).
    /// Increases the total supply and deposits the minted amount into the token balance.
    public fun mint(
        admin: &TokenAdmin,
        token: &mut SuiphtToken,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(ctx.sender() == admin.admin, 1); // Only admin can mint
        token.total_supply = token.total_supply + amount; // Increase total supply
        
        let new_tokens = balance::create(amount);
        balance::join(&mut token.balance, new_tokens)
    }

    /// Transfers tokens to another user.
    /// Withdraws the specified amount from the token balance and transfers it.
    public fun transfer(
        token: &mut SuiphtToken,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check that the sender has enough balance
        assert!(balance::value(&token.balance) >= amount, 2); // Error code 2 for insufficient balance

        // Split the tokens to transfer
        let tokens_to_transfer = balance::split(&mut token.balance, amount);
        // Transfer the tokens to the recipient
        transfer::transfer(tokens_to_transfer, recipient);
    }

    /// Creates a liquidity pool (only admin can call this).
    /// Withdraws an initial token amount from the token balance and pairs it with SUI.
    public fun create_liquidity_pool(
        admin: &TokenAdmin,
        token: &mut SuiphtToken,
        initial_token_amount: u64,
        initial_sui_amount: u64,
        ctx: &mut TxContext
    ): LiquidityPool {
        // Ensure that only the admin can create a liquidity pool.
        assert!(ctx.sender() == admin.admin, 3);
        // Check that the token balance is sufficient
        assert!(balance::value(&token.balance) >= initial_token_amount, 4); // Error code 4 for insufficient balance
        // Deduct tokens from the token balance
        let tokens_for_pool = balance::split(&mut token.balance, initial_token_amount);

        // Deduct SUI coins from the transaction context
        let sui_coins = coin::take(ctx, initial_sui_amount);
        LiquidityPool {
            id: new_uid(ctx),
            token_balance: Balance { value: initial_token_amount },
            sui_balance: Balance { value: initial_sui_amount },
            owner: ctx.sender(),
        }
    }

   /// Adds liquidity to the pool
public fun add_liquidity(
    pool: &mut LiquidityPool,
    token: &mut SuiphtToken,
    token_amount: u64,
    sui_amount: u64,
    ctx: &mut TxContext
) {
    // Check that the token balance is sufficient
    assert!(balance::value(&token.balance) >= token_amount, 5); // Error code 5 for insufficient balance

    // Deduct tokens from the token balance
    let tokens_to_add = balance::split(&mut token.balance, token_amount);

    // Deduct SUI coins from the transaction context
    let sui_to_add = coin::take(ctx, sui_amount);

    // Add tokens and SUI to the pool
    balance::join(&mut pool.token_balance, tokens_to_add);
    coin::join(&mut pool.sui_balance, sui_to_add);
}

    /// Removes liquidity (only owner can remove liquidity)
public fun remove_liquidity(
    pool: &mut LiquidityPool,
    token_amount: u64,
    sui_amount: u64,
    recipient: address,
    ctx: &mut TxContext
) {
    // Only the pool owner can remove liquidity
    assert!(ctx.sender() == pool.owner, 6); // Error code 6 for unauthorized access

    // Check that the pool has sufficient tokens and SUI
    assert!(balance::value(&pool.token_balance) >= token_amount, 7); // Error code 7 for insufficient tokens
    assert!(coin::value(&pool.sui_balance) >= sui_amount, 8); // Error code 8 for insufficient SUI

    // Deduct tokens and SUI from the pool
    let tokens_to_transfer = balance::split(&mut pool.token_balance, token_amount);
    let sui_to_transfer = coin::split(&mut pool.sui_balance, sui_amount);

    // Transfer tokens and SUI to the recipient
    transfer::transfer(tokens_to_transfer, recipient);
    transfer::transfer(sui_to_transfer, recipient);
}
}
