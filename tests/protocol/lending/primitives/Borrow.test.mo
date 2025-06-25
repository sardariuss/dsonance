import Borrow "../../../../src/protocol/lending/primitives/Borrow";
import Owed "../../../../src/protocol/lending/primitives/Owed";
import LendingTypes "../../../../src/protocol/lending/Types";
import { test; suite; } "mo:test";
import { verify; optionalTestify; Testify; } = "../../../utils/Testify";

suite("Borrow", func() {

    let index1 : LendingTypes.Index = { value = 1.0; timestamp = 0 };
    let index2 : LendingTypes.Index = { value = 2.0; timestamp = 1000 };

    let testify_borrow_result = {
        equal = Testify.result(Testify.borrow.equal, Testify.text.equal).equal;
    };
    let testify_opt_borrow_result = {
        equal = Testify.result(optionalTestify(Testify.borrow.equal), Testify.text.equal).equal;
    };

    test("new creates correct borrow", func() {
        let b = Borrow.new(100, index1);
        let expected = {
            raw_amount = 100.0;
            owed = { index = index1; accrued_amount = 100.0 };
        };
        verify(b, expected, Testify.borrow.equal);
    });

    test("sum adds two borrows", func() {
        let b1 = Borrow.new(100, index1);
        let b2 = Borrow.new(50, index2);
        let result = Borrow.sum(b1, b2);
        // owed1 accrued to index2: 100*2/1=200, plus 50 = 250
        let expected = #ok({
            raw_amount = 150.0;
            owed = { index = index2; accrued_amount = 250.0 };
        });
        verify(result, expected, testify_borrow_result.equal);
    });

    test("sum fails if augend is invalid", func() {
        let b1 = { raw_amount = 0.0; owed = { index = index1; accrued_amount = 0.0 } };
        let b2 = Borrow.new(50, index2);
        let result = Borrow.sum(b1, b2);
        verify(result, #err("Borrow.sum error: Invalid augend"), testify_borrow_result.equal);
    });

    test("slash returns null when fully repaid", func() {
        let b = Borrow.new(100, index1);
        let owed_full = Owed.new(100, index1);
        let result = Borrow.slash(b, owed_full);
        verify(result, #ok(null), testify_opt_borrow_result.equal);
    });

    test("slash returns updated borrow for partial repayment", func() {
        let b = Borrow.new(100, index1);
        let owed_partial = Owed.new(50, index1);
        let result = Borrow.slash(b, owed_partial);
        // After repaying 50, 50 remains
        let expected = #ok(?{
            raw_amount = 100.0 - 50.0; // 50 left
            owed = { index = index1; accrued_amount = 50.0 };
        });
        // But since raw_amount < EPSILON, slash returns #ok(null)
        verify(result, expected, testify_opt_borrow_result.equal);
    });

    test("slash fails if repayment owed.accrued_amount too small", func() {
        let b = Borrow.new(100, index1);
        let owed_zero = Owed.new(0, index1);
        let result = Borrow.slash(b, owed_zero);
        verify(result, #err("Borrow.repay error: Repayment owed.accrued_amount too small"), testify_opt_borrow_result.equal);
    });

    test("is_valid returns true for valid borrow", func() {
        let b = Borrow.new(100, index1);
        verify(Borrow.is_valid(b), true, Testify.bool.equal);
    });

    test("is_valid returns false for zero raw_amount", func() {
        let b = { raw_amount = 0.0; owed = { index = index1; accrued_amount = 100.0 } };
        verify(Borrow.is_valid(b), false, Testify.bool.equal);
    });

});
