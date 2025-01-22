
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import VoteView from "./VoteView";
import { useEffect, useState } from "react";
import NewVote from "./NewVote";
import { TabButton } from "./TabButton";
import { toNullable } from "@dfinity/utils";

function VoteList() {

  const { authenticated } = useAuth();

  const [selectedVote, setSelectedVote] = useState<string | null>(null);
  const [currentCategory, setCurrentCategory] = useState<string | undefined>(undefined);
  // Somehow a useState is required otherwise the votes require two fetches to show up
  const [votes, setVotes] = useState<SYesNoVote[] | undefined>(undefined);

  const { call: fetchVotes } = backendActor.useQueryCall({
    functionName: 'get_votes',
  });

  const { data: categories } = backendActor.useQueryCall({
    functionName: 'get_categories',
  });

  const refreshVotes = () => {
    fetchVotes([{ category: toNullable(currentCategory) }]).then(setVotes);
  }

  useEffect(() => {
    refreshVotes();
  }
  , [currentCategory]);

  return (
    <div className="flex flex-col border-x dark:border-gray-700 w-2/3">
      <ul className="flex flex-wrap text-sm dark:text-gray-400 font-medium text-center w-full">
        <li key={0} className={`border-b dark:border-gray-700 grow`}>
          <TabButton label={"All"} isCurrent={currentCategory === undefined} setIsCurrent={() => { setCurrentCategory(undefined); }}/>
        </li>
        {
          categories && categories.map((category, index) => (
            <li key={index + 1} className={`border-b dark:border-gray-700 border-l grow`}>
              <TabButton label={category} isCurrent={category === currentCategory} setIsCurrent={() => { setCurrentCategory(category); }}/>
            </li>
          ))
        }
      </ul>
      {
        authenticated && currentCategory && <NewVote refreshVotes={refreshVotes} category={currentCategory}/>
      }
      <ul>
        {
          votes && votes.map((vote: SYesNoVote, index) => (
            <li key={index}>
              <VoteView selected={selectedVote} setSelected={setSelectedVote} vote={vote} refreshVotes={refreshVotes}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default VoteList;
