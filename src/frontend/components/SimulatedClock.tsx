import React, { useState, useEffect, useRef } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { timeToDate } from "../utils/conversions/date";

const SimulatedClock = () => {

  const speed = 1.0;

  const { call: refreshClockInfo, data: clockInfo } = protocolActor.useQueryCall({
    functionName: "clock_info",
  });

  useEffect(() => {
    refreshClockInfo();
  }, []);

  useEffect(() => {
    setCurrentTime(clockInfo !== undefined ? timeToDate(clockInfo.time) : undefined);
    setCurrentSpeed(clockInfo !== undefined ? clockInfo.dilation_factor : 1.0);
  }, [clockInfo]);
  
  const [currentTime, setCurrentTime] = useState<Date | undefined>(undefined);
  const [currentSpeed, setCurrentSpeed] = useState<number>(1.0); // Store the current speed
  
  const lastRealTimeRef = useRef<number>(Date.now()); // Store the last real timestamp
  
  useEffect(() => {

    const interval = setInterval(() => {
      const now = Date.now();
      const elapsedRealTime = now - lastRealTimeRef.current; // Real-time elapsed in ms
      const simulatedElapsedTime = elapsedRealTime * currentSpeed; // Simulated time elapsed
      lastRealTimeRef.current = now; // Update the last real-time reference
      
      // Update the current time
      setCurrentTime(prevTime =>
        prevTime ? new Date(prevTime.getTime() + simulatedElapsedTime) : undefined
      );
    }, 500); // Update every 500ms
    
    return () => clearInterval(interval); // Cleanup the timer on unmount
  }, [currentSpeed]);

  return (
    currentTime ? 
      <div className="flex flex-row items-center space-x-2">
        <span className="dark:text-gray-400 text-gray-600 text-sm">Simulation time:</span>
        <span>{currentTime.toLocaleString()}</span>
      </div> : <></>
  );
};

export default SimulatedClock;
