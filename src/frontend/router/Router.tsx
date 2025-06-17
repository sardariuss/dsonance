import { Route, Routes } from "react-router-dom";

import Home from "../components/Home";
import User from "../components/user/User";
import Dashboard from "../components/Dashboard";
import Vote from "../components/Vote";
import NewVote from "../components/NewVote";
import Ballot from "../components/user/Ballot";
import BorrowTab from "../components/BorrowTab";

const Router = () => {
  
    return (
      <Routes>
        <Route path={"/"} element={<Home />} />
        <Route path={"/new"} element={<NewVote />} />
        <Route path={"/dashboard"} element={<Dashboard />} />
        <Route path={"/user/:principal"} element={<User />} />
        <Route path={"/vote/:id"} element={<Vote />} />
        <Route path={"/ballot/:id"} element={<Ballot />} />
        <Route path={"/borrow"} element={<BorrowTab/>} />
      </Routes>
    );
  };
  
  export default Router;
  