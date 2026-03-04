import { motion } from "framer-motion";
import { X, Search, Trash2, CalendarCheck, Plus } from "lucide-react";
import { useEffect, useState } from "react";
import { toast } from "react-hot-toast";
import { get, post } from "../../services/ApiEndPoint";

const ScheduleTable = () => {
  const [showPopup, setShowPopup] = useState(false);
  const [selectedDay, setSelectedDay] = useState("");
  const [selectedPeriod, setSelectedPeriod] = useState(null);
  const [availableTeachers, setAvailableTeachers] = useState([]);
  const [selectedTeacher, setSelectedTeacher] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [filteredSchedules, setFilteredSchedules] = useState([]);
  const [scheduleData, setScheduleData] = useState([]);
  const [fdata, setFdata] = useState();
  const [selectedClass, setSelectedClass] = useState("Select a class");

  const dayMap = { M: "Monday", T: "Tuesday", W: "Wednesday", Th: "Thursday", F: "Friday" };

  const initializeSchedule = () => {
    return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"].map((day) => ({
      name: day,
      schedule: Array(4).fill(null)
    }));
  };

  const fetchSchedules = async (classId) => {
    try {
      const response = await get(`/api/admin/classS/${classId}`);
      const data = await response.data;
      setFdata(data);

      const scheduleMap = initializeSchedule();

      if (data.success && data.message === "Class schedule retrieved successfully!") {
        toast.success(data.message);

        data.schedules.forEach((item) => {
          const dayName = dayMap[item.day];
          const dayIndex = scheduleMap.findIndex((d) => d.name === dayName);
          if (dayIndex !== -1) {
            scheduleMap[dayIndex].schedule[item.period - 1] = item.teacherId.name;
          }
        });
      } else if (data.success && data.message === "No schedules found!") {
        toast.success(data.message);
      }

      setScheduleData(scheduleMap);
      setFilteredSchedules(scheduleMap);
    } catch (error) {
      if (error) {
        toast.error(error.response?.data?.message || "Error fetching schedules");
        console.error("Error fetching schedules:", error);
      }
    }
  };

  useEffect(() => {
    if (selectedClass !== "Select a class") {
      fetchSchedules(selectedClass);
    } else {

      const emptySchedule = initializeSchedule();
      setScheduleData(emptySchedule);
      setFilteredSchedules(emptySchedule);
    }
  }, [selectedClass]);

  const handleSearch = (e) => {
    const term = e.target.value.toLowerCase();
    setSearchTerm(term);
    const filtered = scheduleData.filter((day) =>
      day.name.toLowerCase().includes(term)
    );
    setFilteredSchedules(filtered);
  };

  const handleDeleteAssignment = async (dayName, index) => {
    const updatedSchedule = [...scheduleData];
    const dayIndex = updatedSchedule.findIndex((day) => day.name === dayName);
  
    if (dayIndex !== -1) {
      const assignment = updatedSchedule[dayIndex].schedule[index];
      
      const reverseDayMap = Object.fromEntries(
        Object.entries(dayMap).map(([key, value]) => [value, key])
      );
      const day = reverseDayMap[dayName];

      if (assignment && assignment !== '-') {
        const scheduleItem = fdata?.schedules?.find((item) => 
          item.day === day && item.period === (index + 1)
        );
    
        if (scheduleItem) {
          const scheduleId = scheduleItem._id;
          try {
            const request = await post(`/api/admin/deleteS/${scheduleId}`);
            toast.success(request.data.message);
            updatedSchedule[dayIndex].schedule[index] = null;
            setScheduleData(updatedSchedule);
            setFilteredSchedules(
              filteredSchedules.map(day => 
                day.name === dayName 
                  ? {...day, schedule: day.schedule.map((s, i) => i === index ? null : s)} 
                  : day
              )
            );
          } catch (error) {
            toast.error(error.response?.data?.message || "Failed to delete assignment");
          }
        }
      } else {
        toast.error("No assignment to delete at this period!");
      }
    } else {
      toast.error("Error: Day not found!");
    }
  };
  
  const handleAssign = (dayName, index) => {
    setSelectedPeriod(index + 1);

    const reverseDayMap = Object.fromEntries(
      Object.entries(dayMap).map(([key, value]) => [value, key])
    );
    const day = reverseDayMap[dayName];
    setSelectedDay(day);
    
    // Clear previous selection
    setSelectedTeacher("");
    
    // Fetch available teachers
    const fetchTeachers = async () => {
      try {
        const response = await get(`/api/admin/available?day=${day}&period=${index + 1}`);
        setAvailableTeachers(response.data.data);
      } catch (error) {
        toast.error("Failed to fetch teachers.");
      }
    };
    
    fetchTeachers();
    setShowPopup(true);
  };

  const handleAssignTeacher = async () => {
    if (!selectedTeacher) {
      toast.error("Please select a teacher");
      return;
    }
    
    try {
      const response = await post(`/api/admin/assignS`, {
        classId: selectedClass,
        teacherId: selectedTeacher,
        day: selectedDay,
        period: selectedPeriod,
      });
      
      toast.success(response.data.message);
      setShowPopup(false);
      fetchSchedules(selectedClass);
    } catch (error) {
      toast.error(error.response?.data?.message || "Failed to assign teacher");
    }
  };

  return (
    <motion.div
      className="bg-gray-800 bg-opacity-50 backdrop-blur-md shadow-lg rounded-xl p-6 border border-gray-700 mb-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.2 }}
    >
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-semibold text-gray-100">Schedule Table</h2>
        <div className="flex gap-4">
          <select
            className="bg-gray-700 text-white placeholder-gray-400 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            onChange={(e) => setSelectedClass(e.target.value)}
            value={selectedClass}
          >
            <option value="Select a class">Select a class</option>
            <option value="CST101">CST101</option>
            <option value="MAT101">MAT101</option>
          </select>
        </div>
      </div>

      <div className="relative mb-6">
        <input
          type="text"
          placeholder="Search schedules..."
          className="bg-gray-700 text-white placeholder-gray-400 rounded-lg pl-10 pr-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          onChange={handleSearch}
          value={searchTerm}
        />
        <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-700">
          <thead>
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Day
              </th>
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
                  <td
                    key={index}
                    className="px-6 py-4 whitespace-nowrap text-sm text-gray-300"
                  >
                    <div className="flex items-center ">
                      <span>{subject || ""}</span>
                      
                      {selectedClass !== "Select a class" && (
                        subject ? (
                          <button
                            className="text-red-400 hover:text-red-300 ml-2"
                            onClick={() => handleDeleteAssignment(day.name, index)}
                          >
                            <Trash2 size={16} />
                          </button>
                        ) : (
                          <button
                            className="text-green-400 hover:text-green-300"
                            onClick={() => handleAssign(day.name, index)}
                          >
                            <Plus size={16} />
                          </button>
                        )
                      )}
                    </div>
                  </td>
                ))}
              </motion.tr>
            ))}
          </tbody>
        </table>
        
        {showPopup && (
          <div className="fixed inset-0 flex justify-center items-center bg-gray-700 bg-opacity-50">
            <div className="bg-gray-800 rounded-lg p-6 w-80">
              <div className="flex justify-between items-center">
                <h3 className="text-xl font-semibold">Assign Teacher</h3>
                <button onClick={() => setShowPopup(false)} className="text-gray-500 hover:text-gray-400">
                  <X size={20} />
                </button>
              </div>
              <div className="mt-4">
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-300">Day: {dayMap[selectedDay] || selectedDay}</label>
                </div>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-300">Period: {selectedPeriod}</label>
                </div>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-300">Select Teacher</label>
                  <select
                    className="w-full mt-4 p-2 bg-gray-700 text-white rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    onChange={(e) => setSelectedTeacher(e.target.value)}
                    value={selectedTeacher}
                  >
                    <option value="">Select a teacher</option>
                    {availableTeachers.map((teacher) => (
                      <option
                        key={teacher._id}
                        value={teacher._id}
                      >
                        {teacher.name}
                      </option>
                    ))}                  
                  </select>
                </div>
                <div className="flex justify-end">
                  <button
                    className="bg-blue-500 text-white py-2 px-4 rounded-lg hover:bg-blue-600"
                    onClick={handleAssignTeacher}
                    disabled={!selectedTeacher}
                  >
                    Assign
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </motion.div>
  );
};

export default ScheduleTable;
