import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import CertifiedData "mo:base/CertifiedData";
import CertTree "mo:ic-certification/CertTree";
import ICRC1 "mo:icrc1-mo/ICRC1";
import ICRC2 "mo:icrc2-mo/ICRC2";
import ICRC2Service "mo:icrc2-mo/ICRC2/service";
import ICRC3Legacy "mo:icrc3-mo/legacy";
import ICRC3 "mo:icrc3-mo/";
import ICRC4 "mo:icrc4-mo/ICRC4";
import Error "mo:base/Error";
import Iter "mo:base/Iter";
import UpgradeArchive "mo:icrc3-mo/upgradeArchive";
import ClassPlus "mo:class-plus";

shared ({ caller = _owner }) actor class Token(
  args : ?{
    icrc1 : ?ICRC1.InitArgs;
    icrc2 : ?ICRC2.InitArgs;
    icrc3 : ICRC3.InitArgs; //already typed nullable
    icrc4 : ?ICRC4.InitArgs;
  }
) = this {

  let Map = ICRC2.Map;
  let Set = ICRC2.Set;

  D.print("loading the state");
  let manager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);

  // ===[ REVENUE & TREASURY ACCOUNTS ]===
  stable var revenue_account : ICRC1.Account = {
    // Paling aman: akun canister sendiri → canister bisa otomatis burn/redistribute
    owner = Principal.fromActor(this);
    subaccount = null; // bisa kamu isi subaccount kalau mau pisahkan bookkeeping
  };

  stable var treasury_account : ICRC1.Account = {
    owner = Principal.fromText("qmc7g-dzjeq-haics-mfv4z-a6ypg-3m3yo-cvdrf-kyy3a-aiguy-5yvzh-kae");
    subaccount = null;
  };

  // Track saldo terakhir yang sudah di-sweep
  stable var last_revenue_balance : Nat = 0;

  // Helper
  private func balance_of(a : ICRC1.Account) : Nat {
    icrc1().balance_of(a);
  };
  private func mul_bps(x : Nat, bps : Nat) : Nat { (x * bps) / 10_000 };

  // Bandingkan account
  private func eqAccount(a : ICRC1.Account, b : ICRC1.Account) : Bool {
    a.owner == b.owner and a.subaccount == b.subaccount;
  };

  // Basis point untuk pembagian fee (total = 10_000)
  stable var fee_split_bps = {
    treasury : Nat = 8000; // 80%
    burn : Nat = 2000; // 20%
  };

  let default_icrc1_args : ICRC1.InitArgs = {
    name = ?"Peridot";
    symbol = ?"PER";
    logo = ?"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGYktHRAD/AP8A/6C9p5MAAAAJcEhZcwAACxIAAAsSAdLdfvwAAAAHdElNRQfpCRAEFRiDRgOaAAAEHElEQVR42u2Z32tcRRTHP2fm3k02hja/GpPaBBKQRhJQIhTEN99880X8d/xb/AN80X9AqA0UpWiRajRiklrSgqWpmnR3c+f4MHPv3l1WsLCTYe39wiW5k7Pkez73zJm5s7KxsaG8wjKpDaRWAyC1gdRqAKQ2kFoNgNQGUqsBkNpAajUAUhtIrQZAagOp1QBIbSC1GgCpDaRWAyC1gdTKLuW/KKi+3NGjGPl/AFBV8pkpXn97jWymhTr1lzL0U1EHqnBx1uH04ITiRRckLoi4ABTymRZbH73D6q1N1CnFheIKhyu0f10oRX2s52gvz3Fy5wFFpxcVQrweECo+b7cQa+iengFgM8EYQYT+ZcAYwYR7Y4WF7TVW3tvCTOW+LCIpSgWoKnm7xZsfbmPzjJNvDzn6ap/Z1assvrXKlfVFsplpxCjgah8UyhEDLGyvoSgnez/hIlWCjP2LEYV8Jmf74102PriJKnT+7PDst6c8/v4hf+w/wRWOK+uLLN5cYfbGAibPwjQYNT0cT3845mTvR4ruxdgB2Pn5+U/Hmr9T1t/fZOeTXUQEVbCZpb00y9LWCtd2rtNeeI2/Hj3j+PY+qDK3uTwSZHhGTC9dofv8nLPHp8iYqyDCFFCmr7bJWpai51AFpyDqEAPTc21W313n2s4b3P9sj87zc4yVqvxBhgAAYsjarfFbjQMgNDIjqBHUVqNVYq5QbG7IpjI/362gKqEjG8ANASDaShANgFhBnNSWGQPqwNYDfW4lgBIQKkNxEm0lHDsADYaNFdTJ4B+sVL8aqOZzBUAJiYcqKGMl3s4w3hSwBnVaSx5AquSdv/UVYAS1Mlj2tViVeHuhOABMrQKq5AEMWlv3JcztqgLqZV/GagAwcRUQmmA9Kf9EpRbnH61Ywehgggp+zPqN4GRVwIgeUJYzGpphSEoN1TI4mDz9nuEY+/ofFQBhP6/Oz2MpE6r1gkCq2vuXYFTL5KHsFhreFyYGgISn6pzBhKc9OL8FkIEegAO1MuLtTEITnKAKEBHfCI1UZTyclI+jVi2D/aEvg1PHxXl3kgBQ6wH9Nb2eVNUERDDGoNaNjFVVHt39lSf3H0apgktqgkPGtQ+qqgAdEatwdOeAX778jt6L3uQAQGqbG/AdPjRBVRBb2wnW9wFAVR3qOPz6Z/a/iJd8PAD4dwGDQUS9eeN8ezeKGMUZ9RVgwOa+9flYBS04vH3Ag8/v0TvvRkseIhyIqFOWt5ZZu7Xm78OhZ3ky7A8+/cHo8d0jEOH67o1qnHCA8vs3h3T/7kRNPgqAEsJ/OQavtrduONavIsTNHYj4LiAv495eQqb/olf+m6EGQGoDqdUASG0gtRoAqQ2kVgMgtYHUagCkNpBaDYDUBlKrAZDaQGo1AFIbSK0GQGoDqfUPUpagsrhQ0O8AAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDktMTZUMDQ6MjA6NDcrMDA6MDCUWU1rAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA5LTE2VDA0OjIwOjQ3KzAwOjAw5QT11wAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wOS0xNlQwNDoyMToyNCswMDowMKpUrCwAAAAASUVORK5CYII=";
    decimals = 8;
    // fee = ?#Fixed(10000);
    fee = ?#Environment;
    minting_account = ?{
      owner = _owner;
      subaccount = null;
    };
    max_supply = ?(8_200_000_000 * (10 ** 8));
    min_burn_amount = ?10000;
    max_memo = ?64;
    advanced_settings = null;
    metadata = null;
    fee_collector = ?revenue_account;
    transaction_window = null;
    permitted_drift = null;
    max_accounts = ?100000000;
    settle_to_accounts = ?99999000;
  };

  let default_icrc2_args : ICRC2.InitArgs = {
    max_approvals_per_account = ?10000;
    max_allowance = ?#TotalSupply;
    fee = ?#ICRC1;
    advanced_settings = null;
    max_approvals = ?10000000;
    settle_to_approvals = ?9990000;
  };

  let default_icrc3_args : ICRC3.InitArgs = {
    maxActiveRecords = 3000;
    settleToRecords = 2000;
    maxRecordsInArchiveInstance = 500_000;
    maxArchivePages = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 8000;
    archiveCycles = 20_000_000_000_000;
    archiveControllers = null; //??[put cycle ops prinicpal here];
    supportedBlocks = [
      {
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
    ];
  };

  let default_icrc4_args : ICRC4.InitArgs = {
    max_balances = ?200;
    max_transfers = ?200;
    fee = ?#ICRC1;
  };

  let icrc1_args : ICRC1.InitArgs = switch (args) {
    case (null) default_icrc1_args;
    case (?args) {
      switch (args.icrc1) {
        case (null) default_icrc1_args;
        case (?val) {
          {
            val with
            minting_account = switch (val.minting_account) {
              case (?val) ?val;
              case (null) {
                ?{
                  owner = _owner;
                  subaccount = null;
                };
              };
            };
            fee_collector = switch (val.fee_collector) {
              case (?val) ?val;
              case (null) ?revenue_account;
            };
          };
        };
      };
    };
  };

  let icrc2_args : ICRC2.InitArgs = switch (args) {
    case (null) default_icrc2_args;
    case (?args) {
      switch (args.icrc2) {
        case (null) default_icrc2_args;
        case (?val) val;
      };
    };
  };

  let icrc3_args : ICRC3.InitArgs = switch (args) {
    case (null) default_icrc3_args;
    case (?args) {
      args.icrc3; // FIXED: icrc3 already nullable in args type
    };
  };

  let icrc4_args : ICRC4.InitArgs = switch (args) {
    case (null) default_icrc4_args;
    case (?args) {
      switch (args.icrc4) {
        case (null) default_icrc4_args;
        case (?val) val;
      };
    };
  };

  stable let icrc1_migration_state = ICRC1.init(ICRC1.initialState(), #v0_1_0(#id), ?icrc1_args, _owner);
  stable let icrc2_migration_state = ICRC2.init(ICRC2.initialState(), #v0_1_0(#id), ?icrc2_args, _owner);
  stable let icrc4_migration_state = ICRC4.init(ICRC4.initialState(), #v0_1_0(#id), ?icrc4_args, _owner);
  stable let icrc3_migration_state = ICRC3.initialState();
  stable let cert_store : CertTree.Store = CertTree.newStore();
  let ct = CertTree.Ops(cert_store);

  stable var owner = _owner;
  stable var icrc3_migration_state_new = icrc3_migration_state;

  let #v0_1_0(#data(icrc1_state_current)) = icrc1_migration_state;

  private var _icrc1 : ?ICRC1.ICRC1 = null;

  private func get_icrc1_state() : ICRC1.CurrentState {
    return icrc1_state_current;
  };

  private func get_icrc1_environment() : ICRC1.Environment {
    {
      get_time = null;

      // Gunakan fee dinamis: 0 saat sweep dari revenue_account ke treasury_account, selain itu 10_000.
      get_fee = ?(
        func(_state, _env, req : ICRC1.TransferArgs) : ICRC1.Balance {
          let isFromRevenue = (req.from_subaccount == revenue_account.subaccount);
          let isToTreasury = (req.to.owner == treasury_account.owner) and (req.to.subaccount == treasury_account.subaccount);

          if (isFromRevenue and isToTreasury) {
            0;
          } else {
            10_000;
          };
        }
      );

      add_ledger_transaction = ?icrc3().add_record;
    };
  };

  // FIXED: Add error handling and validation to sweep_fees
  public shared func sweep_fees() : async () {
    let bal = balance_of(revenue_account);
    if (bal <= last_revenue_balance) return;

    let fresh = bal - last_revenue_balance;

    // FIXED: Add minimum threshold check
    if (fresh < 20000) return; // Skip if less than 2x fee

    let burn_amt = mul_bps(fresh, fee_split_bps.burn);
    let treasury_amt = mul_bps(fresh, fee_split_bps.treasury);

    // Validate amounts before processing
    if (burn_amt + treasury_amt > fresh) {
      D.trap("Invalid fee split calculation");
    };

    // 1) Burn (fee = 0 berkat get_fee)
    if (burn_amt > 0) {
      switch (
        await* icrc1().burn_tokens(
          Principal.fromActor(this),
          {
            from_subaccount = revenue_account.subaccount;
            amount = burn_amt;
            memo = null;
            created_at_time = null;
          },
          false,
        )
      ) {
        case (#trappable(_)) ();
        case (#awaited(_)) ();
        case (#err e) D.trap("Burn failed: " # debug_show (e));
      };
    };

    // 2) Transfer ke Treasury (fee = 0)
    if (treasury_amt > 0) {
      switch (
        await* icrc1().transfer_tokens(
          Principal.fromActor(this),
          {
            from_subaccount = revenue_account.subaccount;
            to = treasury_account;
            amount = treasury_amt;
            fee = ?0;
            memo = null;
            created_at_time = null;
          },
          false,
          null,
        )
      ) {
        case (#trappable(_)) ();
        case (#awaited(_)) ();
        case (#err e) D.trap("Treasury transfer failed: " # debug_show (e));
      };
    };

    last_revenue_balance += fresh;
  };

  func icrc1() : ICRC1.ICRC1 {
    switch (_icrc1) {
      case (null) {
        let initclass : ICRC1.ICRC1 = ICRC1.ICRC1(?icrc1_migration_state, Principal.fromActor(this), get_icrc1_environment());
        ignore initclass.register_supported_standards({
          name = "ICRC-3";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-3/";
        });
        ignore initclass.register_supported_standards({
          name = "ICRC-10";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-10/";
        });
        ignore initclass.register_supported_standards({
          // FIXED: removed icrc1() call
          name = "ICRC-106";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-106";
        });

        _icrc1 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc2_state_current)) = icrc2_migration_state;

  private var _icrc2 : ?ICRC2.ICRC2 = null;

  private func get_icrc2_state() : ICRC2.CurrentState {
    return icrc2_state_current;
  };

  private func get_icrc2_environment() : ICRC2.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
    };
  };

  func icrc2() : ICRC2.ICRC2 {
    switch (_icrc2) {
      case (null) {
        let initclass : ICRC2.ICRC2 = ICRC2.ICRC2(?icrc2_migration_state, Principal.fromActor(this), get_icrc2_environment());
        _icrc2 := ?initclass;
        ignore icrc1().register_supported_standards({
          name = "ICRC-103";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-103";
        });
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc4_state_current)) = icrc4_migration_state;

  private var _icrc4 : ?ICRC4.ICRC4 = null;

  private func get_icrc4_state() : ICRC4.CurrentState {
    return icrc4_state_current;
  };

  private func get_icrc4_environment() : ICRC4.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
    };
  };

  func icrc4() : ICRC4.ICRC4 {
    switch (_icrc4) {
      case (null) {
        let initclass : ICRC4.ICRC4 = ICRC4.ICRC4(?icrc4_migration_state, Principal.fromActor(this), get_icrc4_environment());
        _icrc4 := ?initclass;
        ignore icrc1().register_supported_standards({
          name = "ICRC-4";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-4";
        });
        initclass;
      };
      case (?val) val;
    };
  };

  private func updated_certification(cert : Blob, lastIndex : Nat) : Bool {
    // D.print("updating the certification " # debug_show(CertifiedData.getCertificate(), ct.treeHash()));
    ct.setCertifiedData();
    // D.print("did the certification " # debug_show(CertifiedData.getCertificate()));
    return true;
  };

  private func get_certificate_store() : CertTree.Store {
    // D.print("returning cert store " # debug_show(cert_store));
    return cert_store;
  };

  private func get_icrc3_environment() : ICRC3.Environment {
    {
      updated_certification = ?updated_certification;
      get_certificate_store = ?get_certificate_store;
    };
  };

  func ensure_block_types(icrc3Class : ICRC3.ICRC3) : () {
    let supportedBlocks = Buffer.fromIter<ICRC3.BlockType>(icrc3Class.supported_block_types().vals());

    let blockequal = func(a : { block_type : Text }, b : { block_type : Text }) : Bool {
      a.block_type == b.block_type;
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2approve"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1mint"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1burn"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    icrc3Class.update_supported_blocks(Buffer.toArray(supportedBlocks));
  };

  let icrc3 = ICRC3.Init<system>({
    manager = manager;
    initialState = icrc3_migration_state_new;
    args = ?icrc3_args;
    pullEnvironment = ?get_icrc3_environment;
    onInitialize = ?(
      func(newClass : ICRC3.ICRC3) : async* () {
        ensure_block_types(newClass);
      }
    );
    onStorageChange = func(state : ICRC3.State) {
      icrc3_migration_state_new := state;
    };
  });

  public shared query func get_treasury_account() : async ICRC1.Account {
    treasury_account;
  };

  /// Functions for the ICRC1 token standard
  public shared query func icrc1_name() : async Text {
    icrc1().name();
  };

  public shared query func icrc1_symbol() : async Text {
    icrc1().symbol();
  };

  public shared query func icrc1_decimals() : async Nat8 {
    icrc1().decimals();
  };

  public shared query func icrc1_fee() : async ICRC1.Balance {
    icrc1().fee();
  };

  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
    icrc1().metadata();
  };

  public shared query func icrc1_total_supply() : async ICRC1.Balance {
    icrc1().total_supply();
  };

  public shared query func icrc1_minting_account() : async ?ICRC1.Account {
    ?icrc1().minting_account();
  };

  public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
    icrc1().balance_of(args);
  };

  public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
    icrc1().supported_standards();
  };

  public shared query func icrc10_supported_standards() : async [ICRC1.SupportedStandard] {
    icrc1().supported_standards();
  };

  public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
    switch (await* icrc1().transfer_tokens(caller, args, false, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query ({ caller }) func icrc130_get_allowances(args : ICRC2Service.GetAllowancesArgs) : async ICRC2Service.AllowanceResult {
    return icrc2().getAllowances(caller, args);
  };

  stable var upgradeError = "";
  stable var upgradeComplete = false;

  public query ({ caller }) func getUpgradeError() : async Text {
    if (caller != _owner) { D.trap("Unauthorized") };
    return upgradeError;
  };

  public shared ({ caller }) func upgradeArchive(bOverride : Bool) : async () {
    if (caller != _owner) { D.trap("Unauthorized") };
    if (bOverride == true or upgradeComplete == false) {} else {
      D.trap("Upgrade already complete");
    };
    try {
      let result = await UpgradeArchive.upgradeArchive(Iter.toArray<Principal>(Map.keys(icrc3().get_state().archives)));
      upgradeComplete := true;
    } catch (e) {
      upgradeError := Error.message(e);
    };
  };

  public shared ({ caller }) func update_archive_controllers() : async () {
    if (_owner != caller) { D.trap("Unauthorized") };

    for (archive in Map.keys(icrc3().get_state().archives)) {
      switch (icrc3().get_state().constants.archiveProperties.archiveControllers) {
        case (?val) {
          let final_list = switch (val) {
            case (?list) {
              let a_set = Set.fromIter<Principal>(list.vals(), Map.phash);
              Set.add(a_set, Map.phash, Principal.fromActor(this));
              Set.add(a_set, Map.phash, _owner);
              ?Set.toArray(a_set);
            };
            case (null) {
              ?[Principal.fromActor(this), _owner];
            };
          };
          let ic : ICRC3.IC = actor ("aaaaa-aa");
          ignore ic.update_settings(({
            canister_id = archive;
            settings = {
              controllers = final_list;
              freezing_threshold = null;
              memory_allocation = null;
              compute_allocation = null;
            };
          }));
        };
        case (_) {};
      };
    };
  };

  stable var icrc106IndexCanister : ?Principal = null;

  public type Icrc106Error = {
    #GenericError : { description : Text; error_code : Nat };
    #IndexPrincipalNotSet;
  };

  public query func icrc106_get_index_principal() : async {
    #Ok : Principal;
    #Err : Icrc106Error;
  } {
    switch (icrc106IndexCanister) {
      case (?val) { #Ok(val) };
      case (null) { #Err(#IndexPrincipalNotSet) };
    };
  };

  public shared ({ caller }) func set_icrc106_index_principal(principal : ?Principal) : async () {
    if (caller != owner) { D.trap("Unauthorized") };
    icrc106IndexCanister := principal;
  };

  public shared ({ caller }) func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
    if (caller != owner) { D.trap("Unauthorized") };

    switch (await* icrc1().mint_tokens(caller, args)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
    switch (await* icrc1().burn_tokens(caller, args, false)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query ({ caller }) func icrc2_allowance(args : ICRC2.AllowanceArgs) : async ICRC2.Allowance {
    return icrc2().allowance(args.spender, args.account, false);
  };

  public shared ({ caller }) func icrc2_approve(args : ICRC2.ApproveArgs) : async ICRC2.ApproveResponse {
    switch (await* icrc2().approve_transfers(caller, args, false, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public shared ({ caller }) func icrc2_transfer_from(args : ICRC2.TransferFromArgs) : async ICRC2.TransferFromResponse {
    switch (await* icrc2().transfer_tokens_from(caller, args, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query ({ caller }) func icrc103_get_allowances(args : ICRC2.GetAllowancesArgs) : async ICRC2Service.AllowanceResult {
    return icrc2().getAllowances(caller, args);
  };

  public query func icrc3_get_blocks(args : ICRC3.GetBlocksArgs) : async ICRC3.GetBlocksResult {
    return icrc3().get_blocks(args);
  };

  public query func get_transactions(args : { start : Nat; length : Nat }) : async ICRC3Legacy.GetTransactionsResponse {
    let results = icrc3().get_blocks_legacy(args);
    return {
      first_index = icrc3().get_state().firstIndex;
      log_length = icrc3().get_state().lastIndex + 1;
      transactions = results.transactions;
      archived_transactions = results.archived_transactions;
    };
  };

  public query func icrc3_get_archives(args : ICRC3.GetArchivesArgs) : async ICRC3.GetArchivesResult {
    return icrc3().get_archives(args);
  };

  public query func icrc3_get_tip_certificate() : async ?ICRC3.DataCertificate {
    return icrc3().get_tip_certificate();
  };

  public query func icrc3_supported_block_types() : async [ICRC3.BlockType] {
    return icrc3().supported_block_types();
  };

  public query func get_tip() : async ICRC3.Tip {
    return icrc3().get_tip();
  };

  public shared ({ caller }) func icrc4_transfer_batch(args : ICRC4.TransferBatchArgs) : async ICRC4.TransferBatchResults {
    switch (await* icrc4().transfer_batch_tokens(caller, args, null, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) err;
      case (#err(#awaited(err))) err;
    };
  };

  public shared query func icrc4_balance_of_batch(request : ICRC4.BalanceQueryArgs) : async ICRC4.BalanceQueryResult {
    icrc4().balance_of_batch(request);
  };

  public shared query func icrc4_maximum_update_batch_size() : async ?Nat {
    ?icrc4().get_state().ledger_info.max_transfers;
  };

  public shared query func icrc4_maximum_query_batch_size() : async ?Nat {
    ?icrc4().get_state().ledger_info.max_balances;
  };

  public shared ({ caller }) func admin_update_owner(new_owner : Principal) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    owner := new_owner;
    return true;
  };

  public shared ({ caller }) func admin_update_icrc1(requests : [ICRC1.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc1().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc2(requests : [ICRC2.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc2().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc4(requests : [ICRC4.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc4().update_ledger_info(requests);
  };

  // FIXED: Add functions to manage fee splits
  public shared ({ caller }) func admin_update_fee_split(treasury_bps : Nat, burn_bps : Nat) : async Bool {
    if (caller != owner) D.trap("Unauthorized");

    // Validate total equals 10000 basis points (100%)
    if (treasury_bps + burn_bps != 10000) {
      D.trap("Fee split must total 10000 basis points");
    };

    fee_split_bps := {
      treasury = treasury_bps;
      burn = burn_bps;
    };
    true;
  };

  public query ({ caller }) func get_fee_split() : async {
    treasury : Nat;
    burn : Nat;
  } {
    if (caller != owner) D.trap("Unauthorized");
    fee_split_bps;
  };

  public query ({ caller }) func get_revenue_info() : async {
    revenue_account : ICRC1.Account;
    treasury_account : ICRC1.Account;
    current_balance : Nat;
    last_swept_balance : Nat;
    available_to_sweep : Nat;
  } {
    if (caller != owner) D.trap("Unauthorized");
    let current_bal = balance_of(revenue_account);
    {
      revenue_account = revenue_account;
      treasury_account = treasury_account;
      current_balance = current_bal;
      last_swept_balance = last_revenue_balance;
      available_to_sweep = if (current_bal > last_revenue_balance) {
        current_bal - last_revenue_balance;
      } else { 0 };
    };
  };

  /* /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_listener(trx: ICRC1.Transaction, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func approval_listener(trx: ICRC2.TokenApprovalNotification, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_from_listener(trx: ICRC2.TransferFromNotification, trxid: Nat) : () {

  }; */

  public shared ({ caller }) func admin_set_revenue_account(a : ICRC1.Account) : async Bool {
    if (caller != owner) D.trap("Unauthorized");
    revenue_account := a;

    // reflect ke ledger (biar collector ikut berubah)
    ignore icrc1().update_ledger_info([#FeeCollector(?a)]);
    return true;
  };

  public shared ({ caller }) func admin_set_treasury_account(a : ICRC1.Account) : async Bool {
    if (caller != owner) D.trap("Unauthorized");
    treasury_account := a;
    true;
  };

  private stable var _init = false;

  public shared ({ caller }) func admin_init() : async () {
    //can only be called once
    if (_init == false) {
      if (caller != owner) D.trap("Unauthorized");
      //ensure metadata has been registered
      let test1 = icrc1().metadata();
      let test2 = icrc2().metadata();
      let test4 = icrc4().metadata();
      let test3 = icrc3().stats();

      //uncomment the following line to register the transfer_listener
      // icrc1().register_token_transferred_listener<system>(NS_TRANSFER_FROM, transfer_listener);

      //uncomment the following line to register the transfer_listener
      // icrc2().register_token_approved_listener<system>(NS_TRANSFER_FROM, approval_listener);

      //uncomment the following line to register the transfer_listener
      // icrc2().register_transfer_from_listener<system>(NS_TRANSFER_FROM, transfer_from_listener);
    };
    _init := true;
  };

  // Deposit cycles into this canister.
  public shared func deposit_cycles() : async () {
    let amount = ExperimentalCycles.available();
    let accepted = ExperimentalCycles.accept<system>(amount);
    assert (accepted == amount);
  };

  public shared query func get_cycles_balance() : async Nat {
    ExperimentalCycles.balance();
  };

  system func postupgrade() {
    //re wire up the listener after upgrade
    //uncomment the following line to register the transfer_listener
    // icrc1().register_token_transferred_listener(NS_TRANSFER_FROM, transfer_listener);

    //uncomment the following line to register the transfer_listener
    // icrc2().register_token_approved_listener(NS_TRANSFER_FROM, approval_listener);

    //uncomment the following line to register the transfer_listener
    // icrc2().register_transfer_from_listener(NS_TRANSFER_FROM, transfer_from_listener);
  };

};
