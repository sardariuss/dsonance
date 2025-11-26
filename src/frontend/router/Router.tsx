import { Route, Routes } from "react-router-dom";

import PoolList from "../components/PoolList";
import Profile from "../components/user/Profile";
import Dashboard from "../components/Dashboard";
import Pool from "../components/Pool";
import NewPool from "../components/NewPool";
import FaucetPage from "../components/FaucetPage";
import DaoPage from "../components/dao/DaoPage";
import ProtocolPage from "../components/ProtocolPage";

const Router = () => {
  
    return (
      <Routes>
        <Route path={"/"} element={<PoolList />} />
        <Route path={"/new"} element={<NewPool />} />
        <Route path={"/dashboard"} element={<Dashboard />} />
        <Route path={"/dao"} element={<DaoPage />} />
        <Route path={"/protocol"} element={<ProtocolPage />} />
        <Route path={"/user/:principal"} element={<Profile />} />
        <Route path={"/pool/:id"} element={<Pool />} />
        <Route path={"/faucet"} element={<FaucetPage/>} />
      </Routes>
    );
  };
  
  export default Router;
  