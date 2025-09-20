import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import ICRC1 "mo:icrc1-mo/ICRC1/";

import RepIndy "mo:rep-indy-hash";
import Star "mo:star/star";
import Vec "mo:vector";

import Migration "./migrations";
import MigrationTypes "./migrations/types";

/// The ICRC4 class with all the functions for creating an
/// ICRC4 token on the Internet Computer
module {

  let debug_channel = {
    announce = false;
    transfer = true;
    approve = true;
  };

  /// # State
  ///
  /// Encapsulates the entire ledger state across versions, facilitating data migration.
  /// It is a variant that includes possible format versions of the ledger state, enabling seamless upgrades to the system.
  ///
  /// ## Example
  ///
  /// ```
  /// let initialState = ICRC4.initialState();
  /// let currentState = #v0_1_0(#data(initialState));
  /// ```
  public type State =               MigrationTypes.State;

  /// # CurrentState
  ///
  /// Represents the current version of the ledger state, including all necessary data like token approvals, ledger information, and indexes.
  /// This is the state format that the ledger operates on at runtime.
  ///
  /// ## Members
  ///
  /// The data structure typically includes fields such as:
  /// - `ledger_info`: General information about the ledger, fees, and approval limits.
  /// - `token_approvals`: A map tracking the current approval allowances between accounts.
  /// - `indexes`: Various indexes to speed up operations like looking up token approvals.
  public type CurrentState =        MigrationTypes.Current.State;
  public type Environment =         MigrationTypes.Current.Environment;

  public type Account =             MigrationTypes.Current.Account;
  public type Balance =             MigrationTypes.Current.Balance;
  public type Value =               MigrationTypes.Current.Value;
  public type Subaccount =          MigrationTypes.Current.Subaccount;


  public type Fee =                 MigrationTypes.Current.Fee;
  public type GetFee =                 MigrationTypes.Current.GetFee;

  public type InitArgs =            MigrationTypes.Current.InitArgs;

  /// # TransferBatchListener
  ///
  /// Defines the signature for listener callbacks that are triggered after a successful `transfer_batch` operation.
  /// Listeners are used to execute additional logic tied to token transfer events, such as updating external systems or logs.
  ///
  /// ## Parameters
  ///
  /// - `notification`: `TransferBatchNotification` - The details about the transfer that has occurred.
  /// - `result`: `Nat` - The unique identifier for the transfer transaction.
  public type TransferBatchListener = MigrationTypes.Current.TransferBatchListener;

  /// # TransferBatchNotification
  ///
  /// Contains detailed information about a `transfer_from` operation that has been performed, enabling listeners to react accordingly.
  ///
  /// ## Members
  ///
  /// - `from`: `Account` - The source account from which tokens were transferred.
  /// - `transfers`: `[TransferArg]` - The set destination accounts, amounts to which tokens were transferred.
  /// - Additional fields may include `fee`, `memo`, and timestamps.
  public type TransferBatchNotification = MigrationTypes.Current.TransferBatchNotification;

  public type CanBatchTransfer = MigrationTypes.Current.CanBatchTransfer;

  public type TransferBatchResults = MigrationTypes.Current.TransferBatchResults;
  public type TransferBatchResult = MigrationTypes.Current.TransferBatchResult;
  

  public type LedgerInfo = MigrationTypes.Current.LedgerInfo;
  public type Stats = MigrationTypes.Current.Stats;

  public type TransferArgs = MigrationTypes.Current.TransferArgs;
  public type TransferError = ICRC1.TransferError;
  public type TransferBatchArgs = MigrationTypes.Current.TransferBatchArgs;
  public type TransferBatchError = MigrationTypes.Current.TransferBatchError;

  public type BalanceQueryArgs = MigrationTypes.Current.BalanceQueryArgs;
  public type BalanceQueryResult = MigrationTypes.Current.BalanceQueryResult;

  public type UpdateLedgerInfoRequest = MigrationTypes.Current.UpdateLedgerInfoRequest;
  public type MetaDatum = ICRC1.MetaDatum;

  /// # Transaction
  ///
  /// Models the details of a ledger transaction, capturing all relevant data including sender, receiver, amounts, and optional metadata.
  ///
  /// ## Members
  ///
  /// - `operation`: `Operation` - The operation performed, e.g., a transfer or burn.
  /// - `from`: `Account` - The account from which tokens are debited.
  /// - `to`: `Account` - The account to which tokens are credited.
  /// - `amount`: `Nat` - The amount of tokens involved in the transaction.
  /// - And more fields for additional details such as fees, timestamps, and memo information.
  public type Transaction = MigrationTypes.Current.Transaction;

  /// # `initialState`
  ///
  /// Creates and returns the initial state of the ICRC-4 ledger.
  ///
  /// ## Returns
  ///
  /// `State`: The initial state object based on the `v0_0_0` version specified by the `MigrationTypes.State` variant.
  ///
  /// ## Example
  ///
  /// ```
  /// let state = ICRC4.initialState();
  /// ```
  public func initialState() : State {#v0_0_0(#data)};

  /// # currentStateVersion
  ///
  /// Indicates the current version of the ledger state that this ICRC-4 implementation is using.
  /// It is used for data migration purposes to ensure compatibility across different ledger state formats.
  ///
  /// ## Value
  ///
  /// `#v0_1_0(#id)`: A unique identifier representing the version of the ledger state format currently in use, as defined by the `State` data type.
  public let currentStateVersion = #v0_1_0(#id);

  public let init = Migration.migrate;
  
  public let Map = ICRC1.Map;

  /// #class ICRC4
  /// Initializes the state of the ICRC4 class.
  /// - Parameters:
  ///     - stored: `?State` - An optional initial state to start with; if `null`, the initial state is derived from the `initialState` function.
  ///     - canister: `Principal` - The principal of the canister where this class is used.
  ///     - environment: `Environment` - The environment settings for various ICRC standards-related configurations.
  /// - Returns: No explicit return value as this is a class constructor function.
  ///
  /// The `ICRC4` class encapsulates the logic for the batch transfer of tokens and is an add-on Class for ICRC1
  /// Within the class, we have various methods such as `get_ledger_info`, `transfer_batch`, 
  /// `get_balances`, and many others
  /// that assist in handling the ICRC-4 standard functionalities.
  ///
  /// The methods often utilize helper functions like `testMemo`, `testCreatedAt` and others that perform 
  /// specific operations such as validation of data and performing the necessary changes to the transfers 
  /// and the ledger based on the token transactions.
  ///
  /// Event listeners  are also defined to maintain the correct state 
  /// of approvals after transfers and to ensure the system remains within configured limitations.
  ///
  /// The `ICRC4` class allows for detailed ledger updates using `update_ledger_info`, 
  /// querying for different approval states, and managing the transfer of tokens.
  ///    
  /// Additional functions like `get_stats` provide insight into the current state the ledger addon.
  public class ICRC4(stored: ?State, canister: Principal, environment: Environment){

    /// # State
    ///
    /// Encapsulates the entire ledger state across versions, facilitating data migration.
    /// It is a variant that includes possible format versions of the ledger state, enabling seamless upgrades to the system.
    ///
    /// ## Example
    ///
    /// ```
    /// let initialState = ICRC4.initialState();
    /// let currentState = #v0_1_0(#data(initialState));
    /// ```
    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, null, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val,currentStateVersion, null, canister);
        foundState;
      };
    };

    
    
    private let transfer_batch_listeners = Vec.new<(Text, TransferBatchListener)>();

    public let migrate = Migration.migrate;


    /// # `get_ledger_info`
    ///
    /// Retrieves the current ledger information for the ICRC-4 ledger, which contains parameters such as fee and
    /// configurations that apply to the icrc4 functionalty of this ledger.
    ///
    /// ## Returns
    ///
    /// `LedgerInfo`: A record that contains data about the ledger itself as it pertains to ICRC4, such as fee structure (fixed or
    /// based on ICRC-1 standard), max number of approvals blances or transfers per request.
    ///
    /// ## Example
    ///
    /// ```
    /// let ledgerInfo = myICRC4Instance.get_ledger_info();
    /// ```
    public func get_ledger_info() :  LedgerInfo {
      return state.ledger_info;
    };

    /// # `get_state`
    ///
    /// Acquires the current state of the ledger, which reflects all the approvals and the setup of the ledger,
    /// along with any other metadata maintained.
    ///
    /// ## Returns
    ///
    /// `CurrentState`: All encompassing state structure that includes account balances, approval mappings,
    /// and ledger configuration, as defined in `MigrationTypes.Current.State`.
    ///
    /// ## Example
    ///
    /// ```
    /// let currentState = myICRC4Instance.get_state();
    /// ```
    public func get_state() :  CurrentState {
      return state;
    };

    
      /// `metadata`
      ///
      /// Retrieves all metadata associated with the token ledger relative to icrc4
      /// If no metadata is found, the method initializes default metadata based on the state and the canister Principal.
      ///
      /// Returns:
      /// `MetaData`: A record containing all metadata entries for this ledger.
      public func metadata() : [ICRC1.MetaDatum] {
         switch(state.ledger_info.metadata){
          case(?val) {};
          case(null) {
            let newdata = init_metadata();
            state.ledger_info.metadata := ?newdata;
          };
         };

         switch(state.ledger_info.metadata){
          case(?val){
            switch(val){
              case(#Map(val)) val;
              case(_) D.trap("malformed metadata");
            };
          };
          case(null){D.trap("unreachable metadata");}
         };
      };


      /// Creates a Stable Buffer with the default metadata and returns it.
      public func init_metadata() : MigrationTypes.Current.Value {
          
          let md = switch(state.ledger_info.metadata){
            case(?val){
              switch(val){
                case(#Map(val)) val;
                case(_) [];
              };
            };
            case(null)[];
          };

          let results = Map.new<Text, ICRC1.MetaDatum>();
          
          
          for(thisItem in md.vals()){
            ignore Map.put(results, Map.thash, thisItem.0, thisItem);
          };

          ignore Map.put(results, Map.thash, "icrc4:max_balances",("icrc4:max_balances", #Nat(state.ledger_info.max_balances)));
          ignore Map.put(results, Map.thash,"icrc4:max_transfers", ("icrc4:max_transfers", #Nat(state.ledger_info.max_transfers)));

          ignore Map.put(results, Map.thash, "icrc4:fee", ("icrc4:fee", switch(state.ledger_info.fee){
                case(#ICRC1) #Text("icrc1"); 
                case(#Fixed(val)) #Nat(val);
                case(#Environment) #Nat(10000); //a lie as it is determined at runtime.
          }));

          let final_result = Iter.toArray(Map.vals(results));

          state.ledger_info.metadata := ?#Map(final_result);
          ignore environment.icrc1.register_metadata(final_result);

          #Map(final_result);
      };

    /// # get_fee
    ///
    /// Calculates the fee required for batch transfers per transfer item.
    ///
    /// ## Parameters
    ///
    /// - `request`: `TransferBatchArgs` - The parameters for the batc request, which includes information
    ///
    /// ## Returns
    ///
    /// `Nat` - The calculated fee based on the approval request parameters and the ledger's fee policy.
    /// This function ensures that the fee is never below the required minimum set by the ledger configuration.
    ///
    /// ## Remarks
    ///
    /// This function will return the maximum fee between the ledger's fixed or environment-determined fee
    /// and any user-provided fee amount. If no user fee is provided, the ledger's ICRC1 fee policy will be used.
    public func get_fee(batch_request : TransferBatchNotification, request: ICRC1.TransferArgs) : Nat {
      
      switch(state.ledger_info.fee){
        case(#Fixed(val)){
          switch(request.fee){
            case(null) val;
            case(?user_fee){
              Nat.max(val,user_fee);
            };
          };
        };
        case(#ICRC1){
          environment.icrc1.get_fee({
            from_subaccount = request.from_subaccount;
            to = request.to;
            amount = request.amount;
            fee = request.fee;
            memo  = request.memo;
            created_at_time = request.created_at_time;
          });
        };
        case(#Environment){
          switch(environment.get_fee){
            case(?get_fee_env){
              let val = get_fee_env(state, environment, batch_request, request);
              switch(request.fee){
                case(null) val;
                case(?user_fee){
                  Nat.max(val,user_fee);
                };
              };
            };
            case(_){
              10000;
            };
          };
        };
      
      };
    };

    /// # validate_batch_transfer
    ///
    /// Validates the parameters and the state of the ledger for an transfer request.
    ///
    /// ## Parameters
    ///
    /// - `from`: `Account` - The source account from which tokens can be spent upon approval.
    /// - `transfer`: `TransferBatchArgs` - The detailed approval request including the spender information and the amount.
   
    ///
    /// ## Returns
    ///
    /// `Star<TransferBatchResult, Text>` - A Star type result that contains either an approval response indicating success
    /// or an error message if the validation fails.
    ///
    /// ## Remarks
    ///
    /// This function performs a series of checks, including account validation, fee sufficiency, and allowance
    /// exactness (if `expected_allowance` is provided), along with tests for memo size, expiration, and creation
    /// timestamp validity.
    public func validate_transfer_batch( transfer : TransferBatchNotification
          ): Result.Result<TransferBatchResults, TransferBatchResults>{

      if(transfer.transfers.size() >= state.ledger_info.max_transfers){
        //this iteration of icrc4 does process any transactions if the limit is exceeded.
        return #err([?#Err(#TooManyRequests({limit = state.ledger_info.max_transfers}))]);
      };

      return #ok([]);

    };

    //events

    /// # register_transfer_batch_listener
    ///
    /// Registers a listener that will be triggered after a successful transfer batch operation.
    ///
    /// ## Parameters
    ///
    /// - `namespace`: `Text` - A unique name identifying the listener.
    /// - `remote_func`: `TokenBatchlListener` - A callback function that will be invoked with token batch notifications.
    ///
    /// ## Remarks
    ///
    /// The registered listener callback function receives notifications containing details about the token batc operation and the corresponding transaction ID. It is useful for tracking delegation events as token owners grant spend permissions to third parties. Note that transfer notifications will also be sent from icrc1.
    public func register_transfer_batch_listener(namespace: Text, remote_func : TransferBatchListener){
      environment.icrc1.register_listener<TransferBatchListener>(namespace, remote_func, transfer_batch_listeners);
    };


    

    //ledger mangement

    /// Updates ledger information such as approval limitations with the provided request.
    /// - Parameters:
    ///     - request: `[UpdateLedgerInfoRequest]` - A list of requests containing the updates to be applied to the ledger.
    /// - Returns: `[Bool]` - An array of booleans indicating the success of each update request.
    public func update_ledger_info(request: [UpdateLedgerInfoRequest]) : [Bool]{
      
      //todo: Security at this layer?

      let results = Vec.new<Bool>();
      for(thisItem in request.vals()){
        switch(thisItem){
          
          case(#MaxTransfers(val)){state.ledger_info.max_transfers := val};
          case(#MaxBalances(val)){state.ledger_info.max_balances := val};
          
          
          case(#Fee(fee)){
            state.ledger_info.fee := fee;
          }
        };
        Vec.add(results, true);
      };

      ignore init_metadata();
      return Vec.toArray(results);
    };


    /// # transfer_batch_tokens
    ///
    /// Processes token transfers under the ICRC-4 standard, including fee validation and actually moving tokens.
    ///
    /// ## Parameters
    ///
    /// - `caller`: `Principal` - The principal of the user (or canister) initiating the transfer.
    /// - `transferBatchArgs`: `TransferBatchArgs` - The arguments detailing the transfer operations.
    ///
    /// ## Returns
    ///
    /// `Star<TransferBatchResult, Text>` - A response type capturing the outcome of the transfer batch operation which may include transaction IDs on success or an error message.
    ///
    /// ## Remarks
    ///
    /// This function combines validation with actual state changes, fee deductions, and transaction logging. When the transfer is complete, event listeners are notified of the change, and the internal approval state is updated to reflect the new balances.
    public func transfer_batch_tokens(caller: Principal, transferBatchArgs: TransferBatchArgs, can_transfer : ICRC1.CanTransfer, can_batch_transfer : CanBatchTransfer) : async* Star.Star<TransferBatchResults, TransferBatchResults> {

        let icrc1 = environment.icrc1;

        let results = Vec.new<?TransferBatchResult>();

        let pre_notification = {
          transfers = transferBatchArgs; 
          from = caller;
        };

        switch(validate_transfer_batch(pre_notification)){
          case(#err(err)){
            return #trappable(err);
          };
          case(#ok(val)){};
        };

        var bAwaited = false;

        let (notification) : (TransferBatchNotification) = switch(await* handleCanBatchTransfer(pre_notification, can_batch_transfer)){
            case(#trappable(val)) val;
            case(#awaited(val)){
              bAwaited := true;
              
              //revalidate 
              switch (validate_transfer_batch(val)) {
                case (#err(errors)) {
                    return #awaited(errors);
                };
                case (#ok(_)) {};
              };
              val;
            };
            case(#err(val)){
              return #err(val);
            };
          };

        

        

        label proc for(thisItem in notification.transfers.vals()){

          let from = {
            owner = caller;
            subaccount = thisItem.from_subaccount;
          };


          let tx_kind = if (ICRC1.account_eq(from, icrc1.get_state().minting_account)) {
            #mint;
          } else if (ICRC1.account_eq(thisItem.to, icrc1.get_state().minting_account)) {
            #burn;
          } else {
            #transfer;
          };

          let tx_req = ICRC1.UtilsHelper.create_transfer_req(thisItem, caller, tx_kind);

          //when we create the transfer we should calculate the required fee. This should only be done once and used throughout the rest of the calcualtion

          let calculated_fee = switch(tx_req.kind){
            case(#transfer){
              get_fee(notification, thisItem);
            };
            case(_){
              0;
            };
          };

          debug if (debug_channel.transfer) D.print("validating");
          switch (icrc1.validate_request(tx_req, calculated_fee, false)) {
              case (#err(errorType)) {
                  Vec.add<?TransferBatchResult>(results, ?#Err(errorType));
                  continue proc;
              };
              case (#ok(_)) {};
          };

          let txMap = icrc1.transfer_req_to_value(tx_req);
          let txTopMap = icrc1.transfer_req_to_value_top(calculated_fee, tx_req);

          let pre_notification_token = {
            tx_req with
            calculated_fee = calculated_fee;
          };

          let (finaltx, finaltxtop, notification_token) : (Value, ?Value, ICRC1.TransactionRequestNotification) = switch(await* icrc1.handleCanTransfer(txMap, ?txTopMap, pre_notification_token, can_transfer)){
            case(#trappable(val)) val;
            case(#awaited(val)){
              bAwaited := true;
              let override_fee = val.2.calculated_fee;
              //revalidate 
              switch (icrc1.validate_request(val.2, override_fee, false)) {
                case (#err(errorType)) {
                  Vec.add<?TransferBatchResult>(results, ?#Err(errorType));
                  continue proc;
                };
                case (#ok(_)) {};
              };
              val;
            };
            case(#err(#trappable(val))){
              debug if (debug_channel.transfer) D.print("handleCanTransfer gave us a trappable error of " # debug_show(val));
              Vec.add<?TransferBatchResult>(results, ?val);
              continue proc;
            };
            case(#err(#awaited(val))){
              debug if (debug_channel.transfer) D.print("handleCanTransfer gave us an awaited error of " # debug_show(val));
              bAwaited := true;
              Vec.add<?TransferBatchResult>(results, ?val);
              continue proc;
            };
          };
          

          let { amount; to; } = notification_token;

          debug if (debug_channel.transfer)D.print("Moving tokens");

          var finaltxtop_var = finaltxtop;
          var finaltx_var = finaltx;
          let final_fee = notification_token.calculated_fee;


          debug if (debug_channel.transfer)D.print("Final fee used " # debug_show(final_fee));

          // process transaction
          switch(notification_token.kind){
              case(#mint){
                  ICRC1.UtilsHelper.mint_balance(icrc1.get_state(), to, amount);
              };
              case(#burn){
                  ICRC1.UtilsHelper.burn_balance(icrc1.get_state(), from, amount);
              };
              case(#transfer){
                  ICRC1.UtilsHelper.transfer_balance(icrc1.get_state(), notification_token);

                  // burn fee
                  if(final_fee > 0){
                    switch(icrc1.get_state().fee_collector){
                      case(null){
                        ICRC1.UtilsHelper.burn_balance(icrc1.get_state(), from, final_fee);
                      };
                      case(?val){
                        finaltxtop_var := switch(icrc1.handleFeeCollector(final_fee, val, notification_token, finaltxtop)){
                          case(#ok(val)) val;
                          case(#err(err)){
                            Vec.add<?TransferBatchResult>(results, ?#Err(#GenericError({error_code= 6453; message=err})));
                            continue proc;
                          };
                        };
                      };
                    };
                  };
              };
          };

          // store transaction
          let index = icrc1.handleAddRecordToLedger<system>(finaltx_var, finaltxtop_var, notification_token);

          let tx_final = ICRC1.UtilsHelper.req_to_tx(notification_token, index);

          if(calculated_fee > 0) icrc1.setFeeCollectorBlock(index);

          //add trx for dedupe
          let trxhash = Blob.fromArray(RepIndy.hash_val(finaltx_var));

          debug if (debug_channel.transfer)D.print("attempting to add recent" # debug_show(trxhash, finaltx_var));

          ignore Map.put<Blob, (Nat64, Nat)>(icrc1.get_state().recent_transactions, Map.bhash, trxhash, (icrc1.get_time64(), index));

          icrc1.handleBroadcastToListeners<system>(tx_final, index);

          debug if (debug_channel.transfer)D.print("done transfer");
          Vec.add<?TransferBatchResult>(results, ?#Ok(index));
        };

       icrc1.handleCleanUp<system>();

       let finalResults = Vec.toArray(results);

       debug if (debug_channel.transfer)D.print("attempting to call listeners" # debug_show(Vec.size(transfer_batch_listeners)));
        for(thisItem in Vec.vals(transfer_batch_listeners)){
          thisItem.1<system>(notification, finalResults);
        };

       return if(bAwaited){
          #awaited(finalResults);
       } else {
          #trappable(finalResults);
       };
    };

      /// Manages the logging of Memos to the ledger.
      ///
      /// Parameters:
      /// - `memo`: The memo of the batch.
      /// - `memoBlock`: The block that the memo was written to for this batch if avilable.
      /// - `txtop`: transaction information for transaction logging.
      /// - `txtop`: Optional top layer information for transaction logging.
      ///
      /// Returns:
      /// - `Result<?Value, Text>`: The result of the memo operation containing updated top layer information or an error message.
      ///
      /// Remarks:
      /// - The first time through the memo will be written to the transaction. Subsiquent items will be written to memo-block at the top layer.
      /*
    public func handleBatchMemo(memo: Blob, memoBlock : ?Nat, tx: Value, txtop : ?Value) : Result.Result<(Value,?Value), Text> {
        var finaltxtop_var = txtop;
        var finaltx_var = tx;
        switch(memoBlock){
          case(?memoBlock){
            finaltxtop_var := switch(ICRC1.UtilsHelper.insert_map(finaltxtop_var, "memo_block", #Nat(memoBlock))){
              case(#ok(val)) ?val;
              case(#err(err)) return #err("unreachable map addition");
            };
          };
          case(null){
            finaltx_var := switch(ICRC1.UtilsHelper.insert_map(?finaltx_var, "memo", #Blob(memo))){
              case(#ok(val)) val;
              case(#err(err)) return #err("unreachable map addition");
            };
          };
        };

        #ok(finaltx_var, finaltxtop_var);
      };
      */


      /// Evaluates additional transfer batch validation rules if provided.
      ///
      /// Parameters:
      /// - `pre_notification`: The pre-transfer notification containing initial transfer information.
      /// - `canBatchTransfer`: Optional rules to validate the transfer further.
      ///
      /// Returns:
      /// - A star-patterned response that may either contain the updated data or errors.
      ///
      /// Possible Responses:
      /// - Returns the original data if no additional rules are provided.
      /// - On calling a synchronous validation function, returns the result or any encountered error.
      /// - On calling an asynchronous validation function, either returns the result or goes into a waiting state for further handling.
      public func handleCanBatchTransfer(pre_notification: TransferBatchNotification, canBatchTransfer : CanBatchTransfer) : async* Star.Star<(TransferBatchNotification), MigrationTypes.Current.TransferBatchResults> {
        switch(canBatchTransfer){
            case(null){
              #trappable(pre_notification);
            };
            case(?#Sync(remote_func)){
              switch(remote_func<system>(pre_notification)){
                case(#ok(val)) return #trappable(val);
                case(#err(tx)) return #err(#trappable(tx));
              };
            };
            case(?#Async(remote_func)){
              
              switch(await* remote_func(pre_notification)){
                case(#trappable(val)) #trappable(val);
                case(#awaited(val)){
                  #awaited(val);
                };
                case(#err(#awaited(tx))){
                  return #err(#awaited(tx));
                };
                case(#err(#trappable(tx))){
                  return #err(#trappable(tx));
                };
              };
            };
          };
      };


    /// Simplified function that matchs the icrc4 patter
    /// We encourage you to use transfer_batch_tokens and handle any waited state
    ///
    public func transfer_batch(caller: Principal, transferBatchArgs: TransferBatchArgs) : async* TransferBatchResults {
      switch( await* transfer_batch_tokens(caller, transferBatchArgs, null, null)){
          case(#trappable(val)) val;
          case(#awaited(val)) val;
          case(#err(#trappable(err))) err;
          case(#err(#awaited(err))) err;
        };
    };

    public func balance_of_batch_tokens(args : BalanceQueryArgs) : Result.Result<BalanceQueryResult, Text>{
      let results = ICRC1.Vector.new<Nat>();

      if(args.accounts.size() > state.ledger_info.max_balances) return #err("too many requests. allowed:" # debug_show(state.ledger_info.max_balances));

      for(thisItem in args.accounts.vals()){
        ICRC1.Vector.add<Nat>(results, environment.icrc1.balance_of(thisItem));
      };

      return #ok(ICRC1.Vector.toArray(results));
    };

    public func balance_of_batch(args : BalanceQueryArgs) : BalanceQueryResult{
      switch(balance_of_batch_tokens(args)){
        case(#ok(val)) val;
        case(#err(err)) D.trap(err);
      };
    };

    

    /// # `get_stats`
    ///
    /// Provides statistics that summarize the current ledger state, including the max transfers and balance checks,
    /// the limits that are set, and the overall ledger setup.
    ///
    /// ## Returns
    ///
    /// `Stats`: A snapshot structure representing ledger statistics like the number of approvals set up,
    /// the configurations of the ledger, as well as the indexing status for quick lookup.
    ///
    /// ## Example
    ///
    /// ```
    /// let statistics = myICRC4Instance.get_stats();
    /// ```
    public func get_stats() : Stats {
      return {
        
        max_balances  = state.ledger_info.max_balances;
        fee = state.ledger_info.fee;
        max_transfers = state.ledger_info.max_transfers;
        
      };
    };

    ///register some items with icrc4
    ignore init_metadata();

    ignore environment.icrc1.register_supported_standards({
        name = "ICRC-4";
        url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-4/";
    });



  };
};
