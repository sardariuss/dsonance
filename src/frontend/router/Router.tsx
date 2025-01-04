import { Route, Routes } from "react-router-dom";
import { useAuth } from "@ic-reactor/react";

import VoteList from "../components/VoteList";
import User from "../components/user/User";
import Info from "../components/Info";
import Vote from "../components/Vote";

const Router = () => {
    const { identity } = useAuth({});
  
    return (
      <Routes>
        <Route path={"/"} element={<VoteList />} />
        <Route path={"/info"} element={<Info />} />
        <Route path={"/user/:principal"} element={<User />} />
        <Route path={"/vote/:id"} element={<Vote />} />
      </Routes>
    );
  };
  
  export default Router;
  