import { useAuth } from "@nfid/identitykit/react";
import { backendActor } from "./actors/BackendActor";
import pica from "pica";

import { useState, useEffect } from "react";

import { v4 as uuidv4 } from 'uuid';
import { Link, useNavigate } from "react-router-dom";
import { DOCS_URL, NEW_VOTE_PLACEHOLDER, VOTE_MAX_CHARACTERS } from "../constants";
import BackArrowIcon from "./icons/BackArrowIcon";
import { showErrorToast, showSuccessToast, extractErrorMessage } from '../utils/toasts';

function NewVote() {

  const INPUT_BOX_ID = "new-vote-input";

  const { user, connect } = useAuth();
  const authenticated = !!user;
  
  const [text, setText] = useState("");
  const [thumbnail, setThumbnail] = useState<Uint8Array | null>(null);
  const [thumbnailPreview, setThumbnailPreview] = useState<string | null>(null);

  const navigate = useNavigate();

  const { call: newVote, loading } = backendActor.authenticated.useUpdateCall({
    functionName: 'new_vote',
    onSuccess: (result) => {
      if (result === undefined) {
        return;
      }
      if ('err' in result) {
        console.error(result.err);
        showErrorToast(extractErrorMessage(result.err), "New vote");
        return;
      }
      showSuccessToast("Your vote has been created successfully", "New vote");
      navigate(`/vote/${result.ok.vote_id}`);
    },
    onError: (error) => {
      console.error(error);
      showErrorToast(extractErrorMessage(error), "New vote");
    }
  });

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file && file.type.startsWith("image/")) {
      const image = new Image();
      const reader = new FileReader();

      reader.onload = () => {
        if (reader.result) {
          image.src = reader.result as string;
          setThumbnailPreview(reader.result as string); // Set preview
        }
      };

      image.onload = async () => {
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
          showErrorToast("Failed to process the image. Please try again.", "Image upload");
        }
      };

      reader.readAsDataURL(file);
    } else {
      showErrorToast("Please select a valid image file.", "Image upload");
    }
  };

  const openVote = () => {
    if (authenticated) {
      if (thumbnail === null) {
        throw new Error("Thumbnail is null");
      };
      newVote([{ text, id: uuidv4(), from_subaccount: [], thumbnail }]);
    } else {
      connect();
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
    <div className="flex flex-col gap-6 w-full max-w-4xl mx-auto">
      {/* Work in progress notice */}
      <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 p-4 rounded-lg">
        <div className="flex items-center gap-3">
          <span className="text-amber-600 dark:text-amber-400 text-xl mt-0.5">ℹ️</span>
          <div className="flex-1">
            <p className="text-sm text-gray-700 dark:text-gray-300">
              <span className="font-semibold">Work in progress:</span> Any user can currently open new pools. Soon, only DAO members will be able to propose new pools, which will then be subject to community voting.
            </p>
          </div>
        </div>
      </div>

      {/* Guidelines Card */}
      <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 p-4 rounded-lg">
        <h3 className="font-semibold text-gray-900 dark:text-white mb-2">Pool Suggestion Guidelines</h3>
        <ul className="space-y-1 text-sm text-gray-700 dark:text-gray-300">
          <li className="flex items-start gap-2">
            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
            <span>Be precise and fact-based</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
            <span>Claims must be investigable — something evidence could confirm or refute</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-green-600 dark:text-green-400 mt-0.5">✓</span>
            <span>Focus on past or ongoing events</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-red-600 dark:text-red-400 mt-0.5">✗</span>
            <span>Avoid topics whose resolution date is known in advance</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-red-600 dark:text-red-400 mt-0.5">✗</span>
            <span>Avoid moral judgments or unverifiable personal opinions</span>
          </li>
        </ul>
        <Link to={DOCS_URL} className="text-blue-600 dark:text-blue-400 mt-3 inline-flex items-center text-sm hover:underline font-medium" target="_blank" rel="noopener">
          Read full guidelines →
        </Link>
      </div>

      {/* Main Content Area */}
      <div className="flex flex-col lg:flex-row gap-6">
        {/* Left: Text Input */}
        <div className="flex-1 flex flex-col gap-2">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Pool Statement
          </label>
          <div
            id={INPUT_BOX_ID}
            className={`input-box break-words min-h-40 w-full text-base p-4 rounded-lg border-2 transition-all duration-200
              bg-white dark:bg-gray-900
              border-gray-300 dark:border-gray-600
              hover:border-gray-400 dark:hover:border-gray-500
              focus:border-blue-500 dark:focus:border-blue-400 focus:ring-2 focus:ring-blue-100 dark:focus:ring-blue-900/30
              ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-400 dark:text-gray-500"}`}
            data-placeholder={NEW_VOTE_PLACEHOLDER}
            contentEditable="true"
          />
          <div className="flex justify-between items-center">
            <span className="text-xs text-gray-500 dark:text-gray-400">
              {text.length > 0 ? `${text.length} / ${VOTE_MAX_CHARACTERS} characters` : ''}
            </span>
            {text.length > VOTE_MAX_CHARACTERS && (
              <span className="text-xs text-red-600 dark:text-red-400">
                Character limit exceeded
              </span>
            )}
          </div>
        </div>

        {/* Right: Thumbnail Upload */}
        <div className="flex flex-col gap-2">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Thumbnail Image
          </label>
          <label
            htmlFor="thumbnail-upload"
            className={`relative w-10 h-10 rounded-lg border-2 border-dashed transition-all cursor-pointer overflow-hidden
              ${thumbnailPreview
                ? 'border-gray-300 dark:border-gray-600'
                : 'border-gray-300 dark:border-gray-600 hover:border-blue-400 dark:hover:border-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/10'
              }`}
          >
            {thumbnailPreview ? (
              <div className="relative w-full h-full group">
                <img
                  src={thumbnailPreview}
                  alt="Thumbnail Preview"
                  className="w-full h-full object-cover"
                />
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all flex items-center justify-center">
                  <span className="text-white opacity-0 group-hover:opacity-100 transition-opacity font-medium">
                    Change Image
                  </span>
                </div>
              </div>
            ) : (
              <div className="flex items-center justify-center h-full text-gray-400 dark:text-gray-500">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
              </div>
            )}
          </label>
          <input
            id="thumbnail-upload"
            type="file"
            accept="image/*"
            onChange={handleFileChange}
            className="hidden"
          />
        </div>
      </div>

      {/* Action Button */}
      <div className="flex justify-end">
        <button
          className={`px-6 py-3 rounded-lg font-medium transition-all
            ${loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS || thumbnail === null
              ? 'bg-gray-300 dark:bg-gray-700 text-gray-500 dark:text-gray-400 cursor-not-allowed'
              : 'bg-blue-600 hover:bg-blue-700 text-white shadow-md hover:shadow-lg'
            }`}
          onClick={openVote}
          disabled={loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS || thumbnail === null}
        >
          {loading ? 'Submitting...' : 'Suggest Pool'}
        </button>
      </div>
    </div>
  );
}

export default NewVote;
