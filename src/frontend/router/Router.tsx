import { Route, Routes } from "react-router-dom";

import Home from "../components/Home";
import Profile from "../components/user/Profile";
import Dashboard from "../components/Dashboard";
import Vote from "../components/Vote";
import NewVote from "../components/NewVote";
import Ballot from "../components/user/Ballot";
import BorrowPage from "../components/borrow/BorrowPage";
import FaucetPage from "../components/FaucetPage";

const Router = () => {
  
    return (
      <Routes>
        <Route path={"/"} element={<Home />} />
        <Route path={"/new"} element={<NewVote />} />
        <Route path={"/dashboard"} element={<Dashboard />} />
        <Route path={"/user/:principal"} element={<Profile />} />
        <Route path={"/vote/:id"} element={<Vote />} />
        <Route path={"/ballot/:id"} element={<Ballot />} />
        <Route path={"/borrow"} element={<BorrowPage/>} />
        <Route path={"/faucet"} element={<FaucetPage/>} />
      </Routes>
    );
  };
  
  export default Router;
  