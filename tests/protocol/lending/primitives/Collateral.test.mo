import Collateral "../../../../src/protocol/lending/primitives/Collateral";
import LendingTypes "../../../../src/protocol/lending/Types";
import { test; suite; } "mo:test";
import { verify; Testify; } = "../../../utils/Testify";

suite("Collateral", func() {

    let testify_collateral_result = {
        equal = Testify.result(Testify.collateral.equal, Testify.text.equal).equal;
    };

    test("sum adds collateral amounts", func() {
        let c1 : LendingTypes.Collateral = { amount = 100 };
        let c2 : LendingTypes.Collateral = { amount = 50 };
        let expected : LendingTypes.Collateral = { amount = 150 };
        verify(Collateral.sum(c1, c2), expected, Testify.collateral.equal);
    });

    test("sub subtracts collateral amounts", func() {
        let c1 : LendingTypes.Collateral = { amount = 100 };
        let c2 : LendingTypes.Collateral = { amount = 40 };
        let expected : LendingTypes.Collateral = { amount = 60 };
        verify(Collateral.sub(c1, c2), #ok(expected), testify_collateral_result.equal);
    });

    test("sub returns #err if subtraction would be negative", func() {
        let c1 : LendingTypes.Collateral = { amount = 30 };
        let c2 : LendingTypes.Collateral = { amount = 40 };
        verify(Collateral.sub(c1, c2), #err("Subtraction resulted in negative collateral"), testify_collateral_result.equal);
    });

    test("sub returns zero if amounts are equal", func() {
        let c1 : LendingTypes.Collateral = { amount = 50 };
        let c2 : LendingTypes.Collateral = { amount = 50 };
        let expected : LendingTypes.Collateral = { amount = 0 };
        verify(Collateral.sub(c1, c2), #ok(expected), testify_collateral_result.equal);
    });

});
