
import { EYesNoChoice } from "../utils/conversions/yesnochoice";

interface ChoiceViewProps {
  choice: EYesNoChoice;
}

const ChoiceView = ({ choice }: ChoiceViewProps) => {

    return <span className={`px-1 rounded text-sm font-medium ${choice === EYesNoChoice.Yes ? "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300" : "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"}`}>{choice}</span>
}

export default ChoiceView;

