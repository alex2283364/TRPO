import Header from "../components/common/Header";


import ScheduleTable from "../components/schedule/ScheduleTable";

const Schedule = () => {
	return (
		<div className='flex-1 overflow-auto relative z-10 h-screen'>
			<Header title='Class Schedule' />

			<main className='max-w-7xl mx-auto py-6 px-4 lg:px-8'>

				<ScheduleTable />

			</main>
		</div>
	);
};
export default Schedule;
