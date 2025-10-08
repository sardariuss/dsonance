import { YesNoChoice } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";
import { useMemo } from "react";

interface ChoiceViewProps {
  choice: EYesNoChoice;
}

const ChoiceView = ({ choice }: ChoiceViewProps) => {

    return <span className={`${choice === EYesNoChoice.Yes ? " text-brand-true dark:text-brand-true-dark" : " text-brand-false"}`}>{choice}</span>
}

export default ChoiceView;

