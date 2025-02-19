import { Route, Routes } from "react-router-dom";

import Home from "../components/Home";
import User from "../components/user/User";
import Dashboard from "../components/Dashboard";
import Vote from "../components/Vote";
import NewVote from "../components/NewVote";

const Router = () => {
  
    return (
      <Routes>
        <Route path={"/"} element={<Home />} />
        <Route path={"/new"} element={<NewVote />} />
        <Route path={"/dashboard"} element={<Dashboard />} />
        <Route path={"/user/:principal"} element={<User />} />
        <Route path={"/vote/:id"} element={<Vote />} />
      </Routes>
    );
  };
  
  export default Router;
  