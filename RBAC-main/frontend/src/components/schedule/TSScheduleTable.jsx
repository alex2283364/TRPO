import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { CalendarCheck, Search } from "lucide-react";
import { toast } from "react-hot-toast";
import { get } from "../../services/ApiEndPoint";
import { useSelector } from "react-redux";


const TeachersScheduleTable = () => {
  const user = useSelector((state) => state.Auth.user);
 const teacherId = user._id
 console.log(teacherId)

  const [scheduleData, setScheduleData] = useState([]);
  const [filteredSchedules, setFilteredSchedules] = useState([]);
  const dayMap = { M: "Monday", T: "Tuesday", W: "Wednesday", Th: "Thursday", F: "Friday" };

  const initializeSchedule = () => {
    return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].map((day) => ({
      name: day,
      schedule: Array(4).fill("-"),
    }));
  };

  useEffect(() => {
    const fetchTeacherSchedule = async () => {
      try {
        const response = await get(`/api/auth/teacherS/${teacherId}`);
        const data = response.data;
        if(data ==null){
          toast.error("No Schedule Found!");
        }
        const scheduleMap = initializeSchedule();

        data.schedules.forEach((item) => {
          const dayName = dayMap[item.day];
          const dayIndex = scheduleMap.findIndex((d) => d.name === dayName);
          if (dayIndex !== -1) {
            scheduleMap[dayIndex].schedule[item.period - 1] = item.classId; // Show class name
          }
        });

        setScheduleData(scheduleMap);
        setFilteredSchedules(scheduleMap);
      } catch (error) {
        toast.error(error.response.data.message);
      }
    };

    fetchTeacherSchedule();
  }, [teacherId]);

  return (
    <motion.div
      className="bg-gray-800 bg-opacity-50 backdrop-blur-md shadow-lg rounded-xl p-6 border border-gray-700 mb-8 mt-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 1.2 }}
    >
      <h2 className="text-xl font-semibold text-gray-100 mb-6">Your Schedule</h2>
      <table className="min-w-full divide-y divide-gray-700">
        <thead>
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Day</th>
            {["1st Hour", "2nd Hour", "3rd Hour", "4th Hour"].map((hour) => (
              <th
                key={hour}
                className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
              >
                {hour}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-700">
          {filteredSchedules.map((day) => (
            <motion.tr
              key={day.name}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
            >
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-100 flex gap-2 items-center">
                <CalendarCheck size={18} />
                {day.name}
              </td>
              {day.schedule.map((subject, index) => (
                <td key={index} className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                  {subject || "-"}
                </td>
              ))}
            </motion.tr>
          ))}
        </tbody>
      </table>
    </motion.div>
  );
};

const StudentsScheduleTable = () => {
  const [selectedClass, setSelectedClass] = useState("Select a class");
  const [scheduleData, setScheduleData] = useState([]);
  const dayMap = { M: "Monday", T: "Tuesday", W: "Wednesday", Th: "Thursday", F: "Friday" };

  const initializeSchedule = () => {
    return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].map((day) => ({
      name: day,
      schedule: Array(4).fill("-"),
    }));
  };

  const fetchClassSchedule = async (classId) => {
    try {
      const response = await get(`/api/auth/classS/${classId}`);
      const data = response.data;
      const scheduleMap = initializeSchedule();

      data.schedules.forEach((item) => {
        const dayName = dayMap[item.day];
        const dayIndex = scheduleMap.findIndex((d) => d.name === dayName);
        if (dayIndex !== -1) {
          scheduleMap[dayIndex].schedule[item.period - 1] = item.teacherId.name; // Show teacher's name
        }
      });

      setScheduleData(scheduleMap);
    } catch (error) {
      toast.error("Failed to fetch class schedule.");
    }
  };

  useEffect(() => {
    if (selectedClass !== "Select a class") {
      fetchClassSchedule(selectedClass);
    }
  }, [selectedClass]);

  return (
    <motion.div
      className="bg-gray-800 bg-opacity-50 backdrop-blur-md shadow-lg rounded-xl p-6 border border-gray-700 mb-8 mt-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 1.2 }}
    >
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold text-gray-100">Class Schedule</h2>
        <select
          className="bg-gray-700 text-white placeholder-gray-400 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          onChange={(e) => setSelectedClass(e.target.value)}
        >
          <option value="Select a class">Select a class</option>
          <option value="CST101">CST101</option>
          <option value="MAT101">MAT101</option>
        </select>
      </div>
      <table className="min-w-full divide-y divide-gray-700">
        <thead>
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Day</th>
            {["1st Hour", "2nd Hour", "3rd Hour", "4th Hour"].map((hour) => (
              <th
                key={hour}
                className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
              >
                {hour}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-700">
          {scheduleData.map((day) => (
            <motion.tr
              key={day.name}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
            >
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-100 flex gap-2 items-center">
                <CalendarCheck size={18} />
                {day.name}
              </td>
              {day.schedule.map((subject, index) => (
                <td key={index} className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                  {subject || "-"}
                </td>
              ))}
            </motion.tr>
          ))}
        </tbody>
      </table>
    </motion.div>
  );
};

export { TeachersScheduleTable, StudentsScheduleTable };
