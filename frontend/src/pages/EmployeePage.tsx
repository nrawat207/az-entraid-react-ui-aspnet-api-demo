import { useState, useEffect } from 'react';
import { fetchEmployees, login } from '../api';
import EmployeeTable from '../components/EmployeeTable';
import type { Employee, User } from '../types';
import './EmployeePage.css';

interface EmployeePageProps {
  user: User | null;
}

export default function EmployeePage({ user }: EmployeePageProps) {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadEmployees = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchEmployees();
        setEmployees(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch employees');
      } finally {
        setLoading(false);
      }
    };

    if (user) {
      loadEmployees();
    }
  }, [user]);

  if (!user) {
    return (
      <div className="login-prompt">
        <div className="prompt-content">
          <h2>Welcome to Employee Directory</h2>
          <p>Please log in to view employee information.</p>
          <button className="login-prompt-btn" onClick={login}>Sign in with Entra ID</button>
        </div>
      </div>
    );
  }

  return (
    <div>
      <EmployeeTable employees={employees} loading={loading} error={error} />
    </div>
  );
}
