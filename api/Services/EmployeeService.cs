using api.Models;

namespace api.Services;

public class EmployeeService
{
    public static List<Employee> GetEmployees()
    {
        return new List<Employee>
        {
            new() { Id = 1, Name = "Alice Johnson", Department = "Engineering", Role = "Senior Developer", Location = "San Francisco" },
            new() { Id = 2, Name = "Bob Smith", Department = "Engineering", Role = "DevOps Engineer", Location = "Seattle" },
            new() { Id = 3, Name = "Carol Williams", Department = "Sales", Role = "Account Executive", Location = "New York" },
            new() { Id = 4, Name = "David Brown", Department = "HR", Role = "HR Manager", Location = "Austin" },
            new() { Id = 5, Name = "Eve Davis", Department = "Marketing", Role = "Marketing Manager", Location = "Boston" }
        };
    }
}
