// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead

import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Star "mo:star/star";

import MapLib "mo:map/Map";
import SetLib "mo:map/Set";
import VecLib "mo:vector";

import ICRC1 "mo:icrc1-mo/ICRC1/";

module {

  /// Vector provides an interface to a vector-like collection.
  public let Vector = VecLib;

  /// Map provides an interface to a key-value storage collection.
  public let Map = MapLib;

  /// Set provides an interface to a set-like collection, storing unique elements.
  public let Set = SetLib;

  public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
  };

  public type Subaccount = Blob;

  ///Note: these are different than the ICRC1 Transfer args
  public type TransferArgs =  ICRC1.TransferArgs;

  /// Provides the input to a batch transaction
  public type TransferBatchArgs =  [TransferArgs];

  ///Possible Errors
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


  public type BalanceQueryResult = [Nat];

  /// Stats contains general statistics about the ledger and approvals in the system.
  public type Stats = {
    /// Shared ledger info with configurations.
    max_balances : Nat;
    max_transfers : Nat;
    fee : Fee;
  };

  /// Fee defines the structure of how fees are calculated and charged.
  public type Fee = {
    /// A fixed fee amount that is applied to transactions.
    #Fixed: Nat;
    /// Indicates fee structure is defined in the surrounding environment.
    #Environment;
    /// Fee is defined and managed by ICRC-1 standards.
    #ICRC1;
  };

  /// `TransferBatchNotification`
  ///
  /// Represents the notification for a batch transaction request
  public type TransferBatchNotification =  {
    from: Principal;
    transfers: [TransferArgs]
  };

  public type TransferBatchListener = <system>(notification: TransferBatchNotification, results: TransferBatchResults) -> ();

  public type CanBatchTransfer = ?{
    #Sync : <system>(notification: TransferBatchNotification) -> Result.Result<TransferBatchNotification, TransferBatchResults>;
    #Async : <system>(notification: TransferBatchNotification) -> async* Star.Star<TransferBatchNotification, TransferBatchResults>;
  };

  

  /// Environment defines the context in which the token ledger operates.
  public type Environment = {
    /// Reference to the ICRC-1 ledger interface.
    icrc1 : ICRC1.ICRC1;
    /// Optional fee calculating function.
    get_fee : ?GetFee;
    /// Optional synchronous or asynchronous functions triggered when transferring from an account.
    
  };

  public type GetFee = (State, Environment, TransferBatchNotification, ICRC1.TransferArgs) -> Balance;

  /// Value is a generic type capable of representing different values in a shared data structure.
  public type Value = {
    #Nat : Nat;
    #Int : Int;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
    #Map: [(Text, Value)];
  };


  /// UpdateLedgerInfoRequest defines requests that can update ledger configurations.
  public type UpdateLedgerInfoRequest = {
    #MaxBalances : Nat;
    #MaxTransfers : Nat;
    #Fee : Fee;
  };

  /// InitArgs represents the initialization arguments for setting up an ICRC1 token canister that includes ICRC4 standards.
  public type InitArgs = {
      max_balances : ?Nat;
      max_transfers : ?Nat;
      fee : ?Fee;
  };

  /// Balance represents numerical token balance.
  public type Balance = Nat;


  /// Transaction is a record that logs a transaction action.
  public type Transaction = ICRC1.Transaction;

  
  /// LedgerInfo contains mutable configurations for the ledger.
  public type LedgerInfo = {
    var max_balances : Nat;
    var max_transfers : Nat;
    var fee : Fee;
    var metadata : ?Value;
  };

  

  /// State represents the entire state of the ledger, containing ledger configurations, approvals, and indices.
  public type State = {
    ledger_info : LedgerInfo;
  };

  public type Service = actor {
    icrc4_transfer_batch : (TransferBatchArgs) -> async TransferBatchResults;
    icrc4_balance_of_batch : query (BalanceQueryResult) -> async  BalanceQueryResult;
    icrc4_maximum_update_batch_size : query (Nat) -> async ?Nat;
    icrc4_maximum_query_batch_size : query (Nat) -> async ?Nat;
  };


};