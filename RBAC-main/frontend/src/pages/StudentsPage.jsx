

import Header from "../components/common/Header";
import StudetsTable from "../components/users/StudentsTable";


const Students = () => {
	return (
		<div className='flex-1 relative z-10 overflow-auto h-screen'>
			<Header title={"Manage Students"} />

			<main className='max-w-7xl mx-auto py-6 px-4 lg:px-8'>

			<StudetsTable/>
			</main>
		</div>
	);
};
export default Students;
