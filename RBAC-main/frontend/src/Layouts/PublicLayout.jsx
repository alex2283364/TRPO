import React, { useEffect } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';

export default function PublicLayout() {
  const user = useSelector((state) => state.Auth.user);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    if (user) {
      if (user.role === 'HOD') {
        navigate('/dashboard'); 
      } else {
        navigate('/dashboard'); 
      }
    } else if (location.pathname === '/') {
      navigate('/login'); 
    }
  }, [user, navigate, location]);

  return <Outlet />;
}
