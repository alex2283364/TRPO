

import Header from "../components/common/Header";

import USTable from "../components/users/USTable";

const Teachers = () => {
	return (
		<div className='flex-1 overflow-auto relative z-10 h-screen	'>
			<Header title='Manage Teachers' />

			<main className='max-w-7xl mx-auto py-6 px-4 lg:px-8'>
				
				<USTable/>

			</main>
		</div>
	);
};
export default Teachers;
