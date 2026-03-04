import {  Navigate, Route, Routes } from "react-router-dom";

import Sidebar from "./components/common/Sidebar";
import PublicLayout from "./Layouts/PublicLayout";
import UserLayout from "./Layouts/UserLayout";
import DashBoard from "./pages/DashPage";
import Schedule from "./pages/SchedulePAge";
import UsersPage from "./pages/UsersPage";
import Teachers from "./pages/TeachersPage";
import SettingsPage from "./pages/SettingsPage";
import Login from "./pages/LoginPage";
import Signup from "./pages/SignupPage";
import Students from "./pages/StudentsPage";
import { useSelector } from "react-redux";
import NotFound from "./components/common/Notfound";

function App() {

	const user = useSelector((state)=>state.Auth.user)
	
	return (
		<>
			<div className='fixed inset-0 z-0'>
				<div className='absolute inset-0 bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 opacity-80' />
				<div className='absolute inset-0 backdrop-blur-sm' />
				<Routes>
				<Route element={<PublicLayout />}>
					<Route path="/" element={<Navigate to="/login" />} />
					<Route path="/login" element={<Login />} />
					<Route path="/signup" element={<Signup />} />
				</Route>
				</Routes>	
				<div className='flex justify-center h-screen bg-gray-900 text-gray-100 overflow-hidden'>
				{user?<Sidebar />:''}
				<Routes>
					<Route element={<UserLayout/>}>
						<Route path='/dashboard' element={<DashBoard />} />
						<Route path='/schedule' element={<Schedule />} />
						<Route path='/users' element={<UsersPage />} />
						<Route path='/teachers' element={<Teachers />} />
						<Route path='/students' element={<Students />} />
						<Route path='/settings' element={<SettingsPage />} />
					</Route>
					<Route path="*" element={<NotFound/>} />
				</Routes>
				</div>
			</div>
		</>
	);
}

export default App;
