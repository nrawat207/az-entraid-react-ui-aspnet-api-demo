using api.Models;
using Microsoft.EntityFrameworkCore;

namespace api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Department> Departments => Set<Department>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Department>(entity =>
        {
            entity.HasKey(department => department.Id);
            entity.Property(department => department.Name).HasMaxLength(100).IsRequired();
            entity.Property(department => department.Description).HasMaxLength(500).IsRequired();
            entity.Property(department => department.ManagerName).HasMaxLength(100).IsRequired();
            entity.Property(department => department.Location).HasMaxLength(100).IsRequired();

            entity.HasData(
                new Department
                {
                    Id = 1,
                    Name = "Engineering",
                    Description = "Builds and operates product features and developer platforms.",
                    ManagerName = "Alice Johnson",
                    Location = "San Francisco",
                    EmployeeCount = 24,
                    CreatedUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                },
                new Department
                {
                    Id = 2,
                    Name = "Sales",
                    Description = "Manages customer relationships, revenue growth, and account planning.",
                    ManagerName = "Carol Williams",
                    Location = "New York",
                    EmployeeCount = 12,
                    CreatedUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                },
                new Department
                {
                    Id = 3,
                    Name = "Human Resources",
                    Description = "Supports hiring, benefits, employee engagement, and workplace policy.",
                    ManagerName = "David Brown",
                    Location = "Austin",
                    EmployeeCount = 8,
                    CreatedUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                }
            );
        });
    }
}
