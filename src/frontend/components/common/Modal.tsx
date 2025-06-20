import { ReactNode, MouseEvent } from "react";
import ReactDOM from "react-dom";
import { MdCancel } from "react-icons/md";

interface Props {
  title: string;
  isVisible: boolean;
  children: ReactNode;
  onClose: () => void;
}

const Modal = ({ title, isVisible, children, onClose }: Props) => {
  
  if (!isVisible) {
    return null;
  }

  const handleOverlayClick = (e: MouseEvent<HTMLDivElement>) => {
    if (e.currentTarget === e.target) {
      onClose();
    }
  };

  const handleModalClick = (e: MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
  };

  return ReactDOM.createPortal(
    <div
      className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 text-black"
      onClick={handleOverlayClick}
    >
      <div className="rounded bg-slate-200 dark:bg-slate-800 p-5 sm:min-w-56 flex flex-col items-center" onClick={handleModalClick}>
        <div className="flex flex-row w-full justify-between items-center mb-5">
          <span className="text-black dark:text-white text-lg font-semibold">{title}</span>
          <button onClick={onClose} className="text-black dark:text-white self-end">
            <MdCancel size={28} />
          </button>
        </div>
        {children}
      </div>
    </div>,
    document.body
  );
};

export default Modal;
