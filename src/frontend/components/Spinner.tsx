
interface SpinnerProps {
  size: string;
}

const Spinner: React.FC<SpinnerProps> = ({ size }) => (
  <svg className={`animate-spin text-blue-500`} viewBox="0 0 50 50" style={{ width: size, height: size }}>
    <circle
      className="spinner-path"
      cx="25"
      cy="25"
      r="20"
      fill="none"
      stroke="currentColor"
      strokeWidth="5"
    />
  </svg>
);

export default Spinner;