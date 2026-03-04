import { Link } from "react-router-dom";

const NotFound = () => {
  return (
    <div className="flex flex-col gap-4 justify-center items-center h-screen z-10">
      <h1 className="text-4xl font-bold text-white">404 - Page Not Found</h1>
      <Link to='/'>
        <button
          type="button"
          className="text-white bg-red-700 hover:bg-red-800 focus:outline-none focus:ring-4 focus:ring-red-300 font-medium rounded-full text-lg px-6 py-3 mb-4 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
        >
          Home
        </button>
      </Link>
    </div>
  );
};

export default NotFound;
