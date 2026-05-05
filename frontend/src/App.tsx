import { useState, useEffect } from 'react';
import Header from './components/Header';
import EmployeePage from './pages/EmployeePage';
import { fetchUser } from './api';
import type { User } from './types';
import './App.css';

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkUser = async () => {
      const userData = await fetchUser();
      setUser(userData);
      setLoading(false);
    };

    checkUser();
  }, []);

  const handleLogoutSuccess = () => {
    setUser(null);
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <>
      <Header user={user} onLogoutSuccess={handleLogoutSuccess} />
      <EmployeePage user={user} />
    </>
  );
}

export default App;
