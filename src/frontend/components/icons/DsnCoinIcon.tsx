import dsnCoinURL from "../../assets/dsn_coin.png"; // adjust path as needed

const DsnCoinIcon = () => (
    <div
        className="h-6 w-6 bg-contain bg-no-repeat bg-center rounded-full"
        style={{ backgroundImage: `url(${dsnCoinURL})` }}
    ></div>
);

export default DsnCoinIcon;
