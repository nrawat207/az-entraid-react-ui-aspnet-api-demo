using api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace api.Controllers;

[ApiController]
[Route("[controller]")]
public class DepartmentsController(AppDbContext dbContext) : ControllerBase
{
    [Authorize]
    [HttpGet("getDepartmentDetails")]
    public async Task<IActionResult> GetDepartmentDetails()
    {
        var departments = await dbContext.Departments
            .AsNoTracking()
            .OrderBy(department => department.Name)
            .ToListAsync();

        return Ok(departments);
    }
}
