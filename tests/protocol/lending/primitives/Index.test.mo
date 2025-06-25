import Index "../../../../src/protocol/lending/primitives/Index";
import LendingTypes "../../../../src/protocol/lending/Types";
import { test; suite; } "mo:test";
import { verify; Testify; } = "../../../utils/Testify";

suite("Index", func() {

    let idx1 : LendingTypes.Index = { value = 1.0; timestamp = 1000 };
    let idx2 : LendingTypes.Index = { value = 2.0; timestamp = 2000 };
    let idx3 : LendingTypes.Index = { value = 1.0; timestamp = 1000 };
    let idx_neg : LendingTypes.Index = { value = -1.0; timestamp = 1000 };

    test("less_or_equal returns true for smaller timestamp and value", func() {
        verify(Index.less_or_equal(idx1, idx2), true, Testify.bool.equal);
    });

    test("less_or_equal returns true for equal timestamp and value", func() {
        verify(Index.less_or_equal(idx1, idx3), true, Testify.bool.equal);
    });

    test("less_or_equal returns false if timestamp is greater", func() {
        verify(Index.less_or_equal(idx2, idx1), false, Testify.bool.equal);
    });

    test("less_or_equal returns false if value is greater", func() {
        let idx4 : LendingTypes.Index = { value = 3.0; timestamp = 1000 };
        verify(Index.less_or_equal(idx4, idx1), false, Testify.bool.equal);
    });

    test("equal returns true for identical indexes", func() {
        verify(Index.equal(idx1, idx3), true, Testify.bool.equal);
    });

    test("equal returns false for different value", func() {
        verify(Index.equal(idx1, idx2), false, Testify.bool.equal);
    });

    test("equal returns false for different timestamp", func() {
        let idx5 : LendingTypes.Index = { value = 1.0; timestamp = 2000 };
        verify(Index.equal(idx1, idx5), false, Testify.bool.equal);
    });

    test("is_valid returns true for non-negative value", func() {
        verify(Index.is_valid(idx1), true, Testify.bool.equal);
    });

    test("is_valid returns false for negative value", func() {
        verify(Index.is_valid(idx_neg), false, Testify.bool.equal);
    });

});
