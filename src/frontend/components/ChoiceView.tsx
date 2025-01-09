import { SBallotType } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";

interface ChoiceProps {
  ballot: SBallotType;
}

const ChoiceView = ({ ballot }: ChoiceProps) => {

    const choice = toEnum(ballot.YES_NO.choice);

    return <span className={`${choice === EYesNoChoice.Yes ? " text-brand-true" : " text-brand-false"}`}>{choice}</span>
}

export default ChoiceView;

