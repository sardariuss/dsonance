import Incentives "../../src/protocol/pools/Incentives";

import { test; suite; } "mo:test";
import Float "mo:base/Float";

import { verify; Testify; } = "../utils/Testify";

suite("Incentives", func(){

    let parameters = {
        consent_steepness = 0.1;
        dissent_steepness = 1.0;
    };

    test("Consensus", func(){
        // Test with both totals at 0 - should return 0.5
        var consensus = Incentives.compute_consensus({
            total_yes = 0.0;
            total_no = 0.0;
        });
        verify<Float>(consensus, 0.5, Testify.float.equalEpsilon9);

        // Test with equal votes - should return 0.5
        consensus := Incentives.compute_consensus({
            total_yes = 100.0;
            total_no = 100.0;
        });
        verify<Float>(consensus, 0.5, Testify.float.equalEpsilon9);

        // Test with more YES votes - should return > 0.5
        consensus := Incentives.compute_consensus({
            total_yes = 75.0;
            total_no = 25.0;
        });
        verify<Float>(consensus, 0.75, Testify.float.equalEpsilon9);

        // Test with more NO votes - should return < 0.5
        consensus := Incentives.compute_consensus({
            total_yes = 30.0;
            total_no = 70.0;
        });
        verify<Float>(consensus, 0.3, Testify.float.equalEpsilon9);

        // Test with only YES votes
        consensus := Incentives.compute_consensus({
            total_yes = 1000.0;
            total_no = 0.0;
        });
        verify<Float>(consensus, 1.0, Testify.float.equalEpsilon9);

        // Test with only NO votes
        consensus := Incentives.compute_consensus({
            total_yes = 0.0;
            total_no = 500.0;
        });
        verify<Float>(consensus, 0.0, Testify.float.equalEpsilon9);

        // Test with fractional values
        consensus := Incentives.compute_consensus({
            total_yes = 33.33;
            total_no = 66.67;
        });
        verify<Float>(consensus, 0.3333, Testify.float.equalEpsilon3);
    });

    test("Resistance", func(){
        // Test NO choice - how much NO needed to reach 0.5 consensus
        var resistance = Incentives.compute_resistance({
            choice = #NO;
            total_yes = 75.0;
            total_no = 25.0;
            target_consensus = 0.5;
        });
        // 75 / (75 + 25 + 50) = 75 / 150 = 0.5
        verify<Float>(resistance, 50.0, Testify.float.equalEpsilon9);

        // Make sure the opposite choice returns the same magnitude but negative
        resistance := Incentives.compute_resistance({
            choice = #YES;
            total_yes = 75.0;
            total_no = 25.0;
            target_consensus = 0.5;
        });
        verify<Float>(resistance, -50.0, Testify.float.equalEpsilon9);

        // Test YES choice - how much YES needed to reach 0.6 consensus
        resistance := Incentives.compute_resistance({
            choice = #YES;
            total_yes = 30.0;
            total_no = 70.0;
            target_consensus = 0.6;
        });
        // (30 + 75) / (30 + 75 + 70) = 105 / 175 = 0.6
        verify<Float>(resistance, 75.0, Testify.float.equalEpsilon9);

        // Make sure the opposite choice returns the same magnitude but negative
        resistance := Incentives.compute_resistance({
            choice = #NO;
            total_yes = 30.0;
            total_no = 70.0;
            target_consensus = 0.6;
        });
        verify<Float>(resistance, -75.0, Testify.float.equalEpsilon9);

        // Test with balanced votes targeting higher consensus
        resistance := Incentives.compute_resistance({
            choice = #YES;
            total_yes = 100.0;
            total_no = 100.0;
            target_consensus = 0.75;
        });
        // (100 + 200) / (100 + 100 + 200) = 300 / 400 = 0.75
        verify<Float>(resistance, 200.0, Testify.float.equalEpsilon9);

        // Test with balanced votes targeting lower consensus
        resistance := Incentives.compute_resistance({
            choice = #NO;
            total_yes = 100.0;
            total_no = 100.0;
            target_consensus = 0.25;
        });
        // (100) / (100 + 200 + 100) = 100 / 400 = 0.25
        verify<Float>(resistance, 200.0, Testify.float.equalEpsilon9);

        // Test edge case: moving from strong NO to balanced
        resistance := Incentives.compute_resistance({
            choice = #YES;
            total_yes = 10.0;
            total_no = 90.0;
            target_consensus = 0.5;
        });
        // (10 + 80) / (10 + 80 + 90) = 90 / 180 = 0.5
        verify<Float>(resistance, 80.0, Testify.float.equalEpsilon9);

        // Test with zero votes
        resistance := Incentives.compute_resistance({
            choice = #YES;
            total_yes = 0.0;
            total_no = 0.0;
            target_consensus = 0.7;
        });
        verify<Float>(resistance, 0.0, Testify.float.equalEpsilon9);
    });

    test("Opposite Worth", func(){
        // Test YES choice at consensus 0.6
        var total_yes = 60.0;
        var total_no = 40.0;
        var consensus = Incentives.compute_consensus({ total_yes; total_no; });
        verify<Float>(consensus, 0.6, Testify.float.equalEpsilon9);

        let yes_amount = 100.0;
        var opposite_worth = Incentives.compute_opposite_worth({
            choice = #YES;
            amount = yes_amount;
            consensus;
        });

        // Add yes_amount to YES and opposite_worth to NO
        // Consensus should remain unchanged
        var new_consensus = Incentives.compute_consensus({
            total_yes = total_yes + yes_amount;
            total_no = total_no + opposite_worth;
        });
        verify<Float>(new_consensus, consensus, Testify.float.equalEpsilon9);

        // Test NO choice at consensus 0.3
        total_yes := 30.0;
        total_no := 70.0;
        consensus := Incentives.compute_consensus({ total_yes; total_no; });
        verify<Float>(consensus, 0.3, Testify.float.equalEpsilon9);

        let no_amount = 50.0;
        opposite_worth := Incentives.compute_opposite_worth({
            choice = #NO;
            amount = no_amount;
            consensus;
        });

        // Add no_amount to NO and opposite_worth to YES
        // Consensus should remain unchanged
        new_consensus := Incentives.compute_consensus({
            total_yes = total_yes + opposite_worth;
            total_no = total_no + no_amount;
        });
        verify<Float>(new_consensus, consensus, Testify.float.equalEpsilon9);

        // Test with balanced votes (consensus 0.5)
        total_yes := 100.0;
        total_no := 100.0;
        consensus := Incentives.compute_consensus({ total_yes; total_no; });
        verify<Float>(consensus, 0.5, Testify.float.equalEpsilon9);

        let balanced_amount = 75.0;
        opposite_worth := Incentives.compute_opposite_worth({
            choice = #YES;
            amount = balanced_amount;
            consensus;
        });

        // At consensus 0.5, opposite worth should be equal to the amount
        verify<Float>(opposite_worth, balanced_amount, Testify.float.equalEpsilon9);

        new_consensus := Incentives.compute_consensus({
            total_yes = total_yes + balanced_amount;
            total_no = total_no + opposite_worth;
        });
        verify<Float>(new_consensus, consensus, Testify.float.equalEpsilon9);

        // Test with high consensus (0.9)
        total_yes := 90.0;
        total_no := 10.0;
        consensus := Incentives.compute_consensus({ total_yes; total_no; });
        verify<Float>(consensus, 0.9, Testify.float.equalEpsilon9);

        let high_amount = 100.0;
        opposite_worth := Incentives.compute_opposite_worth({
            choice = #NO;
            amount = high_amount;
            consensus;
        });

        new_consensus := Incentives.compute_consensus({
            total_yes = total_yes + opposite_worth;
            total_no = total_no + high_amount;
        });
        verify<Float>(new_consensus, consensus, Testify.float.equalEpsilon9);

        // Test with low consensus (0.2)
        total_yes := 20.0;
        total_no := 80.0;
        consensus := Incentives.compute_consensus({ total_yes; total_no; });
        verify<Float>(consensus, 0.2, Testify.float.equalEpsilon9);

        let low_amount = 150.0;
        opposite_worth := Incentives.compute_opposite_worth({
            choice = #YES;
            amount = low_amount;
            consensus;
        });

        new_consensus := Incentives.compute_consensus({
            total_yes = total_yes + low_amount;
            total_no = total_no + opposite_worth;
        });
        verify<Float>(new_consensus, consensus, Testify.float.equalEpsilon9);
    });

    test("Dissent", func(){
        var dissent = Incentives.compute_dissent({
            initial_addend = 100.0;
            parameters;
            choice = #YES;
            amount = 100;
            total_yes = 0;
            total_no = 0;
        });

        verify<Float>(dissent, 1.0, Testify.float.equalEpsilon9);

        dissent := Incentives.compute_dissent({
            initial_addend = 0.0;
            parameters;
            choice = #YES;
            amount = 2;
            total_yes = 9999;
            total_no = 10000;
        });

        let without_addend = dissent;

        verify<Float>(dissent, 0.5, Testify.float.equalEpsilon6);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            parameters;
            choice = #YES;
            amount = 2;
            total_yes = 9999;
            total_no = 10000;
        });

        verify<Float>(dissent, without_addend, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 0.0;
            parameters;
            choice = #YES;
            amount = 10000;
            total_yes = 0;
            total_no = 10000;
        });

        verify<Float>(dissent, 0.5, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            parameters;
            choice = #YES;
            amount = 66394;
            total_yes = 25114;
            total_no = 95243;
        });

        verify<Float>(dissent, 0.5, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            parameters;
            choice = #NO;
            amount = 131260;
            total_yes = 194000;
            total_no = 63079;
        });

        verify<Float>(dissent, 0.607, Testify.float.greaterThan);
    });
    
})