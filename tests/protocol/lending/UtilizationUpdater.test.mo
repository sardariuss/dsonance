import UtilizationUpdater "../../../src/protocol/lending/UtilizationUpdater";
import { test; suite; } "mo:test";
import { verify; Testify; } = "../../utils/Testify";

suite("Utilization", func() {

    let parameters = {
        reserve_liquidity = 0.1;
    };
    let updater = UtilizationUpdater.UtilizationUpdater({ parameters });

    let testify_utilization_result = {
        equal = Testify.result(Testify.utilization.equal, Testify.text.equal).equal;
    };

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
        verify(updater.add_raw_supplied(u0, 100), #ok(expected), testify_utilization_result.equal);
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
        verify(updater.remove_raw_supplied(u0, 50.0), #ok(expected), testify_utilization_result.equal);
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
            ratio = 75.0 / 90.0;
        };
        verify(updater.add_raw_borrow(u0, 75), #ok(expected), testify_utilization_result.equal);
    });

    test("remove_raw_borrow decreases raw_borrowed and updates ratio", func() {
        let u0 = {
            raw_supplied = 100.0;
            raw_borrowed = 80.0;
            ratio = 0.8 / 0.9; // 80/90
        };
        let expected = {
            raw_supplied = 100.0;
            raw_borrowed = 50.0;
            ratio = 50.0 / 90.0;
        };
        verify(updater.remove_raw_borrow(u0, 30.0), #ok(expected), testify_utilization_result.equal);
    });

    test("ratio is 1.0 if borrowed > available", func() {
        let u0 = {
            raw_supplied = 100.0;
            raw_borrowed = 95.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 100.0;
            raw_borrowed = 105.0;
            ratio = 1.0;
        };
        verify(updater.add_raw_borrow(u0, 10), #ok(expected), testify_utilization_result.equal);
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
        verify(updater.add_raw_borrow(u0, 0), #ok(expected), testify_utilization_result.equal);
    });

    test("ratio is 1.0 if nothing supplied but something borrowed", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        let expected = {
            raw_supplied = 0.0;
            raw_borrowed = 10.0;
            ratio = 1.0;
        };
        verify(updater.add_raw_borrow(u0, 10), #ok(expected), testify_utilization_result.equal);
    });

    test("remove_raw_supplied returns #err if removing too much", func() {
        let u0 = {
            raw_supplied = 10.0;
            raw_borrowed = 0.0;
            ratio = 0.0;
        };
        verify(
            updater.remove_raw_supplied(u0, 20.0),
            #err("Cannot remove more than total supplied"),
            testify_utilization_result.equal
        );
    });

    test("remove_raw_borrow returns #err if removing too much", func() {
        let u0 = {
            raw_supplied = 0.0;
            raw_borrowed = 5.0;
            ratio = 0.0;
        };
        verify(
            updater.remove_raw_borrow(u0, 10.0),
            #err("Cannot remove more than total borrowed"),
            testify_utilization_result.equal
        );
    });

});