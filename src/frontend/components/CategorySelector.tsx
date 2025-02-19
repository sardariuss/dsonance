import Select from "react-select";
import { backendActor } from "../actors/BackendActor";

interface CategorySelectorProps {
  selectedCategory: string | null; // Only one category at a time
  setSelectedCategory: React.Dispatch<React.SetStateAction<string | null>>;
}

const CategorySelector: React.FC<CategorySelectorProps> = ({ selectedCategory, setSelectedCategory }) => {

  const { data: categories } = backendActor.useQueryCall({
    functionName: "get_categories",
    onSuccess: (categories) => {
        if (categories) {
            setSelectedCategory(categories[0]);
        }
    },
  });

  return (
    <Select
        options={Object.values(categories ?? []).map((category) => ({
            value: category,
            label: category,
        }))}
        value={{ value: selectedCategory, label: selectedCategory }}
        onChange={(option) => {
            if (option !== null) setSelectedCategory(option.value);
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
  );
};

export default CategorySelector;
