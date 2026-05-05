import type { Employee } from '../types';
import './EmployeeTable.css';

interface EmployeeTableProps {
  employees: Employee[];
  loading: boolean;
  error: string | null;
}

export default function EmployeeTable({ employees, loading, error }: EmployeeTableProps) {
  if (loading) {
    return <div className="message">Loading employees...</div>;
  }

  if (error) {
    return <div className="message error">Error loading employees: {error}</div>;
  }

  if (!employees || employees.length === 0) {
    return <div className="message">No employees found.</div>;
  }

  return (
    <div className="table-container">
      <table className="employee-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Department</th>
            <th>Role</th>
            <th>Location</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((emp) => (
            <tr key={emp.id}>
              <td>{emp.id}</td>
              <td>{emp.name}</td>
              <td>{emp.department}</td>
              <td>{emp.role}</td>
              <td>{emp.location}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
