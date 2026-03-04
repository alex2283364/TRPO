import { GraduationCap, School, Users } from "lucide-react";
import { motion } from "framer-motion";
import Header from "../components/common/Header";
import StatCard from "../components/common/StatCard";
import UserData from "../components/common/UsersData";
import { useSelector } from "react-redux";
import { get } from "../services/ApiEndPoint";
import { useState, useEffect } from "react"; 
import { useNavigate } from "react-router-dom";
import { StudentsScheduleTable, TeachersScheduleTable } from "../components/schedule/TSScheduleTable";

const DashBoard = () => {
	const navigate = useNavigate();
	
	const [hodCount, setHodCount] = useState(0);
	const [teacherCount, setTeacherCount] = useState(0);
	const [studentCount, setStudentCount] = useState(0);

	const user = useSelector((state) => state.Auth.user);
	//console.log(user)
	useEffect(() => {
		
		if (!user) {
		  navigate('/');
		}
	  }, [user, navigate]);

	const getUser = async () => {
		try {
			const response = await get("/api/admin/getuser");
			if (response.status === 200) {
				const fetchedUsers = response.data.users;

				let hodCount = 0;
				let teacherCount = 0;
				let studentCount = 0;

		
				fetchedUsers.forEach((user) => {
					if (user.role === "HOD") {
						hodCount++;
					} else if (user.role === "Teacher") {
						teacherCount++;
					} else if (user.role === "Student") {
						studentCount++;
					}
				});

				setHodCount(hodCount);
				setTeacherCount(teacherCount);
				setStudentCount(studentCount);
			}
		} catch (error) {
			console.log(error);
		}
	};


	useEffect(() => {
		getUser();
	}, []); 

	return (
		<div className="flex-1 overflow-auto relative z-10 h-screen">
			<Header title="Dashboard" />

			<main className="max-w-7xl mx-auto py-6 px-4 lg:px-8">
				<motion.div
					className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8"
					initial={{ opacity: 0, y: 20 }}
					animate={{ opacity: 1, y: 0 }}
					transition={{ duration: 1 }}
				>
					{user.role === "HOD" ? (
						<>
							<StatCard name="Teachers" icon={Users} value={teacherCount} color="#6366F1" />
							<StatCard name="Students" icon={Users} value={studentCount} color="#8B5CF6" />
							<StatCard name="HOD's" icon={GraduationCap} value={hodCount} color="#EC4899" />
							<StatCard name="Classes" icon={School} value="2" color="#10B981" />
						</>
					) : null}
				</motion.div>
				<UserData />
				{user.role=='Teacher' && (<TeachersScheduleTable/>)}
				{user.role=='Student' && (<StudentsScheduleTable/>)}
			</main>
		</div>
	);
};
export default DashBoard;
