import Header from "../components/common/Header";
import DangerZone from "../components/settings/DangerZone";
import Profile from "../components/settings/Profile";
const SettingsPage = () => {
	return (
		<div className='flex-1 overflow-auto relative z-10 bg-gray-900 h-screen'>
			<Header title='Settings' />
			<main className='max-w-4xl mx-auto py-6 px-4 lg:px-8'>
				<Profile />
				<DangerZone />
			</main>
		</div>
	);
};
export default SettingsPage;
