import { motion } from "framer-motion";
import { useDispatch, useSelector } from "react-redux";
import { useNavigate } from "react-router-dom";
import { post } from "../../services/ApiEndPoint";
import { toast } from "react-hot-toast";
import { Logout } from "../../Redux/AuthSlice";


const UserData = () => {

    const user =useSelector((state)=> state.Auth.user)
    const dispacth =useDispatch()
    const navigate = useNavigate()
    const logout = async()=>{

        try {
          const request = await post('/api/auth/logout')
          const response = request.data
          if(request.status==200){
            toast.success(response.message);
            dispacth(Logout())
            navigate('/login')
          }
        } catch (error) {
          // console.log(error)
          if(error.response){
            toast.error(error.response.data.message)
          }
        }
    }
    

    return (
      <motion.div
        className="bg-gray-800 bg-opacity-50 backdrop-filter backdrop-blur-lg shadow-lg rounded-xl p-6 border border-gray-700"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 1.0 }}
      >
        <h2 className="text-2xl font-semibold text-gray-100 mb-4">Welcome, {user.name}</h2>
        
        <div className="space-y-6">
          <div className="flex flex-col space-y-4">
            {user ? (
              <p className="text-xl text-gray-300">
                Name: {user.name}
                <br />
                Email: {user.email}
                <br />
                Role: {user.role}
              </p>
            ) : (
              ""
            )}
    
            <div className="flex justify-center">
              <button
                type="button"
                className="text-white bg-red-700 hover:bg-red-800 focus:outline-none focus:ring-4 focus:ring-red-300 font-medium rounded-full text-lg px-6 py-3 mb-4 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
                onClick={logout}
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </motion.div>
    );
  }
export default UserData;
