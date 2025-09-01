import UtilizationUpdater "../../../src/protocol/lending/UtilizationUpdater";
import { test; suite; } "mo:test";
import { verify; Testify; } = "../../utils/Testify";

suite("Utilization", func() {

    test("add_raw_supplied increases raw_supplied and updates ratio", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 100.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.add_raw_supplied(u0, 100);
        verify(result, expected, Testify.utilization.equal);
    });

    test("remove_raw_supplied decreases raw_supplied and updates ratio", func() {
        let u0 = {
            raw_supplied = 200.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 150.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.remove_raw_supplied(u0, 50.0);
        verify(result, expected, Testify.utilization.equal);
    });

    test("add_raw_borrow increases raw_borrowed and updates ratio", func() {
        let u0 = {
            raw_supplied = 100.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 100.0;
            raw_borrowed = 75.0;
            ratio = 75.0 / 100.0; // Pure mathematical ratio: borrowed / supplied
        };
        let result = UtilizationUpdater.add_raw_borrow(u0, 75);
        verify(result, #ok(expected), Testify.result(Testify.utilization.equal, Testify.text.equal).equal);
    });

    test("remove_raw_borrow decreases raw_borrowed and updates ratio", func() {
        let u0 = {
            raw_supplied = 100.0;
            raw_borrowed = 80.0;
            ratio = 80.0 / 100.0; // Pure mathematical ratio: borrowed / supplied
        };
        let expected = {
            raw_supplied = 100.0;
            raw_borrowed = 50.0;
            ratio = 50.0 / 100.0; // Pure mathematical ratio: borrowed / supplied
        };
        let result = UtilizationUpdater.remove_raw_borrow(u0, 30.0);
        verify(result, expected, Testify.utilization.equal);
    });

    test("add_raw_borrow fails if trying to borrow more than supplied", func() {
        let u0 = {
            raw_supplied = 100.0;
            raw_borrowed = 95.0;
            ratio = 0.95;
        };
        let result = UtilizationUpdater.add_raw_borrow(u0, 10);
        verify(result, #err("Cannot borrow more than total supplied: 105 > 100"), Testify.result(Testify.utilization.equal, Testify.text.equal).equal);
    });

    test("ratio is 0.0 if nothing supplied", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.add_raw_borrow(u0, 0);
        verify(result, #ok(expected), Testify.result(Testify.utilization.equal, Testify.text.equal).equal);
    });

    test("add_raw_borrow fails if nothing supplied but trying to borrow", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.add_raw_borrow(u0, 10);
        verify(result, #err("Cannot borrow more than total supplied: 10 > 0"), Testify.result(Testify.utilization.equal, Testify.text.equal).equal);
    });

    test("remove_raw_supplied clamps to zero instead of erroring", func() {
        let u0 = {
            raw_supplied = 10.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected_clamped = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.remove_raw_supplied(u0, 20.0);
        verify(result, expected_clamped, Testify.utilization.equal);
    });

    test("remove_raw_borrow clamps to zero instead of erroring", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 5.0;
            ratio = 0.0;
        };
        let expected_clamped = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let result = UtilizationUpdater.remove_raw_borrow(u0, 10.0);
        verify(result, expected_clamped, Testify.utilization.equal);
    });

});