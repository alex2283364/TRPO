import { User } from "lucide-react";
import SettingSection from "./SettingSection";
import { useSelector } from "react-redux";

const Profile = () => {

	const user = useSelector((state)=>state.Auth.user)
	console.log(user)
	return (
		<SettingSection icon={User} title={"Profile"}>
			<div className='flex flex-col sm:flex-row items-center mb-6 '>
				<div className="h-10 w-10 rounded-full bg-gradient-to-r from-purple-400 to-blue-500 flex items-center justify-center text-white font-semibold mr-19">
					{user.name.charAt(0)}
				</div>

				<div className="ml-4">
					<h3 className='text-lg font-semibold text-gray-100'>{user.name}</h3>
					<p className='text-gray-400'>{user.email}</p>
				</div>
			</div>

			<button className='bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded transition duration-200 w-full sm:w-auto'>
				Edit Profile
			</button>
		</SettingSection>
	);
};
export default Profile;
