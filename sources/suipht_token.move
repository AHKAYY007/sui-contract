module 0x1::suipht_token {
    // Import required modules and functions.
    use sui::object::{UID, new as new_uid};
    use sui::tx_context::TxContext;
    use sui::balance::{Balance, deposit, withdraw, zero};
    use sui::math::safe_add;
    use sui::transfer;
    use sui::coin::SUI;

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
        sui_balance: Balance<SuiphtToken>, // IMPORTANT: Ensure that type SUI is defined in your environment.
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
        // Ensure that the caller is the admin.
        assert!(ctx.sender() == admin.admin, 1);
        // Increase total supply using safe addition.
        token.total_supply = safe_add(token.total_supply, amount);
        // Deposit the minted amount into the token balance.
        deposit(&mut token.balance, amount);
    }

    /// Transfers tokens to another user.
    /// Withdraws the specified amount from the token balance and transfers it.
    public fun transfer(
        token: &mut SuiphtToken,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Withdraw returns a coin (resource) representing the withdrawn tokens.
        let coin = withdraw(&mut token.balance, amount);
        // Transfer the coin to the recipient.
        transfer::transfer(coin, recipient);
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
        // Withdraw tokens from the token balance for the pool.
        let _ = withdraw(&mut token.balance, initial_token_amount);
        // Create and return a new LiquidityPool.
        LiquidityPool {
            id: new_uid(ctx),
            token_balance: Balance { value: initial_token_amount },
            sui_balance: Balance { value: initial_sui_amount },
            owner: ctx.sender(),
        }
    }

    /// Adds liquidity to the pool.
    /// Withdraws tokens from the token balance and deposits both tokens and SUI into the pool balances.
    public fun add_liquidity(
        pool: &mut LiquidityPool,
        token: &mut SuiphtToken,
        token_amount: u64,
        sui_amount: u64,
        ctx: &mut TxContext
    ) {
        // Withdraw tokens from the user's token balance.
        let _ = withdraw(&mut token.balance, token_amount);
        // Deposit the tokens into the pool's token balance.
        deposit(&mut pool.token_balance, token_amount);
        // Deposit the SUI amount into the pool's SUI balance.
        deposit(&mut pool.sui_balance, sui_amount);
    }

    /// Removes liquidity (only the pool owner can remove liquidity).
    /// Withdraws tokens and SUI from the pool and transfers them to the recipient.
    public fun remove_liquidity(
        pool: &mut LiquidityPool,
        token_amount: u64,
        sui_amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Ensure that only the pool owner can remove liquidity.
        assert!(ctx.sender() == pool.owner, 6);
        // Withdraw the specified amounts from the pool.
        let token_coin = withdraw(&mut pool.token_balance, token_amount);
        let sui_coin = withdraw(&mut pool.sui_balance, sui_amount);
        // Transfer the withdrawn coins to the recipient.
        transfer::transfer(token_coin, recipient);
        transfer::transfer(sui_coin, recipient);
    }
}
