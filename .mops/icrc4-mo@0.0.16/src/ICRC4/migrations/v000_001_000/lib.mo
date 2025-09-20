import MigrationTypes "../types";
import v0_1_0 "types";

import D "mo:base/Debug";
import Opt "mo:base/Option";
import Itertools "mo:itertools/Iter";

import Vec "mo:vector";
import Map "mo:map/Map";
import Set "mo:map/Set";

module {

  type Account = v0_1_0.Account;
  type Balance = v0_1_0.Balance;

  public func upgrade(prevmigration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    let {
        max_transfers;
        max_balances;
        fee;
    } = switch(args){
      case(?args) {
        {
          args with
          max_transfers = Opt.get<Nat>(args.max_transfers, 3000);
          max_balances = Opt.get<Nat>(args.max_balances, 3000);
          fee = switch(args.fee){
            case(null) #ICRC1;
            case(?val) val;
          };
        }
      };
      case(null) {{
          max_transfers = 3000;
          max_balances = 3000;
          fee = #ICRC1;
        }
      };
    };

    

    let state : MigrationTypes.Current.State = {
      ledger_info = {
        var max_transfers = max_transfers;
        var max_balances = max_balances;
        var fee = fee;
        var metadata = null;
      };
    };

    

    return #v0_1_0(#data(state));
  };

  public func downgrade(prev_migration_state: MigrationTypes.State, args: MigrationTypes.Args, caller: Principal): MigrationTypes.State {

    return #v0_0_0(#data);
  };

};