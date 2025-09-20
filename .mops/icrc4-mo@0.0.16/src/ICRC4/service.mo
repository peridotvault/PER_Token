module {
  public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
  };

  public type Subaccount = Blob;

  public type TransferArgs =  {
    from_subaccount: ?Subaccount;
    to: Account;
    amount: Nat;
    fee: ?Nat;
    memo: ?Blob;
    created_at_time: ?Nat64;
  };

  /// Provides the input to a batch transaction
  public type TransferBatchArgs =  [TransferArgs];

public type TransferBatchError = {
      #BadBurn : {min_burn_amount : Nat};
      #BadFee : { expected_fee : Nat };
      #InsufficientFunds : { balance : Nat };
      #GenericBatchError : { error_code : Nat; message : Text };
      
      #TemporarilyUnavailable;
      #TooOld;
      #TooManyRequests : { limit: Nat };
      #CreatedInFuture : { ledger_time: Nat64 };
      #Duplicate : { duplicate_of : Nat }; //todo: should this be different for batch since the items can go into many transactions
      #GenericError : { error_code : Nat; message : Text };
  };

  public type TransferBatchResult = {
      #Ok : Nat;
      #Err : TransferBatchError;
  };

  public type TransferBatchResults = [?TransferBatchResult];

  public type BalanceQueryArgs = {
    accounts: [Account];
  };


  public type BalanceQueryResult = [(Account, Nat)]; 


  public type Service = actor {
    icrc4_transfer_batch : (TransferBatchArgs) -> async TransferBatchResults;
    icrc4_balance_of_batch : query (BalanceQueryResult) -> async  BalanceQueryResult;
    icrc4_maximum_update_batch_size : query (Nat) -> async ?Nat;
    icrc4_maximum_query_batch_size : query (Nat) -> async ?Nat;
  };
};