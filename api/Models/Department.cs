namespace api.Models;

public class Department
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public required string Description { get; set; }
    public required string ManagerName { get; set; }
    public required string Location { get; set; }
    public int EmployeeCount { get; set; }
    public DateTime CreatedUtc { get; set; }
}
