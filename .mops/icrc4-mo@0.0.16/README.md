# ICRC-4: Batch Transactions Class for Motoko

## Warning - While this this module has been running in production for over a year, It has not been audited and you should use it at your own risk.  If you would like to contribute to getting the library audited, please send an email to austin at panindustrial dot com.

## Introduction to ICRC-4 Class

The `ICRC-4` class is a Motoko implementation designed for the Internet Computer to handle batch processing of transfer transactions for the fungible tokens compliant with the ICRC-1 standard. This advancement in the token standard is focused on reducing the overhead of operations by allowing multiple transfers from and to multiple accounts in a single call, which greatly optimizes multi-account token transfers.

## Installation

Include the ICRC-4 class in your Motoko project using `mops`, a package manager for the Motoko programming language.

```sh
mops add icrc4-mo
```

## Basic Usage Example

```motoko
import ICRC1 "mo:icrc1-mo/ICRC1"; //ICRC4 requires ICRC1 for use
import ICRC4 "mo:icrc4-mo/ICRC4";

// Initialize ICRC-1
let icrc1 = ICRC1.ICRC1(...);

stable var icrc4_migration_state = ICRC1.init(ICRC4.initialState() , #v0_1_0(#id), _args, init_msg.caller);

let #v0_1_0(#data(icrc4_state_current)) = icrc4_migration_state;

private var _icrc4 : ?ICRC4.ICRC4 = null;

// Create ICRC-4 environment
let icrc4Env = {
  icrc1 = icrc1;
  get_fee = null;
};


func icrc4() : ICRC4.ICRC4 {
    switch(_icrc4){
      case(null){
        let initclass : ICRC4.ICRC4 = ICRC4.ICRC4(?icrc4_migration_state, Principal.fromActor(this), get_icrc4_environment());
        _icrc4 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };
```

The above pattern will allow your class to call icrc4().XXXXX to easily access the stable state of your class and you will not have to worry about pre or post upgrade methods.

### Init Args:

```
  /// Fee defines the structure of how fees are calculated and charged.
  public type Fee = {
    /// A fixed fee amount that is applied to transactions.
    #Fixed: Nat;
    /// Indicates fee structure is defined in the surrounding environment(See get_fee function).
    #Environment;
    /// Fee is defined and managed by ICRC-1 standards.
    #ICRC1;
  };

 public type InitArgs = {
      max_balances : ?Nat; // The maximum number of balances that can be requested in one query - defaults to 3000
      max_transfers : ?Nat; // The maximum number of transfers that can be requested in one query - defaults to 3000
      fee : ?Fee; // How to charge for fees.
  };
```

### Environment

The environment pattern lets you pass dynamic information about your environment to the class.

```

  // Environment defines the context in which the token ledger operates.
  public type Environment = {
    /// Reference to the ICRC-1 ledger interface.
    icrc1 : ICRC1.ICRC1;
    /// Optional fee calculating function.  The function will be called for each item in the batch and the resultant balance will be applied as the fee. ie you could return the base fee/number of transactions.
    get_fee : ?((State, Environment,  TransferBatchArgs, ICRC1.TransferArgs) -> Balance);
  };
```

## Class Functions

### Transfer Batch

To execute a batch transfer, use the `transfer_batch` function provided by ICRC-4. The arguments for the function should include details such as a list of transfers, a batch memo for deduplication, and the creation time.

```motoko
let transferBatchResult = await icrc4.transfer_batch_tokens(caller, {
  transfers = [ {
    { 
      from_subaccount = ...;
      to = ...; 
      amount = ...;
      fee = ...;
    },
    ...
  };
  memo = ...;
  created_at_time = ...;
], caller, null, null);
```

### Balance Batch Query

Retrieve multiple account balances by using the `balance_of_batch` function. Provide a list of accounts you wish to query.

```motoko
let balanceQueryResults = icrc4.balance_of_batch({
  accounts = vec { account1, account2, ... }
});
```

## Metadata and Ledger Information

Access the metadata and adjust ledger parameters using supported methods:

```motoko
// Fetch ledger information
let ledgerInfo = icrc4.get_ledger_info();

// Update ledger information
let updateSuccesses = icrc4.update_ledger_info(vec {
  #MaxTransfers(5000),
  #MaxBalances(5000),
  #Fee(#Fixed(5000 * e8s))
});

// Retrieve metadata
let currentMetadata = icrc4.metadata();
```

## Subscriptions

Register event listeners to trigger additional logic post-batch-transfer.

The class has a register_transfer_batch_listener endpoint that allows other objects to register an event listener and be notified whenever a token event occurs from one user to another.

The events are synchronous and cannot directly make calls to other canisters.  We suggest using them to set timers if notifications need to be sent using the Timers API.

```motoko
 public type TransferBatchListener = (notification: TransferBatchNotification, results: TransferBatchResult) -> ();


// Register a batch transfer listener
icrc4.register_transfer_batch_listener("my_namespace", func(notification: TransferBatchNotification, result : TransferBatchResult) {
  // Logic after batch transfer
});
```

## Overrides

The user may assign a function to intercept each transaction batch and each transaction just before it is committed to the transaction log.  These functions are optional. The user may manipulate the values and return them to the processing transaction and the new values will be used for the transaction block information and for notifying subscribed components.

By returning an #err from these functions you will effectively cancel the transaction and the caller will receive back a #GenericError for that request with the message you provide.

Wire these functions up by including them in the call to transfer_batch_tokens as the third and fourth parameter.

```
  public type CanBatchTransfer = ?{
    #Sync : (notification: TransferBatchNotification) -> Result.Result<TransferBatchNotification, Text>;
    #Async : (notification: TransferBatchNotification) -> async* Star.Star<TransferBatchNotification, Text>;
  };

  public type CanTransfer = ?{
    #Sync : ((trx: Value, trxtop: ?Value, notification: TransactionRequestNotification) -> Result.Result<(trx: Value, trxtop: ?Value, notification: TransactionRequestNotification), Text>);
    #Async : ((trx: Value, trxtop: ?Value, notification: TransactionRequestNotification) -> async* Star.Star<(trx: Value, trxtop: ?Value, notification: TransactionRequestNotification), Text>);
  };

  icrc4.trasfer_batch_tokens(caller, args, can_transfer, can_transfer_batch);
```

### Metadata Synchronization

After updating ledger settings, it's recommended to verify that the changes are reflected in the token metadata. You can retrieve the updated metadata using the `metadata()` function and cross-verify the updates.

## Security Considerations

While using ICRC-4, always validate necessary preconditions for transfers and ensure the caller has sufficient permissions and balances.  Batch transactions are NOT atomic and thus some transactions may execute while others may fail. Handle failures appropriately.

## Getting Help

For assistance, report issues or contribute to the development of this standard, reach out through the GitHub repository.

## Conclusion

Adopting the ICRC-4 class extends the capabilities of the ICRC-1 fungible token standard, providing efficient batch transaction processing, query optimizations, and event-driven architecture for developers on the Internet Computer.

For further details and best practices for implementing the ICRC-4 standard, please visit the [ICRC-4 Specification](https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-4/).

## Additional Notes

- Keep your dependencies updated and closely follow the changes in the official [ICRC-4 repository](https://github.com/dfinity/ICRC-4) for the latest features and security updates.
- Ensure to monitor the cycle costs when performing transactions and batch queries, as they may have higher usage than traditional icrc1 transactions.
- It is recommended to thoroughly test your implementation of ICRC-4 in a controlled environment before deploying to the main network.