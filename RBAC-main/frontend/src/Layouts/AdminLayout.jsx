import React, { useEffect } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';

export default function AdminLayout() {
  const navigate = useNavigate();
  const user = useSelector((state) => state.Auth.user);

  useEffect(() => {
    if (!user || user.role !== 'HOD') {
      navigate('/login');
    }
  }, [user, navigate]);

  return <Outlet />;
}
