import React, { useState, useEffect, useRef } from "react";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import { useProtocolContext } from "./ProtocolContext";

const SimulatedClock = () => {

  const { info, parameters, refreshInfo, refreshParameters } = useProtocolContext();
  const [currentTime, setCurrentTime] = useState<Date | undefined>(undefined);
  const [currentSpeed, setCurrentSpeed] = useState<number>(1.0); // Store the current speed
  const lastRealTimeRef = useRef<number>(Date.now()); // Store the last real timestamp

  useEffect(() => {
    refreshInfo();
    refreshParameters();
  }, []);

  useEffect(() => {
    setCurrentTime(info !== undefined ? timeToDate(info.current_time) : undefined);
    
  }, [info]);

  useEffect(() => {
    if (parameters !== undefined && 'SIMULATED' in parameters.clock){
      setCurrentSpeed(parameters.clock.SIMULATED.dilation_factor);
    } else {
      setCurrentSpeed(1.0);
    }
    
  }, [parameters]);
  
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
      <div className="flex flex-row items-center space-x-1">
          <span>🧪</span>
          <span className="text-gray-700 dark:text-gray-300">Simulation time:</span>
          <span className="text-lg">
              {formatDateTime(currentTime)}
          </span>
      </div>
      : <></>
  );
};

export default SimulatedClock;
