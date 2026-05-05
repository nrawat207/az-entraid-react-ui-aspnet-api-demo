import { login, logout } from '../api';
import type { User } from '../types';
import './Header.css';

interface HeaderProps {
  user: User | null;
  onLogoutSuccess?: () => void;
}

export default function Header({ user, onLogoutSuccess }: HeaderProps) {
  const handleLogout = async () => {
    await logout(window.location.origin);
    onLogoutSuccess?.();
  };

  return (
    <header className="header">
      <div className="header-content">
        <h1>Employee Directory</h1>
        <div className="auth-section">
          {user ? (
            <>
              <span className="user-name">{user.name}</span>
              <button className="logout-btn" onClick={handleLogout}>Logout</button>
            </>
          ) : (
            <button className="login-btn" onClick={login}>Login</button>
          )}
        </div>
      </div>
    </header>
  );
}
