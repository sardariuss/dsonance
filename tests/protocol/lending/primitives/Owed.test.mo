import Owed "../../../../src/protocol/lending/primitives/Owed";
import LendingTypes "../../../../src/protocol/lending/Types";
import { test; suite; } "mo:test";
import { verify; Testify; } = "../../../utils/Testify";

suite("Owed", func() {

    let index1 : LendingTypes.Index = { value = 1.0; timestamp = 0 };
    let index2 : LendingTypes.Index = { value = 2.0; timestamp = 1000 };

    let testify_owed_result = {
        equal = Testify.result(Testify.owed.equal, Testify.text.equal).equal;
    };

    test("new creates correct owed", func() {
        let owed = Owed.new(100, index1);
        let expected = { index = index1; accrued_amount = 100.0 };
        verify(owed, expected, Testify.owed.equal);
    });

    test("accrue_interests increases accrued_amount with higher index", func() {
        let owed = Owed.new(100, index1);
        let accrued = Owed.accrue_interests(owed, index2);
        let expected = { index = index2; accrued_amount = 200.0 };
        verify(accrued, expected, Testify.owed.equal);
    });

    test("sum adds two owed values at correct index", func() {
        let owed1 = Owed.new(100, index1);
        let owed2 = Owed.new(50, index2);
        let result = Owed.sum(owed1, owed2);
        let expected = #ok({ index = index2; accrued_amount = 200.0 + 50.0 }); // owed1 accrued to index2: 100*2/1=200
        verify(result, expected, testify_owed_result.equal);
    });

    test("sum fails if augend index > addend index", func() {
        let owed1 = Owed.new(100, index2);
        let owed2 = Owed.new(50, index1);
        let result = Owed.sum(owed1, owed2);
        verify(result, #err("Owed sum error: Index of augend is greater than index of addend"), testify_owed_result.equal);
    });

    test("sub subtracts owed values at correct index", func() {
        let owed1 = Owed.new(100, index1);
        let owed2 = Owed.new(50, index2);
        let result = Owed.sub(owed1, owed2);
        // owed1 accrued to index2: 100*2/1=200, minus 50 = 150
        let expected = #ok({ index = index2; accrued_amount = 150.0 });
        verify(result, expected, testify_owed_result.equal);
    });

    test("sub fails if subtrahend > accrued minuend", func() {
        let owed1 = Owed.new(100, index1);
        let owed2 = Owed.new(250, index2);
        let result = Owed.sub(owed1, owed2);
        verify(result, #err("Owed sub error: Subtraction resulted in negative owed amount"), testify_owed_result.equal);
    });

    test("is_valid returns true for valid owed", func() {
        let owed = Owed.new(100, index1);
        verify(Owed.is_valid(owed), true, Testify.bool.equal);
    });

    test("is_valid returns false for negative accrued_amount", func() {
        let owed = { index = index1; accrued_amount = -1.0 };
        verify(Owed.is_valid(owed), false, Testify.bool.equal);
    });

});
