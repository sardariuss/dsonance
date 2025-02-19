import Select from "react-select";
import { SupportedCurrency, useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";

const CurrencyConverter = () => {

  const { currency, setCurrency } = useCurrencyContext();

  return (
    <div className="flex flex-row items-center space-x-1 mr-8">
        <span>View</span>
        <BitcoinIcon />
        <span className="pr-2">in</span>
        <Select
            options={Object.values(SupportedCurrency).map((currency) => ({
                value: currency,
                label: currency,
            }))}
            value={{ value: currency, label: currency }}
            onChange={(option) => {
                if (option !== null) setCurrency(option.value as SupportedCurrency);
            }}
            styles={{
            control: (provided, state) => ({
                ...provided,
                color: "#fff",
                backgroundColor: "#ddd",
                borderColor: state.isFocused ? "rgb(168 85 247) !important" : "#ccc !important", // Enforce purple border
                boxShadow: state.isFocused
                ? "0 0 0 0.5px rgb(168, 85, 247) !important"
                : "none !important", // Enforce purple focus ring
                outline: "none", // Remove browser default outline
            }),
            singleValue: (provided) => ({
                ...provided,
                color: "#000",
            }),
            option: (provided) => ({
                ...provided,
                color: "#000",
                backgroundColor: "#fff",
                "&:hover": {
                backgroundColor: "#ddd",
                },
            }),
            }}
        />
    </div>
  );
}

export default CurrencyConverter;