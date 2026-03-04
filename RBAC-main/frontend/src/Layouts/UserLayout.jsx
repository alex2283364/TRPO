import React, { useEffect, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';

export default function UserLayout() {
  const navigate = useNavigate();
  const user = useSelector((state) => state.Auth.user);
  const [isLoaded, setIsLoaded] = useState(false);  // Track if user info is loaded

  useEffect(() => {
    // Set isLoaded to true once the user state is available
    if (user !== undefined) {
      setIsLoaded(true);
    }

    // If the user is not available, redirect to login
    if (user === null) {
      navigate('/login');
    }
  }, [user, navigate]);

  if (!isLoaded) {
    return <div>Loading...</div>;  
  }

  return <Outlet />;
}
