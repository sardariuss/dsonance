import { Route, Routes } from "react-router-dom";

import VoteList from "../components/VoteList";
import Profile from "../components/user/Profile";
import Dashboard from "../components/Dashboard";
import Vote from "../components/Vote";
import NewVote from "../components/NewVote";
import Ballot from "../components/user/Ballot";
import FaucetPage from "../components/FaucetPage";
import DaoPage from "../components/dao/DaoPage";

const Router = () => {
  
    return (
      <Routes>
        <Route path={"/"} element={<VoteList />} />
        <Route path={"/new"} element={<NewVote />} />
        <Route path={"/dashboard"} element={<Dashboard />} />
        <Route path={"/dao"} element={<DaoPage />} />
        <Route path={"/user/:principal"} element={<Profile />} />
        <Route path={"/vote/:id"} element={<Vote />} />
        <Route path={"/ballot/:id"} element={<Ballot />} />
        <Route path={"/faucet"} element={<FaucetPage/>} />
      </Routes>
    );
  };
  
  export default Router;
  