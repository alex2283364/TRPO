import { UserCheck, UserPlus, UsersIcon } from "lucide-react";
import { motion } from "framer-motion";

import Header from "../components/common/Header";
import StatCard from "../components/common/StatCard";
import UsersTable from "../components/users/UsersTable";


const UsersPage = () => {
	return (
		<div className='flex-1 overflow-auto relative z-10 h-screen'>
			<Header title='Users' />

			<main className='max-w-7xl mx-auto py-6 px-4 lg:px-8'>
		
				<UsersTable />
			</main>
		</div>
	);
};
export default UsersPage;
