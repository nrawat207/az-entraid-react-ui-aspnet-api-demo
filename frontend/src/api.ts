import type { Employee, User } from './types';

const BFF_URL = import.meta.env.VITE_BFF_URL || 'https://localhost:5001';

export const fetchUser = async (): Promise<User | null> => {
  try {
    const response = await fetch(`${BFF_URL}/auth/me`, { credentials: 'include' });
    if (response.ok) {
      return await response.json() as User;
    }
    return null;
  } catch (error) {
    console.error('Error fetching user:', error);
    return null;
  }
};

export const login = (): void => {
  window.location.href = `${BFF_URL}/auth/login?returnUrl=${encodeURIComponent(window.location.href)}`;
};

export const logout = async (returnUrl?: string): Promise<void> => {
  try {
    const url = new URL(`${BFF_URL}/auth/logout`);
    if (returnUrl) {
      url.searchParams.append('returnUrl', returnUrl);
    }
    const response = await fetch(url.toString(), { 
      method: 'GET', 
      credentials: 'include' 
    });
    if (response.redirected) {
      window.location.href = response.url;
    } else {
      window.location.href = returnUrl || '/';
    }
  } catch (error) {
    console.error('Error logging out:', error);
    window.location.href = '/';
  }
};

export const fetchEmployees = async (): Promise<Employee[]> => {
  try {
    const response = await fetch(`${BFF_URL}/api/employees`, { credentials: 'include' });
    if (response.ok) {
      return await response.json() as Employee[];
    }
    throw new Error(`HTTP ${response.status}`);
  } catch (error) {
    console.error('Error fetching employees:', error);
    throw error;
  }
};
