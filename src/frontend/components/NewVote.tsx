import { useAuth } from "@ic-reactor/react";
import { backendActor } from "../actors/BackendActor";
import pica from "pica";

import { useState, useEffect } from "react";

import { v4 as uuidv4 } from 'uuid';
import { useAllowanceContext } from "./context/AllowanceContext";
import { Link, useNavigate } from "react-router-dom";
import { DOCS_URL, NEW_VOTE_PLACEHOLDER, VOTE_MAX_CHARACTERS } from "../constants";
import BackArrowIcon from "./icons/BackArrowIcon";

function NewVote() {

  const INPUT_BOX_ID = "new-vote-input";

  const { authenticated, login } = useAuth({});
  
  const [text, setText] = useState("");
  const [thumbnail, setThumbnail] = useState<Uint8Array | null>(null);
  const [thumbnailPreview, setThumbnailPreview] = useState<string | null>(null);

  const { refreshBtcAllowance } = useAllowanceContext();
  const navigate = useNavigate();

  const { call: newVote, loading } = backendActor.useUpdateCall({
    functionName: 'new_vote',
    onSuccess: (result) => {
      if (result === undefined) {
        return;
      }
      if ('err' in result) {
        console.error(result.err);
        return;
      }
      refreshBtcAllowance();
      navigate(`/vote/${result.ok.vote_id}`);
      
    },
    onError: (error) => {
      console.error(error);
    }
  });

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file && file.type === "image/png") {
      const image = new Image();
      const reader = new FileReader();

      reader.onload = () => {
        if (reader.result) {
          image.src = reader.result as string;
          setThumbnailPreview(reader.result as string); // Set preview
        }
      };

      image.onload = async () => {
        const canvas = document.createElement("canvas"); // @todo: useless ?
        const offscreenCanvas = document.createElement("canvas");
        const picaInstance = pica();

        const { width, height } = image;
        const scale = 96 / Math.min(width, height);
        offscreenCanvas.width = Math.round(width * scale);
        offscreenCanvas.height = Math.round(height * scale);

        try {
          await picaInstance.resize(image, offscreenCanvas);
          const blob = await picaInstance.toBlob(offscreenCanvas, "image/png");
          if (blob) {
            const arrayBuffer = await blob.arrayBuffer();
            const resizedThumbnail = new Uint8Array(arrayBuffer);
            setThumbnail(resizedThumbnail);

            // Update the preview with the resized image
            const resizedPreviewUrl = URL.createObjectURL(blob);
            setThumbnailPreview(resizedPreviewUrl);
          }
        } catch (error) {
          console.error("Image resizing failed:", error);
          alert("Failed to process the image.");
        }
      };

      reader.readAsDataURL(file);
    } else {
      alert("Please select a valid PNG file.");
    }
  };

  const openVote = () => {
    if (authenticated) {
      if (thumbnail === null) {
        throw new Error("Thumbnail is null");
      };
      newVote([{ text, id: uuidv4(), from_subaccount: [], thumbnail }]);
    } else {
      login();
    }
  }

  useEffect(() => {
    
    let proposeVoteInput = document.getElementById(INPUT_BOX_ID);

    const listener = function (this: HTMLElement, _ : Event) {
      setText(this.textContent ?? "");
      // see https://stackoverflow.com/a/73813273
      if (this.innerText.length === 1 && this.children.length === 1){
        this.firstChild?.remove();
      }      
    };
    
    proposeVoteInput?.addEventListener('input', listener);
    
    return () => {
      proposeVoteInput?.removeEventListener('input', listener);
    }
  }, []);

  return (
    <div className="flex flex-col gap-6 bg-slate-50 dark:bg-slate-850 p-6 sm:my-6 sm:rounded-md shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3 h-full sm:h-auto justify-between">

      <div className="w-full grid grid-cols-3 space-x-1 mb-3 items-center">
        <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
          <BackArrowIcon/>
        </div>
        <span className="text-xl font-semibold items-baseline justify-self-center truncate">Create vote</span>
        <span className="grow">{/* spacer */}</span>
      </div>

      <div className="flex flex-col gap-y-2">
        <div className="bg-slate-200 dark:bg-gray-800 p-4 rounded-md">
          <ul className="mt-2 text-md leading-relaxed">
            <li>✅ Be precise and measurable.</li>
            <li>✅ Ensure your statement is time-bound.</li>
            <li>❌ Avoid absolute moral or ideological claims.</li>
            <li>❌ No personal or defamatory statements.</li>
          </ul>
          <Link to={DOCS_URL} className="text-blue-500 mt-2 inline-block text-md hover:underline" target="_blank" rel="noopener">
            Read the full guidelines →
          </Link>
        </div>
        <div 
          id={INPUT_BOX_ID} 
          className={`input-box break-words min-h-24 w-full text-sm p-3 rounded-lg border transition-all duration-200 bg-slate-200 dark:bg-gray-800 border-gray-300 dark:border-slate-700 focus:ring-2 focus:ring-purple-500
            ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
          data-placeholder={NEW_VOTE_PLACEHOLDER}
          contentEditable="true"
        />
        <div className="flex flex-col gap-y-2">
          <label htmlFor="thumbnail-upload" className="text-sm text-gray-600 dark:text-gray-400">
            Upload Thumbnail (PNG only):
          </label>
          <label
            htmlFor="thumbnail-upload"
            className={`button-simple text-lg text-center cursor-pointer inline-block px-4 py-2 w-40`}
          >
            Choose File
          </label>
          <input
            id="thumbnail-upload"
            type="file"
            accept="image/png"
            onChange={handleFileChange}
            className="hidden"
          />
          {thumbnailPreview && (
            <div className="mt-4">
              <img
                className="w-20 h-20 bg-contain bg-no-repeat bg-center rounded-md"
                src={thumbnailPreview}
                alt="Thumbnail Preview"
              />
            </div>
          )}
        </div>
      </div>

      <span className="grow">{/* spacer */}</span>

      <div className="flex flex-row gap-x-2 w-full items-center sm:items-center justify-end">
        
        {
          // @int: DSN minted temporarily disabled
        /*
        <div className="flex flex-row gap-x-2">
          <span className="text-sm text-gray-600 dark:text-gray-400">Fee:</span>
          {formatBalanceE8s(5_000_000_000n, DSONANCE_COIN_SYMBOL, 2)}
        </div>
        */}
        <button className={`button-simple text-lg`} 
                onClick={openVote}
                disabled={loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS || thumbnail === null}>
          Create vote
        </button>
      </div>
    </div>
  );
}

export default NewVote;
